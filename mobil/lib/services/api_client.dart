import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Simple API client wrapper for backend integration.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => _log(obj),
      ),
    );
  }

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late final Dio _dio;

  // Use dart-define to override: --dart-define=API_BASE_URL=https://api.example.com
  // For web (Chrome): use localhost
  // For Android emulator: use 10.0.2.2
  // For iOS simulator: use localhost
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  Dio get client => _dio;

  void _log(Object obj) {
    // Keep logging minimal to avoid noisy console; adjust as needed.
    // ignore: avoid_print
    debugPrint(obj.toString());
  }
}

