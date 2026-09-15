import 'package:intl/intl.dart';

/// Interview model mapped from km-backend InterviewDetail
class InterviewItem {
  final String id;
  final String applicationId;
  final String recruiterId;
  final String candidateId;
  final DateTime? scheduledAt;
  final String type;
  final String location;
  final String status;
  final String notes;
  final String jobTitle;
  final String companyName;
  final String recruiterName;
  final String recruiterEmail;
  final DateTime? createdAt;

  const InterviewItem({
    required this.id,
    required this.applicationId,
    required this.recruiterId,
    required this.candidateId,
    this.scheduledAt,
    this.type = 'Phone',
    this.location = '',
    this.status = 'Scheduled',
    this.notes = '',
    required this.jobTitle,
    required this.companyName,
    this.recruiterName = '',
    this.recruiterEmail = '',
    this.createdAt,
  });

  factory InterviewItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    final jobMap = json['job'] as Map<String, dynamic>? ?? {};
    final recruiterMap = json['recruiter'] as Map<String, dynamic>? ?? {};

    return InterviewItem(
      id: json['id']?.toString() ?? '',
      applicationId: json['application_id']?.toString() ?? '',
      recruiterId: json['recruiter_id']?.toString() ?? '',
      candidateId: json['candidate_id']?.toString() ?? '',
      scheduledAt: parseDate(json['scheduled_at']),
      type: json['type']?.toString() ?? 'Phone',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Scheduled',
      notes: json['notes']?.toString() ?? '',
      jobTitle: jobMap['title']?.toString() ?? 'Interview Position',
      companyName: jobMap['company']?.toString() ?? 'Recruiting Company',
      recruiterName: recruiterMap['name']?.toString() ?? '',
      recruiterEmail: recruiterMap['email']?.toString() ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }

  String get formattedScheduleDate {
    if (scheduledAt == null) return 'Date TBD';
    return DateFormat('EEE, d MMM yyyy • h:mm a').format(scheduledAt!);
  }
}
