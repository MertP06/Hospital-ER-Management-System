package com.acil.er_backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MobileRegisterRequest {

    @NotBlank(message = "Ad soyad zorunludur.")
    private String fullName;

    @NotBlank(message = "TC zorunludur.")
    @Pattern(regexp = "^[0-9]{11}$", message = "TC 11 haneli olmalıdır.")
    private String tc;

    private Integer birthYear;
    private String gender;
}
