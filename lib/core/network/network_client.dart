import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';

/// Centralized HTTP client with consistent timeouts + error translation.
///
/// Security guarantees enforced here (defense-in-depth on top of platform
/// network-security-config / ATS):
///   * Refuses non-HTTPS URIs.
///   * Caps response body size to prevent DoS via giant payloads.
///   * Maps low-level IO exceptions to a small, sanitized [AppException]
///     hierarchy so raw error text never reaches the UI.
class NetworkClient {
  static const int _maxResponseBytes = 5 * 1024 * 1024; // 5 MB

  final http.Client _client;
  final Duration timeout;

  NetworkClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Performs a GET request and returns the decoded JSON body.
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    if (uri.scheme != 'https') {
      throw RemoteException('Refusing non-HTTPS request to ${uri.host}.');
    }
    try {
      final response = await _client.get(uri).timeout(timeout);
      _ensureSuccess(response, uri);
      if (response.bodyBytes.length > _maxResponseBytes) {
        throw RemoteException('Response too large from ${uri.path}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw RemoteException('Unexpected response shape from ${uri.path}.');
      }
      return decoded;
    } on TimeoutException {
      throw const RemoteException('Request timed out.');
    } on SocketException {
      throw const OfflineException();
    } on HandshakeException {
      throw const RemoteException('Secure connection failed.');
    } on HttpException catch (e) {
      throw RemoteException(e.message);
    } on FormatException {
      throw RemoteException('Malformed JSON from ${uri.path}.');
    } on RemoteException {
      rethrow;
    } catch (_) {
      // Never surface raw exception text to the caller — it can leak
      // implementation details (paths, libraries, IP addresses).
      throw const RemoteException('Network error.');
    }
  }

  void _ensureSuccess(http.Response response, Uri uri) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    throw RemoteException('HTTP $code for ${uri.path}');
  }

  void dispose() => _client.close();
}
