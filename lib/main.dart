import 'package:flutter/material.dart';
import 'screens/start_screen.dart';

/// Entrypoint for the Photo Organizer app.
void main() {
  runApp(const MyApp());
}

/// The root widget for the application.
class MyApp extends StatelessWidget {
  /// Creates the top-level application widget.
  const MyApp({Key? key}) : super(key: key);

  @override
  /// Build the [MaterialApp] used as the app shell.
  @override
  Widget build(BuildContext context) {
    const olive = Color(0xFF6B7A3A);
    return MaterialApp(
      title: 'PM Realestate Data & Visuals',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: olive),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2F3A1F),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: olive,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: olive,
            foregroundColor: Colors.white,
            side: const BorderSide(color: olive),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: olive,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const StartScreen(),
    );
  }
}
