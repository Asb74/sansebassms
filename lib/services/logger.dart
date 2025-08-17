import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LoggingService {
  LoggingService._();
  static final LoggingService instance = LoggingService._();

  static const _logFileName = 'app_log.txt';
  static const _maxBytes = 512 * 1024;

  File? _logFile;
  Future<File> get _file async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/$_logFileName');
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }
    return _logFile!;
  }

  Future<void> _write(String level, String message) async {
    final line = '${DateTime.now().toIso8601String()} [$level] $message';
    debugPrint(line);
    try {
      final file = await _file;
      if (await file.length() > _maxBytes) {
        await file.writeAsString('', flush: true);
      }
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  void info(String msg) {
    _write('INFO', msg);
    _sendToCrashlytics(msg);
  }

  void warn(String msg) {
    _write('WARN', msg);
    _sendToCrashlytics(msg);
  }

  void error(String msg, [Object? err, StackTrace? st]) {
    _write('ERROR', '$msg ${err ?? ''}');
    _sendToCrashlytics(msg);
    if (err != null) {
      try {
        FirebaseCrashlytics.instance.recordError(err, st, fatal: false);
      } catch (_) {}
    }
  }

  void _sendToCrashlytics(String msg) {
    try {
      FirebaseCrashlytics.instance.log(msg);
    } catch (_) {}
  }

  Future<String> exportLogFile() async {
    final file = await _file;
    return file.path;
  }
}
