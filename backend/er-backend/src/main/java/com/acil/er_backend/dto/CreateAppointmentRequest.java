package com.acil.er_backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CreateAppointmentRequest {

    @NotBlank(message = "TC kimlik numarası boş olamaz")
    private String patientTc;

    private String chiefComplaint;

    private String basicSymptomsCsv;
}
