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
    return MaterialApp(
      title: 'Photo Organizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StartScreen(),
    );
  }
}
