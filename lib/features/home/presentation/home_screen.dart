import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../applications/presentation/apply_modal.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../../jobs/models/job.dart';
import '../../jobs/providers/jobs_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';

/// KaamMilega™ Home Screen
/// Pixel-perfect implementation matching official design specification.
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCitySelector(String currentCity) {
    CitySelectorSheet.show(
      context,
      currentCity: currentCity,
      onSelected: (selectedCity) {
        ref.read(jobsProvider.notifier).setCity(selectedCity);
      },
    );
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

  void _show99AccessModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                const Text(
                  '₹99 One-Time Access',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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
                      fontWeight: FontWeight.w900,
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
              Icons.auto_awesome_rounded,
              'AI Profile Resume and Score Enhancement',
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
                  colors: [Color(0xFFFF7A00), Color(0xFFFF0066)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0066).withValues(alpha: 0.35),
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
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
    final currentCity = jobsState.filter.city.isNotEmpty
        ? jobsState.filter.city
        : 'Delhi, India';
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: ProfileDrawer(onNavigateTab: widget.onNavigateTab),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP APP BAR (Logo + Search, Notification Bell with red dot, Three-line Menu)
              _buildTopHeader(currentCity, unreadCount),

              const SizedBox(height: 10),

              // 2. INSTANTMILEGA™ PROMO BANNER (Purple Card)
              _buildInstantMilegaBanner(),

              const SizedBox(height: 18),

              // 3. QUICK ACTION CIRCULAR ICONS ROW (Jobs, Instant Work, Skills, Experts, Services, More)
              _buildQuickActionIcons(),

              const SizedBox(height: 22),

              // 4. POPULAR CATEGORIES SECTION
              _buildPopularCategories(),

              const SizedBox(height: 22),

              // 5. RECOMMENDED FOR YOU SECTION (Side by side cards)
              _buildRecommendedSection(jobsState.jobs, jobsState.isLoading),

              const SizedBox(height: 22),

              // 6. UNLOCK ALL BENEFITS WITH ₹99 ACCESS BANNER
              _build99AccessBanner(),

              const SizedBox(height: 22),

              // 7. TOP PICKS SECTION (Vertical List Card)
              _buildTopPicksSection(jobsState.jobs),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP APP BAR & CITY SELECTOR
  // ==========================================
  Widget _buildTopHeader(String currentCity, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo: clickable navigating to home & scrolling to top
              Expanded(
                child: GestureDetector(
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
                        Image.asset(
                          'assets/images/logo.png',
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/images/logo_text.png',
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right Action Icons Row: Search + Notification Bell + Three-line Hamburger
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Icon Button (Left of Notification Bell)
                  IconButton(
                    onPressed: () => _goToJobsTabWithQuery(''),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF1E293B),
                      size: 24,
                    ),
                    splashRadius: 22,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),

                  // Notification Bell with dynamic unread indicator dot
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1E293B),
                            size: 24,
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Three-line Hamburger Option Button (Right of Notification Bell)
                  IconButton(
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFF1E293B),
                      size: 24,
                    ),
                    splashRadius: 22,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Location Selector
          GestureDetector(
            onTap: () => _openCitySelector(currentCity),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  currentCity,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
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
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                      children: [
                        TextSpan(
                          text: 'Instant',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Milega™',
                          style: TextStyle(color: Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Work in Minutes.\nAnywhere, Anytime!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE2E8F0),
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
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: '₹99 ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'ONLY ',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
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
                          color: Color(0xFFF97316),
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
        'bg': const Color(0xFFF3E8FF),
        'color': AppColors.moduleExperts,
        'onTap': () => context.push('/experts'),
      },
      {
        'label': 'Services',
        'icon': Icons.home_repair_service_outlined,
        'bg': const Color(0xFFFFE4E6),
        'color': const Color(0xFFE11D48),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // 5. POPULAR CATEGORIES SECTION
  // ==========================================
  Widget _buildPopularCategories() {
    final categories = [
      {
        'name': 'Delivery',
        'icon': Icons.electric_moped_rounded,
        'bg': const Color(0xFFFFF7ED),
        'color': const Color(0xFFEA580C),
      },
      {
        'name': 'Electrician',
        'icon': Icons.electrical_services_rounded,
        'bg': const Color(0xFFFEF2F2),
        'color': const Color(0xFFDC2626),
      },
      {
        'name': 'AC Repair',
        'icon': Icons.ac_unit_rounded,
        'bg': const Color(0xFFEFF6FF),
        'color': const Color(0xFF2563EB),
      },
      {
        'name': 'House Help',
        'icon': Icons.cleaning_services_rounded,
        'bg': const Color(0xFFFFFBEB),
        'color': const Color(0xFFD97706),
      },
      {
        'name': 'Data Entry',
        'icon': Icons.assignment_rounded,
        'bg': const Color(0xFFFAF5FF),
        'color': const Color(0xFF9333EA),
      },
      {
        'name': 'Driver',
        'icon': Icons.directions_car_rounded,
        'bg': const Color(0xFFF1F5F9),
        'color': const Color(0xFF1E293B),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => _goToJobsTabWithQuery(''),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: categories.map((cat) {
              final name = cat['name'] as String;
              final icon = cat['icon'] as IconData;
              final bg = cat['bg'] as Color;
              final color = cat['color'] as Color;

              return GestureDetector(
                onTap: () => _goToJobsTabWithQuery(name),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
      return const Color(0xFF2563EB);
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
      return const Color(0xFFEA580C);
    }
    if (t.contains('account') || t.contains('finance') || t.contains('data')) {
      return const Color(0xFF9333EA);
    }
    return const Color(0xFF2563EB);
  }

  // ==========================================
  // 6. RECOMMENDED FOR YOU SECTION
  // ==========================================
  Widget _buildRecommendedSection(List<Job> jobs, bool isLoading) {
    if (isLoading && jobs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 145,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended for You',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => _goToJobsTabWithQuery(''),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendedJobs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final job = recommendedJobs[index];
              return _buildRecommendedCard(job);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedShimmerCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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

    return GestureDetector(
      onTap: () {
        if (job.id.isNotEmpty) {
          context.push('/jobs/${job.id}', extra: job);
        }
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
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
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: job.formattedSalary,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const TextSpan(
                        text: ' /month',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
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
                    color: Color(0xFF64748B),
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
                      color: Color(0xFF64748B),
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      job.jobType.isNotEmpty ? job.jobType : 'Job',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 7. UNLOCK ALL BENEFITS WITH ₹99 ACCESS BANNER
  // ==========================================
  Widget _build99AccessBanner() {
    final benefits = [
      {'icon': Icons.work_outline_rounded, 'label': 'Unlimited\nApplications'},
      {'icon': Icons.search_rounded, 'label': 'Priority in\nSearch'},
      {
        'icon': Icons.people_outline_rounded,
        'label': 'Connect with\nProviders',
      },
      {'icon': Icons.auto_awesome_rounded, 'label': 'AI Profile\nBoost'},
      {'icon': Icons.security_outlined, 'label': 'InstantMilega™\nAccess'},
      {'icon': Icons.timer_outlined, 'label': 'Earn More\nRewards'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F083B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F083B).withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              children: [
                TextSpan(text: 'Unlock All Benefits with '),
                TextSpan(
                  text: '₹99 Access',
                  style: TextStyle(color: Color(0xFFFBBF24)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6 Feature Items Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: benefits.map((b) {
              final icon = b['icon'] as IconData;
              final label = b['label'] as String;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF281966),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // CTA Gradient Button
          GestureDetector(
            onTap: _show99AccessModal,
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF0066)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0066).withValues(alpha: 0.35),
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
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Picks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => _goToJobsTabWithQuery(''),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...topPicks.map((job) {
          final isSaved = savedJobIds.contains(job.id);
          final icon = _getJobCategoryIcon(job.title, job.jobType);
          final iconColor = _getJobCategoryColor(job.title);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (job.id.isNotEmpty) {
                  context.push('/jobs/${job.id}', extra: job);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Worker/Company Avatar
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 30),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            job.company,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${job.formattedSalary} /month',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            job.formattedLocation,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Bookmark Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved
                                ? AppColors.primary
                                : const Color(0xFF94A3B8),
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ref
                                .read(jobsProvider.notifier)
                                .toggleSaveJob(job.id);
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
                        // Hard-coded "4.7" rating removed: the backend has
                        // no company ratings, so it was the same for every job.
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
