import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_guard.dart';
import '../../../app/theme/app_colors.dart';
import '../../profile/presentation/widgets/profile_drawer.dart';
import '../../../shared/widgets/category_top_header.dart';
import '../../../shared/widgets/themed_category_bottom_nav.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final List<Map<String, dynamic>> _modules = [
    {
      'id': 'jobs',
      'title': 'Jobs & Recruitment',
      'tagline': 'Find the right job. Build your career.',
      'description': 'Full-time & part-time jobs, top recruiters, verified hiring & application tracking.',
      'icon': Icons.work_outline_rounded,
      'color': const Color(0xFF1A2B8C),
      'bgGradient': [const Color(0xFF1A2B8C), const Color(0xFF2E45B8)],
      'badge': 'Primary Hub',
      'route': '/jobs',
    },
    {
      'id': 'instant_work',
      'title': 'Instant / Hourly Work',
      'tagline': 'Get work, get paid, in minutes.',
      'description': 'Discover fast hourly gigs, delivery, urgent daily shifts & flexible task contracts.',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFFF97316),
      'bgGradient': [const Color(0xFFEA580C), const Color(0xFFF97316)],
      'badge': 'InstantMilega™',
      'route': '/instant-work',
    },
    {
      'id': 'skills',
      'title': 'Skills Marketplace',
      'tagline': 'Show your skills. Get hired.',
      'description': 'Browse verified skills, technical certifications, training categories & talent pools.',
      'icon': Icons.school_outlined,
      'color': const Color(0xFF10B981),
      'bgGradient': [const Color(0xFF059669), const Color(0xFF10B981)],
      'badge': 'Marketplace',
      'route': '/skills-marketplace',
    },
    {
      'id': 'experts',
      'title': 'Experts & Mentors',
      'tagline': 'Learn, grow & succeed with experts.',
      'description': 'Book 1-on-1 career mentorship, resume reviews, technical coaching & mock interviews.',
      'icon': Icons.person_search_outlined,
      'color': const Color(0xFF4F46E5),
      'bgGradient': [const Color(0xFF4338CA), const Color(0xFF6366F1)],
      'badge': 'Verified Mentors',
      'route': '/experts',
    },
    {
      'id': 'services',
      'title': 'Services Marketplace',
      'tagline': 'Find trusted services on-demand.',
      'description': 'Local certified technicians, electricians, home repair, AC maintenance & specialists.',
      'icon': Icons.home_repair_service_outlined,
      'color': const Color(0xFFE11D48),
      'bgGradient': [const Color(0xFFBE123C), const Color(0xFFE11D48)],
      'badge': 'Services',
      'route': '/services',
    },
    {
      'id': 'peer_to_peer',
      'title': 'Peer to Peer Network',
      'tagline': 'Connect, share & grow together.',
      'description': 'Discover workers, alumni, colleagues, send connection invites & chat directly.',
      'icon': Icons.people_outline_rounded,
      'color': const Color(0xFF9333EA),
      'bgGradient': [const Color(0xFF7E22CE), const Color(0xFFA855F7)],
      'badge': 'Networking',
      'route': '/peer-to-peer',
    },
    {
      'id': 'events',
      'title': 'Events & Community',
      'tagline': 'Join events. Build your network.',
      'description': 'Attend job fairs, tech webinars, skill workshops & community career summits.',
      'icon': Icons.event_available_outlined,
      'color': const Color(0xFFD97706),
      'bgGradient': [const Color(0xFFB45309), const Color(0xFFD97706)],
      'badge': 'Community',
      'route': '/events',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _modules.where((m) {
      final title = (m['title'] as String).toLowerCase();
      final desc = (m['description'] as String).toLowerCase();
      final tag = (m['tagline'] as String).toLowerCase();
      final q = _query.toLowerCase();
      return title.contains(q) || desc.contains(q) || tag.contains(q);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: const ThemedCategoryBottomNav(
        activeColor: Color(0xFF1A2B8C),
        secondaryColor: Color(0xFF0C1738),
        categoryLabel: 'Explore',
        categoryIcon: Icons.explore_rounded,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CategoryTopHeader(
              scaffoldKey: _scaffoldKey,
              themeColor: const Color(0xFF1A2B8C),
              searchHint: 'Search all 7 KaamMilega modules...',
              searchController: _searchController,
              onSearchChanged: (val) => setState(() => _query = val.trim()),
              onSearchSubmitted: () =>
                  setState(() => _query = _searchController.text.trim()),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                children: [
                  // Subtitle banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '7 Major Product Ecosystems',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Discover jobs, instant gigs, experts, skills, local services, network & events.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Module Cards
                  ...filtered.map((item) => _buildModuleCard(context, item)),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No matching product area found',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
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

  Widget _buildModuleCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] as String;
    final tagline = item['tagline'] as String;
    final description = item['description'] as String;
    final icon = item['icon'] as IconData;
    final color = item['color'] as Color;
    final bgGradient = item['bgGradient'] as List<Color>;
    final badge = item['badge'] as String;
    final route = item['route'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Account-only modules show the Login Required popup to guests
          // instead of opening (and calling login-only APIs).
          onTap: () {
            if (AuthGuard.isProtected(route)) {
              AuthGuard.openProtected(context, route);
            } else {
              context.push(route);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Gradient Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: bgGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tagline,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
