import 'package:flutter/material.dart';
import '../exceptions/app_exceptions.dart';

class ErrorDialog extends StatelessWidget {
  final AppException exception;
  final VoidCallback? onRetry;

  const ErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            _getIcon(),
            color: theme.colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exception.message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: exception.details != null
          ? Text(
              exception.details!,
              style: theme.textTheme.bodyMedium,
            )
          : null,
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  IconData _getIcon() {
    if (exception is NetworkException) {
      return Icons.wifi_off_rounded;
    } else if (exception is AuthException) {
      return Icons.lock_outline_rounded;
    } else if (exception is ValidationException) {
      return Icons.warning_amber_rounded;
    } else if (exception is FileException) {
      return Icons.error_outline_rounded;
    } else {
      return Icons.error_outline_rounded;
    }
  }

  /// Show error dialog from exception
  static void show(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        exception: exception,
        onRetry: onRetry,
      ),
    );
  }

  /// Show error dialog from generic error
  static void showFromError(
    BuildContext context,
    dynamic error, {
    String? contextMessage,
    VoidCallback? onRetry,
  }) {
    final appException = handleError(error, context: contextMessage);
    show(context, appException, onRetry: onRetry);
  }
}

/// SnackBar alternative for less critical errors
class ErrorSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showFromException(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
  }) {
    show(
      context,
      exception.details ?? exception.message,
      onRetry: onRetry,
    );
  }
}

/// Success message widget
class SuccessSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
