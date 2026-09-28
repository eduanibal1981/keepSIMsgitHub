/// KeepSIMs — Voicemail Message Model
library;

class VoicemailMessage {
  final String id;
  final String callerNumber;
  final String? callerName;
  final String audioUrl;
  final int durationSeconds;
  final String? transcript;
  final String language;
  final String status;
  final bool isRead;
  final DateTime createdAt;
  final String? aiSummary;
  final String? category;
  final String? translation;

  const VoicemailMessage({
    required this.id,
    required this.callerNumber,
    this.callerName,
    required this.audioUrl,
    required this.durationSeconds,
    this.transcript,
    required this.language,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.aiSummary,
    this.category,
    this.translation,
  });

  factory VoicemailMessage.fromJson(Map<String, dynamic> json) {
    return VoicemailMessage(
      id: json['id'] as String,
      callerNumber: json['caller_number'] as String,
      callerName: json['caller_name'] as String?,
      audioUrl: json['audio_url'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      transcript: json['transcript'] as String?,
      language: json['language'] as String? ?? 'en',
      status: json['status'] as String? ?? 'transcribed',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      aiSummary: json['ai_summary'] as String? ?? json['summary'] as String?,
      category: json['category'] as String?,
      translation: json['translation'] as String?,
    );
  }

  String get durationDisplay {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String? get inferredCountryCode {
    if (callerNumber.startsWith('+968')) return 'OM';
    if (callerNumber.startsWith('+1')) return 'US';
    if (callerNumber.startsWith('+44')) return 'GB';
    if (callerNumber.startsWith('+20')) return 'EG';
    if (callerNumber.startsWith('+971')) return 'AE';
    if (callerNumber.startsWith('+966')) return 'SA';
    return null;
  }
}
