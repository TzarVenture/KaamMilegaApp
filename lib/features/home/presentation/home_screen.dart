import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../cities/presentation/city_selector_sheet.dart';
import '../../jobs/providers/jobs_provider.dart';

/// Full-featured Home Screen mirroring the official https://kaammilega.com landing page
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1); // Switch to Jobs tab
    } else {
      context.go('/jobs');
    }
  }

  void _selectRoleAndGo(String role) {
    ref.read(jobsProvider.notifier).setSearchQuery(role);
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      context.go('/jobs');
    }
  }

  void _selectJobTypeAndGo(String jobType) {
    ref.read(jobsProvider.notifier).toggleJobType(jobType);
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      context.go('/jobs');
    }
  }

  void _selectQualificationAndGo(String qual) {
    ref.read(jobsProvider.notifier).toggleQualification(qual);
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

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);
    final currentCity = jobsState.filter.city;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            // Preserved App Logo (clickable to go to top)
            GestureDetector(
              onTap: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            // City Selector Pill
            GestureDetector(
              onTap: () => _openCitySelector(currentCity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
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
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppColors.primary),
            tooltip: 'Call HR Helpline',
            onPressed: _handleCallHR,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HERO SECTION (#3B1641 Deep Plum Banner)
            _buildHeroSection(),

            // 2. LIVE INTERVIEW TICKER
            _buildLiveInterviewTicker(),

            const SizedBox(height: 28),

            // 3. WHERE DO YOU WANT TO WORK? (CITIES CAROUSEL)
            _buildLocationSection(),

            const SizedBox(height: 24),

            // 4. TRUST CARD & VALUE PROPS
            _buildTrustCard(),
            _buildValuePropsBar(),

            const SizedBox(height: 36),

            // 5. POPULAR JOB ROLES
            _buildPopularJobRoles(),

            const SizedBox(height: 36),

            // 6. SEARCH BY QUALIFICATION
            _buildQualificationSection(),

            const SizedBox(height: 36),

            // 7. WHAT TYPE OF JOB DO YOU WANT?
            _buildJobTypeSection(),

            const SizedBox(height: 36),

            // 8. DIVERSITY & INCLUSION BANNER
            _buildDiversityBanner(),

            const SizedBox(height: 36),

            // 9. POPULAR QUESTIONS (FAQ)
            _buildFaqSection(),

            const SizedBox(height: 40),

            // 10. WEBSITE FOOTER
            _buildAppFooter(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. HERO SECTION
  // ==========================================
  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.heroBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroBg.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background ambient circle decorations
          Positioned(
            top: -16,
            left: -16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
            ),
          ),

          // Foreground Content
          Column(
            children: [
              // Headline
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                    fontFamily: 'sans-serif',
                  ),
                  children: [
                    TextSpan(text: 'Find '),
                    TextSpan(
                      text: 'Local Jobs',
                      style: TextStyle(color: AppColors.heroAccent),
                    ),
                    TextSpan(text: '\nWith Better Salary!'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                'Call HR Directly To Fix Interview For FREE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 24),
              // Dual CTA Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _handleCallHR,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                    label: const Text(
                      'Chat With HR',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.heroButton,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1); // Go to Jobs tab
                      } else {
                        context.go('/jobs');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Get A Job Now',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. LIVE INTERVIEW TICKER
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.tickerBg,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.tickerBorder),
        ),
      ),
      child: SizedBox(
        height: 48,
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
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.heroBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'HAS FIXED AN INTERVIEW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
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
  // 3. WHERE DO YOU WANT TO WORK? (CITIES)
  // ==========================================
  Widget _buildLocationSection() {
    final topCities = [
      {'name': 'Mumbai', 'count': '55,000+'},
      {'name': 'Bangalore', 'count': '42,000+'},
      {'name': 'Delhi', 'count': '68,000+'},
      {'name': 'Pune', 'count': '31,000+'},
      {'name': 'Hyderabad', 'count': '28,000+'},
      {'name': 'Chennai', 'count': '22,000+'},
      {'name': 'Kolkata', 'count': '18,000+'},
      {'name': 'Ahmedabad', 'count': '16,000+'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'Where Do You Want To '),
                TextSpan(
                  text: 'Work?',
                  style: TextStyle(color: AppColors.heroButton),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: topCities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final city = topCities[index];
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _selectCityAndGo(city['name']!),
                child: Container(
                  width: 145,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textLight),
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
  // 4. TRUST CARD & VALUE PROPS
  // ==========================================
  Widget _buildTrustCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.tickerBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              children: [
                TextSpan(text: 'More Than '),
                TextSpan(
                  text: '10 Lakh Indians',
                  style: TextStyle(color: AppColors.heroButton),
                ),
                TextSpan(text: ' Trust Kaam Milega 🤝'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Register Now',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton(
                onPressed: _handleCallHR,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.heroButton,
                  side: const BorderSide(color: AppColors.heroButton, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Chat With HR',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValuePropsBar() {
    final benefits = [
      {'title': '100% FREE & Verified Jobs', 'icon': Icons.verified_rounded, 'color': AppColors.verifiedBlue},
      {'title': 'Best Jobs In Your Locality', 'icon': Icons.location_on_rounded, 'color': Colors.redAccent},
      {'title': 'Direct Calls With HR', 'icon': Icons.phone_in_talk_rounded, 'color': Colors.orange},
      {'title': 'Chat With HR', 'icon': Icons.chat_rounded, 'color': Colors.pinkAccent},
      {'title': 'Chat With Like You', 'icon': Icons.groups_rounded, 'color': AppColors.primary},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardLightBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: benefits.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final item = benefits[index];
            return Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 5. POPULAR JOB ROLES
  // ==========================================
  Widget _buildPopularJobRoles() {
    final roles = [
      {'role': 'Delivery', 'vacancies': '5,50,000+ Vacancies', 'icon': Icons.electric_moped_rounded},
      {'role': 'Driver', 'vacancies': '2,10,000+ Vacancies', 'icon': Icons.directions_car_filled_rounded},
      {'role': 'Warehouse / Logistics', 'vacancies': '1,80,000+ Vacancies', 'icon': Icons.warehouse_rounded},
      {'role': 'Manufacturer', 'vacancies': '90,000+ Vacancies', 'icon': Icons.factory_rounded},
      {'role': 'Housekeeping / Peon', 'vacancies': '1,20,000+ Vacancies', 'icon': Icons.cleaning_services_rounded},
      {'role': 'Security Guard', 'vacancies': '95,000+ Vacancies', 'icon': Icons.shield_rounded},
      {'role': 'Painter', 'vacancies': '45,000+ Vacancies', 'icon': Icons.format_paint_rounded},
      {'role': 'Labour / Helper', 'vacancies': '3,00,000+ Vacancies', 'icon': Icons.construction_rounded},
      {'role': 'Technician', 'vacancies': '85,000+ Vacancies', 'icon': Icons.build_rounded},
      {'role': 'Refrigerator & AC', 'vacancies': '60,000+ Vacancies', 'icon': Icons.ac_unit_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Job Roles',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Explore high-demand openings near you',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.95,
            ),
            itemBuilder: (context, index) {
              final item = roles[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectRoleAndGo(item['role'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
  // 6. SEARCH BY QUALIFICATION
  // ==========================================
  Widget _buildQualificationSection() {
    final qualifications = [
      {'label': 'Below 10th', 'icon': '✏️', 'count': '9,30,000+'},
      {'label': '10th Pass', 'icon': '📖', 'count': '4,00,000+'},
      {'label': '12th Pass', 'icon': '📚', 'count': '9,00,000+'},
      {'label': 'Diploma', 'icon': '📜', 'count': '50,000+'},
      {'label': 'Graduate', 'icon': '🎓', 'count': '7,30,000+'},
      {'label': 'Post Graduate', 'icon': '🎓', 'count': '25,000+'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'Search Job Based On '),
                TextSpan(
                  text: 'Qualification',
                  style: TextStyle(color: AppColors.heroButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: qualifications.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final q = qualifications[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _selectQualificationAndGo(q['label']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q['icon']!, style: const TextStyle(fontSize: 22)),
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
  // 7. WHAT TYPE OF JOB DO YOU WANT?
  // ==========================================
  Widget _buildJobTypeSection() {
    final types = [
      {'title': 'Work From Home', 'icon': Icons.home_work_rounded, 'color': AppColors.success},
      {'title': 'Part Time', 'icon': Icons.schedule_rounded, 'color': AppColors.warning},
      {'title': 'Full Time', 'icon': Icons.business_center_rounded, 'color': AppColors.verifiedBlue},
      {'title': 'Fresher Jobs', 'icon': Icons.school_rounded, 'color': Colors.teal},
      {'title': 'Jobs For Women', 'icon': Icons.woman_rounded, 'color': Colors.pink},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'What '),
                TextSpan(
                  text: 'Type Of Job',
                  style: TextStyle(color: AppColors.heroButton),
                ),
                TextSpan(text: ' Do You Want?'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = types[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectJobTypeAndGo(t['title'] as String),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (t['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          t['icon'] as IconData,
                          color: t['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'View 9,30,000+ Vacancies',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
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
  // 8. DIVERSITY & INCLUSION BANNER
  // ==========================================
  Widget _buildDiversityBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3B1641),
            Color(0xFF4A1D52),
            Color(0xFF250D29),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  '4.2 / 5.0 Workplace Rating',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Our Diversity And Inclusion At Workplace',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Equal opportunities for women, freshers, and experienced professionals across India.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(1);
              } else {
                context.go('/jobs');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.heroBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Explore Verified Employers',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. POPULAR QUESTIONS (FAQ)
  // ==========================================
  Widget _buildFaqSection() {
    final faqs = [
      {
        'q': 'Is applying for jobs on Kaam Milega free?',
        'a': 'Yes, 100% FREE! We never charge candidates any registration or application fees.'
      },
      {
        'q': 'How do I contact the HR directly?',
        'a': 'Simply tap on "Call HR" or "Chat With HR" inside any job card to instantly connect with the recruiter.'
      },
      {
        'q': 'How quickly will I get an interview scheduled?',
        'a': 'Most verified candidates get interviews confirmed within 24 to 48 hours directly on phone or WhatsApp.'
      },
      {
        'q': 'Are all the jobs verified?',
        'a': 'Yes, every employer profile and active job opening undergoes direct verification by our team.'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'Popular '),
                TextSpan(
                  text: 'Questions',
                  style: TextStyle(color: AppColors.heroButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...faqs.map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  title: Text(
                    faq['q']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        faq['a']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ==========================================
  // 10. APP FOOTER
  // ==========================================
  Widget _buildAppFooter() {
    return Container(
      color: const Color(0xFF1E112A),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Image (clickable to go to top)
          GestureDetector(
            onTap: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            },
            child: Image.asset(
              'assets/images/logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Find your next job opportunity near you with zero fees. Connect directly with hiring managers.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: const [
              Text(
                'HR Helpline: 1800 123 456',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heroAccent,
                ),
              ),
              Text(
                '100% Free & Verified',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '© 2026 Kaam Milega. All rights reserved.',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
