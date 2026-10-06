/// Who blocked whom between the signed-in user and another person
/// (GET /chats/users/:id/block-status). While either is true, neither can
/// message the other (the server refuses).
class ChatBlockStatus {
  const ChatBlockStatus({
    this.blockedByMe = false,
    this.blockedByOther = false,
  });

  /// The signed-in user blocked the other person (they can unblock).
  final bool blockedByMe;

  /// The other person blocked the signed-in user.
  final bool blockedByOther;

  static const none = ChatBlockStatus();

  bool get isBlocked => blockedByMe || blockedByOther;

  factory ChatBlockStatus.fromJson(Map<String, dynamic> json) =>
      ChatBlockStatus(
        blockedByMe: json['is_blocked_by_me'] == true,
        blockedByOther: json['is_blocked_by_other'] == true,
      );
}
