package com.acil.er_backend.service;

import com.acil.er_backend.dto.*;
import com.acil.er_backend.model.*;
import com.acil.er_backend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class AppointmentServiceImpl implements AppointmentService {

    private final AppointmentRepository appointmentRepo;
    private final PatientRepository patientRepo;
    private final TriageRecordRepository triageRepo;
    private final DoctorNoteRepository noteRepo;

    @Override
    @Transactional
    public Appointment createAppointment(String patientTc, String chiefComplaint, String basicSymptomsCsv) {
        Patient patient = patientRepo.findByTc(patientTc)
                .orElseThrow(() -> new NoSuchElementException("Hasta bulunamadı: " + patientTc));

        int nextQueue = appointmentRepo.findTodayMaxQueueNumber(LocalDate.now()) + 1;

        // Weighted wait time: consider triage-based priority
        List<Appointment> waitingList = getTodayAppointmentsByStatus(AppointmentStatus.WAITING);
        int estimatedWait = calculateWeightedWaitTime(waitingList);

        Appointment ap = new Appointment();
        ap.setPatient(patient);
        ap.setQueueNumber(nextQueue);
        ap.setAppointmentDate(LocalDate.now());
        ap.setStatus(AppointmentStatus.WAITING);
        ap.setChiefComplaint(chiefComplaint);
        ap.setEstimatedWaitMinutes(estimatedWait);
        ap.setBasicSymptomsCsv(basicSymptomsCsv);
        ap.setCreatedAt(LocalDateTime.now());

        return appointmentRepo.save(ap);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Appointment> getTodayAppointments() {
        return appointmentRepo.findByAppointmentDateOrderByQueueNumberAsc(LocalDate.now());
    }

    @Override
    @Transactional(readOnly = true)
    public List<Appointment> getTodayAppointmentsByStatus(AppointmentStatus status) {
        return appointmentRepo.findByAppointmentDateAndStatusOrderByQueueNumberAsc(LocalDate.now(), status);
    }

    @Override
    @Transactional
    public Appointment updateStatus(Long id, AppointmentStatus status) {
        Appointment ap = appointmentRepo.findById(id)
                .orElseThrow(() -> new NoSuchElementException("Randevu bulunamadı: " + id));

        ap.setStatus(status);
        if (status == AppointmentStatus.CALLED) {
            ap.setCalledAt(LocalDateTime.now());
        } else if (status == AppointmentStatus.IN_PROGRESS) {
            ap.setStartedAt(LocalDateTime.now());
        } else if (status == AppointmentStatus.DONE || status == AppointmentStatus.NO_SHOW) {
            ap.setCompletedAt(LocalDateTime.now());
        }

        return appointmentRepo.save(ap);
    }

    @Override
    @Transactional(readOnly = true)
    public AppointmentDetailResponse getDetail(Long id) {
        Appointment ap = appointmentRepo.findById(id)
                .orElseThrow(() -> new NoSuchElementException("Randevu bulunamadı: " + id));

        AppointmentDetailResponse resp = new AppointmentDetailResponse();
        resp.setAppointment(ap);
        resp.setPatient(ap.getPatient());
        resp.setTriageRecords(triageRepo.findByAppointment_IdOrderByCreatedAtDesc(id));
        resp.setDoctorNotes(noteRepo.findByAppointment_IdOrderByCreatedAtDesc(id));

        return resp;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Appointment> getAppointmentsByPatientTc(String tc) {
        return appointmentRepo.findAllByPatientTcOrderByCreatedAtDesc(tc);
    }

    @Override
    @Transactional(readOnly = true)
    public PatientHistoryResponse getPatientHistory(String tc) {
        Patient patient = patientRepo.findByTc(tc)
                .orElseThrow(() -> new NoSuchElementException("Hasta bulunamadı: " + tc));

        PatientHistoryResponse resp = new PatientHistoryResponse();
        resp.setPatient(patient);
        resp.setAppointments(appointmentRepo.findAllByPatientTcOrderByCreatedAtDesc(tc));
        resp.setTriageRecords(triageRepo.findAllByPatientTcOrderByCreatedAtDesc(tc));
        resp.setDoctorNotes(noteRepo.findAllByPatientTcOrderByCreatedAtDesc(tc));
        resp.setUpdatedAt(LocalDateTime.now());

        return resp;
    }

    @Override
    @Transactional(readOnly = true)
    public DashboardStats getDashboardStats() {
        List<Appointment> today = getTodayAppointments();

        DashboardStats stats = new DashboardStats();
        stats.setTotalToday(today.size());
        stats.setWaiting((int) today.stream().filter(a -> a.getStatus() == AppointmentStatus.WAITING).count());
        stats.setCalled((int) today.stream().filter(a -> a.getStatus() == AppointmentStatus.CALLED).count());
        stats.setInProgress((int) today.stream().filter(a -> a.getStatus() == AppointmentStatus.IN_PROGRESS).count());
        stats.setDone((int) today.stream().filter(a -> a.getStatus() == AppointmentStatus.DONE).count());
        stats.setNoShow((int) today.stream().filter(a -> a.getStatus() == AppointmentStatus.NO_SHOW).count());

        // Fix N+1: fetch all triage records for today's appointments in a single query
        List<Long> appointmentIds = today.stream().map(Appointment::getId).toList();
        List<TriageRecord> triages = appointmentIds.isEmpty()
                ? List.of()
                : triageRepo.findByAppointmentIdIn(appointmentIds);

        Map<String, Integer> levels = new HashMap<>();
        for (TriageRecord tr : triages) {
            String level = tr.getTriageLevel() != null ? tr.getTriageLevel() : "BELIRSIZ";
            levels.put(level, levels.getOrDefault(level, 0) + 1);
        }
        stats.setTriageLevels(levels);

        double totalWait = 0;
        int waitCount = 0;
        for (Appointment ap : today) {
            Long wait = ap.getActualWaitMinutes();
            if (wait != null) {
                totalWait += wait;
                waitCount++;
            }
        }
        stats.setAvgWaitTime(waitCount > 0 ? totalWait / waitCount : null);

        stats.setDoneLastHour(
                Math.toIntExact(
                        appointmentRepo.countByStatusAndCompletedAtAfter(
                                AppointmentStatus.DONE,
                                LocalDateTime.now().minusHours(1))));

        return stats;
    }

    @Override
    @Transactional(readOnly = true)
    public WaitingRoomDisplay getWaitingRoomDisplay() {
        WaitingRoomDisplay display = new WaitingRoomDisplay();
        List<Appointment> called = getTodayAppointmentsByStatus(AppointmentStatus.CALLED);
        if (!called.isEmpty()) {
            Appointment current = called.get(0);
            WaitingRoomDisplay.CurrentCall call = new WaitingRoomDisplay.CurrentCall();
            call.setQueueNumber(current.getQueueNumber());
            String name = current.getPatient().getName();
            String[] parts = name.split(" ");
            String maskedName = parts[0] + " " + (parts.length > 1 ? parts[parts.length - 1].charAt(0) + "***" : "");
            call.setPatientName(maskedName);
            call.setMessage("Lütfen muayene odasına geçiniz");
            display.setCurrentCall(call);
        }

        List<Appointment> waiting = getTodayAppointmentsByStatus(AppointmentStatus.WAITING);
        List<WaitingRoomDisplay.WaitingPatient> list = new ArrayList<>();
        for (int i = 0; i < waiting.size(); i++) {
            Appointment ap = waiting.get(i);
            WaitingRoomDisplay.WaitingPatient wp = new WaitingRoomDisplay.WaitingPatient();
            wp.setQueueNumber(ap.getQueueNumber());
            wp.setStatus("Bekliyor");
            wp.setAheadCount(i);
            list.add(wp);
        }
        display.setWaitingList(list);
        display.setTotalWaiting(waiting.size());
        display.setLastUpdated(LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss")));

        return display;
    }

    @Override
    @Transactional(readOnly = true)
    public MobileQueueStatus getMobileQueueStatus(String tc) {
        MobileQueueStatus status = new MobileQueueStatus();

        Optional<Appointment> opt = appointmentRepo.findTodayActiveByTc(tc, LocalDate.now());
        if (opt.isEmpty()) {
            status.setFound(false);
            status.setMessage("Bugün için aktif randevunuz bulunmamaktadır.");
            return status;
        }

        Appointment ap = opt.get();
        status.setFound(true);
        status.setQueueNumber(ap.getQueueNumber());
        status.setStatus(ap.getStatus().name());
        status.setPatientName(ap.getPatient().getName());
        status.setEstimatedWaitMinutes(ap.getEstimatedWaitMinutes());

        if (ap.getStatus() == AppointmentStatus.CALLED) {
            status.setWaitingAhead(0);
            status.setMessage("Sıranız geldi! Lütfen muayene odasına geçiniz.");
        } else if (ap.getStatus() == AppointmentStatus.IN_PROGRESS) {
            status.setWaitingAhead(0);
            status.setMessage("Muayeneniz devam ediyor.");
        } else {
            long ahead = appointmentRepo.countWaitingAhead(LocalDate.now(), AppointmentStatus.WAITING,
                    ap.getQueueNumber());
            status.setWaitingAhead((int) ahead);
            status.setMessage("Sıranızı bekliyorsunuz. Önünüzde " + ahead + " kişi var.");
        }

        return status;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Appointment> findTodayActiveByTc(String tc) {
        return appointmentRepo.findTodayActiveByTc(tc, LocalDate.now());
    }

    /**
     * Weighted wait time calculation considering triage levels.
     * Red (KIRMIZI) patients are prioritized, so green patients wait longer.
     */
    private int calculateWeightedWaitTime(List<Appointment> waitingList) {
        if (waitingList.isEmpty())
            return 0;

        int totalMinutes = 0;
        for (Appointment ap : waitingList) {
            // Check if there's any triage record for this appointment
            List<TriageRecord> triages = triageRepo.findByAppointment_IdOrderByCreatedAtDesc(ap.getId());
            if (!triages.isEmpty()) {
                String level = triages.get(0).getTriageLevel();
                if ("KIRMIZI".equalsIgnoreCase(level)) {
                    totalMinutes += 5; // Red patients are seen quickly
                } else if ("SARI".equalsIgnoreCase(level)) {
                    totalMinutes += 10; // Yellow patients moderate wait
                } else {
                    totalMinutes += 15; // Green patients standard wait
                }
            } else {
                totalMinutes += 15; // Default if no triage yet
            }
        }
        return totalMinutes;
    }
}
