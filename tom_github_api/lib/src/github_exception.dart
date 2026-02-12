import 'models/github_rate_limit.dart';

/// Base exception for all GitHub API errors.
class GitHubException implements Exception {
  final int statusCode;
  final String message;
  final String? documentationUrl;
  final Map<String, dynamic>? responseBody;

  const GitHubException({
    required this.statusCode,
    required this.message,
    this.documentationUrl,
    this.responseBody,
  });

  factory GitHubException.fromResponse(
    int statusCode,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    final message = body['message'] as String? ?? 'Unknown error';
    final docUrl = body['documentation_url'] as String?;

    // Distinguish 403 causes
    if (statusCode == 403 && headers != null) {
      final remaining = headers['x-ratelimit-remaining'];
      if (remaining == '0') {
        return GitHubRateLimitException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
          rateLimit: GitHubRateLimit.fromHeaders(headers),
        );
      }
    }

    return switch (statusCode) {
      401 => GitHubAuthException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
        ),
      403 => GitHubAuthException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
        ),
      404 => GitHubNotFoundException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
        ),
      422 => GitHubValidationException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
          errors: (body['errors'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>(),
        ),
      _ => GitHubException(
          statusCode: statusCode,
          message: message,
          documentationUrl: docUrl,
          responseBody: body,
        ),
    };
  }

  @override
  String toString() => 'GitHubException($statusCode): $message';
}

/// 404 Not Found.
class GitHubNotFoundException extends GitHubException {
  const GitHubNotFoundException({
    required super.statusCode,
    required super.message,
    super.documentationUrl,
    super.responseBody,
  });

  @override
  String toString() => 'GitHubNotFoundException($statusCode): $message';
}

/// 401 Unauthorized / 403 Forbidden (not rate limit).
class GitHubAuthException extends GitHubException {
  const GitHubAuthException({
    required super.statusCode,
    required super.message,
    super.documentationUrl,
    super.responseBody,
  });

  @override
  String toString() => 'GitHubAuthException($statusCode): $message';
}

/// 422 Unprocessable Entity — validation errors.
class GitHubValidationException extends GitHubException {
  final List<Map<String, dynamic>>? errors;

  const GitHubValidationException({
    required super.statusCode,
    required super.message,
    super.documentationUrl,
    super.responseBody,
    this.errors,
  });

  @override
  String toString() => 'GitHubValidationException($statusCode): $message';
}

/// 403 Rate Limit Exceeded.
class GitHubRateLimitException extends GitHubException {
  final GitHubRateLimit rateLimit;

  const GitHubRateLimitException({
    required super.statusCode,
    required super.message,
    super.documentationUrl,
    super.responseBody,
    required this.rateLimit,
  });

  @override
  String toString() =>
      'GitHubRateLimitException: $message (resets at ${rateLimit.resetAt})';
}
