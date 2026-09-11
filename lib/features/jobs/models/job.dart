import 'package:intl/intl.dart';

/// Job Model directly mapped from km-backend MongoDB schema
class Job {
  final String id;
  final String recruiterId;
  final String title;
  final String description;
  final String company;
  final String cityId;
  final String cityName;
  final String location;
  final int salaryMin;
  final int salaryMax;
  final String jobType;
  final String status;
  final List<String> requirements;
  final List<String> weOffer;
  final String gender;
  final String education;
  final int experienceMin;
  final int experienceMax;
  final int vacancies;
  final int applicantCount;
  final DateTime? createdAt;

  const Job({
    required this.id,
    required this.recruiterId,
    required this.title,
    required this.description,
    required this.company,
    required this.cityId,
    required this.cityName,
    required this.location,
    required this.salaryMin,
    required this.salaryMax,
    required this.jobType,
    required this.status,
    required this.requirements,
    required this.weOffer,
    required this.gender,
    required this.education,
    required this.experienceMin,
    required this.experienceMax,
    this.vacancies = 1,
    this.applicantCount = 0,
    this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString());
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return Job(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      recruiterId: json['recruiter_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Job Opportunity',
      description: json['description']?.toString() ?? '',
      company: json['company']?.toString() ?? 'KaamMilega Partner',
      cityId: json['city_id']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? 'All India',
      location: json['location']?.toString() ?? '',
      salaryMin: (json['salary_min'] as num?)?.toInt() ?? 0,
      salaryMax: (json['salary_max'] as num?)?.toInt() ?? 0,
      jobType: json['job_type']?.toString() ?? 'Full-time',
      status: json['status']?.toString() ?? 'open',
      requirements: parseStringList(json['requirements']),
      weOffer: parseStringList(json['we_offer']),
      gender: json['gender']?.toString() ?? '',
      education: json['education']?.toString() ?? '',
      experienceMin: (json['experience_min'] as num?)?.toInt() ?? 0,
      experienceMax: (json['experience_max'] as num?)?.toInt() ?? 0,
      vacancies: (json['vacancies'] as num?)?.toInt() ?? 1,
      applicantCount: (json['applicant_count'] as num?)?.toInt() ?? 0,
      createdAt: parsedDate,
    );
  }

  /// Formatted salary string, e.g. "₹20,000 - ₹30,000" or "Negotiable"
  String get formattedSalary {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    if (salaryMin <= 0 && salaryMax <= 0) return 'Disclosed on interview';
    if (salaryMin > 0 && salaryMax > 0) {
      return '₹${formatter.format(salaryMin)} - ₹${formatter.format(salaryMax)}';
    }
    if (salaryMin > 0) return '₹${formatter.format(salaryMin)}+ / Month';
    return 'Up to ₹${formatter.format(salaryMax)} / Month';
  }

  /// Formatted experience string, e.g. "0-2 Yrs" or "Fresher"
  String get formattedExperience {
    if (experienceMin == 0 && experienceMax == 0) return 'Fresher';
    if (experienceMin == experienceMax) return '$experienceMin Yrs';
    return '$experienceMin-$experienceMax Yrs';
  }

  /// Formatted location string, e.g. "Andheri East, Mumbai"
  String get formattedLocation {
    if (location.isNotEmpty && cityName.isNotEmpty) {
      return '$location, $cityName';
    }
    return location.isNotEmpty ? location : cityName;
  }
}
