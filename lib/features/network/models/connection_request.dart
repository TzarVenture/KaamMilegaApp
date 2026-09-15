/// Model representing a candidate connection request from km-backend
class ConnectionRequestItem {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConnectionRequestItem({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ConnectionRequestItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return ConnectionRequestItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
