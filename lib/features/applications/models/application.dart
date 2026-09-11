import 'package:intl/intl.dart';

/// Application model mapped from km-backend ApplicationDetail
class ApplicationItem {
  final String id;
  final String jobId;
  final String recruiterId;
  final String candidateId;
  final String status;
  final String coverLetter;
  final DateTime? createdAt;
  final String jobTitle;
  final String companyName;
  final String cityName;
  final int salaryMin;
  final int salaryMax;
  final String jobType;

  const ApplicationItem({
    required this.id,
    required this.jobId,
    required this.recruiterId,
    required this.candidateId,
    required this.status,
    required this.coverLetter,
    this.createdAt,
    required this.jobTitle,
    required this.companyName,
    required this.cityName,
    this.salaryMin = 0,
    this.salaryMax = 0,
    this.jobType = 'Full-time',
  });

  factory ApplicationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString());
    }

    final jobMap = json['job'] as Map<String, dynamic>? ?? {};

    return ApplicationItem(
      id: json['id']?.toString() ?? '',
      jobId: json['job_id']?.toString() ?? jobMap['id']?.toString() ?? '',
      recruiterId: json['recruiter_id']?.toString() ?? '',
      candidateId: json['candidate_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Applied',
      coverLetter: json['cover_letter']?.toString() ?? '',
      createdAt: parsedDate,
      jobTitle: jobMap['title']?.toString() ?? 'Applied Position',
      companyName: jobMap['company']?.toString() ?? 'Company',
      cityName: jobMap['city_name']?.toString() ?? '',
      salaryMin: (jobMap['salary_min'] as num?)?.toInt() ?? 0,
      salaryMax: (jobMap['salary_max'] as num?)?.toInt() ?? 0,
      jobType: jobMap['job_type']?.toString() ?? 'Full-time',
    );
  }

  String get formattedSalary {
    if (salaryMin <= 0 && salaryMax <= 0) return 'Disclosed on interview';
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return '₹${formatter.format(salaryMin)} - ₹${formatter.format(salaryMax)}';
  }
}
