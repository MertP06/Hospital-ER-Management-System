package com.acil.er_backend.service;

import com.acil.er_backend.dto.CreateTriageRequest;
import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.TriageRecord;
import com.acil.er_backend.repository.AppointmentRepository;
import com.acil.er_backend.repository.TriageRecordRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TriageServiceImpl implements TriageService {

    private final AppointmentRepository appointmentRepository;
    private final TriageRecordRepository triageRecordRepository;
    private final MedicalInferenceService medicalInferenceService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    @Transactional
    public TriageRecord create(CreateTriageRequest req) {
        Appointment ap = appointmentRepository.findById(req.getAppointmentId())
                .orElseThrow(() -> new NoSuchElementException("Randevu bulunamadı: " + req.getAppointmentId()));

        TriageRecord tr = new TriageRecord();
        tr.setAppointment(ap);
        tr.setNurseSymptomsCsv(req.getNurseSymptomsCsv());
        tr.setTemperature(req.getTemperature());
        tr.setPulse(req.getPulse());
        tr.setBpHigh(req.getBpHigh());
        tr.setBpLow(req.getBpLow());
        tr.setOxygenSaturation(req.getOxygenSaturation());
        tr.setRespiratoryRate(req.getRespiratoryRate());
        tr.setPainLevel(req.getPainLevel());
        tr.setBloodGlucose(req.getBloodGlucose());
        tr.setTriageLevel(req.getTriageLevel());
        tr.setNotes(req.getNotes());
        tr.setCreatedAt(LocalDateTime.now());

        try {
            tr.setCreatedBy(SecurityContextHolder.getContext().getAuthentication().getName());
        } catch (Exception e) {
            tr.setCreatedBy("system");
        }

        // Use centralized MedicalInferenceService instead of duplicating scoring logic
        List<String> symptoms = parseCsv(req.getNurseSymptomsCsv());
        try {
            List<Map<String, Object>> top5 = medicalInferenceService.suggestTop5(symptoms);
            if (!top5.isEmpty()) {
                tr.setSuggestionsJson(objectMapper.writeValueAsString(top5));
                int maxUrgency = top5.stream()
                        .mapToInt(s -> {
                            Object level = s.get("urgency_level");
                            return level != null ? Integer.parseInt(level.toString()) : 0;
                        })
                        .max().orElse(0);
                tr.setAiSuggestedLevel(maxUrgency >= 4 ? "KIRMIZI" : maxUrgency >= 3 ? "SARI" : "YESIL");
                tr.setAiConfidence((int) Math.min(100, 50 + top5.size() * 10));
            }
        } catch (Exception e) {
            log.warn("Tıbbi öneri oluşturulamadı: {}", e.getMessage());
        }

        return triageRecordRepository.save(tr);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TriageRecord> listByAppointment(Long appointmentId) {
        return triageRecordRepository.findByAppointment_IdOrderByCreatedAtDesc(appointmentId);
    }

    private List<String> parseCsv(String csv) {
        if (csv == null || csv.isBlank())
            return List.of();
        return Arrays.stream(csv.split(",")).map(String::trim).filter(s -> !s.isBlank()).collect(Collectors.toList());
    }
}
