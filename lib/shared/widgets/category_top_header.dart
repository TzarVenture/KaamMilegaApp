import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../features/cities/presentation/city_dropdown.dart';
import '../../features/jobs/providers/jobs_provider.dart';
import 'notification_bell_button.dart';
import 'rotating_search_hint.dart';

/// Top header of the category screens, built like the Home header and
/// coloured for the screen ([themeColor]):
/// - a gradient band from the status bar down, with rounded bottom corners
/// - logo and name (tap: Home), search icon, notifications, menu (white)
/// - optional [title] and [subtitle] beside the city picker
/// - a white search box with a soft shadow
class CategoryTopHeader extends ConsumerWidget {
  static const _hintStyle = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Color themeColor;

  /// Screen name shown large in the header (e.g. "Instant work").
  final String? title;

  /// One short line under [title].
  final String? subtitle;
  final String searchHint;

  /// When given, the empty search box shows "Search for 'Gigs'" (one of
  /// these examples), with the example changing every few seconds;
  /// [searchHint] is then what screen readers hear. Without it,
  /// [searchHint] is shown as is.
  final List<String>? searchHintExamples;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onSearchIconTap;

  /// Small search icon in the top-right row. Service screens hide it
  /// (they already have the search bar below).
  final bool showSearchIcon;

  const CategoryTopHeader({
    super.key,
    required this.scaffoldKey,
    required this.themeColor,
    this.title,
    this.subtitle,
    required this.searchHint,
    this.searchHintExamples,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchIconTap,
    this.showSearchIcon = true,
  });

  /// Header colours per module: gradient start (deep, for white text) and
  /// gradient end.
  static final Map<Color, (Color, Color)> _palettes = {
    AppColors.moduleInstantWork: (
      AppColors.moduleInstantWorkDeep,
      AppColors.moduleInstantWork,
    ),
    AppColors.moduleSkills: (
      AppColors.moduleSkillsDeep,
      AppColors.moduleSkills,
    ),
    AppColors.moduleExperts: (
      AppColors.moduleExpertsDeep,
      AppColors.moduleExperts,
    ),
    AppColors.moduleServices: (
      AppColors.moduleServicesDeep,
      AppColors.moduleServicesEnd,
    ),
    AppColors.moduleP2P: (AppColors.moduleP2PDeep, AppColors.moduleP2P),
    AppColors.moduleEvents: (
      AppColors.moduleEventsDeep,
      AppColors.moduleEventsEnd,
    ),
  };

  /// Brand navy (as on Home) for any other colour.
  static (Color, Color) paletteFor(Color color) =>
      _palettes[color] ?? (AppColors.brandNavy, AppColors.navy);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCity = ref.watch(jobsProvider.select((s) => s.filter.city));
    final (deep, end) = paletteFor(themeColor);
    final top = MediaQuery.paddingOf(context).top;

    final city = CityPickerButton(
      currentCity: currentCity.isNotEmpty ? currentCity : 'Delhi, India',
      iconColor: themeColor,
      onSelected: (c) => ref.read(jobsProvider.notifier).setCity(c),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons on the coloured band.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, top + 6, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deep, end],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(26),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Logo and name, then search / notifications / menu
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: _Brand(onNavy: !_palettes.containsKey(themeColor)),
                  ),
                  const SizedBox(width: 8),
                  if (showSearchIcon)
                    IconButton(
                      onPressed: onSearchIconTap,
                      tooltip: 'Search',
                      icon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.white,
                      ),
                    ),
                  const NotificationBellButton(color: AppColors.white),
                  IconButton(
                    onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
                    tooltip: 'Menu',
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 2. Screen title beside the city picker (stacked on narrow
            //    phones), or the city picker alone.
            if (title == null)
              city
            else
              LayoutBuilder(
                builder: (context, box) {
                  final heading = _Title(title: title!, subtitle: subtitle);
                  return box.maxWidth < 340
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [heading, const SizedBox(height: 10), city],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 10),
                            city,
                          ],
                        );
                },
              ),
            const SizedBox(height: 16),

            // 3. Search box
            _SearchBox(
              controller: searchController,
              hint: searchHint,
              examples: searchHintExamples,
              iconColor: themeColor,
              focusColor: deep,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The brand logo on every page: the K mark on a white tile, then the
/// KaamMilega wordmark artwork (white and orange on navy, all white on a
/// module colour), so the letters are exactly the brand's.
class _Brand extends StatelessWidget {
  const _Brand({this.onNavy = false});

  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'KaamMilega. Go to Home',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/home'),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Image.asset(
                onNavy
                    ? 'assets/images/logo_text_on_dark.webp'
                    : 'assets/images/logo_text_white.webp',
                height: 22,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}

/// White search box with a soft shadow (same as Home).
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.examples,
    required this.iconColor,
    required this.focusColor,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final List<String>? examples;
  final Color iconColor;
  final Color focusColor;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final rotating = examples?.isNotEmpty ?? false;
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted?.call(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: rotating ? null : hint,
          hint: rotating
              ? RotatingSearchHint(
                  semanticLabel: hint,
                  examples: examples!,
                  style: CategoryTopHeader._hintStyle,
                )
              : null,
          hintStyle: CategoryTopHeader._hintStyle,
          hintMaxLines: 1,
          filled: true,
          fillColor: AppColors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Icon(Icons.search_rounded, color: iconColor, size: 22),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: focusColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
