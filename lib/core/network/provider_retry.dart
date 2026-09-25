import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_exception.dart';

/// Automatic retry policy for failing providers (used by the app's
/// ProviderScope).
///
/// Riverpod 3 retries every failing provider up to 10 times by default
/// (about 40 seconds of back-off). During that time `.future` does not
/// complete and the same request is repeated in the background, even for
/// answers that cannot change by retrying.
///
/// Here only temporary failures (no internet, timeout, HTTP 5xx) are retried,
/// at most twice (after 200 ms and 400 ms). "Not available" (404), session
/// (401 / 403) and validation errors are shown right away; the screens offer
/// their own Retry button.
Duration? appProviderRetry(int retryCount, Object error) {
  final transient =
      error is AppNetworkException ||
      error is AppTimeoutException ||
      error is AppServerException;
  if (!transient) return null;
  return ProviderContainer.defaultRetry(retryCount, error, maxRetries: 2);
}
