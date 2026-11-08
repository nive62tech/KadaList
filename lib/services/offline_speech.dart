import 'package:flutter/services.dart';

/// Android owns microphone capture and runs whisper.cpp in this process.
/// No system speech service or network fallback is used.
class OfflineSpeech {
  const OfflineSpeech();
  static const channel = MethodChannel('kadalist/offline_speech');

  Future<bool> hasModel() async =>
      await channel.invokeMethod<bool>('hasModel') ?? false;
  Future<bool> importModel() async =>
      await channel.invokeMethod<bool>('importModel') ?? false;
  Future<void> start(String language) =>
      channel.invokeMethod<void>('start', {'language': language});
  Future<String> stop() async =>
      await channel.invokeMethod<String>('stop') ?? '';
  Future<void> cancel() => channel.invokeMethod<void>('cancel');
}
