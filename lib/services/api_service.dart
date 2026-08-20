import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/last_readings.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final List<String>? details;

  ApiException(this.message, [this.statusCode, this.details]);

  @override
  String toString() {
    if (details == null || details!.isEmpty) return message;
    return '$message\n${details!.join('\n')}';
  }
}

class ApiService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}/$path').replace(queryParameters: query);
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> login(String pin) async {
    final res = await http.post(
      _uri('login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    );
    final data = _tryDecode(res.body);
    if (data == null) {
      throw ApiException('Neplatna odpoved zo servera.', res.statusCode);
    }
    return data;
  }

  static Future<LastReadings> fetchLastReadings() async {
    final res = await http.get(_uri('readings.php', {'last': '1'}));
    final data = _tryDecode(res.body);

    // Uspesna odpoved neobsahuje 'success' vobec (iba pln/ele/vod kluce),
    // takze o chybu ide len ked je explicitne 'success': false.
    if (data == null || data['success'] == false) {
      throw ApiException(
        data?['error'] as String? ?? 'Chyba pri nacitani poslednych hodnot.',
        res.statusCode,
      );
    }

    return LastReadings.fromJson(data);
  }

  static Future<void> createReading(Map<String, dynamic> payload) async {
    final res = await http.post(
      _uri('readings.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final data = _tryDecode(res.body);
    if (data == null) {
      throw ApiException('Neplatna odpoved zo servera.', res.statusCode);
    }

    if (data['success'] == true) {
      return;
    }

    if (data['details'] is List) {
      final details = (data['details'] as List).map((e) => e.toString()).toList();
      final message = data['message'] as String? ?? 'Validacia zlyhala.';
      throw ApiException(message, res.statusCode, details);
    }

    final message = data['error'] as String? ?? 'Neznama chyba pri ukladani.';
    throw ApiException(message, res.statusCode);
  }
}
