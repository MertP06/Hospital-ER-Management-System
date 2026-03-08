package com.acil.er_backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

@Entity
@Table(name = "appointments", indexes = {
        @Index(name = "idx_appointment_date", columnList = "appointmentDate"),
        @Index(name = "idx_appointment_status", columnList = "status"),
        @Index(name = "idx_appointment_date_status", columnList = "appointmentDate, status"),
        @Index(name = "idx_appointment_patient_tc", columnList = "patient_tc")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "patient_tc", referencedColumnName = "tc")
    private Patient patient;

    private Integer queueNumber;
    private LocalDate appointmentDate;

    @Enumerated(EnumType.STRING)
    private AppointmentStatus status = AppointmentStatus.WAITING;

    private String chiefComplaint;
    private Integer estimatedWaitMinutes;

    @Column(length = 4096)
    private String basicSymptomsCsv;

    private LocalDateTime createdAt;
    private LocalDateTime calledAt;
    private LocalDateTime startedAt;
    private LocalDateTime completedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        appointmentDate = LocalDate.now();
    }

    public Long getActualWaitMinutes() {
        if (calledAt != null && createdAt != null) {
            return ChronoUnit.MINUTES.between(createdAt, calledAt);
        }
        return null;
    }
}
