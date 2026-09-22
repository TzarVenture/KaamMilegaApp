/// Base Application Exception for KaamMilega
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Offline or network connection failure (DNS failure, socket error, connection reset)
class AppNetworkException extends AppException {
  const AppNetworkException([
    super.message =
        'No internet connection. Please check your network settings.',
    String? code = 'NETWORK_ERROR',
    dynamic originalError,
  ]) : super(code: code, originalError: originalError);
}

/// Connection, send, or receive timeout
class AppTimeoutException extends AppException {
  const AppTimeoutException([
    super.message =
        'Connection timed out. Please check your internet connection.',
    String? code = 'TIMEOUT',
    dynamic originalError,
  ]) : super(code: code, originalError: originalError);
}

/// Server returned a 5xx error or is temporarily unavailable
class AppServerException extends AppException {
  final int? statusCode;

  const AppServerException([
    super.message =
        'Server is temporarily unavailable. Please try again shortly.',
    this.statusCode,
    String? code = 'SERVER_ERROR',
    dynamic originalError,
  ]) : super(code: code, originalError: originalError);
}

/// Authentication or Authorization failure (401 / 403 / Token expired)
class AppAuthException extends AppException {
  final int? statusCode;

  const AppAuthException([
    super.message = 'Session expired or unauthorized. Please sign in again.',
    this.statusCode = 401,
    String? code = 'AUTH_ERROR',
    dynamic originalError,
  ]) : super(code: code, originalError: originalError);
}

/// Resource not found (404)
class AppNotFoundException extends AppException {
  const AppNotFoundException([
    super.message = 'Requested resource was not found.',
    String? code = 'NOT_FOUND',
    dynamic originalError,
  ]) : super(code: code, originalError: originalError);
}

/// Validation / Bad Request failure (400 / 422)
class AppValidationException extends AppException {
  final Map<String, dynamic>? validationErrors;

  const AppValidationException(
    super.message, {
    this.validationErrors,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
  });
}
