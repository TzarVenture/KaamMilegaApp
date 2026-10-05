import 'package:flutter/foundation.dart';

/// The person whose chat is open on screen (null when no chat is open).
///
/// Used to keep the in-app notification banner quiet for messages from the
/// person the user is already chatting with.
class ActiveChat {
  ActiveChat._();

  static final ValueNotifier<String?> partnerId = ValueNotifier<String?>(null);

  static void enter(String userId) {
    if (userId.isNotEmpty) partnerId.value = userId;
  }

  /// Clears only if [userId]'s chat is still the open one (another chat may
  /// have opened on top already).
  static void leave(String userId) {
    if (partnerId.value == userId) partnerId.value = null;
  }
}
