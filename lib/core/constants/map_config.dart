import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Map tile configuration (flutter_map + OpenStreetMap).
///
/// OpenStreetMap's public tile server needs no API key and is fine for
/// development and low traffic, but its usage policy does not allow heavy
/// production use. Before a large public launch, point [tileUrlTemplate] at
/// a commercial tile provider (for example MapTiler or Stadia Maps) and put
/// its key in a build-time setting, never in source control.
class MapConfig {
  MapConfig._();

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Sent as the User-Agent to the tile server (required by OSM policy).
  static const String userAgentPackageName = 'com.kaammilega.app';

  static const String attribution = 'OpenStreetMap contributors';
  static const String attributionUrl =
      'https://www.openstreetmap.org/copyright';

  /// Zoom used when the map centres on the user.
  static const double userZoom = 15;
  static const double maxZoom = 19;
  static const double minZoom = 4;
}

/// Whether map tiles are downloaded. Widget tests override this with
/// `false` (no network in tests); the app always uses `true`.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
