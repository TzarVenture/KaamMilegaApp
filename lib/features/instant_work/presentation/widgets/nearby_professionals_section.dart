import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/network_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../models/nearby_professional.dart';
import '../../providers/instant_milega_provider.dart';

/// "Nearby Professionals": service category chips and the list area.
///
/// Every state is distinct: waiting for location, loading, backend not
/// ready yet, no professionals, request failed, and real results.
class NearbyProfessionalsSection extends ConsumerWidget {
  const NearbyProfessionalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instantMilegaProvider);
    final notifier = ref.read(instantMilegaProvider.notifier);
    final selected = state.selectedProfessional;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nearby Professionals',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in InstantServiceCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      c.icon,
                      size: 16,
                      color: state.categoryId == c.id
                          ? Colors.white
                          : AppColors.moduleInstantWork,
                    ),
                    label: Text(c.label),
                    selected: state.categoryId == c.id,
                    showCheckmark: false,
                    selectedColor: AppColors.moduleInstantWork,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: state.categoryId == c.id
                          ? AppColors.moduleInstantWork
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: state.categoryId == c.id
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                    onSelected: (_) => notifier.selectCategory(c.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (selected != null) ...[
          ProfessionalCard(professional: selected, highlighted: true),
          const SizedBox(height: 12),
        ],
        _content(state, notifier),
      ],
    );
  }

  Widget _content(InstantMilegaState state, InstantMilegaNotifier notifier) {
    if (state.locationStatus == LocationStatus.locating) {
      return const ShimmerLoadingList(count: 2, itemHeight: 84);
    }
    switch (state.professionalsStatus) {
      case ProfessionalsStatus.waitingForLocation:
        return const _InfoCard(
          icon: Icons.location_searching_rounded,
          title: 'Turn on location to see who is near you',
          message: 'Nearby professionals are shown for your current location.',
        );
      case ProfessionalsStatus.loading:
        return const ShimmerLoadingList(count: 2, itemHeight: 84);
      case ProfessionalsStatus.backendPending:
        return const _InfoCard(
          icon: Icons.handyman_outlined,
          title: 'Coming soon near you',
          message:
              'Nearby professionals will appear here once services are '
              'available.',
        );
      case ProfessionalsStatus.empty:
        return const _InfoCard(
          icon: Icons.person_search_outlined,
          title: 'No professionals nearby right now',
          message: 'Try another category or check again later.',
        );
      case ProfessionalsStatus.error:
        return _InfoCard(
          icon: Icons.error_outline_rounded,
          title: 'Couldn\'t load nearby professionals',
          message: NetworkStateView.errorMessageFor(state.error ?? Exception()),
          actionLabel: 'Retry',
          onAction: notifier.loadProfessionals,
        );
      case ProfessionalsStatus.loaded:
        return Column(
          children: [
            for (final p in state.professionals) ...[
              ProfessionalCard(
                professional: p,
                onTap: () => notifier.selectProfessional(p.id),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.moduleInstantWorkLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.moduleInstantWorkText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One professional (list item and map-marker preview). Shows only what the
/// data provides; buttons appear only when an action is passed, so nothing
/// pretends to book or open a profile before those features exist.
class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({
    super.key,
    required this.professional,
    this.onTap,
    this.onViewProfile,
    this.onBook,
    this.highlighted = false,
  });

  final NearbyProfessional professional;
  final VoidCallback? onTap;
  final VoidCallback? onViewProfile;
  final VoidCallback? onBook;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = professional;
    final initial = p.name.trim().isEmpty ? '?' : p.name.trim()[0];
    final details = <String>[
      if (p.distanceLabel != null) p.distanceLabel!,
      if (p.priceLabel != null) p.priceLabel!,
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? AppColors.moduleInstantWork
                  : AppColors.border,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.moduleInstantWorkLight,
                    foregroundImage: p.photoUrl.isNotEmpty
                        ? NetworkImage(p.photoUrl)
                        : null,
                    onForegroundImageError: p.photoUrl.isNotEmpty
                        ? (_, _) {}
                        : null,
                    child: Text(
                      initial.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.moduleInstantWorkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          p.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (p.rating != null || details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (p.rating != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: AppColors.moduleEventsText,
                                    ),
                                    Flexible(
                                      child: Text(
                                        p.reviewCount == null
                                            ? p.rating!.toStringAsFixed(1)
                                            : '${p.rating!.toStringAsFixed(1)} '
                                                  '(${p.reviewCount})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              for (final d in details)
                                Text(d, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (p.isAvailable != null) ...[
                    const SizedBox(width: 8),
                    _AvailabilityChip(available: p.isAvailable!),
                  ],
                ],
              ),
              if (onViewProfile != null || onBook != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onViewProfile != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onViewProfile,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('View Profile'),
                        ),
                      ),
                    if (onViewProfile != null && onBook != null)
                      const SizedBox(width: 8),
                    if (onBook != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onBook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Book Now'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'Available' : 'Busy',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
