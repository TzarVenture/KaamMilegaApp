import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A short message tone: the phone's own notification sound (Android) or
/// the system message sound (iOS), played by a few lines of native code in
/// MainActivity / AppDelegate, so no audio package or sound file is added.
/// Silent / vibrate mode is respected by the phone. Nothing on the web.
class NotificationSound {
  NotificationSound._();

  static const _channel = MethodChannel('com.kaammilega.app/sound');

  /// Several messages at once: one tone.
  static const minGap = Duration(seconds: 2);
  static DateTime? _last;

  static Future<void> play() async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < minGap) return;
    _last = now;
    try {
      await _channel.invokeMethod<void>('playNotification');
    } catch (_) {
      // No native handler (tests, desktop): stay silent.
    }
  }
}

/// Plays the message tone (replaced in tests).
final notificationSoundProvider = Provider<Future<void> Function()>(
  (ref) => NotificationSound.play,
);
