import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/city.dart';

/// City Repository to fetch cities from km-backend
class CityRepository {
  final ApiClient _client;

  CityRepository(this._client);

  /// Fetch list of cities
  Future<List<City>> getCities({String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'active': 'true',
        'limit': 100,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _client.get(
        ApiConstants.cities,
        queryParameters: queryParams,
      );

      final dynamic body = response.data;
      List<dynamic> list = [];

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic>) {
        if (body['data'] is List) {
          list = body['data'];
        } else if (body['cities'] is List) {
          list = body['cities'];
        }
      }

      return list.map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback to top Indian cities if offline or error
      return const [
        City(id: 'all', name: 'All'),
        City(id: 'mumbai', name: 'Mumbai'),
        City(id: 'delhi', name: 'Delhi'),
        City(id: 'bengaluru', name: 'Bengaluru'),
        City(id: 'hyderabad', name: 'Hyderabad'),
        City(id: 'pune', name: 'Pune'),
        City(id: 'chennai', name: 'Chennai'),
        City(id: 'kolkata', name: 'Kolkata'),
        City(id: 'ahmedabad', name: 'Ahmedabad'),
        City(id: 'jaipur', name: 'Jaipur'),
      ];
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final cityRepositoryProvider = Provider<CityRepository>((ref) {
  return CityRepository(ref.watch(apiClientProvider));
});

final citiesFutureProvider = FutureProvider<List<City>>((ref) {
  return ref.watch(cityRepositoryProvider).getCities();
});
