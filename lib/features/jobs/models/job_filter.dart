/// Filter state matching kaammilega.com/jobs UI filters
class JobFilter {
  final String searchQuery;
  final String city;
  final List<String> jobTypes;
  final String salaryRange; // 'all', '5000', '10000', '20000', '30000'
  final String experience; // 'all', '0', '1', '4', '5', '30'
  final List<String> genders; // 'Male', 'Female'
  final List<String> qualification; // '10th Pass', '12th Pass', etc.
  final int page;
  final int limit;

  const JobFilter({
    this.searchQuery = '',
    this.city = 'All',
    this.jobTypes = const [],
    this.salaryRange = 'all',
    this.experience = 'all',
    this.genders = const [],
    this.qualification = const [],
    this.page = 1,
    this.limit = 10,
  });

  /// Count of active filters for UI badge count
  int get activeFilterCount {
    int count = 0;
    count += jobTypes.length;
    if (salaryRange != 'all') count++;
    if (experience != 'all') count++;
    count += genders.length;
    count += qualification.length;
    return count;
  }

  /// Check if any filter is active
  bool get hasActiveFilters =>
      activeFilterCount > 0 ||
      (city.isNotEmpty && city != 'All') ||
      searchQuery.isNotEmpty;

  JobFilter copyWith({
    String? searchQuery,
    String? city,
    List<String>? jobTypes,
    String? salaryRange,
    String? experience,
    List<String>? genders,
    List<String>? qualification,
    int? page,
    int? limit,
  }) {
    return JobFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      city: city ?? this.city,
      jobTypes: jobTypes ?? this.jobTypes,
      salaryRange: salaryRange ?? this.salaryRange,
      experience: experience ?? this.experience,
      genders: genders ?? this.genders,
      qualification: qualification ?? this.qualification,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  /// Convert filter to query parameters expected by km-backend
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{'page': page, 'limit': limit};

    if (searchQuery.isNotEmpty) {
      params['search'] = searchQuery;
    }

    if (city.isNotEmpty && city.toLowerCase() != 'all') {
      params['city_ids'] = city;
    }

    if (jobTypes.isNotEmpty) {
      params['job_types'] = jobTypes.join(',');
    }

    if (salaryRange != 'all') {
      params['salary_min'] = int.tryParse(salaryRange) ?? 0;
    }

    if (experience != 'all') {
      params['experience_max'] = int.tryParse(experience) ?? 0;
    }

    if (genders.isNotEmpty) {
      params['genders'] = genders.join(',');
    }

    if (qualification.isNotEmpty) {
      params['education'] = qualification.join(',');
    }

    return params;
  }
}
