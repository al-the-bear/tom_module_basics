import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

/// Creates a mock HTTP client that returns predefined responses.
///
/// Usage:
/// ```dart
/// final client = createMockClient({
///   'GET /repos/owner/repo/issues/42': MockResponse(
///     200, issueJson,
///   ),
/// });
/// ```
http.Client createMockClient(
  Map<String, MockResponse> responses, {
  MockResponse? defaultResponse,
}) {
  return http_testing.MockClient((request) async {
    final key = '${request.method} ${request.url.path}';

    // Try exact match first
    var mock = responses[key];

    // Try with query parameters
    if (mock == null) {
      final keyWithQuery = request.url.query.isNotEmpty
          ? '$key?${request.url.query}'
          : key;
      mock = responses[keyWithQuery];
    }

    // Try pattern matching (for paths with dynamic segments)
    if (mock == null) {
      for (final entry in responses.entries) {
        if (_pathMatches(entry.key, key)) {
          mock = entry.value;
          break;
        }
      }
    }

    mock ??= defaultResponse ??
        MockResponse(404, {'message': 'Not Found: $key'});

    return http.Response(
      mock.body is String ? mock.body as String : jsonEncode(mock.body),
      mock.statusCode,
      headers: mock.headers,
    );
  });
}

bool _pathMatches(String pattern, String actual) {
  // Simple pattern matching: the pattern key format is "METHOD /path"
  // For now, exact match only
  return pattern == actual;
}

/// A predefined response for the mock HTTP client.
class MockResponse {
  final int statusCode;
  final dynamic body; // String or Map/List (will be JSON-encoded)
  final Map<String, String> headers;

  MockResponse(
    this.statusCode,
    this.body, {
    Map<String, String>? headers,
  }) : headers = {
          'content-type': 'application/json',
          ...?headers,
        };

  /// Create a response with standard rate limit headers.
  MockResponse.withRateLimit(
    this.statusCode,
    this.body, {
    int limit = 5000,
    int remaining = 4999,
    int resetEpoch = 0,
    Map<String, String>? extraHeaders,
  }) : headers = {
          'content-type': 'application/json',
          'x-ratelimit-limit': limit.toString(),
          'x-ratelimit-remaining': remaining.toString(),
          'x-ratelimit-reset': resetEpoch.toString(),
          ...?extraHeaders,
        };
}
