import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/job_filter.dart';

/// Jobs filter sheet.
///
/// Layout (top to bottom, by importance):
/// 1. Instant Milega: the one colourful, raised element, so it is seen
///    first; one large button opens the Instant Milega screen.
/// 2. Job filters as compact chips, all visible at once (no closed
///    accordions), so every choice is one tap away.
/// 3. A sticky footer with Clear all / Apply Filters.
class FilterModalSheet extends StatefulWidget {
  final JobFilter initialFilter;
  final ValueChanged<JobFilter> onApply;

  const FilterModalSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required JobFilter initialFilter,
    required ValueChanged<JobFilter> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FilterModalSheet(initialFilter: initialFilter, onApply: onApply),
    );
  }

  @override
  State<FilterModalSheet> createState() => _FilterModalSheetState();
}

class _FilterModalSheetState extends State<FilterModalSheet> {
  late List<String> _jobTypes;
  late String _salaryRange;
  late String _experience;
  late List<String> _genders;
  late List<String> _qualification;

  static const List<String> kJobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Internship',
  ];

  static const List<Map<String, String>> kSalaryRanges = [
    {'label': 'Any salary', 'value': 'all'},
    {'label': '₹5,000+', 'value': '5000'},
    {'label': '₹10,000+', 'value': '10000'},
    {'label': '₹20,000+', 'value': '20000'},
    {'label': '₹30,000+', 'value': '30000'},
  ];

  static const List<Map<String, String>> kExperienceLevels = [
    {'label': 'Any', 'value': 'all'},
    {'label': 'Fresher', 'value': '0'},
    {'label': '1 Year', 'value': '1'},
    {'label': '2-4 Years', 'value': '4'},
    {'label': '5 Years', 'value': '5'},
    {'label': '5+ Years', 'value': '30'},
  ];

  static const List<String> kGenders = ['Male', 'Female', 'Any'];

  static const List<String> kQualifications = [
    '10th Pass',
    '12th Pass',
    'Diploma',
    'Graduation',
    'Post Graduation',
  ];

  @override
  void initState() {
    super.initState();
    _jobTypes = List.from(widget.initialFilter.jobTypes);
    _salaryRange = widget.initialFilter.salaryRange;
    _experience = widget.initialFilter.experience;
    _genders = List.from(widget.initialFilter.genders);
    _qualification = List.from(widget.initialFilter.qualification);
  }

  int get _activeCount {
    int c = _jobTypes.length + _genders.length + _qualification.length;
    if (_salaryRange != 'all') c++;
    if (_experience != 'all') c++;
    return c;
  }

  void _clearAll() {
    setState(() {
      _jobTypes.clear();
      _salaryRange = 'all';
      _experience = 'all';
      _genders.clear();
      _qualification.clear();
    });
  }

  void _submit() {
    final updated = widget.initialFilter.copyWith(
      jobTypes: _jobTypes,
      salaryRange: _salaryRange,
      experience: _experience,
      genders: _genders,
      qualification: _qualification,
      page: 1,
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  void _openInstantMilega() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/instant-work');
  }

  void _toggle(List<String> list, String value) {
    setState(() {
      list.contains(value) ? list.remove(value) : list.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _activeCount;
    return Material(
      color: AppColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
              child: Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: count == 0 ? null : _clearAll,
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  _InstantMilegaHero(onTap: _openInstantMilega),
                  const SizedBox(height: 22),
                  const _OrDivider(text: 'OR REFINE YOUR JOB SEARCH'),
                  const SizedBox(height: 8),

                  _Section(
                    icon: Icons.payments_outlined,
                    title: 'Monthly salary',
                    child: _ChipWrap(
                      children: [
                        for (final s in kSalaryRanges)
                          _FilterChip(
                            label: s['label']!,
                            selected: _salaryRange == s['value'],
                            onTap: () =>
                                setState(() => _salaryRange = s['value']!),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.timeline_rounded,
                    title: 'Experience',
                    child: _ChipWrap(
                      children: [
                        for (final e in kExperienceLevels)
                          _FilterChip(
                            label: e['label']!,
                            selected: _experience == e['value'],
                            onTap: () =>
                                setState(() => _experience = e['value']!),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.work_outline_rounded,
                    title: 'Job type',
                    hint: 'Pick any',
                    child: _ChipWrap(
                      children: [
                        for (final t in kJobTypes)
                          _FilterChip(
                            label: t,
                            selected: _jobTypes.contains(t),
                            onTap: () => _toggle(_jobTypes, t),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.wc_rounded,
                    title: 'Gender',
                    hint: 'Pick any',
                    child: Row(
                      children: [
                        for (var i = 0; i < kGenders.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _GenderTile(
                              gender: kGenders[i],
                              selected: _genders.contains(kGenders[i]),
                              onTap: () => _toggle(_genders, kGenders[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.school_outlined,
                    title: 'Qualification',
                    hint: 'Pick any',
                    child: _ChipWrap(
                      children: [
                        for (final q in kQualifications)
                          _FilterChip(
                            label: q,
                            selected: _qualification.contains(q),
                            onTap: () => _toggle(_qualification, q),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandNavy.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: count == 0 ? null : _clearAll,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Clear all',
                              maxLines: 1,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandNavy,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              count > 0
                                  ? 'Apply Filters ($count)'
                                  : 'Apply Filters',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Instant Milega hero
// ---------------------------------------------------------------------------

/// The sheet's focal point: orange gradient card with a soft glow, a light
/// sweep that plays twice when the sheet opens (skipped with reduce
/// motion), and one large "Find work now" button.
class _InstantMilegaHero extends StatefulWidget {
  const _InstantMilegaHero({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_InstantMilegaHero> createState() => _InstantMilegaHeroState();
}

class _InstantMilegaHeroState extends State<_InstantMilegaHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  int _runs = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _shine.addStatusListener((status) {
      if (status == AnimationStatus.completed && ++_runs < 2) {
        _shine.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.of(context).disableAnimations) {
      _started = true;
      _shine.forward();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Instant Milega. Find quick gigs near you. Find work now',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.moduleInstantWork.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.moduleInstantWork,
                  AppColors.moduleInstantWorkDeep,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                children: [
                  // Soft decorative circles
                  Positioned(
                    right: -30,
                    top: -40,
                    child: _Circle(size: 140, alpha: 0.10),
                  ),
                  Positioned(
                    right: 50,
                    bottom: -50,
                    child: _Circle(size: 110, alpha: 0.07),
                  ),
                  // Light sweep
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (context, _) {
                          final t = Curves.easeInOut.transform(
                            (_shine.value / 0.45).clamp(0.0, 1.0),
                          );
                          if (_shine.value == 0 || _shine.value >= 0.45) {
                            return const SizedBox.shrink();
                          }
                          return FractionalTranslation(
                            translation: Offset(-1.2 + 2.6 * t, 0),
                            child: Transform.rotate(
                              angle: 0.35,
                              child: Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.white.withValues(alpha: 0),
                                      AppColors.white.withValues(alpha: 0.28),
                                      AppColors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: AppColors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Instant Milega',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Work today',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Skip the wait. Find quick gigs and helpers near you.',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.95),
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Find work now',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.moduleInstantWorkDeep,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                                color: AppColors.moduleInstantWorkDeep,
                              ),
                            ],
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
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderLight)),
        Flexible(
          flex: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderLight)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter sections
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.hint = '',
  });

  final IconData icon;
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

/// Selectable chip: navy with a tick when selected, outlined otherwise.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandNavy : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.brandNavy : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gender tile: blue male sign, pink female sign, neutral for Any.
class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final String gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (gender.toLowerCase()) {
      'male' => (
        Icons.male_rounded,
        AppColors.genderMale,
        AppColors.genderMaleBg,
      ),
      'female' => (
        Icons.female_rounded,
        AppColors.genderFemale,
        AppColors.genderFemaleBg,
      ),
      _ => (Icons.wc_rounded, AppColors.textSecondary, AppColors.background),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: gender,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? bg : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.white : bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected ? color : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 8,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
