import 'package:flutter/material.dart';

import '../../../app/auth_guard.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/banner_image.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../app/theme/app_colors.dart';

class ServicesMarketplaceScreen extends StatefulWidget {
  const ServicesMarketplaceScreen({super.key});

  @override
  State<ServicesMarketplaceScreen> createState() =>
      _ServicesMarketplaceScreenState();
}

class _ServicesMarketplaceScreenState extends State<ServicesMarketplaceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final _servicesStartKey = GlobalKey();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'AC Repair',
    'Electrician',
    'Plumber',
    'House Help',
    'Carpentry',
    'Appliance Repair',
    'Delivery',
  ];

  /// "Search for 'Services'", then the categories above.
  late final List<String> _searchExamples = [
    'Services',
    ..._categories.where((c) => c != 'All'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: AppColors.moduleServices,
        secondaryColor: AppColors.brandNavy,
        categoryLabel: 'Services',
        categoryIcon: Icons.home_repair_service_rounded,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CategoryTopHeader(
              showSearchIcon: false, // search bar below is enough
              scaffoldKey: _scaffoldKey,
              themeColor: AppColors.moduleServices,
              searchHint: 'Search services (e.g. AC service, electrician)...',
              searchHintExamples: _searchExamples,
              searchController: _searchController,
              onSearchChanged: (val) {
                setState(() {});
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                children: [
                  // 1. Hero banner image
                  _buildHeroBanner(),

                  SizedBox(key: _servicesStartKey, height: 14),

                  // 2. Category Horizontal Scroll
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.moduleServices
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.moduleServices
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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

                  const SizedBox(height: 20),

                  // 4. Backend API Required Notice Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.moduleServicesLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.moduleServices.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.handyman_rounded,
                                color: AppColors.moduleServicesText,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Services Marketplace is coming soon',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brandNavy,
                                    ),
                                  ),
                                  Text(
                                    'Launching city by city',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.moduleServicesText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Soon you will be able to book verified electricians, plumbers, technicians and other local professionals right here. Browse the categories below to see what is coming.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF881337),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Service Categories Grid
                  const Text(
                    'Explore Service Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _buildCategoryTile(
                        'AC Repair & Service',
                        'Installation, Gas refilling & cleaning',
                        Icons.ac_unit_rounded,
                        const Color(0xFF0284C7),
                      ),
                      _buildCategoryTile(
                        'Electrician Work',
                        'Wiring, switches, fuse & power setups',
                        Icons.electric_bolt_rounded,
                        AppColors.accent,
                      ),
                      _buildCategoryTile(
                        'Plumbing Services',
                        'Leakages, tap fitting, bathroom fixes',
                        Icons.plumbing_rounded,
                        const Color(0xFF0D9488),
                      ),
                      _buildCategoryTile(
                        'House Cleaning',
                        'Deep cleaning, kitchen & sofa wash',
                        Icons.cleaning_services_rounded,
                        const Color(0xFF7C3AED),
                      ),
                      _buildCategoryTile(
                        'Carpentry',
                        'Furniture repair, door fitting & locks',
                        Icons.carpenter_rounded,
                        const Color(0xFFB45309),
                      ),
                      _buildCategoryTile(
                        'Delivery & Logistics',
                        'Same-day parcel & intra-city shifts',
                        Icons.local_shipping_rounded,
                        const Color(0xFF16A34A),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 6. Action for Job Seekers / Providers
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offer Services in Your City',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Are you a technician, mechanic or service professional? Register your profile to receive local service bookings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => AuthGuard.openProtected(
                              context,
                              '/apply-expert',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.moduleServices,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Register as Service Provider',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
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
        asset: 'assets/images/services_hero.webp',
        pixelWidth: 1080,
        pixelHeight: 690,
        semanticLabel: 'Find trusted services, 100% reliable. Explore services',
        onTap: _scrollToServices,
      ),
    );
  }

  /// "Explore Services" on the banner scrolls to the categories below it.
  void _scrollToServices() {
    final target = _servicesStartKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCategoryTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
