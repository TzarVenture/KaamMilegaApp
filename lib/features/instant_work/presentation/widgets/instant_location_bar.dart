import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../providers/instant_milega_provider.dart';
import '../../services/location_service.dart';

/// InstantMilega location status (no map): the phone's location is needed
/// for spot gigs, going online and nearby professionals. Shows where the
/// reading stands, and how to fix it when it is missing.
class InstantLocationBar extends ConsumerWidget {
  const InstantLocationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instantMilegaProvider);
    final notifier = ref.read(instantMilegaProvider.notifier);
    final service = ref.read(locationServiceProvider);

    switch (state.locationStatus) {
      case LocationStatus.locating:
        return const _Bar(
          leading: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          text: 'Finding your location…',
        );
      case LocationStatus.ready:
        final accuracy = state.location?.accuracyMeters;
        return _Bar(
          leading: const Icon(
            Icons.my_location_rounded,
            size: 18,
            color: AppColors.blue,
          ),
          text: 'Your current location',
          detail: accuracy == null
              ? null
              : 'accurate to about ${accuracy.round()} m',
          trailing: IconButton(
            tooltip: 'Update location',
            visualDensity: VisualDensity.compact,
            onPressed: notifier.locate,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        );
      case LocationStatus.permissionDenied:
        return _Problem(
          icon: Icons.location_disabled_rounded,
          title: 'Location permission is off',
          message: 'Allow location to see gigs and people near you.',
          primaryLabel: 'Allow location',
          onPrimary: notifier.locate,
        );
      case LocationStatus.permissionDeniedForever:
        return _Problem(
          icon: Icons.location_disabled_rounded,
          title: 'Location is blocked for KaamMilega',
          message:
              'Turn on location permission for KaamMilega in your phone '
              'settings, then try again.',
          primaryLabel: 'Open settings',
          onPrimary: service.openAppSettings,
          secondaryLabel: 'Try again',
          onSecondary: notifier.locate,
        );
      case LocationStatus.serviceDisabled:
        return _Problem(
          icon: Icons.location_off_rounded,
          title: 'Location services are turned off',
          message: 'Turn on location (GPS) on your phone to see gigs near you.',
          primaryLabel: 'Turn on location',
          onPrimary: service.openLocationSettings,
          secondaryLabel: 'Try again',
          onSecondary: notifier.locate,
        );
      case LocationStatus.unavailable:
        return _Problem(
          icon: Icons.gps_not_fixed_rounded,
          title: 'Couldn\'t get your location',
          message:
              'Your phone could not find your position. Move to an open '
              'area or check your connection, then retry.',
          primaryLabel: 'Retry',
          onPrimary: notifier.locate,
        );
    }
  }
}

/// One slim line: icon, text (and detail), optional action.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.leading,
    required this.text,
    this.detail,
    this.trailing,
  });

  final Widget leading;
  final String text;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.fromLTRB(14, 6, trailing == null ? 14 : 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (detail != null)
                    TextSpan(
                      text: '  ·  $detail',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Location problem with what to do about it.
class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(primaryLabel),
              ),
              if (secondaryLabel != null && onSecondary != null)
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
