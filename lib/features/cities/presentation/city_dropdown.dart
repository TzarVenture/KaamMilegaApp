import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/city.dart';
import '../repositories/city_repository.dart';

/// "All" is the filter value for every city (what the jobs filter expects);
/// the list shows it as "All Cities".
const String kAllCities = 'All';

/// Rounded "City · All" button that opens [showCityDropdown] right under
/// itself. The arrow points up while the list is open.
class CityPickerButton extends StatefulWidget {
  const CityPickerButton({
    super.key,
    required this.currentCity,
    required this.onSelected,
    this.iconColor = AppColors.accent,
  });

  final String currentCity;
  final ValueChanged<String> onSelected;
  final Color iconColor;

  @override
  State<CityPickerButton> createState() => _CityPickerButtonState();
}

class _CityPickerButtonState extends State<CityPickerButton> {
  bool _open = false;

  Future<void> _openList() async {
    setState(() => _open = true);
    await showCityDropdown(
      context,
      currentCity: widget.currentCity,
      onSelected: widget.onSelected,
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.currentCity.trim().isEmpty
        ? kAllCities
        : widget.currentCity.trim();
    return Semantics(
      button: true,
      label: 'City: $city. Change city',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: _open ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          onTap: _openList,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: widget.iconColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'City · ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextSpan(text: city),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
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

/// Opens the city list as a dropdown under [anchor] (the widget that was
/// tapped): search box, "All Cities", then every city from GET /cities.
/// Tapping outside closes it. Opens above the anchor when there is not
/// enough room below (for example with the keyboard open).
Future<void> showCityDropdown(
  BuildContext anchor, {
  required String currentCity,
  required ValueChanged<String> onSelected,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(anchor).overlay?.context.findRenderObject() as RenderBox?;
  Rect rect;
  if (box != null && overlay != null && box.hasSize) {
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    rect = topLeft & box.size;
  } else {
    rect = const Rect.fromLTWH(16, 120, 0, 0);
  }
  return Navigator.of(anchor).push(
    _CityDropdownRoute(
      anchor: rect,
      currentCity: currentCity,
      onSelected: onSelected,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    ),
  );
}

class _CityDropdownRoute extends PopupRoute<void> {
  _CityDropdownRoute({
    required this.anchor,
    required this.currentCity,
    required this.onSelected,
    required this.barrierLabel,
  });

  final Rect anchor;
  final String currentCity;
  final ValueChanged<String> onSelected;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    const margin = 16.0;
    const gap = 6.0;
    final width = (screen.width - margin * 2).clamp(0.0, 340.0);
    final left = anchor.left.clamp(margin, screen.width - margin - width);
    final keyboardTop = screen.height - media.viewInsets.bottom;
    final roomBelow = keyboardTop - anchor.bottom - gap - margin;
    final roomAbove = anchor.top - media.padding.top - gap - margin;
    final below = roomBelow >= 240 || roomBelow >= roomAbove;
    final height = (below ? roomBelow : roomAbove).clamp(120.0, 420.0);

    final panel = _CityDropdownPanel(
      currentCity: currentCity,
      maxHeight: height,
      onSelected: (city) {
        Navigator.of(context).pop();
        onSelected(city);
      },
    );

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            top: below ? anchor.bottom + gap : null,
            bottom: below ? null : screen.height - anchor.top + gap,
            child: ScaleTransition(
              alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
              scale: Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: panel,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityDropdownPanel extends ConsumerStatefulWidget {
  const _CityDropdownPanel({
    required this.currentCity,
    required this.maxHeight,
    required this.onSelected,
  });

  final String currentCity;
  final double maxHeight;
  final ValueChanged<String> onSelected;

  @override
  ConsumerState<_CityDropdownPanel> createState() => _CityDropdownPanelState();
}

class _CityDropdownPanelState extends ConsumerState<_CityDropdownPanel> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isSelected(String name) =>
      widget.currentCity.trim().toLowerCase() == name.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(citiesFutureProvider);
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search city...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: async.when(
                loading: () => AppShimmer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 6; i++)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: ShimmerBox(
                            width: double.infinity,
                            height: 16,
                            borderRadius: 4,
                          ),
                        ),
                    ],
                  ),
                ),
                // A failure is a failure (with Retry), never "no cities".
                error: (_, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Could not load cities.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(citiesFutureProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (cities) => _list(cities),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<City> cities) {
    final q = _query.toLowerCase();
    final names = <String>[
      if (q.isEmpty || 'all cities'.contains(q)) kAllCities,
      ...cities
          .map((c) => c.name.trim())
          .where(
            (n) =>
                n.isNotEmpty &&
                n.toLowerCase() != 'all' &&
                (q.isEmpty || n.toLowerCase().contains(q)),
          ),
    ];
    if (names.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'No city matches "$_query".',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
        itemCount: names.length,
        itemBuilder: (context, i) {
          final name = names[i];
          final selected = _isSelected(name);
          final label = name == kAllCities ? 'All Cities' : name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onSelected(name),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected
                                  ? AppColors.brandNavy
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.brandNavy,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
