import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class SmartKitApiException implements Exception {
  final int statusCode;
  final String message;

  const SmartKitApiException(this.statusCode, this.message);

  @override
  String toString() => 'SmartKitApiException($statusCode): $message';
}

class SmartKitApiClient {
  SmartKitApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = Uri.parse(baseUrl ?? AppConfig.apiBaseUrl);

  final http.Client _httpClient;
  final Uri _baseUri;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: _headers(accessToken),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(accessToken),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: query,
    );
  }

  Map<String, String> _headers(String? accessToken) {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded =
        response.body.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ?? response.reasonPhrase
              : response.reasonPhrase;
      throw SmartKitApiException(
        response.statusCode,
        message ?? 'Request failed',
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }
}
