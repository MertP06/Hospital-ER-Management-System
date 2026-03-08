package com.acil.er_backend.dto;

import lombok.*;
import java.util.Map;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class DashboardStats {
    private int totalToday;
    private int waiting;
    private int called;
    private int inProgress;
    private int done;
    private int noShow;
    private int doneLastHour;
    private Map<String, Integer> triageLevels;
    private Double avgWaitTime;
}
