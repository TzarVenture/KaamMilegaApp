import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

const _emojiGroups = <(String, List<String>)>[
  (
    'Smileys',
    [
      '😀', '😃', '😄', '😁', '😊', '🙂', '😉', '😍', //
      '😘', '😎', '🤗', '🤔', '😅', '😂', '🤣', '😇',
      '😐', '😴', '😢', '😭', '😡', '😮', '🥳', '🙏',
    ],
  ),
  (
    'Hands',
    [
      '👍', '👎', '👌', '✌️', '🤞', '👏', '🙌', '👋', //
      '🤝', '✋', '💪', '👉', '👈', '👆', '👇', '✍️',
    ],
  ),
  (
    'Work',
    [
      '💼', '📄', '📎', '📌', '📅', '⏰', '✅', '❌', //
      '📞', '📧', '💻', '📱', '🔧', '🔨', '🏗️', '🚚',
      '💰', '📈', '🎯', '⭐',
    ],
  ),
  (
    'Fun',
    [
      '🎉', '🎊', '🎁', '🔥', '💯', '❤️', '💙', '💚', //
      '☕', '🍕', '🍰', '⚽', '🏏', '🎵', '🌟', '🌈',
    ],
  ),
];

/// Emoji sheet with category tabs. Returns the chosen emoji, or null.
Future<String?> showEmojiSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: 300,
        child: DefaultTabController(
          length: _emojiGroups.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [for (final g in _emojiGroups) Tab(text: g.$1)],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final g in _emojiGroups)
                      GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 48,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                        itemCount: g.$2.length,
                        itemBuilder: (context, i) => Semantics(
                          button: true,
                          label: g.$2[i],
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(context, g.$2[i]),
                            child: Center(
                              child: Text(
                                g.$2[i],
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Puts [text] at the cursor (or replaces the selection).
void insertAtCursor(TextEditingController controller, String text) {
  final value = controller.value;
  final sel = value.selection;
  final start = sel.isValid ? sel.start : value.text.length;
  final end = sel.isValid ? sel.end : value.text.length;
  final next = value.text.replaceRange(start, end, text);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + text.length),
  );
}
