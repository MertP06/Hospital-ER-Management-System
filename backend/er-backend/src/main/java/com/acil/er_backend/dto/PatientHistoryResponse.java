package com.acil.er_backend.dto;

import com.acil.er_backend.model.Appointment;
import com.acil.er_backend.model.DoctorNote;
import com.acil.er_backend.model.Patient;
import com.acil.er_backend.model.TriageRecord;
import lombok.*;
import java.util.List;
import java.time.LocalDateTime;

@Getter
@NoArgsConstructor
@AllArgsConstructor
public class PatientHistoryResponse {
    @Setter
    private Patient patient;
    @Setter
    private LocalDateTime updatedAt;

    private List<Appointment> appointments;
    private List<TriageRecord> triageRecords;
    private List<DoctorNote> doctorNotes;
    private int totalAppointments;
    private int totalTriageRecords;
    private int totalDoctorNotes;

    public void setAppointments(List<Appointment> appointments) {
        this.appointments = appointments;
        this.totalAppointments = appointments != null ? appointments.size() : 0;
    }

    public void setTriageRecords(List<TriageRecord> triageRecords) {
        this.triageRecords = triageRecords;
        this.totalTriageRecords = triageRecords != null ? triageRecords.size() : 0;
    }

    public void setDoctorNotes(List<DoctorNote> doctorNotes) {
        this.doctorNotes = doctorNotes;
        this.totalDoctorNotes = doctorNotes != null ? doctorNotes.size() : 0;
    }
}
