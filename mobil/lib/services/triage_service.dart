import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/queue_status.dart';
import '../models/triage_request.dart';
import '../models/triage_response.dart';
import '../models/triage_rule.dart';
import 'api_client.dart';

class TriageService {
  static final TriageService _i = TriageService._();
  TriageService._();
  factory TriageService() => _i;

  List<TriageRule> _rules = [];
  bool _loaded = false;
  bool _loading = false;

  /// Submit triage to backend. Falls back to local rules if backend fails.
  Future<TriageResponse?> submitTriage(TriageRequest request) async {
    try {
      final res = await ApiClient()
          .client
          .post('/mobile/triage', data: request.toJson());

      final data = res.data;
      if (data is Map<String, dynamic>) {
        return TriageResponse.fromJson(data);
      }
      if (data is Map) {
        return TriageResponse.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      // Check if it's a network error (offline) - use local fallback
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        debugPrint('Backend erişilemiyor, yerel tahmin kullanılıyor...');
        return _localFallback(request);
      }

      // Server responded with error (e.g. 409 conflict)
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : e.message ?? 'Triage isteği başarısız';
      throw Exception(msg);
    } catch (e) {
      // Any other error: try local fallback
      debugPrint('Triage hatası, yerel tahmin deneniyor: $e');
      return _localFallback(request);
    }
  }

  /// Local fallback when backend is unreachable
  Future<TriageResponse?> _localFallback(TriageRequest request) async {
    final rule = await matchBySymptoms(request.symptoms);
    if (rule == null) return null;

    return TriageResponse(
      message: 'Çevrimdışı tahmin: Lütfen internet bağlantınızı kontrol edin.',
      urgencyLevel: rule.urgencyLevel,
      urgencyLabel: rule.urgencyLabel,
      responseText: rule.response,
      reasoning: rule.reasoning,
      queueNumber: null,
      estimatedWaitMinutes: null,
      waitingAhead: 0,
      status: 'OFFLINE',
      patientName: null,
    );
  }

  /// Fetch queue status for a patient tc.
  Future<QueueStatus?> fetchQueueStatus(String tc) async {
    if (tc.isEmpty) return null;
    try {
      final res =
          await ApiClient().client.get('/appointments/mobile/queue/$tc');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return QueueStatus.fromJson(data);
      }
      if (data is Map) {
        return QueueStatus.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      // 404 veya başka hatalar için null döndür (aktif randevu yok demektir)
      if (e.response?.statusCode == 404) {
        return QueueStatus(found: false, message: 'Aktif randevu bulunamadı');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch patient history with appointments, triage records, and doctor notes
  Future<Map<String, dynamic>?> fetchPatientHistory(String tc) async {
    if (tc.isEmpty) return null;
    try {
      final res = await ApiClient().client.get('/appointments/history/$tc');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Hasta geçmişi yüklenemedi: $e');
      return null;
    } catch (e) {
      debugPrint('Hasta geçmişi yüklenemedi: $e');
      return null;
    }
  }

  /// Ensure medical data is loaded
  Future<void> _ensureLoaded() async {
    if (_loaded || _loading) return;
    
    try {
      _loading = true;
      final raw = await rootBundle.loadString('assets/medical_data.json');
      final list = jsonDecode(raw) as List;
      _rules = list.map((e) => TriageRule.fromJson(e)).toList();
      _loaded = true;
    } catch (e) {
      throw Exception('Tıbbi veriler yüklenirken hata oluştu: $e');
    } finally {
      _loading = false;
    }
  }

  /// Match symptoms to find the most appropriate triage rule (offline fallback)
  /// Priority: Most matching symptoms > Higher urgency (lower level number)
  Future<TriageRule?> matchBySymptoms(List<String> picked) async {
    if (picked.isEmpty) return null;
    
    await _ensureLoaded();
    
    if (_rules.isEmpty) return null;

    int bestScore = -1;
    TriageRule? bestRule;

    for (final r in _rules) {
      // Count matching symptoms
      final matchingSymptoms = r.symptoms.where((s) => picked.contains(s)).toList();
      final score = matchingSymptoms.length;
      
      if (score > 0) {
        // If this rule has more matches, or same matches but higher urgency (lower level)
        if (score > bestScore ||
            (score == bestScore &&
                bestRule != null &&
                r.urgencyLevel < bestRule.urgencyLevel)) {
          bestScore = score;
          bestRule = r;
        } else if (bestRule == null) {
          bestScore = score;
          bestRule = r;
        }
      }
    }
    
    return bestRule;
  }

  /// Get all available rules (for debugging/admin purposes)
  Future<List<TriageRule>> getAllRules() async {
    await _ensureLoaded();
    return List.unmodifiable(_rules);
  }

  /// Reset the service (useful for testing)
  void reset() {
    _rules = [];
    _loaded = false;
    _loading = false;
  }
}
