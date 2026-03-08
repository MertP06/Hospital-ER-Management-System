package com.acil.er_backend.dto;

import lombok.*;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class WaitingRoomDisplay {
    private CurrentCall currentCall;
    private List<WaitingPatient> waitingList;
    private int totalWaiting;
    private String lastUpdated;

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CurrentCall {
        private Integer queueNumber;
        private String patientName;
        private String message;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class WaitingPatient {
        private Integer queueNumber;
        private String status;
        private int aheadCount;
    }
}
