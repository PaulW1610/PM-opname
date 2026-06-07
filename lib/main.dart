import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/start_screen.dart';
import 'services/stability_logger_service.dart';

/// Entrypoint for the Photo Organizer app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Delay telemetry until after the first frame so startup can paint immediately.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeStabilityLogging());
  });
}

Future<void> _initializeStabilityLogging() async {
  try {
    await StabilityLoggerService.initialize();
    StabilityLoggerService.addBreadcrumb('main_started');
  } catch (_) {}
}

/// The root widget for the application.
class MyApp extends StatelessWidget {
  /// Creates the top-level application widget.
  const MyApp({Key? key}) : super(key: key);

  @override
  /// Build the [MaterialApp] used as the app shell.
  @override
  Widget build(BuildContext context) {
    const azureBlue = Color(0xFF006FAF);
    return MaterialApp(
      title: 'blueprint collective',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: azureBlue),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2F3A1F),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azureBlue,
            foregroundColor: Colors.white,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: azureBlue,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: azureBlue,
            foregroundColor: Colors.white,
            side: const BorderSide(color: azureBlue),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: azureBlue,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: azureBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const StartScreen(),
    );
  }
}
