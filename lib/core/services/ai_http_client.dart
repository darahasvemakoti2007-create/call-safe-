import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Clean HTTP transport contract for remote AI and Speech-to-Text calls.
///
/// Enables dependency injection and deterministic testing without
/// third-party HTTP package dependencies or live internet requirements.
abstract class AIHttpClient {
  Future<String> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  });
}

/// Standard [AIHttpClient] implementation using dart:io [HttpClient].
class DefaultAIHttpClient implements AIHttpClient {
  const DefaultAIHttpClient();

  @override
  Future<String> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url).timeout(timeout);
      headers.forEach((k, v) => request.headers.set(k, v));
      request.add(utf8.encode(body));
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      }
      throw HttpException('HTTP ${response.statusCode}: $responseBody', uri: url);
    } finally {
      client.close();
    }
  }
}
