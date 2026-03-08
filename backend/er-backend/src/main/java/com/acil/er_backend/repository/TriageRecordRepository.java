package com.acil.er_backend.repository;

import com.acil.er_backend.model.TriageRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface TriageRecordRepository extends JpaRepository<TriageRecord, Long> {

    List<TriageRecord> findByAppointment_IdOrderByCreatedAtDesc(Long appointmentId);

    @Query("SELECT t FROM TriageRecord t WHERE t.appointment.patient.tc = :tc ORDER BY t.createdAt DESC")
    List<TriageRecord> findAllByPatientTcOrderByCreatedAtDesc(@Param("tc") String tc);

    @Query("SELECT t FROM TriageRecord t WHERE t.appointment.id IN :appointmentIds")
    List<TriageRecord> findByAppointmentIdIn(@Param("appointmentIds") List<Long> appointmentIds);
}
