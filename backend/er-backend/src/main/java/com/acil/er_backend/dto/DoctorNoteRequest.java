package com.acil.er_backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;
import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class DoctorNoteRequest {

    @NotNull(message = "appointmentId boş olamaz.")
    private Long appointmentId;

    @NotBlank(message = "Tanı boş olamaz.")
    private String diagnosis;

    private String secondaryDiagnosis;

    @NotBlank(message = "Plan boş olamaz.")
    private String plan;

    private String prescription;
    private String labOrders;
    private LocalDate followUpDate;
    private String followUpNotes;
    private Boolean referralNeeded;
    private String referralDepartment;

    @Min(0)
    @Max(365)
    private Integer restDays;
}
