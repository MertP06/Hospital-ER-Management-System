package com.acil.er_backend.dto;

import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.DoctorNote;
import com.acil.er_backend.model.Patient;
import com.acil.er_backend.model.TriageRecord;
import lombok.*;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class AppointmentDetailResponse {
    private Appointment appointment;
    private Patient patient;
    private List<TriageRecord> triageRecords;
    private List<DoctorNote> doctorNotes;
}
