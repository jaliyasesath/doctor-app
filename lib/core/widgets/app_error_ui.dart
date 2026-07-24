import 'package:flutter/material.dart';

import '../errors/app_exception.dart';

class AppErrorUiModel {
  const AppErrorUiModel({
    required this.message,
    required this.isRetryable,
    required this.requiresLogin,
  });

  final String message;
  final bool isRetryable;
  final bool requiresLogin;

  factory AppErrorUiModel.fromError(Object error) {
    if (error is AppException) {
      final reference = error.traceId == null || error.traceId!.isEmpty
          ? ''
          : '\nReference: ${error.traceId}';
      return AppErrorUiModel(
        message: '${error.userMessage}$reference',
        isRetryable: error.isRetryable,
        requiresLogin: error.requiresLogin,
      );
    }

    return const AppErrorUiModel(
      message: 'Something went wrong. Please try again.',
      isRetryable: true,
      requiresLogin: false,
    );
  }
}

class AppErrorUi {
  AppErrorUi._();

  static void show(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
    VoidCallback? onLogin,
  }) {
    final model = AppErrorUiModel.fromError(error);
    final action = model.requiresLogin && onLogin != null
        ? SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.white,
            onPressed: onLogin,
          )
        : model.isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(model.message)),
            ],
          ),
          action: action,
          backgroundColor: const Color(0xFF9F2D2D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }
}
