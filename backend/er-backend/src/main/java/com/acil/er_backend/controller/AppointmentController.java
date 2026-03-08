package com.acil.er_backend.controller;

import com.acil.er_backend.dto.*;
import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.AppointmentStatus;
import com.acil.er_backend.service.AppointmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointmentService;

    @GetMapping
    public List<Appointment> getToday(@RequestParam(required = false) AppointmentStatus status) {
        if (status != null) {
            return appointmentService.getTodayAppointmentsByStatus(status);
        }
        return appointmentService.getTodayAppointments();
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Appointment>> create(@Valid @RequestBody CreateAppointmentRequest request) {
        Appointment ap = appointmentService.createAppointment(
                request.getPatientTc(), request.getChiefComplaint(), request.getBasicSymptomsCsv());
        return ResponseEntity.ok(ApiResponse.success("Randevu oluşturuldu.", ap));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<ApiResponse<Appointment>> updateStatus(
            @PathVariable Long id, @RequestBody Map<String, String> body) {
        AppointmentStatus status = AppointmentStatus.valueOf(body.get("status"));
        Appointment ap = appointmentService.updateStatus(id, status);
        return ResponseEntity.ok(ApiResponse.success("Durum güncellendi.", ap));
    }

    @GetMapping("/{id}/detail")
    public ResponseEntity<AppointmentDetailResponse> getDetail(@PathVariable Long id) {
        return ResponseEntity.ok(appointmentService.getDetail(id));
    }

    @GetMapping("/by-patient/{tc}")
    public List<Appointment> getByPatient(@PathVariable String tc) {
        return appointmentService.getAppointmentsByPatientTc(tc);
    }

    @GetMapping("/history/{tc}")
    public ResponseEntity<PatientHistoryResponse> getPatientHistory(@PathVariable String tc) {
        return ResponseEntity.ok(appointmentService.getPatientHistory(tc));
    }

    @GetMapping("/dashboard")
    public DashboardStats getDashboard() {
        return appointmentService.getDashboardStats();
    }

    @GetMapping("/waiting-room")
    public WaitingRoomDisplay getWaitingRoom() {
        return appointmentService.getWaitingRoomDisplay();
    }

    @GetMapping("/mobile/queue/{tc}")
    public AppointmentService.MobileQueueStatus getMobileQueue(@PathVariable String tc) {
        return appointmentService.getMobileQueueStatus(tc);
    }
}
