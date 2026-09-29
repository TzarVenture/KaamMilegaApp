import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/open_chat.dart';
import '../../providers/network_provider.dart';
import '../../repositories/network_repository.dart';

/// Asks a guest to log in. Returns true when signed in.
bool requireSignedIn(BuildContext context, WidgetRef ref) {
  if (AuthGuard.isSignedIn(ref.read(authProvider))) return true;
  showAuthPromptDialog(
    context,
    title: 'Login Required',
    message: 'Please log in to connect and chat with people.',
  );
  return false;
}

/// Opens the chat with [userId] (a guest is asked to log in first).
void chatWithMember(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) {
  if (!requireSignedIn(context, ref)) return;
  openChatWithUser(context, ref, receiverId: userId, title: name);
}

/// Connect button with the server's state for [userId]:
/// Connect (POST /network/connect), Pending or Connected
/// (GET /network/status/:id). Guests are asked to log in.
class ConnectButton extends ConsumerStatefulWidget {
  const ConnectButton({
    super.key,
    required this.userId,
    required this.name,
    this.height = 40,
    this.fontSize = 12,
  });

  final String userId;
  final String name;
  final double height;
  final double fontSize;

  @override
  ConsumerState<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<ConnectButton> {
  bool _sending = false;

  Future<void> _connect() async {
    if (_sending || !requireSignedIn(context, ref)) return;
    final id = widget.userId;
    setState(() => _sending = true);
    String message;
    var ok = false;
    try {
      await ref.read(networkRepositoryProvider).sendInvitation(id);
      ok = true;
      message = 'Connection request sent to ${widget.name}.';
    } on AppException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    // Show the server's state (pending / connected), not a guess.
    ref.invalidate(connectionStatusProvider(id));
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionUserIdProvider) != null;
    // '' none, pending, accepted, ignored (backend network.ConnectionStatus)
    final status = signedIn
        ? ref.watch(connectionStatusProvider(widget.userId))
        : const AsyncValue<String>.data('');
    final value = status.asData?.value ?? '';

    final String label;
    VoidCallback? onPressed;
    if (_sending) {
      label = 'Sending...';
    } else if (status.isLoading) {
      label = 'Connect';
    } else if (value == 'accepted') {
      label = 'Connected';
    } else if (value == 'pending' || value == 'ignored') {
      // The server refuses a second request while one exists.
      label = 'Pending';
    } else {
      label = 'Connect';
      onPressed = _connect;
    }

    return ElevatedButton(
      onPressed: onPressed,
      style:
          ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            // Pending / Connected: a soft outlined label, not a grey block
            disabledBackgroundColor: AppColors.background,
            disabledForegroundColor: AppColors.textSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size(0, widget.height),
            // Take exactly [height]; the default adds space up to 48 px,
            // which overflowed the compact Home cards.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? const BorderSide(color: AppColors.border)
                  : BorderSide.none,
            ),
          ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
