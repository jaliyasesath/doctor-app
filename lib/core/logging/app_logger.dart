import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

class AppLogger {
  AppLogger._();

  static const int _maximumBytes = 1024 * 1024;
  static const int _bytesToKeep = 512 * 1024;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> info(
    String message, {
    String source = 'App',
  }) {
    return _enqueue('INFO', message, source: source);
  }

  static Future<void> warning(
    String message, {
    String source = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    return _enqueue(
      'WARN',
      message,
      source: source,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> error(
    Object error,
    StackTrace stackTrace, {
    String source = 'App',
    String? context,
  }) {
    return _enqueue(
      'ERROR',
      context ?? 'Unhandled error',
      source: source,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<String?> getLogFilePath() async {
    try {
      return (await _logFile()).path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _logFile();
      if (await file.exists()) await file.writeAsString('');
    } catch (_) {
      // Logging must never crash the application.
    }
  }

  static Future<void> _enqueue(
    String level,
    String message, {
    required String source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _writeQueue = _writeQueue
        .then((_) => _write(
              level,
              message,
              source: source,
              error: error,
              stackTrace: stackTrace,
            ))
        .catchError((_) {
      // Logging failures are intentionally swallowed.
    });

    return _writeQueue;
  }

  static Future<void> _write(
    String level,
    String message, {
    required String source,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final file = await _logFile();
    await _trimIfRequired(file);

    final buffer = StringBuffer()
      ..writeln(
          '${DateTime.now().toUtc().toIso8601String()} [$level] [$source]')
      ..writeln(_singleLine(message));

    if (error is AppException) {
      buffer
        ..writeln('Code: ${error.code}')
        ..writeln('Status: ${error.statusCode ?? '-'}')
        ..writeln('TraceId: ${error.traceId ?? '-'}')
        ..writeln('Error: ${_singleLine(error.message)}');
    } else if (error != null) {
      buffer.writeln('Error: ${_singleLine(error.toString())}');
    }
    if (stackTrace != null) buffer.writeln('Stack: $stackTrace');
    buffer.writeln('---');

    await file.writeAsString(
      buffer.toString(),
      mode: FileMode.append,
      flush: level == 'ERROR',
    );
  }

  static Future<File> _logFile() async {
    final directory = await getApplicationSupportDirectory();
    final logDirectory =
        Directory('${directory.path}${Platform.pathSeparator}logs');
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    return File(
        '${logDirectory.path}${Platform.pathSeparator}doctor_app_errors.log');
  }

  static Future<void> _trimIfRequired(File file) async {
    if (!await file.exists()) return;
    if (await file.length() <= _maximumBytes) return;

    final bytes = await file.readAsBytes();
    final start = bytes.length > _bytesToKeep ? bytes.length - _bytesToKeep : 0;
    var retained = utf8.decode(bytes.sublist(start), allowMalformed: true);
    final firstLineBreak = retained.indexOf('\n');
    if (firstLineBreak >= 0) retained = retained.substring(firstLineBreak + 1);
    await file.writeAsString(retained, flush: true);
  }

  static String _singleLine(String value) {
    return value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  }
}
