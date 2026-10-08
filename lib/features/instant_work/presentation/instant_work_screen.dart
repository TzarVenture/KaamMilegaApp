import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../applications/presentation/apply_modal.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/banner_image.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';
import '../../jobs/models/job.dart';
import '../../jobs/presentation/job_detail_screen.dart';
import '../providers/instant_candidate_provider.dart';
import '../providers/instant_milega_provider.dart';
import '../providers/instant_work_provider.dart';
import '../models/nearby_professional.dart';
import '../providers/spot_gigs_provider.dart';
import 'widgets/instant_availability_card.dart';
import 'widgets/instant_location_bar.dart';
import 'widgets/spot_gigs_widgets.dart';
import 'widgets/nearby_professionals_section.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../app/theme/app_colors.dart';

class InstantWorkScreen extends ConsumerStatefulWidget {
  const InstantWorkScreen({super.key});

  @override
  ConsumerState<InstantWorkScreen> createState() => _InstantWorkScreenState();
}

class _InstantWorkScreenState extends ConsumerState<InstantWorkScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final _workStartKey = GlobalKey();

  /// Rotating search hint: gigs, then the InstantMilega trades (the same
  /// list as the category chips, so they always match).
  static final List<String> _searchExamples = [
    'Gigs',
    for (final c in InstantServiceCategory.values)
      if (c.id != InstantServiceCategory.allId) c.label,
  ];

  final List<String> _filters = [
    'All',
    'Today',
    'Hourly',
    'Urgent',
    'Nearby',
    'Delivery',
    'Helper',
  ];

  @override
  void initState() {
    super.initState();
    // Instant Milega is location-first: read the device location (and ask
    // for permission) when this screen opens, never at app start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(instantMilegaProvider.notifier).locate();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instantWorkProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: AppColors.moduleInstantWork,
        secondaryColor: AppColors.brandNavy,
        categoryLabel: 'Instant',
        categoryIcon: Icons.bolt_rounded,
      ),
      // The coloured header runs up under the status bar.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Header (Logo + Search/Notification/Drawer + Location + Search Bar)
            CategoryTopHeader(
              showSearchIcon: false, // search bar below is enough
              scaffoldKey: _scaffoldKey,
              themeColor: AppColors.moduleInstantWork,
              title: 'Instant work',
              subtitle: 'Quick gigs and helpers near you.',
              searchHint: 'Search nearby gigs, delivery, helper...',
              // "Search for 'Gigs'", then the InstantMilega trades.
              searchHintExamples: _searchExamples,
              searchController: _searchController,
              onSearchChanged: (val) {
                ref
                    .read(instantWorkProvider.notifier)
                    .setSearchQuery(val.trim());
              },
              onSearchSubmitted: () {
                ref
                    .read(instantWorkProvider.notifier)
                    .setSearchQuery(_searchController.text.trim());
              },
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppColors.moduleInstantWork,
                onRefresh: () => Future.wait([
                  ref.read(instantWorkProvider.notifier).loadGigs(),
                  ref.read(instantMilegaProvider.notifier).loadProfessionals(),
                  ref.read(instantCandidateProvider.notifier).load(),
                  ref.read(spotGigsProvider.notifier).refreshAll(),
                ]),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  children: [
                    // Hero banner image, right below the search bar
                    _buildHeroBanner(),

                    const SizedBox(height: 14),

                    // Location status (needed for gigs; no map)
                    const InstantLocationBar(),

                    const SizedBox(height: 14),

                    // Go online (InstantPass) card, as on the website
                    const InstantAvailabilityCard(),

                    const SizedBox(height: 18),

                    // Claimed spot gig (call, chat, directions, complete)
                    const ActiveGigCard(),

                    // Live open spot gigs for the primary trade
                    const SpotGigsSection(),

                    const SizedBox(height: 18),

                    // Gig pay credited to the wallet
                    const GigEarningsCard(),

                    const SizedBox(height: 18),

                    // 0. Nearby professionals (backend-pending until the
                    // nearby-professionals API exists)
                    const NearbyProfessionalsSection(),

                    const SizedBox(height: 18),

                    // 2. Quick Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final f = _filters[index];
                          final isSelected = state.activeFilter == f;
                          return InkWell(
                            onTap: () => ref
                                .read(instantWorkProvider.notifier)
                                .setFilter(f),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.moduleInstantWork
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.moduleInstantWork
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. Section Header
                    Row(
                      key: _workStartKey,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Available Work Near You',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${state.gigs.length} Gigs',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 5. Work Cards / Empty State
                    if (state.isLoading)
                      const ShimmerLoadingList(count: 3, itemHeight: 120)
                    else if (state.gigs.isEmpty)
                      _buildEmptyState()
                    else
                      ...state.gigs.map((job) => _buildWorkCard(context, job)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return FadeSlideIn(
      child: BannerImage(
        asset: 'assets/images/instant_work_hero.webp',
        pixelWidth: 1080,
        pixelHeight: 657,
        semanticLabel: 'Get work. Get paid. In minutes. Find work now',
        onTap: _scrollToWork,
      ),
    );
  }

  /// "Find Work Now" on the banner scrolls to the work near you.
  void _scrollToWork() {
    final target = _workStartKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildEmptyState() {
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 36,
                color: AppColors.moduleInstantWorkText,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No instant gigs currently in your area',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Recruiters post urgent hourly shifts frequently. Pull down to refresh or browse full-time openings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/jobs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleInstantWork,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Browse All Jobs',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkCard(BuildContext context, Job job) {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Text(
                    job.jobType.isNotEmpty ? job.jobType : 'Instant Work',
                    style: const TextStyle(
                      color: AppColors.moduleInstantWorkText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    job.formattedSalary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  job.company,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.formattedLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (job.requirements.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: job.requirements.take(3).map((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              JobDetailScreen(jobId: job.id, initialJob: job),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.moduleInstantWork,
                      side: const BorderSide(color: Color(0xFFFDBA74)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ApplyModalSheet.show(
                        context,
                        job: job,
                        onSuccess: () {
                          ref.read(instantWorkProvider.notifier).refresh();
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.moduleInstantWork,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Instant Apply',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
