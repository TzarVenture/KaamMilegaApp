import 'package:flutter/material.dart';

/// A session an Expert offers (km-backend `Mentorship` from
/// GET /mentorships/expert/my).
class ExpertOffering {
  final String id;
  final String title;
  final String description;
  final String category;

  /// Length in minutes.
  final int durationMinutes;

  /// Price in rupees; 0 = free session.
  final double price;

  /// "active" or "inactive".
  final String status;
  final double rating;
  final int reviews;

  const ExpertOffering({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.durationMinutes = 0,
    this.price = 0,
    this.status = 'active',
    this.rating = 0,
    this.reviews = 0,
  });

  factory ExpertOffering.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    num n(String key) => json[key] is num ? json[key] as num : 0;
    return ExpertOffering(
      id: str('id'),
      title: str('title'),
      description: str('description'),
      category: str('category'),
      durationMinutes: n('duration').toInt(),
      price: n('price').toDouble(),
      status: str('status').isEmpty ? 'active' : str('status').toLowerCase(),
      rating: n('rating').toDouble(),
      reviews: n('reviews').toInt(),
    );
  }

  bool get isFree => price <= 0;
  bool get isActive => status == 'active';
}

/// What the Expert fills in to create or edit an offering
/// (km-backend `CreateMentorshipRequest`, used for both POST and PATCH).
class ExpertOfferingDraft {
  final String title;
  final String description;
  final String category;
  final int durationMinutes;
  final double price;

  const ExpertOfferingDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.price,
  });

  static const int maxPrice = 100000;

  /// Why the server should not be asked yet, or null when it is complete.
  /// (The backend does not validate these fields itself.)
  String? get problem {
    if (title.trim().length < 3) return 'Please enter a title.';
    if (description.trim().length < 10) {
      return 'Please describe the session (at least 10 characters).';
    }
    if (category.trim().isEmpty) return 'Please choose a category.';
    if (durationMinutes <= 0) return 'Please choose a duration.';
    if (price < 0 || price > maxPrice) {
      return 'Please enter a price between ₹0 and ₹$maxPrice.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'category': category.trim(),
    'duration': durationMinutes,
    'price': price,
  };
}

/// One day of an Expert's weekly hours (km-backend `Availability`).
/// `day_of_week`: 0 = Sunday … 6 = Saturday; times are "HH:mm".
class WeeklyHours {
  final int dayOfWeek;
  final TimeOfDay start;
  final TimeOfDay end;

  const WeeklyHours({
    required this.dayOfWeek,
    required this.start,
    required this.end,
  });

  static const dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String get dayName => dayNames.elementAtOrNull(dayOfWeek) ?? '';

  /// Null when the row is not usable (bad day or time, or inactive).
  static WeeklyHours? fromJson(Map<String, dynamic> json) {
    final day = json['day_of_week'];
    final start = parseTime(json['start_time']?.toString());
    final end = parseTime(json['end_time']?.toString());
    if (day is! num || day < 0 || day > 6) return null;
    if (start == null || end == null) return null;
    if (json['is_active'] == false) return null;
    return WeeklyHours(dayOfWeek: day.toInt(), start: start, end: end);
  }

  Map<String, dynamic> toJson() => {
    'day_of_week': dayOfWeek,
    'start_time': formatTime(start),
    'end_time': formatTime(end),
  };

  bool get isValid => _minutes(end) > _minutes(start);

  /// Whether a session of [minutes] starting at [at] fits inside these
  /// hours on that day.
  bool fits(DateTime at, int minutes) {
    if (at.weekday % 7 != dayOfWeek) return false;
    final from = at.hour * 60 + at.minute;
    return from >= _minutes(start) && from + _length(minutes) <= _minutes(end);
  }

  /// A session with no length set is treated as 30 minutes.
  static int _length(int minutes) => minutes > 0 ? minutes : 30;

  /// Start times on [day], every [step] minutes, where a [minutes]-long
  /// session fits inside [hours] and starts no earlier than [earliest].
  static List<TimeOfDay> slots(
    List<WeeklyHours> hours,
    DateTime day,
    int minutes, {
    required DateTime earliest,
    int step = 30,
  }) {
    final starts = <int>{};
    for (final h in hours.where((h) => h.dayOfWeek == day.weekday % 7)) {
      for (
        var m = _minutes(h.start);
        m + _length(minutes) <= _minutes(h.end);
        m += step
      ) {
        final at = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
        if (!at.isBefore(earliest)) starts.add(m);
      }
    }
    final sorted = starts.toList()..sort();
    return [for (final m in sorted) TimeOfDay(hour: m ~/ 60, minute: m % 60)];
  }

  /// The first day from [earliest] (within [days]) that has a free slot.
  static DateTime? firstBookableDay(
    List<WeeklyHours> hours,
    int minutes, {
    required DateTime earliest,
    int days = 60,
  }) {
    for (var i = 0; i <= days; i++) {
      final day = DateTime(earliest.year, earliest.month, earliest.day + i);
      if (slots(hours, day, minutes, earliest: earliest).isNotEmpty) {
        return day;
      }
    }
    return null;
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay? parseTime(String? value) {
    final parts = (value ?? '').trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
