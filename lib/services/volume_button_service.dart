import 'package:flutter/services.dart';

/// Stuurt een event bij elke fysieke volumeknop-druk (iOS), zodat de
/// volumeknop als camerasluiter gebruikt kan worden.
///
/// De native kant (AppDelegate.swift) begint pas met luisteren zodra er een
/// abonnee is op deze stream, en stopt weer bij annuleren — zo blijft de
/// audio-sessie alleen actief wanneer de camera open is.
class VolumeButtonService {
  static const EventChannel _channel = EventChannel('blueprint/volume_button');

  /// Emits (zonder waarde) telkens als een volumeknop wordt ingedrukt.
  static Stream<void> get presses =>
      _channel.receiveBroadcastStream().map<void>((_) {});
}
