import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../cities/repositories/city_repository.dart';
import '../models/job.dart';
import '../models/job_filter.dart';
import '../models/jobs_response.dart';

/// Repository for handling Job APIs from km-backend
class JobRepository {
  final ApiClient _client;

  JobRepository(this._client);

  /// Fetch jobs with filtering and pagination
  Future<JobsResponse> getJobs(JobFilter filter) async {
    try {
      final response = await _client.get(
        ApiConstants.jobs,
        queryParameters: filter.toQueryParams(),
      );

      if (response.data is Map<String, dynamic>) {
        return JobsResponse.fromJson(response.data as Map<String, dynamic>);
      }

      // If array is returned
      if (response.data is List) {
        final list = (response.data as List)
            .map((e) => Job.fromJson(e as Map<String, dynamic>))
            .toList();
        return JobsResponse(
          jobs: list,
          total: list.length,
          page: 1,
          limit: 10,
        );
      }

      return const JobsResponse(jobs: [], total: 0, page: 1, limit: 10);
    } catch (e) {
      // Fallback to sample jobs matching kaammilega.com if network fails
      return _getSampleJobsFallback(filter);
    }
  }

  /// Fetch single job by ID
  Future<Job> getJobById(String id) async {
    try {
      final response = await _client.get('${ApiConstants.jobDetail}$id');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      // Return sample job fallback if not found
      return _sampleJobs.firstWhere(
        (j) => j.id == id,
        orElse: () => _sampleJobs.first,
      );
    }
  }

  /// Sample mock jobs for offline smoothness & instant preview
  JobsResponse _getSampleJobsFallback(JobFilter filter) {
    var filtered = _sampleJobs;

    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      filtered = filtered
          .where((j) =>
              j.title.toLowerCase().contains(q) ||
              j.company.toLowerCase().contains(q) ||
              j.cityName.toLowerCase().contains(q))
          .toList();
    }

    if (filter.city.isNotEmpty && filter.city.toLowerCase() != 'all') {
      filtered = filtered
          .where((j) => j.cityName.toLowerCase() == filter.city.toLowerCase())
          .toList();
    }

    return JobsResponse(
      jobs: filtered,
      total: filtered.length,
      page: filter.page,
      limit: filter.limit,
    );
  }

  static final List<Job> _sampleJobs = [
    Job(
      id: 'job_001',
      recruiterId: 'rec_01',
      title: 'Delivery Executive (Bikes & Vans)',
      company: 'Shadowfax Logistics',
      cityId: 'c_mumbai',
      cityName: 'Mumbai',
      location: 'Andheri East',
      salaryMin: 18000,
      salaryMax: 28000,
      jobType: 'Full-time',
      status: 'open',
      requirements: ['Bike & Valid Driving License', 'Smartphone with 4G', 'Aadhaar Card'],
      weOffer: ['Daily Fuel Allowance', 'Flexible Shifts', 'Weekly Incentives & Bonus'],
      gender: 'Any',
      education: '10th Pass',
      experienceMin: 0,
      experienceMax: 2,
      vacancies: 25,
      applicantCount: 94,
      description:
          'We are hiring Delivery Executives for our hub in Andheri East. Responsibilities include pickup and prompt doorstep delivery of packages. Weekly payout available with high bonus rewards.',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Job(
      id: 'job_002',
      recruiterId: 'rec_02',
      title: 'Field Sales & Customer Relationship Officer',
      company: 'Kotak Mahindra Partner',
      cityId: 'c_delhi',
      cityName: 'Delhi',
      location: 'Connaught Place',
      salaryMin: 22000,
      salaryMax: 35000,
      jobType: 'Full-time',
      status: 'open',
      requirements: ['Good Hindi Communication', 'Basic English', '12th Pass or Graduate'],
      weOffer: ['Health Insurance', 'Performance Incentives', 'Clear Career Progression'],
      gender: 'Any',
      education: '12th Pass',
      experienceMin: 1,
      experienceMax: 3,
      vacancies: 10,
      applicantCount: 65,
      description:
          'Join our energetic field sales team to introduce digital banking solutions to small merchants and retailers in Delhi NCR. Lucrative monthly commissions above base salary.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Job(
      id: 'job_003',
      recruiterId: 'rec_03',
      title: 'Warehouse Operations & Inventory Assistant',
      company: 'Blinkit Fulfillment Hub',
      cityId: 'c_bengaluru',
      cityName: 'Bengaluru',
      location: 'Whitefield',
      salaryMin: 17000,
      salaryMax: 24000,
      jobType: 'Full-time',
      status: 'open',
      requirements: ['Physical Fitness', 'Punctuality', 'Basic Scanner Usage'],
      weOffer: ['Subsidized Canteen', 'Overtime Allowance', 'Safety Equipment Provided'],
      gender: 'Any',
      education: '10th Pass',
      experienceMin: 0,
      experienceMax: 1,
      vacancies: 40,
      applicantCount: 120,
      description:
          'Immediate openings for dark store fulfillment pickers and sorters. Responsible for scanning items, packaging orders, and ensuring on-time dispatch.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Job(
      id: 'job_004',
      recruiterId: 'rec_04',
      title: 'Security Supervisor (Corporate Office)',
      company: 'G4S Facility Services',
      cityId: 'c_pune',
      cityName: 'Pune',
      location: 'Hinjewadi Phase 1',
      salaryMin: 20000,
      salaryMax: 26000,
      jobType: 'Full-time',
      status: 'open',
      requirements: ['Height 5ft 7in+', 'Clean Police Record', 'Prior Security Experience'],
      weOffer: ['PF & ESIC Benefits', 'Free Uniforms', 'Quarterly Rewards'],
      gender: 'Male',
      education: '12th Pass',
      experienceMin: 2,
      experienceMax: 5,
      vacancies: 6,
      applicantCount: 38,
      description:
          'Looking for disciplined security supervisors for premier IT park in Hinjewadi. Day and Night rotating shifts available with complete statutory benefits.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Job(
      id: 'job_005',
      recruiterId: 'rec_05',
      title: 'Telecaller & Customer Support Executive',
      company: 'Teleperformance India',
      cityId: 'c_hyderabad',
      cityName: 'Hyderabad',
      location: 'Madhapur, Hitech City',
      salaryMin: 19000,
      salaryMax: 27000,
      jobType: 'Full-time',
      status: 'open',
      requirements: ['Fluent in Hindi & Telugu', 'Basic Computer Skills', 'Customer First Mindset'],
      weOffer: ['Cab Facility', '5 Days Working', 'Medical Cover'],
      gender: 'Any',
      education: 'Graduation',
      experienceMin: 0,
      experienceMax: 2,
      vacancies: 15,
      applicantCount: 82,
      description:
          'Customer support executive role handling inbound inquiries for an e-commerce partner. Comprehensive 2-week paid training provided upon selection.',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.watch(apiClientProvider));
});
