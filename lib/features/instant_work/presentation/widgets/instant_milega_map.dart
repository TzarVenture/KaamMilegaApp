import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/map_config.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../models/nearby_professional.dart';
import '../../providers/instant_milega_provider.dart';
import '../../services/location_service.dart';

/// Current-location line and map for Instant Milega.
///
/// The map area keeps the same [height] in every state (locating, errors,
/// map), so nothing jumps when the location arrives.
class InstantMilegaMapSection extends ConsumerWidget {
  const InstantMilegaMapSection({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instantMilegaProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentLocationLine(state: state),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _MapArea(state: state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationLine extends StatelessWidget {
  const _CurrentLocationLine({required this.state});

  final InstantMilegaState state;

  @override
  Widget build(BuildContext context) {
    final ready = state.locationStatus == LocationStatus.ready;
    final accuracy = state.location?.accuracyMeters;
    final title = switch (state.locationStatus) {
      LocationStatus.ready => 'Your current location',
      LocationStatus.locating => 'Finding your location…',
      _ => 'Location not available',
    };
    return Row(
      children: [
        Icon(
          ready ? Icons.my_location_rounded : Icons.location_searching_rounded,
          size: 18,
          color: ready ? AppColors.blue : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (ready && accuracy != null)
                  TextSpan(
                    text: '  ·  accurate to about ${accuracy.round()} m',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MapArea extends ConsumerWidget {
  const _MapArea({required this.state});

  final InstantMilegaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(instantMilegaProvider.notifier);
    final service = ref.read(locationServiceProvider);
    switch (state.locationStatus) {
      case LocationStatus.locating:
        return Stack(
          fit: StackFit.expand,
          children: [
            const ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
            Center(
              child: _Pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Flexible(child: Text('Finding your location…')),
                  ],
                ),
              ),
            ),
          ],
        );
      case LocationStatus.ready:
        final location = state.location;
        if (location == null) return const SizedBox.shrink();
        return _UserMap(
          location: location,
          professionals: state.professionals,
          onProfessionalTap: notifier.selectProfessional,
        );
      case LocationStatus.permissionDenied:
        return _LocationMessage(
          icon: Icons.location_disabled_rounded,
          title: 'Location permission is off',
          message: 'Allow location to see the map and professionals near you.',
          primaryLabel: 'Allow location',
          onPrimary: notifier.locate,
        );
      case LocationStatus.permissionDeniedForever:
        return _LocationMessage(
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
        return _LocationMessage(
          icon: Icons.location_off_rounded,
          title: 'Location services are turned off',
          message: 'Turn on location (GPS) on your phone to see the map.',
          primaryLabel: 'Turn on location',
          onPrimary: service.openLocationSettings,
          secondaryLabel: 'Try again',
          onSecondary: notifier.locate,
        );
      case LocationStatus.unavailable:
        return _LocationMessage(
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

/// The map centred on the user: blue dot, accuracy circle, "My location"
/// control, and markers for real professionals (none until the backend
/// provides them).
class _UserMap extends ConsumerStatefulWidget {
  const _UserMap({
    required this.location,
    required this.professionals,
    required this.onProfessionalTap,
  });

  final DeviceLocation location;
  final List<NearbyProfessional> professionals;
  final ValueChanged<String?> onProfessionalTap;

  @override
  ConsumerState<_UserMap> createState() => _UserMapState();
}

class _UserMapState extends ConsumerState<_UserMap> {
  final MapController _controller = MapController();
  bool _mapReady = false;

  LatLng get _userPoint =>
      LatLng(widget.location.latitude, widget.location.longitude);

  @override
  void didUpdateWidget(covariant _UserMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude;
    if (moved) _recenter();
  }

  void _recenter() {
    if (!_mapReady) return;
    _controller.move(_userPoint, MapConfig.userZoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTiles = ref.watch(mapTilesEnabledProvider);
    final accuracy = widget.location.accuracyMeters;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _userPoint,
            initialZoom: MapConfig.userZoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            onMapReady: () => _mapReady = true,
            onTap: (_, _) => widget.onProfessionalTap(null),
          ),
          children: [
            if (showTiles)
              TileLayer(
                urlTemplate: MapConfig.tileUrlTemplate,
                userAgentPackageName: MapConfig.userAgentPackageName,
                maxZoom: MapConfig.maxZoom,
              ),
            if (accuracy != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userPoint,
                    radius: accuracy,
                    useRadiusInMeter: true,
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderColor: AppColors.blue.withValues(alpha: 0.35),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final p in widget.professionals)
                  Marker(
                    point: LatLng(p.location.latitude, p.location.longitude),
                    width: 40,
                    height: 40,
                    child: ProfessionalMapPin(
                      professional: p,
                      onTap: () => widget.onProfessionalTap(p.id),
                    ),
                  ),
                Marker(
                  point: _userPoint,
                  width: 24,
                  height: 24,
                  child: const _UserDot(),
                ),
              ],
            ),
            if (showTiles)
              SimpleAttributionWidget(
                source: const Text(MapConfig.attribution),
                onTap: () => launchUrl(
                  Uri.parse(MapConfig.attributionUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              tooltip: 'My location',
              icon: const Icon(Icons.my_location_rounded),
              color: AppColors.blue,
              onPressed: _recenter,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are here',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Map marker for one professional (used once the backend returns them).
class ProfessionalMapPin extends StatelessWidget {
  const ProfessionalMapPin({
    super.key,
    required this.professional,
    required this.onTap,
  });

  final NearbyProfessional professional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${professional.name}, ${professional.service}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.moduleInstantWork,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.handyman_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        child: child,
      ),
    );
  }
}

/// Location problem shown inside the map area (scrolls on small screens or
/// with large text instead of overflowing).
class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
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
      ),
    );
  }
}
