package com.acil.er_backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CreateTriageRequest {

    @NotNull(message = "appointmentId boş olamaz.")
    private Long appointmentId;

    @NotBlank(message = "Semptom listesi boş olamaz.")
    private String nurseSymptomsCsv;

    @DecimalMin(value = "30.0")
    @DecimalMax(value = "45.0")
    private Double temperature;

    @Min(20)
    @Max(240)
    private Integer pulse;

    @Min(50)
    @Max(260)
    private Integer bpHigh;

    @Min(30)
    @Max(200)
    private Integer bpLow;

    @Min(50)
    @Max(100)
    private Integer oxygenSaturation;

    @Min(5)
    @Max(60)
    private Integer respiratoryRate;

    @Min(0)
    @Max(10)
    private Integer painLevel;

    @Min(20)
    @Max(600)
    private Integer bloodGlucose;

    @NotBlank(message = "Triage seviyesi boş olamaz.")
    private String triageLevel;

    private String notes;
}
