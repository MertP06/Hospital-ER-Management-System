import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/storage_service.dart';
import '../services/triage_service.dart';
import '../models/patient.dart';
import '../utils/urgency_helper.dart';

class TriageResultPage extends StatefulWidget {
  const TriageResultPage({super.key});

  @override
  State<TriageResultPage> createState() => _TriageResultPageState();
}

class _TriageResultPageState extends State<TriageResultPage> {
  Patient? _p;
  bool _refreshing = false;
  bool _notifyOnUpdate = true;
  int? _lastWait;
  String? _lastStatusText;

  bool get _isFinished {
    final status = (_p?.status ?? '').toUpperCase();
    return status == 'DONE';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await StorageService.getLastPatient();
    final notifyPref = await StorageService.getNotifyPreference();
    setState(() {
      _p = p;
      _notifyOnUpdate = notifyPref;
      _lastWait = p?.estimatedWaitMinutes;
      _lastStatusText = p?.statusMessage ?? p?.status;
    });
  }

  Future<void> _refreshQueue() async {
    final current = await StorageService.getLastPatient();
    if (current == null) return;

    setState(() => _refreshing = true);
    try {
      final status = await TriageService().fetchQueueStatus(current.nationalId);
      if (status == null) return;

      final newWait = status.estimatedWaitMinutes ?? current.estimatedWaitMinutes;
      final newStatusText = status.message ?? status.status ?? current.status;
      final hasChange = (_lastWait != null && newWait != _lastWait) ||
          (_lastStatusText != null && newStatusText != _lastStatusText);

      final updated = current.copyWith(
        queueNumber: status.queueNumber ?? current.queueNumber,
        estimatedWaitMinutes:
            status.estimatedWaitMinutes ?? current.estimatedWaitMinutes,
        status: status.status ?? current.status,
        statusMessage: status.message ?? current.statusMessage,
      );
      await StorageService.saveLastPatient(updated);
      setState(() {
        _p = updated;
        _lastWait = updated.estimatedWaitMinutes;
        _lastStatusText = updated.statusMessage ?? updated.status;
      });

      if (_notifyOnUpdate && hasChange) {
        _playAlert();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.triageResultTitle),
      ),
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
                      Icons.info_outline,
                      size: 64,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.noRecordYet,
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
                child: Column(
                  children: [
                    if (_isCalled(p)) _buildCalledBanner(),
                    if (_isFinished) _buildFinishedBanner(),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.fullName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                _buildStatusChip(p),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.badge,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${AppStrings.nationalId}: ${p.nationalId}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (p.createdAt != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${AppStrings.createdAt}: ${_formatDateTime(p.createdAt!)}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            _buildSymptomsSection(p),
                            const Divider(height: 32),
                            _buildQueueSection(p),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _refreshing ? null : _refreshQueue,
                                    icon: _refreshing
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.refresh),
                                    label: Text(
                                      _refreshing
                                          ? 'Güncelleniyor...'
                                          : 'Sırayı Güncelle',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Switch(
                                  value: _notifyOnUpdate,
                                  onChanged: (v) async {
                                    setState(() => _notifyOnUpdate = v);
                                    await StorageService.saveNotifyPreference(v);
                                  },
                                  activeColor: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Bekleme süresi değişince sesli uyarı',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSymptomsSection(Patient p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.symptoms,
          style: TextStyle(
            fontSize: 16,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQueueSection(Patient p) {
    final waitTime = p.estimatedWaitMinutes ??
        UrgencyHelper.getEstimatedWaitTime(p.queueNumber);
    final statusText = p.statusMessage ?? p.status;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.confirmation_number,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                "${AppStrings.queueNumber}:",
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${p.queueNumber}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (statusText != null) ...[
            const SizedBox(height: 12),
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
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

  Widget _buildCalledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.campaign, color: AppColors.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sıranız geldi! Lütfen muayene odasına geçiniz.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  AppStrings.triageFinishedTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppStrings.triageFinishedDesc,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isCalled(Patient p) {
    final status = (p.status ?? '').toUpperCase();
    return status == 'CALLED';
  }

  void _playAlert() {
    SystemSound.play(SystemSoundType.alert);
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
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
}
