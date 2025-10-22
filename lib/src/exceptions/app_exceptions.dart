/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  AppException(this.message, {this.details, this.originalError});

  @override
  String toString() {
    if (details != null) {
      return '$message: $details';
    }
    return message;
  }
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(super.message, {super.details, super.originalError});

  factory NetworkException.noConnection() {
    return NetworkException(
      'No internet connection',
      details: 'Please check your network settings and try again',
    );
  }

  factory NetworkException.timeout() {
    return NetworkException(
      'Connection timeout',
      details: 'The request took too long to complete',
    );
  }

  factory NetworkException.serverError() {
    return NetworkException(
      'Server error',
      details: 'The server encountered an error. Please try again later',
    );
  }
}

/// Authentication-related exceptions
class AuthException extends AppException {
  AuthException(super.message, {super.details, super.originalError});

  factory AuthException.invalidCredentials() {
    return AuthException(
      'Invalid credentials',
      details: 'The roll number or access code you entered is incorrect',
    );
  }

  factory AuthException.userNotFound() {
    return AuthException(
      'User not found',
      details: 'No account exists with this roll number',
    );
  }

  factory AuthException.notApproved() {
    return AuthException(
      'Account not approved',
      details: 'Your account is pending admin approval',
    );
  }

  factory AuthException.sessionExpired() {
    return AuthException(
      'Session expired',
      details: 'Please log in again to continue',
    );
  }

  factory AuthException.unauthorized() {
    return AuthException(
      'Unauthorized access',
      details: 'You do not have permission to perform this action',
    );
  }
}

/// Database/Supabase-related exceptions
class DatabaseException extends AppException {
  DatabaseException(super.message, {super.details, super.originalError});

  factory DatabaseException.queryFailed() {
    return DatabaseException(
      'Database query failed',
      details: 'Failed to fetch data from the server',
    );
  }

  factory DatabaseException.insertFailed() {
    return DatabaseException(
      'Failed to save data',
      details: 'Could not save your changes. Please try again',
    );
  }

  factory DatabaseException.updateFailed() {
    return DatabaseException(
      'Failed to update data',
      details: 'Could not update the record. Please try again',
    );
  }

  factory DatabaseException.deleteFailed() {
    return DatabaseException(
      'Failed to delete data',
      details: 'Could not delete the record. Please try again',
    );
  }

  factory DatabaseException.notFound() {
    return DatabaseException(
      'Data not found',
      details: 'The requested data could not be found',
    );
  }
}

/// Validation-related exceptions
class ValidationException extends AppException {
  ValidationException(super.message, {super.details, super.originalError});

  factory ValidationException.emptyField(String fieldName) {
    return ValidationException(
      'Required field missing',
      details: '$fieldName cannot be empty',
    );
  }

  factory ValidationException.invalidFormat(String fieldName) {
    return ValidationException(
      'Invalid format',
      details: '$fieldName has an invalid format',
    );
  }

  factory ValidationException.invalidEmail() {
    return ValidationException(
      'Invalid email',
      details: 'Please enter a valid email address',
    );
  }

  factory ValidationException.passwordTooShort() {
    return ValidationException(
      'Password too short',
      details: 'Password must be at least 6 characters',
    );
  }
}

/// File upload-related exceptions
class FileException extends AppException {
  FileException(super.message, {super.details, super.originalError});

  factory FileException.uploadFailed() {
    return FileException(
      'File upload failed',
      details: 'Could not upload the file. Please try again',
    );
  }

  factory FileException.fileTooLarge() {
    return FileException(
      'File too large',
      details: 'The file size exceeds the maximum allowed size',
    );
  }

  factory FileException.unsupportedFormat() {
    return FileException(
      'Unsupported file format',
      details: 'This file type is not supported',
    );
  }

  factory FileException.deleteFailed() {
    return FileException(
      'Failed to delete file',
      details: 'Could not delete the file. Please try again',
    );
  }
}

/// Helper function to convert generic errors to AppExceptions
AppException handleError(dynamic error, {String? context}) {
  if (error is AppException) {
    return error;
  }

  // Handle common error types
  final errorString = error.toString().toLowerCase();

  if (errorString.contains('network') || 
      errorString.contains('socket') || 
      errorString.contains('connection')) {
    return NetworkException.noConnection();
  }

  if (errorString.contains('timeout')) {
    return NetworkException.timeout();
  }

  if (errorString.contains('unauthorized') || errorString.contains('401')) {
    return AuthException.unauthorized();
  }

  if (errorString.contains('not found') || errorString.contains('404')) {
    return DatabaseException.notFound();
  }

  if (errorString.contains('500') || errorString.contains('server error')) {
    return NetworkException.serverError();
  }

  // Default to generic database exception
  return DatabaseException(
    context ?? 'An unexpected error occurred',
    details: error.toString(),
    originalError: error,
  );
}
