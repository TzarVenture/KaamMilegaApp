import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_guard.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/banner_image.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';
import '../models/expert_profile.dart';
import '../providers/expert_provider.dart';
import '../repositories/expert_repository.dart';
import 'expert_detail_screen.dart';
import 'widgets/upcoming_session_banner.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../app/theme/app_colors.dart';

class ExpertsScreen extends ConsumerStatefulWidget {
  const ExpertsScreen({super.key});

  @override
  ConsumerState<ExpertsScreen> createState() => _ExpertsScreenState();
}

class _ExpertsScreenState extends ConsumerState<ExpertsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final _expertsStartKey = GlobalKey();

  final List<String> _categories = [
    'All',
    'Interview Prep',
    'Career Guidance',
    'Technical Skills',
    'Soft Skills',
    'Resume Review',
    'Entrepreneurship',
  ];

  /// "Search for 'Mentors'", then the categories above (search matches
  /// mentor name, session title, description and category).
  late final List<String> _searchExamples = [
    'Mentors',
    ..._categories.where((c) => c != 'All'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expertProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: AppColors.moduleExperts,
        secondaryColor: AppColors.brandNavy,
        categoryLabel: 'Experts',
        categoryIcon: Icons.person_search_rounded,
      ),
      // The coloured header runs up under the status bar.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            CategoryTopHeader(
              showSearchIcon: false, // search bar below is enough
              scaffoldKey: _scaffoldKey,
              themeColor: AppColors.moduleExperts,
              title: 'Experts',
              subtitle: 'Book 1-on-1 time with mentors.',
              searchHint: 'Search mentors by name, role or skill...',
              searchHintExamples: _searchExamples,
              searchController: _searchController,
              onSearchChanged: (val) {
                ref.read(expertProvider.notifier).setSearchQuery(val.trim());
              },
              onSearchSubmitted: () {
                ref
                    .read(expertProvider.notifier)
                    .setSearchQuery(_searchController.text.trim());
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.moduleExperts,
                onRefresh: () {
                  ref.invalidate(myBookingsProvider);
                  return ref.read(expertProvider.notifier).loadExperts();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  children: [
                    // 0. The user's next booked call (hidden when none)
                    const UpcomingSessionBanner(),

                    // 1. Hero banner image
                    _buildHeroBanner(),

                    SizedBox(key: _expertsStartKey, height: 14),

                    // 2. Category Filter Chips Horizontal Filter
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = state.selectedCategory == cat;
                          return InkWell(
                            onTap: () => ref
                                .read(expertProvider.notifier)
                                .setCategory(cat),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.moduleExperts
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.moduleExperts
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                cat,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Verified Mentors & Coaches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${state.experts.length} Mentors',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 5. Experts List
                    if (state.isLoading)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        itemBuilder: (context, index) => FadeSlideIn(
                          index: index,
                          child: Builder(
                            builder: (context) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const ShimmerCircle(size: 52),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          ShimmerBox(
                                            width: 140,
                                            height: 16,
                                            borderRadius: 4,
                                          ),
                                          SizedBox(height: 6),
                                          ShimmerBox(
                                            width: 100,
                                            height: 12,
                                            borderRadius: 4,
                                          ),
                                          SizedBox(height: 10),
                                          ShimmerBox(
                                            width: 80,
                                            height: 18,
                                            borderRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else if (state.error != null)
                      _buildErrorState(state.error!)
                    else if (state.experts.isEmpty)
                      _buildEmptyState()
                    else
                      ...state.experts.map(
                        (exp) => _buildExpertCard(context, exp),
                      ),

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
        asset: 'assets/images/experts_hero.webp',
        pixelWidth: 1080,
        pixelHeight: 740,
        semanticLabel:
            'Learn. Grow. Succeed with the right mentor. Find an expert',
        onTap: _scrollToExperts,
      ),
    );
  }

  /// "Find an Expert" on the banner scrolls to the filters and experts.
  void _scrollToExperts() {
    final target = _expertsStartKey.currentContext;
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
              decoration: const BoxDecoration(
                color: AppColors.moduleExpertsLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 36,
                color: AppColors.moduleExperts,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No mentors found in this category yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Are you an expert in your field? Apply to mentor peers on KaamMilega.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  AuthGuard.openProtected(context, '/apply-expert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleExperts,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Apply as Expert',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
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
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.moduleExpertsLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 32,
                color: AppColors.moduleExperts,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Mentorship Catalog Unavailable',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(expertProvider.notifier).loadExperts(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleExperts,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpertCard(BuildContext context, ExpertItem expert) {
    return Container(
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
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.moduleExpertsLight,
                foregroundImage: expert.expertImage.isNotEmpty
                    ? NetworkImage(expert.expertImage)
                    : null,
                onForegroundImageError: expert.expertImage.isNotEmpty
                    ? (_, _) {}
                    : null,
                child: Text(
                  expert.expertName.isNotEmpty
                      ? expert.expertName[0].toUpperCase()
                      : 'E',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.moduleExperts,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expert.expertName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          expert.ratingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (expert.expertHeadline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expert.expertHeadline,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.moduleExpertsLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expert.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.moduleExperts,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expert.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          if (expert.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              expert.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fee / Session',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    expert.price > 0
                        ? '₹${expert.price.toInt()}'
                        : 'Free Session',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpertDetailScreen(expert: expert),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.moduleExperts,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Book Session',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
