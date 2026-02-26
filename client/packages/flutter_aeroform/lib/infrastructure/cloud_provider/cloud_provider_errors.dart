import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error thrown when cloud provider API returns an error response
class CloudProviderAPIError implements Exception {
  final int statusCode;
  final String message;
  final List<String> errors;
  final String? rawResponse;

  CloudProviderAPIError({
    required this.statusCode,
    required this.message,
    this.errors = const [],
    this.rawResponse,
  });

  /// Creates error from HTTP response
  factory CloudProviderAPIError.fromResponse(http.Response response) {
    String message = 'Request failed';
    final List<String> errors = [];

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      message = json['errors'] != null
          ? (json['errors'] as List).join(', ')
          : json['error']?.toString() ?? message;
      if (json['errors'] is List) {
        errors.addAll((json['errors'] as List).map((e) => e.toString()));
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : 'Unknown error';
    }

    return CloudProviderAPIError(
      statusCode: response.statusCode,
      message: message,
      errors: errors,
      rawResponse: response.body,
    );
  }

  /// Returns user-friendly error message based on status code
  String getUserFriendlyMessage() {
    switch (statusCode) {
      case 400:
        return 'Invalid configuration: $message';
      case 401:
        return 'Authentication failed. Please sign in again.';
      case 402:
        return 'Insufficient account balance. Please add funds to your Linode account.';
      case 403:
        return 'Access denied. Please check your permissions.';
      case 404:
        return 'Resource not found.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
        return 'Service temporarily unavailable. Please try again.';
      default:
        return 'Request failed: $message';
    }
  }

  @override
  String toString() =>
      'CloudProviderAPIError[$statusCode]: $message (${errors.join(', ')})';
}

/// Error thrown during OAuth token exchange or refresh
class OAuthError implements Exception {
  final String? errorCode;
  final String message;
  final String? rawResponse;

  OAuthError({
    this.errorCode,
    required this.message,
    this.rawResponse,
  });

  /// Creates error from OAuth HTTP response
  factory OAuthError.fromResponse(http.Response response) {
    String errorCode = 'unknown_error';
    String message = 'OAuth request failed';

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = json['error']?.toString() ?? errorCode;
      message = json['error_description']?.toString() ?? message;
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    return OAuthError(
      errorCode: errorCode,
      message: message,
      rawResponse: response.body,
    );
  }

  /// Returns user-friendly error message based on OAuth error code
  String getUserFriendlyMessage() {
    switch (errorCode) {
      case 'invalid_grant':
        return 'The authorization code has expired or has already been used.';
      case 'access_denied':
        return 'Access was denied. Please try again.';
      case 'unauthorized_client':
        return 'This client is not authorized to request tokens.';
      case 'unsupported_grant_type':
        return 'The grant type is not supported.';
      default:
        return 'Authentication failed: $message';
    }
  }

  @override
  String toString() => 'OAuthError[$errorCode]: $message';
}