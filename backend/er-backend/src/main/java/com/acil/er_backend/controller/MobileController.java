package com.acil.er_backend.controller;

import com.acil.er_backend.dto.MobileRegisterRequest;
import com.acil.er_backend.dto.MobileTriageRequest;
import com.acil.er_backend.dto.MobileTriageResponse;
import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.Patient;
import com.acil.er_backend.service.AppointmentService;
import com.acil.er_backend.service.MedicalInferenceService;
import com.acil.er_backend.service.PatientService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/mobile")
@RequiredArgsConstructor
@Slf4j
public class MobileController {

    private final PatientService patientService;
    private final AppointmentService appointmentService;
    private final MedicalInferenceService medicalInferenceService;

    @PostMapping("/patient/register")
    public ResponseEntity<Map<String, Object>> registerPatient(@Valid @RequestBody MobileRegisterRequest req) {
        if (patientService.existsByTc(req.getTc())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("message", "Bu TC ile kayıtlı hasta zaten mevcut. Lütfen giriş yapın."));
        }
        Patient newPatient = new Patient();
        newPatient.setTc(req.getTc());
        newPatient.setName(req.getFullName());
        newPatient.setBirthYear(req.getBirthYear());
        newPatient.setGender(req.getGender());
        patientService.savePatient(newPatient);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "Hasta başarıyla kaydedildi.", "patient", newPatient));
    }

    @PostMapping("/patient/login")
    public ResponseEntity<Map<String, Object>> loginPatient(@RequestBody Map<String, String> loginReq) {
        String tc = loginReq.get("tc");
        String name = loginReq.get("name");

        if (tc == null || tc.isBlank() || name == null || name.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("message", "TC ve isim boş olamaz."));
        }

        Optional<Patient> patientOpt = patientService.getPatientByTc(tc);
        if (patientOpt.isPresent() && patientOpt.get().getName().equalsIgnoreCase(name)) {
            return ResponseEntity.ok(Map.of("message", "Giriş başarılı.", "patient", patientOpt.get()));
        }
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("message", "Geçersiz TC veya isim."));
    }

    @PostMapping("/triage")
    public ResponseEntity<MobileTriageResponse> submitTriage(@Valid @RequestBody MobileTriageRequest req) {
        Patient patient = patientService.getPatientByTc(req.getTc())
                .orElseThrow(() -> new NoSuchElementException("Hasta bulunamadı: " + req.getTc()));

        // Check for active appointment - now via service layer (not direct repo)
        var existingAppointment = appointmentService.findTodayActiveByTc(req.getTc());
        if (existingAppointment.isPresent()) {
            Appointment active = existingAppointment.get();
            MobileTriageResponse resp = new MobileTriageResponse();
            resp.setMessage(String.format(
                    "Zaten aktif bir randevunuz bulunmaktadır. Sıra No: %d, Durum: %s. Lütfen mevcut randevunuz tamamlanana kadar yeni randevu oluşturmayın.",
                    active.getQueueNumber(),
                    active.getStatus().name()));
            resp.setQueueNumber(active.getQueueNumber());
            resp.setStatus(active.getStatus().name());
            resp.setEstimatedWaitMinutes(active.getEstimatedWaitMinutes());
            return ResponseEntity.status(HttpStatus.CONFLICT).body(resp);
        }

        String basicSymptomsCsv = req.getSymptoms() != null ? String.join(",", req.getSymptoms()) : null;

        Appointment appointment = appointmentService.createAppointment(
                req.getTc(),
                buildChiefComplaint(req),
                basicSymptomsCsv);

        MobileTriageResponse resp = new MobileTriageResponse();

        // Use centralized MedicalInferenceService (no duplicate logic)
        enrichWithInference(resp, req.getSymptoms());

        var queue = appointmentService.getMobileQueueStatus(patient.getTc());
        resp.setQueueNumber(queue.getQueueNumber() != null
                ? queue.getQueueNumber()
                : appointment.getQueueNumber());
        resp.setEstimatedWaitMinutes(queue.getEstimatedWaitMinutes() != null
                ? queue.getEstimatedWaitMinutes()
                : appointment.getEstimatedWaitMinutes());
        resp.setWaitingAhead(queue.getWaitingAhead());
        resp.setStatus(queue.getStatus() != null ? queue.getStatus() : appointment.getStatus().name());
        resp.setPatientName(queue.getPatientName() != null ? queue.getPatientName() : patient.getName());
        resp.setMessage(queue.getMessage());

        return ResponseEntity.ok(resp);
    }

    /**
     * Uses centralized MedicalInferenceService instead of duplicating scoring
     * logic.
     */
    private void enrichWithInference(MobileTriageResponse resp, List<String> symptoms) {
        if (symptoms == null || symptoms.isEmpty()) {
            setDefaultUrgency(resp);
            return;
        }

        List<Map<String, Object>> top5 = medicalInferenceService.suggestTop5(symptoms);
        if (top5 != null && !top5.isEmpty()) {
            Map<String, Object> best = top5.get(0);
            resp.setUrgencyLevel(parseInt(best.get("urgency_level"), 3));
            resp.setUrgencyLabel(str(best.get("urgency_label"), "BELIRSIZ"));
            resp.setResponseText(str(best.get("response"),
                    "Belirtileriniz kaydedildi. Lütfen acil serviste bekleyiniz."));
            resp.setReasoning(str(best.get("reasoning"), null));
        } else {
            setDefaultUrgency(resp);
        }
    }

    private void setDefaultUrgency(MobileTriageResponse resp) {
        resp.setUrgencyLevel(3);
        resp.setUrgencyLabel("DEGERLENDIRME");
        resp.setResponseText("Belirtileriniz kaydedildi. Lütfen acil serviste bekleyiniz.");
    }

    private String buildChiefComplaint(MobileTriageRequest req) {
        if (req.getChiefComplaint() != null && !req.getChiefComplaint().isBlank()) {
            return req.getChiefComplaint();
        }
        List<String> symptoms = req.getSymptoms();
        if (symptoms == null || symptoms.isEmpty())
            return "Mobil kayıt";
        return String.join(", ", symptoms);
    }

    private int parseInt(Object val, int fallback) {
        try {
            if (val == null)
                return fallback;
            return Integer.parseInt(val.toString());
        } catch (Exception e) {
            return fallback;
        }
    }

    private String str(Object v, String fallback) {
        return v != null ? v.toString() : fallback;
    }
}
