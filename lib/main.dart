import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/start_screen.dart';
import 'services/stability_logger_service.dart';
import 'theme/brand.dart';

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
  Widget build(BuildContext context) {
    const navy = BrandColors.navy;
    const orange = BrandColors.orange;
    return MaterialApp(
      title: 'blueprint collective',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
          secondary: orange,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            side: const BorderSide(color: navy),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: navy,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: orange,
          foregroundColor: Colors.white,
        ),
      ),
      home: const StartScreen(),
    );
  }
}
