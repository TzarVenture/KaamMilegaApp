import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';

void main() {
  group('Job Model Tests', () {
    test(
      'Job.fromJson correctly maps fields and computes formatted values',
      () {
        final json = {
          'id': 'job_123',
          'title': 'Delivery Driver',
          'company': 'Zomato',
          'city_name': 'Mumbai',
          'location': 'Andheri',
          'salary_min': 20000,
          'salary_max': 30000,
          'job_type': 'Full-time',
          'experience_min': 1,
          'experience_max': 3,
          'requirements': ['Bike', 'License'],
          'we_offer': ['Fuel Allowance'],
          'vacancies': 10,
          'applicant_count': 45,
        };

        final job = Job.fromJson(json);

        expect(job.id, 'job_123');
        expect(job.title, 'Delivery Driver');
        expect(job.company, 'Zomato');
        expect(job.cityName, 'Mumbai');
        expect(job.formattedSalary, '₹20,000 - ₹30,000');
        expect(job.formattedExperience, '1-3 Yrs');
        expect(job.formattedLocation, 'Andheri, Mumbai');
        expect(job.requirements.length, 2);
      },
    );

    test(
      'JobFilter.toQueryParams generates expected backend API query params',
      () {
        const filter = JobFilter(
          searchQuery: 'driver',
          city: 'Mumbai',
          jobTypes: ['Full-time', 'Part-time'],
          salaryRange: '20000',
          experience: '4',
          genders: ['Male'],
          qualification: ['10th Pass'],
          page: 2,
          limit: 10,
        );

        final params = filter.toQueryParams();

        expect(params['search'], 'driver');
        expect(params['city_ids'], 'Mumbai');
        expect(params['job_types'], 'Full-time,Part-time');
        expect(params['salary_min'], 20000);
        expect(params['experience_max'], 4);
        expect(params['genders'], 'Male');
        expect(params['education'], '10th Pass');
        expect(params['page'], 2);
        expect(params['limit'], 10);
        expect(filter.activeFilterCount, 6);
      },
    );

    test('JobsResponse.fromJson parses list and pagination data', () {
      final json = {
        'total': 25,
        'page': 1,
        'limit': 10,
        'jobs': [
          {
            'id': 'j1',
            'title': 'Security Guard',
            'company': 'G4S',
            'city_name': 'Pune',
          },
          {
            'id': 'j2',
            'title': 'Sales Executive',
            'company': 'Airtel',
            'city_name': 'Pune',
          },
        ],
      };

      final res = JobsResponse.fromJson(json);

      expect(res.total, 25);
      expect(res.page, 1);
      expect(res.limit, 10);
      expect(res.totalPages, 3);
      expect(res.hasNextPage, true);
      expect(res.hasPreviousPage, false);
      expect(res.jobs.length, 2);
    });
  });
}
