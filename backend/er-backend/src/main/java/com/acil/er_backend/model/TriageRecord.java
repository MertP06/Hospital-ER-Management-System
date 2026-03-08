package com.acil.er_backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "triage_records", indexes = {
        @Index(name = "idx_triage_appointment_id", columnList = "appointment_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TriageRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "appointment_id")
    private Appointment appointment;

    private String nurseSymptomsCsv;

    private Double temperature;
    private Integer pulse;
    private Integer bpHigh;
    private Integer bpLow;
    private Integer oxygenSaturation;
    private Integer respiratoryRate;
    private Integer painLevel;
    private Integer bloodGlucose;

    private String triageLevel;
    private String aiSuggestedLevel;
    private Integer aiConfidence;

    @Column(columnDefinition = "TEXT")
    private String suggestionsJson;

    @Column(columnDefinition = "TEXT")
    private String notes;

    private String createdBy;
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
