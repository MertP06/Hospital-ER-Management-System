package com.acil.er_backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.*;

@JsonInclude(JsonInclude.Include.NON_NULL)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MobileTriageResponse {
    private Integer queueNumber;
    private Integer estimatedWaitMinutes;
    private Integer urgencyLevel;
    private String urgencyLabel;
    private String responseText;
    private String reasoning;
    private String status;
    private String patientName;
    private Integer waitingAhead;
    private String message;
}
