package com.acil.er_backend.controller;

import com.acil.er_backend.dto.ApiResponse;
import com.acil.er_backend.dto.CreateTriageRequest;
import com.acil.er_backend.model.TriageRecord;
import com.acil.er_backend.service.TriageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/triage")
@RequiredArgsConstructor
public class TriageController {

    private final TriageService triageService;

    @PostMapping
    public ResponseEntity<ApiResponse<TriageRecord>> create(@Valid @RequestBody CreateTriageRequest request) {
        TriageRecord record = triageService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Triaj kaydı oluşturuldu.", record));
    }

    @GetMapping("/by-appointment/{appointmentId}")
    public List<TriageRecord> getByAppointment(@PathVariable Long appointmentId) {
        return triageService.listByAppointment(appointmentId);
    }
}
