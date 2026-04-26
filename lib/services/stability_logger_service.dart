import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StabilityLoggerService {
  static final Queue<String> _breadcrumbs = ListQueue<String>();
  static const int _maxBreadcrumbs = 80;
  static bool _initialized = false;
  static bool _crashlyticsReady = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _initializeCrashlyticsIfAvailable();

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (_crashlyticsReady) {
        unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
      }
      unawaited(
        recordException(
          details.exception,
          details.stack ?? StackTrace.current,
          context: 'flutter_error',
          fatal: true,
        ),
      );
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_crashlyticsReady) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: true,
            reason: 'platform_dispatcher',
          ),
        );
      }
      unawaited(
        recordException(
          error,
          stack,
          context: 'platform_dispatcher',
          fatal: true,
        ),
      );
      return false;
    };

    addBreadcrumb('logger_initialized');
    await _writeLogLine(
      {
        'ts': DateTime.now().toIso8601String(),
        'type': 'startup',
        'event': 'stability_logger_initialized',
      },
    );
  }

  static void addBreadcrumb(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final item = '${DateTime.now().toIso8601String()} | $trimmed';
    _breadcrumbs.addLast(item);
    while (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log(trimmed);
    }
  }

  static Future<void> recordException(
    Object error,
    StackTrace stack, {
    required String context,
    bool fatal = false,
  }) async {
    if (_crashlyticsReady) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: context,
      );
    }

    await _writeLogLine(
      {
        'ts': DateTime.now().toIso8601String(),
        'type': 'exception',
        'context': context,
        'fatal': fatal,
        'error': error.toString(),
        'stack': stack.toString(),
        'breadcrumbs': _breadcrumbs.toList(growable: false),
      },
    );
  }

  static Future<void> recordEvent(
    String event, {
    Map<String, dynamic>? data,
  }) async {
    addBreadcrumb(event);
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log('event:$event ${data ?? const {}}');
    }
    await _writeLogLine(
      {
        'ts': DateTime.now().toIso8601String(),
        'type': 'event',
        'event': event,
        if (data != null) 'data': data,
      },
    );
  }

  static Future<void> _writeLogLine(Map<String, dynamic> payload) async {
    try {
      final file = await _logFile();
      final line = '${jsonEncode(payload)}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<File> _logFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/stability');
    await dir.create(recursive: true);
    return File('${dir.path}/crash_log.jsonl');
  }

  static Future<void> _initializeCrashlyticsIfAvailable() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _crashlyticsReady = true;
      FirebaseCrashlytics.instance.log('crashlytics_initialized');
    } catch (error, stack) {
      _crashlyticsReady = false;
      await _writeLogLine(
        {
          'ts': DateTime.now().toIso8601String(),
          'type': 'startup',
          'event': 'crashlytics_not_configured',
          'error': error.toString(),
          'stack': stack.toString(),
        },
      );
    }
  }
}
