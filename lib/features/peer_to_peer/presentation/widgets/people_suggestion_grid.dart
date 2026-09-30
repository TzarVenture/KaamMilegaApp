import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/models/user_profile.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart'
    show PersonAvatar;
import '../../../network/presentation/widgets/connect_button.dart';
import '../../../network/services/impression_tracker.dart';

/// "People You May Know" as a two-column grid of profile cards (three on
/// tablets): cover strip, round photo, name, what they do, city, then
/// Connect and Message. Cards in a row share the same height so the grid
/// stays even with long names or large text sizes.
class PeopleSuggestionGrid extends StatelessWidget {
  const PeopleSuggestionGrid({
    super.key,
    required this.users,
    required this.onOpen,
    required this.onMessage,
  });

  final List<UserProfile> users;
  final ValueChanged<UserProfile> onOpen;
  final ValueChanged<UserProfile> onMessage;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < users.length; i += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(const SizedBox(width: _gap));
        final index = i + c;
        cells.add(
          Expanded(
            child: index < users.length
                ? PeopleSuggestionCard(
                    user: users[index],
                    onOpen: () => onOpen(users[index]),
                    onMessage: () => onMessage(users[index]),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class PeopleSuggestionCard extends StatelessWidget {
  const PeopleSuggestionCard({
    super.key,
    required this.user,
    required this.onOpen,
    required this.onMessage,
  });

  final UserProfile user;
  final VoidCallback onOpen;
  final VoidCallback onMessage;

  static const double _coverHeight = 54;
  static const double _avatarSize = 68;
  static const double _ring = 3;

  /// What the person does: headline, else their skills / work categories.
  String get _subtitle {
    final headline = user.headline.trim();
    if (headline.isNotEmpty) return headline;
    final tags = [
      ...user.skills,
      ...user.jobCategories,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).take(3);
    return tags.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Member';
    final subtitle = _subtitle;
    final city = user.city.trim();
    const avatarTop = _coverHeight - _avatarSize / 2 - _ring;

    final card = Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover strip with the photo overlapping its bottom edge.
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _coverHeight,
                      child: _Cover(user: user),
                    ),
                    // Room for the lower half of the photo and its ring.
                    const SizedBox(height: _avatarSize / 2 + _ring + 2),
                  ],
                ),
                Positioned(
                  top: avatarTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(_ring),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: PersonAvatar(user: user, size: _avatarSize),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ConnectButton(
                      userId: user.id,
                      name: name,
                      height: 36,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Tooltip(
                      message: 'Message $name',
                      child: OutlinedButton(
                        onPressed: onMessage,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.moduleP2P,
                          side: const BorderSide(color: AppColors.border),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 17,
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
    );
    // Seen cards count as "Post impressions" for that member
    return ImpressionBeacon(authorId: user.id, child: card);
  }
}

/// The member's cover photo, or a soft brand gradient when there is none
/// (or it fails to load).
class _Cover extends StatelessWidget {
  const _Cover({required this.user});

  final UserProfile user;

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.moduleP2PLight, AppColors.primaryLight],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (user.coverImage.isEmpty) return _fallback;
    return Image.network(
      user.coverImage,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback,
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? _fallback : child,
    );
  }
}
