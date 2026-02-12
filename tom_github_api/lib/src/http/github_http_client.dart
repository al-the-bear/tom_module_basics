import 'dart:convert';

import 'package:http/http.dart' as http;

import '../github_exception.dart';
import '../models/github_rate_limit.dart';

/// Internal HTTP wrapper that adds authentication, content headers,
/// rate limit tracking, and error handling to all GitHub API requests.
class GitHubHttpClient {
  final String _token;
  final http.Client _httpClient;
  final String _baseUrl;

  GitHubRateLimit? _lastRateLimit;

  GitHubHttpClient({
    required String token,
    required http.Client httpClient,
    required String baseUrl,
  })  : _token = token,
        _httpClient = httpClient,
        _baseUrl = baseUrl;

  /// Rate limit info from the most recent response.
  GitHubRateLimit? get lastRateLimit => _lastRateLimit;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// GET request, returning parsed JSON.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(path, queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// GET request returning the raw [http.Response] (for pagination).
  Future<http.Response> getRaw(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(path, queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    _updateRateLimit(response.headers);
    _checkForErrors(response);
    return response;
  }

  /// GET request from a full URL (for following pagination links).
  Future<http.Response> getUrl(String url) async {
    final uri = Uri.parse(url);
    final response = await _httpClient.get(uri, headers: _headers);
    _updateRateLimit(response.headers);
    _checkForErrors(response);
    return response;
  }

  /// POST request, returning parsed JSON.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// POST request returning raw [http.Response] (for array responses).
  Future<http.Response> postRaw(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    _updateRateLimit(response.headers);
    _checkForErrors(response);
    return response;
  }

  /// PATCH request, returning parsed JSON.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.patch(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request. Returns void.
  Future<void> delete(String path) async {
    final uri = _buildUri(path);
    final response = await _httpClient.delete(uri, headers: _headers);
    _updateRateLimit(response.headers);
    if (response.statusCode >= 400) {
      _throwException(response);
    }
  }

  /// POST request that expects 204 No Content (e.g., workflow dispatch).
  Future<void> postNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    _updateRateLimit(response.headers);
    if (response.statusCode >= 400) {
      _throwException(response);
    }
  }

  void close() {
    _httpClient.close();
  }

  // --- Internals ---

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$base$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    _updateRateLimit(response.headers);

    if (response.statusCode >= 400) {
      _throwException(response);
    }

    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _checkForErrors(http.Response response) {
    if (response.statusCode >= 400) {
      _throwException(response);
    }
  }

  Never _throwException(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = {'message': response.body};
    }
    throw GitHubException.fromResponse(
      response.statusCode,
      body,
      headers: response.headers,
    );
  }

  void _updateRateLimit(Map<String, String> headers) {
    if (headers.containsKey('x-ratelimit-limit')) {
      _lastRateLimit = GitHubRateLimit.fromHeaders(headers);
    }
  }
}

/// Parse the `Link` header from a paginated response.
///
/// Returns a map of rel -> url, e.g. `{'next': '...', 'last': '...'}`.
Map<String, String> parseLinkHeader(String? linkHeader) {
  if (linkHeader == null || linkHeader.isEmpty) return {};
  final links = <String, String>{};
  for (final part in linkHeader.split(',')) {
    final match = RegExp(r'<([^>]+)>;\s*rel="([^"]+)"').firstMatch(part.trim());
    if (match != null) {
      links[match.group(2)!] = match.group(1)!;
    }
  }
  return links;
}
