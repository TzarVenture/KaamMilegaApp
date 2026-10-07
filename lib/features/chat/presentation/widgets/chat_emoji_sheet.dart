import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// One emoji and the words that find it in search.
typedef _Emoji = (String emoji, String words);

/// A small built-in set (no package, no image assets): the phone keyboard
/// still has every emoji.
const _emojiGroups = <(String, List<_Emoji>)>[
  (
    'Smileys',
    [
      ('😀', 'grin happy smile'),
      ('😃', 'happy smile joy'),
      ('😄', 'laugh happy smile'),
      ('😁', 'grin beam teeth'),
      ('😊', 'blush smile happy'),
      ('🙂', 'smile ok fine'),
      ('😉', 'wink'),
      ('😍', 'love heart eyes'),
      ('😘', 'kiss love'),
      ('😎', 'cool sunglasses'),
      ('🤗', 'hug thanks'),
      ('🤔', 'think hmm question'),
      ('😅', 'sweat relief nervous'),
      ('😂', 'laugh tears lol funny'),
      ('🤣', 'rofl laugh lol funny'),
      ('😇', 'angel innocent'),
      ('😐', 'neutral meh'),
      ('😴', 'sleep tired'),
      ('😢', 'sad cry'),
      ('😭', 'cry sob sad'),
      ('😡', 'angry mad'),
      ('😮', 'wow surprise shock'),
      ('🥳', 'party celebrate birthday'),
      ('🙏', 'please thanks pray namaste'),
    ],
  ),
  (
    'Hands',
    [
      ('👍', 'thumbs up yes ok like good'),
      ('👎', 'thumbs down no dislike'),
      ('👌', 'ok perfect fine'),
      ('✌️', 'peace victory'),
      ('🤞', 'fingers crossed luck hope'),
      ('👏', 'clap applause well done'),
      ('🙌', 'hooray celebrate raise'),
      ('👋', 'wave hi hello bye'),
      ('🤝', 'handshake deal agree'),
      ('✋', 'hand stop wait'),
      ('💪', 'strong muscle power'),
      ('👉', 'point right'),
      ('👈', 'point left'),
      ('👆', 'point up'),
      ('👇', 'point down'),
      ('✍️', 'write sign'),
    ],
  ),
  (
    'Work',
    [
      ('💼', 'job work briefcase office'),
      ('📄', 'document resume cv file'),
      ('📎', 'attach clip file'),
      ('📌', 'pin important location'),
      ('📅', 'date calendar schedule interview'),
      ('⏰', 'time alarm clock late'),
      ('✅', 'done yes check complete'),
      ('❌', 'no cross wrong cancel'),
      ('📞', 'call phone'),
      ('📧', 'email mail'),
      ('💻', 'laptop computer'),
      ('📱', 'mobile phone'),
      ('🔧', 'tool repair fix'),
      ('🔨', 'hammer build tool'),
      ('🏗️', 'construction building site'),
      ('🚚', 'truck delivery transport'),
      ('💰', 'money salary pay'),
      ('📈', 'growth chart up'),
      ('🎯', 'target goal'),
      ('⭐', 'star rating'),
    ],
  ),
  (
    'Fun',
    [
      ('🎉', 'party congrats celebrate tada'),
      ('🎊', 'confetti celebrate'),
      ('🎁', 'gift present'),
      ('🔥', 'fire hot lit'),
      ('💯', 'hundred perfect score'),
      ('❤️', 'heart love red'),
      ('💙', 'heart blue'),
      ('💚', 'heart green'),
      ('☕', 'coffee tea chai'),
      ('🍕', 'pizza food'),
      ('🍰', 'cake sweet birthday'),
      ('⚽', 'football soccer'),
      ('🏏', 'cricket bat'),
      ('🎵', 'music song'),
      ('🌟', 'star shine'),
      ('🌈', 'rainbow'),
    ],
  ),
];

/// Emoji picked in this session, newest first (no storage).
final List<String> _recent = [];
const _maxRecent = 16;

/// Emoji matching [query] by keyword (all words must match the start of a
/// keyword), in list order.
@visibleForTesting
List<String> searchEmoji(String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final g in _emojiGroups)
      for (final e in g.$2)
        if (words.every((w) => e.$2.split(' ').any((k) => k.startsWith(w))))
          e.$1,
  ];
}

/// Emoji sheet: search, Recent and category tabs. Returns the chosen emoji,
/// or null.
Future<String?> showEmojiSheet(BuildContext context) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _EmojiSheet(),
  );
  if (picked != null) {
    _recent
      ..remove(picked)
      ..insert(0, picked);
    if (_recent.length > _maxRecent) _recent.removeLast();
  }
  return picked;
}

class _EmojiSheet extends StatefulWidget {
  const _EmojiSheet();

  @override
  State<_EmojiSheet> createState() => _EmojiSheetState();
}

class _EmojiSheetState extends State<_EmojiSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      if (_recent.isNotEmpty) ('Recent', List<String>.of(_recent)),
      for (final g in _emojiGroups) (g.$1, [for (final e in g.$2) e.$1]),
    ];
    final height = MediaQuery.sizeOf(context).height * 0.5;
    return Padding(
      // Stays above the keyboard while searching.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: height.clamp(280.0, 420.0),
          child: DefaultTabController(
            length: groups.length,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search emoji (e.g. ok, thanks, call)',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  Expanded(child: _results(searchEmoji(_query)))
                else ...[
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: [for (final g in groups) Tab(text: g.$1)],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [for (final g in groups) _grid(g.$2)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(List<String> found) {
    if (found.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No emoji found. Your keyboard has more.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return _grid(found);
  }

  Widget _grid(List<String> emoji) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 48,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emoji.length,
      itemBuilder: (context, i) => Semantics(
        button: true,
        label: emoji[i],
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pop(context, emoji[i]),
          child: Center(
            child: Text(emoji[i], style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
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
