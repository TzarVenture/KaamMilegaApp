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

  /// True when the employer gave a salary.
  bool get hasSalary => salaryMin > 0 || salaryMax > 0;

  /// Short salary for list cards, e.g. "₹25K – ₹35K" or "₹1.2L – ₹1.5L"
  /// (monthly), so the full range fits on a phone instead of being cut off.
  String get compactSalary {
    if (!hasSalary) return 'Salary disclosed at interview';
    if (salaryMin > 0 && salaryMax > 0) {
      if (salaryMin == salaryMax) return '₹${_shortAmount(salaryMin)}';
      return '₹${_shortAmount(salaryMin)} – ₹${_shortAmount(salaryMax)}';
    }
    if (salaryMin > 0) return '₹${_shortAmount(salaryMin)}+';
    return 'Up to ₹${_shortAmount(salaryMax)}';
  }

  /// 950 -> "950", 25000 -> "25K", 12500 -> "12.5K", 150000 -> "1.5L".
  static String _shortAmount(int value) {
    String trim(double v) {
      final text = v.toStringAsFixed(1);
      return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
    }

    if (value >= 100000) return '${trim(value / 100000)}L';
    if (value >= 1000) return '${trim(value / 1000)}K';
    return '$value';
  }

  /// Title for display. Titles typed in ALL CAPS are shown in normal case
  /// ("DEV ENGINEER" -> "Dev Engineer"); short words such as "UI" or "HR"
  /// keep their capitals. Other titles are shown as typed.
  String get displayTitle {
    final t = title.trim();
    if (t.isEmpty || t != t.toUpperCase() || t == t.toLowerCase()) return t;
    return t
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.length <= 2) return w;
          return w[0] + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// "Today", "1 day ago", "5 days ago", "2 weeks ago", then a date.
  String get postedLabel {
    final created = createdAt;
    if (created == null) return '';
    final days = DateTime.now().difference(created.toLocal()).inDays;
    if (days < 0) return '';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day ago';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final weeks = days ~/ 7;
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    return DateFormat('d MMM yyyy').format(created.toLocal());
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
