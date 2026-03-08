package com.acil.er_backend.controller;

import com.acil.er_backend.service.MedicalDataService;
import com.acil.er_backend.service.MedicalInferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/medical")
@RequiredArgsConstructor
public class MedicalController {

    private final MedicalDataService medicalDataService;
    private final MedicalInferenceService inferenceService;

    @GetMapping("/symptoms")
    public Set<String> getAllSymptoms() {
        return medicalDataService.getAllSymptoms();
    }

    @GetMapping("/data")
    public List<Map<String, Object>> getAllData() {
        return medicalDataService.getRecords();
    }

    @PostMapping("/search")
    public List<Map<String, Object>> search(@RequestBody Map<String, Object> body) {
        return inferenceService.suggestTop5(extractSymptoms(body));
    }

    @PostMapping("/suggest")
    public List<Map<String, Object>> suggest(@RequestBody Map<String, Object> body) {
        return inferenceService.suggestTop5(extractSymptoms(body));
    }

    @PostMapping("/infer")
    public List<Map<String, Object>> infer(@RequestBody Map<String, Object> body) {
        return inferenceService.suggestTop5(extractSymptoms(body));
    }

    private List<String> extractSymptoms(Map<String, Object> body) {
        Object symptomsObj = body.get("symptoms");
        if (symptomsObj instanceof List<?> list) {
            List<String> symptoms = new ArrayList<>();
            for (Object s : list) {
                if (s != null)
                    symptoms.add(s.toString());
            }
            return symptoms;
        }
        return List.of();
    }
}
