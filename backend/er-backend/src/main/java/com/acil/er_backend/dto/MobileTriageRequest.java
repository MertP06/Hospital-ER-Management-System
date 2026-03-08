package com.acil.er_backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import lombok.*;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MobileTriageRequest {

    @NotBlank(message = "Ad soyad zorunludur.")
    private String fullName;

    @NotBlank(message = "TC zorunludur.")
    @Pattern(regexp = "^[0-9]{11}$", message = "TC 11 haneli olmalıdır.")
    private String tc;

    @NotEmpty(message = "Semptom listesi boş olamaz.")
    private List<String> symptoms;

    private Integer birthYear;
    private String gender;
    private String chiefComplaint;
}
