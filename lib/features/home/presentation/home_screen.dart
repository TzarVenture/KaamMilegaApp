import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../applications/presentation/apply_modal.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../../jobs/presentation/widgets/job_card.dart';
import '../../jobs/providers/jobs_provider.dart';

/// Modern native mobile application Home Screen with cross-platform
/// responsiveness for iOS, Android, Tablet, and Desktop displays.
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  void _selectCityAndGo(String city) {
    ref.read(jobsProvider.notifier).setCity(city);
    _goToJobsTab();
  }

  void _selectRoleAndGo(String role) {
    ref.read(jobsProvider.notifier).setSearchQuery(role);
    _goToJobsTab();
  }

  void _selectJobTypeAndGo(String jobType) {
    ref.read(jobsProvider.notifier).toggleJobType(jobType);
    _goToJobsTab();
  }

  void _selectQualificationAndGo(String qual) {
    ref.read(jobsProvider.notifier).toggleQualification(qual);
    _goToJobsTab();
  }

  void _goToJobsTab() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      context.go('/jobs');
    }
  }

  void _handleCallHR() async {
    final uri = Uri(scheme: 'tel', path: '1800123456');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('HR Support Helpline: 1800 123 456'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _handleChat() {
    context.push('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);
    final currentCity = jobsState.filter.city;
    final recommendedJobs = jobsState.jobs.take(3).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            // App Logo (clickable to scroll top)
            GestureDetector(
              onTap: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Image.asset(
                'assets/images/logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            // City Selector Pill
            GestureDetector(
              onTap: () => _openCitySelector(currentCity),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        currentCity,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Messages & Chats',
            onPressed: _handleChat,
          ),
          IconButton(
            icon: const Icon(
              Icons.headset_mic_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Call HR Helpline',
            onPressed: _handleCallHR,
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. STICKY MOBILE SEARCH BAR WIDGET
                _buildMobileSearchBar(),

                // 2. HORIZONTAL QUICK CATEGORY CHIPS
                _buildQuickCategoryChips(),

                const SizedBox(height: 16),

                // 3. PROMO HERO BANNER (Native App Card)
                _buildNativeHeroCard(),

                // 4. LIVE INTERVIEW TICKER
                _buildLiveInterviewTicker(),

                const SizedBox(height: 24),

                // 5. RECOMMENDED JOBS FEED (Native Mobile Feed)
                _buildRecommendedJobsFeed(recommendedJobs, jobsState.isLoading),

                const SizedBox(height: 24),

                // 6. POPULAR JOB ROLES GRID (Responsive)
                _buildPopularJobRoles(isDesktop, isTablet),

                const SizedBox(height: 24),

                // 7. WHERE DO YOU WANT TO WORK? (CITIES CAROUSEL)
                _buildLocationSection(),

                const SizedBox(height: 24),

                // 8. SEARCH BY QUALIFICATION (Responsive)
                _buildQualificationSection(isDesktop, isTablet),

                const SizedBox(height: 24),

                // 9. WHAT TYPE OF JOB DO YOU WANT?
                _buildJobTypeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. MOBILE SEARCH BAR WIDGET
  // ==========================================
  Widget _buildMobileSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: GestureDetector(
        onTap: _goToJobsTab,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search jobs by title, company, or skill...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.tune_rounded, color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. HORIZONTAL QUICK CATEGORY CHIPS
  // ==========================================
  Widget _buildQuickCategoryChips() {
    final categories = [
      {'label': '🔥 All Jobs', 'role': ''},
      {'label': '🚚 Delivery', 'role': 'Delivery'},
      {'label': '🚗 Driver', 'role': 'Driver'},
      {'label': '🏢 Work From Home', 'jobType': 'Work From Home'},
      {'label': '⏰ Part Time', 'jobType': 'Part Time'},
      {'label': '🎓 Freshers', 'jobType': 'Fresher Jobs'},
      {'label': '📦 Warehouse', 'role': 'Warehouse / Logistics'},
      {'label': '🛠️ Technician', 'role': 'Technician'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final label = cat['label']!;
            final isFirst = index == 0;

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (cat.containsKey('role') && cat['role']!.isNotEmpty) {
                  _selectRoleAndGo(cat['role']!);
                } else if (cat.containsKey('jobType')) {
                  _selectJobTypeAndGo(cat['jobType']!);
                } else {
                  _goToJobsTab();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isFirst ? AppColors.primary : AppColors.cardLightBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFirst ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isFirst ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 3. PROMO HERO CARD (Native App Banner)
  // ==========================================
  Widget _buildNativeHeroCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroBg.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.heroAccent,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '100% FREE & VERIFIED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Find Local Jobs With Better Salary!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect directly with hiring managers without any fees',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _handleCallHR,
                icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                label: const Text(
                  'Chat With HR',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroButton,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _goToJobsTab,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Explore Jobs',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. LIVE INTERVIEW TICKER
  // ==========================================
  Widget _buildLiveInterviewTicker() {
    final candidateNames = [
      'Dharmender',
      'Priya Sharma',
      'Rahul Verma',
      'Amit Patel',
      'Sunita Roy',
      'Vikram Singh',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.tickerBg,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.tickerBorder),
        ),
      ),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: candidateNames.length,
          separatorBuilder: (_, _) => const SizedBox(width: 20),
          itemBuilder: (context, index) {
            final name = candidateNames[index];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.heroBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'HAS FIXED AN INTERVIEW',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 5. RECOMMENDED JOBS FEED (Native Mobile Cards)
  // ==========================================
  Widget _buildRecommendedJobsFeed(List recommendedJobs, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Recommended Jobs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _goToJobsTab,
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (isLoading && recommendedJobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (recommendedJobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.work_outline_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Explore Active Jobs Near You',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Browse thousands of verified job openings',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _goToJobsTab,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Browse',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: recommendedJobs.map((job) {
              return JobCard(
                job: job,
                isTopMatch: job.id == recommendedJobs.first.id,
                onTap: () => context.push('/jobs/${job.id}'),
                onApply: () =>
                    ApplyModalSheet.show(context, job: job, onSuccess: () {}),
                onChat: _handleChat,
                onCall: _handleCallHR,
              );
            }).toList(),
          ),
      ],
    );
  }

  // ==========================================
  // 6. POPULAR JOB ROLES (Responsive Grid)
  // ==========================================
  Widget _buildPopularJobRoles(bool isDesktop, bool isTablet) {
    final roles = [
      {
        'role': 'Delivery',
        'vacancies': '5,50,000+ Vacancies',
        'icon': Icons.electric_moped_rounded,
      },
      {
        'role': 'Driver',
        'vacancies': '2,10,000+ Vacancies',
        'icon': Icons.directions_car_filled_rounded,
      },
      {
        'role': 'Warehouse / Logistics',
        'vacancies': '1,80,000+ Vacancies',
        'icon': Icons.warehouse_rounded,
      },
      {
        'role': 'Manufacturer',
        'vacancies': '90,000+ Vacancies',
        'icon': Icons.factory_rounded,
      },
      {
        'role': 'Housekeeping / Peon',
        'vacancies': '1,20,000+ Vacancies',
        'icon': Icons.cleaning_services_rounded,
      },
      {
        'role': 'Security Guard',
        'vacancies': '95,000+ Vacancies',
        'icon': Icons.shield_rounded,
      },
    ];

    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Job Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top hiring categories with high response rates',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isDesktop ? 2.3 : 1.95,
            ),
            itemBuilder: (context, index) {
              final item = roles[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectRoleAndGo(item['role'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['role'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['vacancies'] as String,
                              style: const TextStyle(
                                fontSize: 9,
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. WHERE DO YOU WANT TO WORK? (CITIES)
  // ==========================================
  Widget _buildLocationSection() {
    final topCities = [
      {'name': 'Mumbai', 'count': '55,000+'},
      {'name': 'Bangalore', 'count': '42,000+'},
      {'name': 'Delhi', 'count': '68,000+'},
      {'name': 'Pune', 'count': '31,000+'},
      {'name': 'Hyderabad', 'count': '28,000+'},
      {'name': 'Chennai', 'count': '22,000+'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Explore Jobs By City',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topCities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final city = topCities[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _selectCityAndGo(city['name']!),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLight),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        city['name']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${city['count']} Jobs',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: const [
                          Text(
                            'VIEW JOBS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 10,
                            color: AppColors.textLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 8. SEARCH BY QUALIFICATION (Responsive)
  // ==========================================
  Widget _buildQualificationSection(bool isDesktop, bool isTablet) {
    final qualifications = [
      {'label': 'Below 10th', 'icon': '✏️', 'count': '9,30,000+'},
      {'label': '10th Pass', 'icon': '📖', 'count': '4,00,000+'},
      {'label': '12th Pass', 'icon': '📚', 'count': '9,00,000+'},
      {'label': 'Diploma', 'icon': '📜', 'count': '50,000+'},
      {'label': 'Graduate', 'icon': '🎓', 'count': '7,30,000+'},
      {'label': 'Post Graduate', 'icon': '🎓', 'count': '25,000+'},
    ];

    final crossAxisCount = isDesktop ? 6 : (isTablet ? 4 : 3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jobs By Qualification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: qualifications.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final q = qualifications[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectQualificationAndGo(q['label']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        q['label']!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        q['count']!,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. WHAT TYPE OF JOB DO YOU WANT?
  // ==========================================
  Widget _buildJobTypeSection() {
    final types = [
      {
        'title': 'Work From Home',
        'icon': Icons.home_work_rounded,
        'color': AppColors.success,
      },
      {
        'title': 'Part Time',
        'icon': Icons.schedule_rounded,
        'color': AppColors.warning,
      },
      {
        'title': 'Full Time',
        'icon': Icons.business_center_rounded,
        'color': AppColors.verifiedBlue,
      },
      {
        'title': 'Fresher Jobs',
        'icon': Icons.school_rounded,
        'color': Colors.teal,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Type Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8, height: 8),
            itemBuilder: (context, index) {
              final t = types[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectJobTypeAndGo(t['title'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (t['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          t['icon'] as IconData,
                          color: t['color'] as Color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Explore Active Openings',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
