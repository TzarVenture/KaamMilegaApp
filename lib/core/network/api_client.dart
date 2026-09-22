import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import 'app_exception.dart';
import 'connectivity_service.dart';
import 'network_status.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Network client powered by Dio with safe error translation and connectivity resilience
class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl, Dio? dio}) {
    _dio =
        dio ??
        Dio(
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
        onResponse: (response, handler) {
          // If we receive a valid server response, update connectivity as online
          ConnectivityService().updateStatus(NetworkStatus.online);
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized / Token Expiration
          if (error.response?.statusCode == 401) {
            await LocalStorage.clearSession();
          }

          // If network connection failure or timeout, update connectivity service
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            ConnectivityService().updateStatus(NetworkStatus.offline);
          }

          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Translates raw DioException or system error into structured AppException
  AppException _handleError(dynamic error) {
    if (error is AppException) return error;

    if (error is SocketException) {
      ConnectivityService().updateStatus(NetworkStatus.offline);
      return AppNetworkException(
        'No internet connection or server unreachable.',
        'NETWORK_ERROR',
        error,
      );
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      String readableMessage = 'Something went wrong. Please try again.';

      if (error.response?.data is Map) {
        final data = error.response!.data as Map<String, dynamic>;
        readableMessage = data['error'] ?? data['message'] ?? readableMessage;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return AppTimeoutException(
            'Connection timed out. Please check your internet.',
            'TIMEOUT',
            error,
          );

        case DioExceptionType.connectionError:
          ConnectivityService().updateStatus(NetworkStatus.offline);
          return AppNetworkException(
            'No internet connection. Please check your network.',
            'NETWORK_ERROR',
            error,
          );

        case DioExceptionType.badResponse:
          if (statusCode == 401 || statusCode == 403) {
            return AppAuthException(
              readableMessage,
              statusCode,
              'AUTH_ERROR',
              error,
            );
          }
          if (statusCode == 404) {
            final notFoundMsg =
                (error.response?.data is Map &&
                    (error.response!.data['error'] != null ||
                        error.response!.data['message'] != null))
                ? readableMessage
                : 'This service or resource is currently unavailable.';
            return AppNotFoundException(notFoundMsg, 'NOT_FOUND', error);
          }
          if (statusCode != null && statusCode >= 500) {
            return AppServerException(
              'Server temporarily unavailable. Please try again later.',
              statusCode,
              'SERVER_ERROR',
              error,
            );
          }
          return AppValidationException(
            readableMessage,
            validationErrors: error.response?.data is Map
                ? error.response!.data as Map<String, dynamic>
                : null,
            originalError: error,
          );

        case DioExceptionType.cancel:
          return const AppValidationException('Request was cancelled.');

        case DioExceptionType.badCertificate:
          return const AppNetworkException(
            'Security certificate verification failed.',
          );

        case DioExceptionType.unknown:
        default:
          if (error.error is SocketException) {
            ConnectivityService().updateStatus(NetworkStatus.offline);
            return AppNetworkException(
              'No internet connection or server unreachable.',
              'NETWORK_ERROR',
              error,
            );
          }
          return AppNetworkException(readableMessage, 'NETWORK_ERROR', error);
      }
    }

    return AppNetworkException(
      error.toString().replaceFirst('Exception: ', ''),
      'UNKNOWN_ERROR',
      error,
    );
  }

  /// Safe request execution wrapper
  Future<Response<T>> _safeExecute<T>(
    Future<Response<T>> Function() execute,
  ) async {
    try {
      return await execute();
    } catch (e, stack) {
      if (e is DioException) {
        final code = e.response?.statusCode != null
            ? 'HTTP ${e.response!.statusCode}'
            : e.type.name;
        final method = e.requestOptions.method;
        final path = e.requestOptions.path;
        final info = e.response?.statusCode == 404
            ? 'Backend endpoint unavailable'
            : (e.response?.statusMessage ?? e.message ?? '');
        debugPrint(
          '[ApiClient] $code | $method $path${info.isNotEmpty ? " - $info" : ""}',
        );
      } else {
        debugPrint('[ApiClient] Unexpected error: $e');
        if (kDebugMode) {
          debugPrint(stack.toString());
        }
      }
      throw _handleError(e);
    }
  }

  /// Helper for GET requests
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _safeExecute(
      () =>
          _dio.get<T>(path, queryParameters: queryParameters, options: options),
    );
  }

  /// Helper for POST requests
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _safeExecute(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Helper for PATCH requests
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _safeExecute(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Helper for DELETE requests
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _safeExecute(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }
}
