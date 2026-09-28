import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/wallet_dispute.dart';
import '../repositories/wallet_repository.dart';

/// Refund requests raised by the signed-in user (GET /wallet/my/disputes).
/// Loaded fresh where needed, and no request without a session.
final myWalletDisputesProvider =
    FutureProvider.autoDispose<List<WalletDispute>>((ref) {
      if (ref.watch(sessionUserIdProvider) == null) {
        return const <WalletDispute>[];
      }
      return ref.watch(walletRepositoryProvider).getMyDisputes();
    });
