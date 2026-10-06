import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../repositories/chat_repository.dart';

/// What the user chose in the report sheet once it was sent.
class ChatReportResult {
  const ChatReportResult({required this.reportNumber, required this.blocked});

  /// e.g. "REP-123456" ('' when the server sent none).
  final String reportNumber;

  /// The user also blocked the other person.
  final bool blocked;
}

/// "Report conversation" sheet: reason, optional details and "Also block
/// this user"; sends POST /chats/:id/report. Returns the result when the
/// report was sent, null when closed without sending.
Future<ChatReportResult?> showChatReportSheet(
  BuildContext context, {
  required String conversationId,
  required String name,
}) {
  return showModalBottomSheet<ChatReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ChatReportSheet(conversationId: conversationId, name: name),
  );
}

class ChatReportSheet extends ConsumerStatefulWidget {
  const ChatReportSheet({
    super.key,
    required this.conversationId,
    required this.name,
  });

  final String conversationId;
  final String name;

  /// Same reasons as the website (sent as written).
  static const reasons = [
    'Spam or unwanted advertising',
    'Harassment or inappropriate behavior',
    'Fraud, scam, or fake job offer',
    'Asking for money or advance payment',
    'Hate speech or abusive language',
    'Other concern',
  ];

  @override
  ConsumerState<ChatReportSheet> createState() => _ChatReportSheetState();
}

class _ChatReportSheetState extends ConsumerState<ChatReportSheet> {
  final _details = TextEditingController();
  String _reason = ChatReportSheet.reasons.first;
  bool _block = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final number = await ref
          .read(chatRepositoryProvider)
          .reportConversation(
            widget.conversationId,
            reason: _reason,
            description: _details.text.trim(),
            blockUser: _block,
          );
      if (!mounted) return;
      Navigator.pop(
        context,
        ChatReportResult(reportNumber: number, blocked: _block),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is AppException
            ? e.message
            : 'Could not send the report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.name.isNotEmpty ? widget.name : 'this person';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report conversation',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Your chat with $who will be sent to the KaamMilega '
                        'team for review.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Why are you reporting this conversation?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final reason in ChatReportSheet.reasons)
              _ReasonTile(
                text: reason,
                selected: reason == _reason,
                onTap: _sending ? null : () => setState(() => _reason = reason),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                hintText:
                    'Tell us what happened so our team can review this '
                    'properly...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _block,
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _block = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.brandNavy,
              title: const Text(
                'Also block this user',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'They will not be able to message you again on KaamMilega.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text(
                            'Submit report',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One reason: a filled ring when chosen.
class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.brandNavy : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected
                        ? AppColors.brandNavy
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
