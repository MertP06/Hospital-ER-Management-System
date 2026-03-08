package com.acil.er_backend.service;

import com.acil.er_backend.dto.*;
import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.AppointmentStatus;
import lombok.*;
import java.util.List;
import java.util.Optional;

public interface AppointmentService {
    Appointment createAppointment(String patientTc, String chiefComplaint, String basicSymptomsCsv);

    List<Appointment> getTodayAppointments();

    List<Appointment> getTodayAppointmentsByStatus(AppointmentStatus status);

    Appointment updateStatus(Long id, AppointmentStatus status);

    AppointmentDetailResponse getDetail(Long id);

    List<Appointment> getAppointmentsByPatientTc(String tc);

    PatientHistoryResponse getPatientHistory(String tc);

    DashboardStats getDashboardStats();

    WaitingRoomDisplay getWaitingRoomDisplay();

    MobileQueueStatus getMobileQueueStatus(String tc);

    Optional<Appointment> findTodayActiveByTc(String tc);

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    class MobileQueueStatus {
        private boolean found;
        private Integer queueNumber;
        private String status;
        private int waitingAhead;
        private Integer estimatedWaitMinutes;
        private String patientName;
        private String message;
    }
}
