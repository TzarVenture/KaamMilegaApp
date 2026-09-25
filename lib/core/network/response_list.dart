import 'app_exception.dart';

/// Reads a list response from km-backend: either a JSON array, or an object
/// holding the array under one of [keys] (default `data`).
///
/// A successful response with no body or `null` means "no items" (Go encodes
/// an empty slice as `null`). Anything else is reported as an error
/// ([AppValidationException]), never as an empty list, so a broken response
/// is not shown as "no data".
List<Map<String, dynamic>> readListResponse(
  dynamic body, {
  List<String> keys = const ['data'],
}) {
  return readRawListResponse(
    body,
    keys: keys,
  ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

/// Like [readListResponse] but keeps the items as they are (e.g. a list of
/// IDs).
List<dynamic> readRawListResponse(
  dynamic body, {
  List<String> keys = const ['data'],
}) {
  if (body == null || (body is String && body.trim().isEmpty)) return const [];
  List<dynamic>? list;
  if (body is List) {
    list = body;
  } else if (body is Map) {
    for (final key in keys) {
      final value = body[key];
      if (value is List) {
        list = value;
        break;
      }
      // `{"data": null}`: the server has no items.
      if (body.containsKey(key) && value == null) return const [];
    }
  }
  if (list == null) {
    throw const AppValidationException(
      'Unexpected response from server. Please try again.',
    );
  }
  return list;
}
