class QueueStatus {
  final int? queueNumber;
  final int? estimatedWaitMinutes;
  final String? status;
  final bool? found;
  final int? waitingAhead;
  final String? message;
  final String? patientName;

  const QueueStatus({
    this.queueNumber,
    this.estimatedWaitMinutes,
    this.status,
    this.found,
    this.waitingAhead,
    this.message,
    this.patientName,
  });

  factory QueueStatus.fromJson(Map<String, dynamic> json) => QueueStatus(
        queueNumber: _asInt(json['queueNumber'] ?? json['queue_number']),
        estimatedWaitMinutes:
            _asInt(json['estimatedWaitMinutes'] ?? json['estimated_wait_minutes']),
        status: json['status']?.toString(),
        found: json['found'] as bool?,
        waitingAhead: _asInt(json['waitingAhead'] ?? json['waiting_ahead']),
        message: json['message']?.toString(),
        patientName: json['patientName']?.toString(),
      );

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
