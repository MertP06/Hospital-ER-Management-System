package com.acil.er_backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "patients")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Patient {

    @Id
    @Column(length = 11)
    @NotBlank(message = "TC kimlik numarası boş olamaz")
    @Pattern(regexp = "^[0-9]{11}$", message = "TC kimlik numarası 11 haneli olmalıdır")
    private String tc;

    @NotBlank(message = "İsim boş olamaz")
    private String name;

    private Integer birthYear;

    @Pattern(regexp = "^[EK]$", message = "Cinsiyet E veya K olmalıdır")
    private String gender;

    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
