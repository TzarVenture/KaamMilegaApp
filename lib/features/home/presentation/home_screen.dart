import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/voice_search_button.dart';
import '../../applications/presentation/apply_modal.dart';
import '../../../app/auth_guard.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cities/presentation/city_dropdown.dart';
import '../../jobs/models/job.dart';
import '../../jobs/models/job_filter.dart';
import '../../jobs/providers/jobs_provider.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import 'widgets/connect_like_you_section.dart';
import 'widgets/home_section_header.dart';
import 'widgets/home_welcome.dart';
import 'widgets/featured_companies_section.dart';
import 'widgets/job_categories_section.dart';
import 'widgets/job_shortcuts_sections.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/rotating_search_hint.dart';

/// KaamMilega™ Home Screen
/// Pixel-perfect implementation matching official design specification.
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Space between two Home sections (the same everywhere).
  static const double _sectionGap = 28;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToJobsTabWithQuery([String query = '']) {
    if (query.isNotEmpty) {
      ref.read(jobsProvider.notifier).setSearchQuery(query);
    }
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      context.go('/jobs');
    }
  }

  /// Qualification / job type shortcut: opens the Jobs tab with only that
  /// filter on (the selected city is kept). Home's own lists are unchanged.
  void _openJobsWithShortcut(JobShortcut shortcut) {
    final city = ref.read(jobsProvider).filter.city;
    ref.read(jobsProvider.notifier).applyFilter(shortcut.filterFor(city));
    _goToJobsTabWithQuery();
  }

  /// Photo category: opens the Jobs tab searching for that trade (only
  /// that search; the selected city is kept).
  void _openJobsWithCategory(JobCategory category) {
    final city = ref.read(jobsProvider).filter.city;
    ref
        .read(jobsProvider.notifier)
        .applyFilter(JobFilter(city: city, searchQuery: category.query));
    _goToJobsTabWithQuery();
  }

  void _show99AccessModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '₹99 One-Time Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LIFETIME UNLOCK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Unlock full candidate power with ₹99 lifetime access:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _buildBenefitRow(
              Icons.work_rounded,
              'Unlimited Job Applications without daily limits',
            ),
            _buildBenefitRow(
              Icons.search_rounded,
              'Priority Search ranking for recruiter discovery',
            ),
            _buildBenefitRow(
              Icons.people_rounded,
              'Directly connect and chat with verified providers',
            ),
            _buildBenefitRow(
              Icons.assignment_ind_rounded,
              'Profile and resume strength review',
            ),
            _buildBenefitRow(
              Icons.bolt_rounded,
              'Full InstantMilega™ on-demand spot gig dispatch',
            ),
            _buildBenefitRow(
              Icons.card_giftcard_rounded,
              'Earn more reward coins & cashback vouchers',
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentBright],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '₹99 Access is coming soon. Payments are not live yet, so you have not been charged.',
                      ),
                      backgroundColor: Color(0xFFD97706),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Get ₹99 Access Now →',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);
    // Home lists use their own city-only request (homeJobsProvider). If it
    // fails (e.g. offline), the Jobs tab's list is used only while that list
    // is not narrowed by a search or filter.
    final homeJobsAsync = ref.watch(homeJobsProvider);
    final jobsTabUnfiltered =
        jobsState.filter.searchQuery.isEmpty &&
        jobsState.filter.activeFilterCount == 0 &&
        jobsState.filter.page == 1;
    final homeJobs =
        homeJobsAsync.value ??
        (homeJobsAsync.hasError && jobsTabUnfiltered
            ? jobsState.jobs
            : const <Job>[]);
    final homeJobsLoading = homeJobsAsync.isLoading && homeJobs.isEmpty;
    final currentCity = jobsState.filter.city.isNotEmpty
        ? jobsState.filter.city
        : 'Delhi, India';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: ProfileDrawer(onNavigateTab: widget.onNavigateTab),
      // 1. TOP APP BAR — same AppBar (height, padding, icons) as the Jobs
      // tab, so switching tabs does not move it. Stays while scrolling.
      appBar: _buildTopBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                // No bounce at the top: the navy header stays attached.
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Same order idea as a store front: find a job first,
                    // then browse, then offers, then people. Every section
                    // uses HomeSectionHeader and the same gap between them.

                    // Navy header: greeting with the city, then search.
                    _buildHeroHeader(currentCity),
                    const SizedBox(height: 16),

                    // Signed in: the user's numbers and profile progress
                    // in one card.
                    FadeSlideIn(
                      index: 1,
                      child: HomeDashboardCard(
                        onOpenProfile: () => widget.onNavigateTab?.call(4),
                      ),
                    ),
                    if (AuthGuard.isSignedIn(ref.watch(authProvider)))
                      const SizedBox(height: 16),

                    // InstantMilega(TM) banner
                    FadeSlideIn(index: 1, child: _buildInstantMilegaBanner()),
                    const SizedBox(height: _sectionGap),

                    // Shortcuts to the app's areas (Jobs, Instant Work, ...)
                    FadeSlideIn(index: 2, child: _buildQuickActionIcons()),
                    const SizedBox(height: _sectionGap),

                    // Explore Popular Job Categories (photo tiles)
                    FadeSlideIn(
                      index: 3,
                      child: JobCategoriesSection(
                        onSelected: _openJobsWithCategory,
                        onViewAll: _goToJobsTabWithQuery,
                      ),
                    ),
                    const SizedBox(height: _sectionGap),

                    // Jobs: Recommended for You (sideways), then Top Picks
                    FadeSlideIn(
                      index: 3,
                      child: _buildRecommendedSection(
                        homeJobs,
                        homeJobsLoading,
                      ),
                    ),
                    if (homeJobsLoading || homeJobs.isNotEmpty)
                      const SizedBox(height: _sectionGap),
                    FadeSlideIn(
                      index: 4,
                      child: _buildTopPicksSection(homeJobs),
                    ),
                    if (homeJobs.isNotEmpty)
                      const SizedBox(height: _sectionGap),

                    // Find jobs your way: job type, then education
                    FadeSlideIn(
                      index: 5,
                      child: JobTypeShortcutsSection(
                        onSelected: _openJobsWithShortcut,
                      ),
                    ),
                    const SizedBox(height: _sectionGap),
                    FadeSlideIn(
                      index: 6,
                      child: QualificationShortcutsSection(
                        onSelected: _openJobsWithShortcut,
                      ),
                    ),
                    const SizedBox(height: _sectionGap),

                    // Rs 99 Access offer
                    FadeSlideIn(index: 8, child: _build99AccessBanner()),
                    const SizedBox(height: _sectionGap),

                    // Employers hiring (hidden when there are none)
                    const FadeSlideIn(
                      index: 9,
                      child: FeaturedCompaniesSection(),
                    ),
                    const SizedBox(height: _sectionGap),

                    // People: members, then experts
                    const FadeSlideIn(
                      index: 10,
                      child: ConnectLikeYouSection(),
                    ),
                    const SizedBox(height: _sectionGap),
                    const FadeSlideIn(
                      index: 11,
                      child: ConnectExpertsSection(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP APP BAR (pinned: stays visible while the page scrolls,
  //    same behaviour as the Jobs tab app bar)
  // ==========================================
  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      // Navy, flowing into the header below (no line between them).
      backgroundColor: AppColors.brandNavy,
      surfaceTintColor: AppColors.brandNavy,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      // Logo: scrolls Home back to the top
      title: GestureDetector(
        onTap: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          if (widget.onNavigateTab != null) {
            widget.onNavigateTab!(0);
          } else {
            try {
              context.go('/home');
            } catch (_) {}
          }
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The K mark on a white tile (its dark parts would vanish
              // on navy), then the name in white and brand orange.
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
              Semantics(
                label: 'KaamMilega',
                excludeSemantics: true,
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Kaammi',
                        style: TextStyle(color: AppColors.white),
                      ),
                      TextSpan(
                        text: 'lega',
                        style: TextStyle(color: AppColors.accentBright),
                      ),
                      TextSpan(
                        text: '™',
                        style: TextStyle(color: AppColors.white, fontSize: 10),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Notification bell (shared button: ripple, tap area, badge).
        const NotificationBellButton(color: AppColors.white),

        // Menu (opens the profile drawer)
        IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColors.white,
            size: 24,
          ),
          splashRadius: 20,
          tooltip: 'Menu',
          onPressed: () {
            _scaffoldKey.currentState?.openEndDrawer();
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ==========================================
  // 1b. NAVY HEADER: greeting, city, search (scrolls with the page)
  // ==========================================
  /// Navy panel under the app bar: greeting with the city picker, then
  /// the search box. On narrow phones the city goes under the greeting.
  Widget _buildHeroHeader(String currentCity) {
    final city = CityPickerButton(
      currentCity: currentCity,
      onSelected: (c) => ref.read(jobsProvider.notifier).setCity(c),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) => box.maxWidth < 340
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HomeGreeting(),
                      const SizedBox(height: 10),
                      city,
                    ],
                  )
                : Row(
                    children: [
                      const Expanded(child: HomeGreeting()),
                      const SizedBox(width: 10),
                      city,
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _buildSearchBox(),
        ],
      ),
    );
  }

  // ==========================================
  // 1c. SEARCH BOX (typed or voice) -> Jobs tab search
  // ==========================================
  /// Searches jobs by title, description, company or location (backend
  /// GET /jobs `search`). Opens the Jobs tab with the results; Home's own
  /// lists are not filtered.
  void _submitHomeSearch([String? text]) {
    final query = (text ?? _searchController.text).trim();
    FocusScope.of(context).unfocus();
    _searchController.clear();
    _goToJobsTabWithQuery(query);
  }

  static const _searchExamples = [
    'Jobs',
    'Companies',
    'Locations',
    'Electrician',
    'Delivery jobs',
    'Part-time work',
  ];

  Widget _buildSearchBox() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitHomeSearch,
        decoration: InputDecoration(
          // "Search for 'Jobs'", then 'Companies', ... (what this box
          // finds: jobs by title, company or location).
          hint: const RotatingSearchHint(
            semanticLabel: 'Search jobs, companies or locations',
            examples: _searchExamples,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.brandNavy,
          ),
          suffixIcon: VoiceSearchButton(
            color: AppColors.textSecondary,
            onText: (words) {
              _searchController.value = TextEditingValue(
                text: words,
                selection: TextSelection.collapsed(offset: words.length),
              );
            },
            onDone: _submitHomeSearch,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. INSTANTMILEGA™ PROMO BANNER (Purple Card)
  // ==========================================
  Widget _buildInstantMilegaBanner() {
    return GestureDetector(
      onTap: () => context.push('/instant-work'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.deepNavy, Color(0xFF152A7A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepNavy.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Glowing Stopwatch/Lightning Badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF070F35),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // Middle: Copy
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    const TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      children: [
                        TextSpan(
                          text: 'Instant',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Milega',
                          style: TextStyle(color: AppColors.brandOrange),
                        ),
                        TextSpan(
                          text: '™',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Work in Minutes.\nAnywhere, Anytime!',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.border,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Right: ONE TIME ACCESS ₹99 ONLY >
            GestureDetector(
              onTap: _show99AccessModal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ONE TIME ACCESS',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(
                              text: '₹99 ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'ONLY ',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. QUICK ACTION CIRCULAR ICONS ROW
  // ==========================================
  Widget _buildQuickActionIcons() {
    final actions = [
      {
        'label': 'Jobs',
        'icon': Icons.work_outline_rounded,
        'bg': AppColors.primaryLight,
        'color': AppColors.primary,
        'onTap': () => _goToJobsTabWithQuery(''),
      },
      {
        'label': 'Instant Work',
        'icon': Icons.bolt_rounded,
        'bg': AppColors.accentLight,
        'color': AppColors.accent,
        'onTap': () => context.push('/instant-work'),
      },
      {
        'label': 'Skills',
        'icon': Icons.school_outlined,
        'bg': const Color(0xFFDCFCE7),
        'color': AppColors.moduleSkills,
        'onTap': () => context.push('/skills-marketplace'),
      },
      {
        'label': 'Experts',
        'icon': Icons.person_search_outlined,
        'bg': AppColors.moduleExpertsLight,
        'color': AppColors.moduleExperts,
        'onTap': () => context.push('/experts'),
      },
      {
        'label': 'Services',
        'icon': Icons.home_repair_service_outlined,
        'bg': AppColors.moduleServicesLight,
        'color': AppColors.moduleServices,
        'onTap': () => context.push('/services'),
      },
      {
        'label': 'More',
        'icon': Icons.more_horiz_rounded,
        'bg': const Color(0xFFF1F5F9),
        'color': const Color(0xFF475569),
        'onTap': () => context.push('/explore'),
      },
    ];

    return _HorizontalStrip(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 18,
        children: actions.map((item) {
          final label = item['label'] as String;
          final icon = item['icon'] as IconData;
          final bg = item['bg'] as Color;
          final color = item['color'] as Color;
          final onTap = item['onTap'] as VoidCallback;

          return GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Category Icon & Color Helpers
  IconData _getJobCategoryIcon(String title, String jobType) {
    final t = title.toLowerCase();
    if (t.contains('deliver') ||
        t.contains('rider') ||
        t.contains('courier') ||
        t.contains('zomato') ||
        t.contains('swiggy') ||
        t.contains('zepto') ||
        t.contains('blinkit')) {
      return Icons.delivery_dining_rounded;
    }
    if (t.contains('design') ||
        t.contains('graphic') ||
        t.contains('ui') ||
        t.contains('ux') ||
        t.contains('creative') ||
        t.contains('video') ||
        t.contains('editor')) {
      return Icons.design_services_rounded;
    }
    if (t.contains('dev') ||
        t.contains('tech') ||
        t.contains('software') ||
        t.contains('engineer') ||
        t.contains('it ') ||
        t.contains('programmer') ||
        t.contains('web')) {
      return Icons.code_rounded;
    }
    if (t.contains('electr') ||
        t.contains('technician') ||
        t.contains('plumb') ||
        t.contains('repair') ||
        t.contains('carpenter') ||
        t.contains('mechanic')) {
      return Icons.engineering_rounded;
    }
    if (t.contains('drive') ||
        t.contains('chauffeur') ||
        t.contains('cab') ||
        t.contains('uber') ||
        t.contains('ola')) {
      return Icons.directions_car_rounded;
    }
    if (t.contains('clean') ||
        t.contains('maid') ||
        t.contains('housekeep') ||
        t.contains('cook') ||
        t.contains('chef')) {
      return Icons.cleaning_services_rounded;
    }
    if (t.contains('sale') ||
        t.contains('market') ||
        t.contains('bpo') ||
        t.contains('call') ||
        t.contains('tele') ||
        t.contains('customer')) {
      return Icons.headset_mic_rounded;
    }
    if (t.contains('account') ||
        t.contains('finance') ||
        t.contains('audit') ||
        t.contains('data entry') ||
        t.contains('back office')) {
      return Icons.assignment_rounded;
    }
    if (t.contains('secur') || t.contains('guard')) {
      return Icons.security_rounded;
    }
    if (t.contains('teach') ||
        t.contains('tutor') ||
        t.contains('faculty') ||
        t.contains('trainer')) {
      return Icons.school_rounded;
    }
    return Icons.work_rounded;
  }

  Color _getJobCategoryColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('deliver') || t.contains('rider')) {
      return const Color(0xFFEF4444);
    }
    if (t.contains('design') || t.contains('graphic')) {
      return AppColors.blue;
    }
    if (t.contains('dev') || t.contains('tech') || t.contains('software')) {
      return const Color(0xFF7C3AED);
    }
    if (t.contains('electr') ||
        t.contains('technician') ||
        t.contains('mechanic')) {
      return const Color(0xFFD97706);
    }
    if (t.contains('drive')) {
      return const Color(0xFF1E293B);
    }
    if (t.contains('clean') || t.contains('maid')) {
      return const Color(0xFF0D9488);
    }
    if (t.contains('sale') || t.contains('market') || t.contains('tele')) {
      return AppColors.accent;
    }
    if (t.contains('account') || t.contains('finance') || t.contains('data')) {
      return AppColors.blue;
    }
    return AppColors.blue;
  }

  // ==========================================
  // 6. RECOMMENDED FOR YOU SECTION
  // ==========================================
  /// Height of the horizontal "Recommended" row. Grows with the phone's
  /// font size so card text is never cut off (no cap on text scaling).
  // 160: room for Poppins with the brand line height (145 overflowed by 3 px).
  double _recommendedRowHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(160).clamp(160.0, 280.0);

  Widget _buildRecommendedSection(List<Job> jobs, bool isLoading) {
    if (isLoading && jobs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: 'Recommended for You',
            subtitle: 'Latest jobs on KaamMilega',
            onSeeAll: () => _goToJobsTabWithQuery(''),
          ),
          const SizedBox(height: HomeSectionHeader.gap),
          SizedBox(
            height: _recommendedRowHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _buildRecommendedShimmerCard(),
            ),
          ),
        ],
      );
    }

    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final recommendedJobs = jobs.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Recommended for You',
          subtitle: 'Latest jobs on KaamMilega',
          onSeeAll: () => _goToJobsTabWithQuery(''),
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        SizedBox(
          height: _recommendedRowHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendedJobs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              child: Builder(
                builder: (context) {
                  final job = recommendedJobs[index];
                  return _buildRecommendedCard(job);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedShimmerCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: HomeCard.decoration(),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 55,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCard(Job job) {
    final icon = _getJobCategoryIcon(job.title, job.jobType);
    final iconColor = _getJobCategoryColor(job.title);

    return PressableScale(
      child: GestureDetector(
        onTap: () {
          if (job.id.isNotEmpty) {
            context.push('/jobs/${job.id}', extra: job);
          }
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: HomeCard.decoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          job.company,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: job.formattedSalary,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text: ' /month',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.formattedLocation,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shows the real job type. (Previously a hard-coded "4.8"
                  // star rating, identical for every company.)
                  Row(
                    children: [
                      const Icon(
                        Icons.work_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        job.jobType.isNotEmpty ? job.jobType : 'Job',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!ref.read(authProvider).isAuthenticated) {
                        showAuthPromptDialog(
                          context,
                          title: 'Sign In to Apply',
                          message:
                              'Please sign in to your KaamMilega account to apply for ${job.title} at ${job.company}.',
                        );
                        return;
                      }
                      ApplyModalSheet.show(
                        context,
                        job: job,
                        onSuccess: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Applied for ${job.title} successfully!',
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.brandNavy,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Apply Now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 7. UNLOCK ALL BENEFITS WITH ₹99 ACCESS BANNER
  // ==========================================
  Widget _build99AccessBanner() {
    final benefits = [
      (Icons.work_outline_rounded, 'Unlimited applications'),
      (Icons.search_rounded, 'Priority in search'),
      (Icons.people_outline_rounded, 'Connect with providers'),
      (Icons.trending_up_rounded, 'Profile boost'),
      (Icons.bolt_rounded, 'InstantMilega™ access'),
      (Icons.card_giftcard_rounded, 'Earn more rewards'),
    ];

    Widget tile((IconData, String) b) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(b.$1, color: AppColors.topMatchGold, size: 20),
            const SizedBox(height: 6),
            Text(
              b.$2,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );

    Widget tileRow(int from) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(benefits[from]),
          const SizedBox(width: 8),
          tile(benefits[from + 1]),
          const SizedBox(width: 8),
          tile(benefits[from + 2]),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(HomeCard.radius + 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text.rich(
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
              children: [
                TextSpan(text: 'Unlock all benefits with '),
                TextSpan(
                  text: '₹99 Access',
                  style: TextStyle(color: AppColors.topMatchGold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          tileRow(0),
          const SizedBox(height: 8),
          tileRow(3),
          const SizedBox(height: 16),

          // CTA Gradient Button
          GestureDetector(
            onTap: _show99AccessModal,
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentBright],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBright.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Get ₹99 Access Now →',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. TOP PICKS SECTION
  // ==========================================
  Widget _buildTopPicksSection(List<Job> jobs) {
    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final savedJobIds = ref.watch(jobsProvider).savedJobIds;
    // Show top picks from jobs list (take up to 3 jobs)
    final topPicks = jobs.length > 2
        ? jobs.skip(2).take(4).toList()
        : jobs.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Top Picks',
          subtitle: 'More openings you may like',
          onSeeAll: () => _goToJobsTabWithQuery(''),
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          decoration: HomeCard.decoration(),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final (i, job) in topPicks.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 76,
                      color: AppColors.borderLight,
                    ),
                  _buildTopPickRow(job, savedJobIds.contains(job.id)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopPickRow(Job job, bool isSaved) {
    final icon = _getJobCategoryIcon(job.title, job.jobType);
    final iconColor = _getJobCategoryColor(job.title);
    return InkWell(
      onTap: () {
        if (job.id.isNotEmpty) {
          context.push('/jobs/${job.id}', extra: job);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Company only when known (no empty line).
                  if (job.company.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      job.company,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${job.formattedSalary} /month',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (job.formattedLocation.isNotEmpty)
                          TextSpan(text: '  ·  ${job.formattedLocation}'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: isSaved ? 'Remove from saved' : 'Save job',
              icon: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () {
                ref.read(jobsProvider.notifier).toggleSaveJob(job.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isSaved
                          ? 'Job removed from saved jobs'
                          : 'Job saved successfully!',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A row that spreads its items across the screen like before, and
/// scrolls sideways when they do not fit (small phones, large text).
class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.child});

  final Widget child;

  static const double _sidePadding = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
        child: ConstrainedBox(
          // At least the screen width, so items stay spread out when they fit
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth - _sidePadding * 2,
          ),
          child: child,
        ),
      ),
    );
  }
}
