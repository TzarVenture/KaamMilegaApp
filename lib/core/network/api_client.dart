import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

/// Network client powered by Dio for smooth, fast, and secure API requests
class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Attach request & response interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = LocalStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized / Token Expiration
          if (error.response?.statusCode == 401) {
            await LocalStorage.clearSession();
          }

          // Extract backend error message if present
          String readableMessage = 'Something went wrong. Please try again.';

          if (error.response?.data is Map) {
            final data = error.response!.data as Map<String, dynamic>;
            readableMessage =
                data['error'] ?? data['message'] ?? readableMessage;
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            readableMessage =
                'Connection timed out. Please check your internet.';
          } else if (error.type == DioExceptionType.connectionError) {
            readableMessage = 'No internet connection or server unreachable.';
          }

          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: readableMessage,
            ),
          );
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Helper for GET requests
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Helper for POST requests
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Helper for PATCH requests
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Helper for DELETE requests
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
