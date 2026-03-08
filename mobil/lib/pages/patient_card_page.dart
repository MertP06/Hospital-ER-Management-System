import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/storage_service.dart';
import '../services/triage_service.dart';
import '../models/patient.dart';
import '../utils/urgency_helper.dart';

class PatientCardPage extends StatefulWidget {
  const PatientCardPage({super.key});

  @override
  State<PatientCardPage> createState() => _PatientCardPageState();
}

class _PatientCardPageState extends State<PatientCardPage> {
  Patient? _p;
  Map<String, dynamic>? _history;
  bool _loadingHistory = false;
  String _statusFilter = 'ALL';
  bool _sortDesc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Prefer auth patient; fall back to last registered patient
    final p = await StorageService.getAuthPatient() ?? await StorageService.getLastPatient();
    setState(() => _p = p);
    if (p != null) {
      _loadHistory(p.nationalId);
    }
  }

  Future<void> _loadHistory(String tc) async {
    setState(() => _loadingHistory = true);
    try {
      final history = await TriageService().fetchPatientHistory(tc);
      setState(() => _history = history);
    } catch (e) {
      debugPrint('Geçmiş yüklenemedi: $e');
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.patientCardTitle)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3F4FF),
              Color(0xFFF9F5FF),
              Color(0xFFF0FDF4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: p == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.recordNotFound,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(p),
                        const Divider(height: 32),
                        _buildPatientInfo(p),
                        const SizedBox(height: 24),
                        _buildSymptomsInfo(p),
                        if (p.createdAt != null) ...[
                          const SizedBox(height: 24),
                          _buildTimestampInfo(p),
                        ],
                        const SizedBox(height: 24),
                        _buildHistorySection(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Patient p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${AppStrings.nationalId}: ${p.nationalId}",
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusChip(p),
      ],
    );
  }

  Widget _buildPatientInfo(Patient p) {
    final waitTime = p.estimatedWaitMinutes ??
        UrgencyHelper.getEstimatedWaitTime(p.queueNumber);
    final statusText = p.statusMessage ?? p.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.confirmation_number,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              "${AppStrings.queueNumber}:",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              "${p.queueNumber}",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              "${AppStrings.estimatedWait}: ~$waitTime ${AppStrings.minutes}",
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (statusText != null) ...[
          const SizedBox(height: 4),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSymptomsInfo(Patient p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.symptoms,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.symptoms.map((symptom) {
            return Chip(
              label: Text(symptom),
              backgroundColor: AppColors.surfaceVariant,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimestampInfo(Patient p) {
    final dateTime = p.createdAt!;
    final formattedDate = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    final formattedTime = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

    return Row(
      children: [
        const Icon(
          Icons.access_time,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          "Kayıt Tarihi: $formattedDate $formattedTime",
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(Patient p) {
    final status = (p.status ?? '').toUpperCase();
    if (status.isEmpty) return const SizedBox.shrink();

    final color = _statusColor(status);

    return Chip(
      label: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: color,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CALLED':
        return AppColors.success;
      case 'IN_PROGRESS':
        return AppColors.info;
      case 'WAITING':
        return AppColors.warning;
      case 'DONE':
      case 'NO_SHOW':
        return AppColors.textTertiary;
      default:
        return AppColors.primary;
    }
  }

  Color _triageLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'KIRMIZI':
        return AppColors.error;
      case 'SARI':
        return AppColors.warning;
      case 'YESIL':
      case 'YEŞİL':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildHistorySection() {
    if (_loadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_history == null) {
      return const SizedBox.shrink();
    }

    final appointments = _history!['appointments'] as List<dynamic>? ?? [];
    final doctorNotes = _history!['doctorNotes'] as List<dynamic>? ?? [];
    // Backend returns triageRecords as a top-level list, build lookup by appointmentId
    final allTriageRecords = _history!['triageRecords'] as List<dynamic>? ?? [];

    if (appointments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Randevu Geçmişi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildHistoryFilters(),
        const SizedBox(height: 12),
        ..._filterAndSortAppointments(appointments).map((apt) {
          final status = apt['status']?.toString() ?? '';
          final isDone = status == 'DONE';
          final aptId = apt['id'];
          final aptNotes = doctorNotes.where((note) => note['appointment']?['id'] == aptId).toList();
          // Match triage records by appointment id from top-level list
          final triageRecords = allTriageRecords.where((tr) => tr['appointment']?['id'] == aptId).toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.access_time,
                        color: isDone ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sıra: ${apt['queueNumber'] ?? '—'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          _getStatusLabel(status),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: _statusColor(status),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ],
                  ),
                  if (apt['createdAt'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tarih: ${_formatDateTime(apt['createdAt'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (apt['chiefComplaint'] != null && apt['chiefComplaint'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Şikayet: ${apt['chiefComplaint']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildSummaryBadges(
                    complaint: apt['chiefComplaint']?.toString(),
                    hasTriage: triageRecords.isNotEmpty,
                    hasNotes: aptNotes.isNotEmpty,
                  ),
                  if (triageRecords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildTriageSummary(triageRecords),
                  ],
                  if (isDone && aptNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Muayene Sonuçları:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...aptNotes.map((note) => _buildDoctorNoteCard(note)),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTriageSummary(List<dynamic> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Triaj Bilgisi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...records.map((tr) {
          final level = (tr['triageLevel'] ?? '—').toString();
          final symptoms = tr['nurseSymptomsCsv']?.toString();
          final notes = tr['notes']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(
                        level,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: _triageLevelColor(level),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    const SizedBox(width: 8),
                    if (tr['temperature'] != null)
                      Text(
                        'Ateş: ${tr['temperature']}°C',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (symptoms != null && symptoms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Semptomlar: $symptoms',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Not: $notes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDoctorNoteCard(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note['diagnosis'] != null) ...[
            Row(
              children: [
                const Icon(Icons.medical_services, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tanı: ${note['diagnosis']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (note['plan'] != null) ...[
            Text(
              'Plan: ${note['plan']}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (note['prescription'] != null && note['prescription'].toString().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.medication, size: 16, color: AppColors.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Reçete: ${note['prescription']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (note['restDays'] != null && note['restDays'] > 0) ...[
            Row(
              children: [
                const Icon(Icons.bedtime, size: 16, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'İstirahat: ${note['restDays']} gün',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (note['followUpDate'] != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.info),
                const SizedBox(width: 4),
                Text(
                  'Kontrol: ${note['followUpDate']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING':
        return 'Bekliyor';
      case 'CALLED':
        return 'Çağrıldı';
      case 'IN_PROGRESS':
        return 'Muayenede';
      case 'DONE':
        return 'Tamamlandı';
      case 'NO_SHOW':
        return 'Gelmedi';
      default:
        return status;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '—';
    try {
      final str = dateTime.toString();
      if (str.contains('T')) {
        final parts = str.split('T');
        final date = parts[0];
        final time = parts[1].split('.')[0].substring(0, 5);
        return '$date $time';
      }
      return str;
    } catch (e) {
      return dateTime.toString();
    }
  }

  List<dynamic> _filterAndSortAppointments(List<dynamic> appointments) {
    final filtered = appointments.where((apt) {
      if (_statusFilter == 'ALL') return true;
      return (apt['status']?.toString().toUpperCase() ?? '') == _statusFilter;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a['createdAt']?.toString() ?? '';
      final bDate = b['createdAt']?.toString() ?? '';
      final cmp = bDate.compareTo(aDate);
      return _sortDesc ? cmp : -cmp;
    });
    return filtered;
  }

  Widget _buildHistoryFilters() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _statusFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('Tümü')),
            DropdownMenuItem(value: 'WAITING', child: Text('Bekleyen')),
            DropdownMenuItem(value: 'CALLED', child: Text('Çağrılan')),
            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Muayenede')),
            DropdownMenuItem(value: 'DONE', child: Text('Tamamlandı')),
            DropdownMenuItem(value: 'NO_SHOW', child: Text('Gelmedi')),
          ],
          onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => setState(() => _sortDesc = !_sortDesc),
          icon: Icon(
            _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Tarihe göre sırala',
        ),
      ],
    );
  }

  Widget _buildSummaryBadges({
    String? complaint,
    required bool hasTriage,
    required bool hasNotes,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (complaint != null && complaint.isNotEmpty)
          _chip(Icons.chat_bubble_outline, 'Şikayet var'),
        _chip(
          Icons.assignment_turned_in,
          hasTriage ? 'Triaj kaydı var' : 'Triaj yok',
          color: hasTriage ? AppColors.info : AppColors.textSecondary,
        ),
        _chip(
          Icons.note_alt,
          hasNotes ? 'Doktor notu var' : 'Doktor notu yok',
          color: hasNotes ? AppColors.success : AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (color ?? AppColors.textSecondary).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color ?? AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
