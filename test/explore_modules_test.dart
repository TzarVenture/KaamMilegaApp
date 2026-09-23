import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaam_milega/features/skills_marketplace/models/skill_item.dart';
import 'package:kaam_milega/features/experts/models/expert_profile.dart';
import 'package:kaam_milega/features/explore/presentation/explore_screen.dart';
import 'package:kaam_milega/features/services/presentation/services_marketplace_screen.dart';
import 'package:kaam_milega/shared/widgets/category_top_header.dart';
import 'package:kaam_milega/shared/widgets/themed_category_bottom_nav.dart';

void main() {
  group('ExpertItem Model Tests', () {
    test('ExpertItem parses from backend MentorshipDetail format properly', () {
      final json = {
        'mentorship': {
          'id': '6ab0ffff6e6f5b6fca57e8e8',
          'expert_id': '6a71c96b609929c567d3aa14',
          'title': '1-on-1 Mock Interview & Salary Negotiation Strategy',
          'description': 'Real-world interview practice and feedback.',
          'category': 'Interview Prep',
          'duration': 45,
          'price': 499,
          'rating': 4.9,
          'reviews': 28,
          'status': 'active',
        },
        'expert': {
          'id': '6a71c96b609929c567d3aa14',
          'name': 'Reeta Patel .',
          'headline': 'VP Engineering & Career Mentor',
          'profile_image': 'https://example.com/avatar.png',
          'bio': 'Experienced career coach',
          'rating': 5,
        },
      };

      final expert = ExpertItem.fromJson(json);
      expect(expert.id, '6ab0ffff6e6f5b6fca57e8e8');
      expect(expert.expertId, '6a71c96b609929c567d3aa14');
      expect(
        expert.title,
        '1-on-1 Mock Interview & Salary Negotiation Strategy',
      );
      expect(expert.expertName, 'Reeta Patel .');
      expect(expert.expertHeadline, 'VP Engineering & Career Mentor');
      expect(expert.category, 'Interview Prep');
      expect(expert.price, 499.0);
      expect(expert.duration, 45);
      expect(expert.rating, 4.9);
      expect(expert.reviews, 28);
    });

    test('ExpertItem parses from flat JSON format properly', () {
      final json = {
        'id': 'exp-501',
        'title': 'Senior Career & Interview Guidance',
        'expert_name': 'Priya Sharma',
        'expert_headline': 'VP Engineering',
        'category': 'Career Guidance',
        'price': 499.0,
        'duration': 45,
        'rating': 4.9,
        'reviews': 32,
      };

      final expert = ExpertItem.fromJson(json);
      expect(expert.id, 'exp-501');
      expect(expert.title, 'Senior Career & Interview Guidance');
      expect(expert.expertName, 'Priya Sharma');
      expect(expert.expertHeadline, 'VP Engineering');
      expect(expert.price, 499.0);
      expect(expert.duration, 45);
      expect(expert.rating, 4.9);
      expect(expert.reviews, 32);
    });
  });

  group('Skills Marketplace Model Tests', () {
    test('SkillItem parses from JSON properly', () {
      final json = {
        'id': 'skill-101',
        'name': 'Electrician & Wireman',
        'category': 'Technical & Trades',
      };

      final item = SkillItem.fromJson(json);
      expect(item.id, 'skill-101');
      expect(item.name, 'Electrician & Wireman');
      expect(item.category, 'Technical & Trades');
    });

    test('SkillItem defaults to sensible values on partial json', () {
      final json = {'name': 'Plumbing'};

      final item = SkillItem.fromJson(json);
      expect(item.name, 'Plumbing');
      expect(item.category, 'General');
    });
  });

  group('ExploreScreen Widget Tests', () {
    testWidgets('ExploreScreen renders top header, bottom nav and 7 modules', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ExploreScreen())),
      );
      await tester.pumpAndSettle();

      // Verify CategoryTopHeader and ThemedCategoryBottomNav
      expect(find.byType(CategoryTopHeader), findsOneWidget);
      expect(find.byType(ThemedCategoryBottomNav), findsOneWidget);
      expect(find.text('7 Major Product Ecosystems'), findsOneWidget);

      // Verify 7 product area modules
      expect(find.text('Jobs & Recruitment'), findsOneWidget);
      expect(find.text('Instant / Hourly Work'), findsOneWidget);
      expect(find.text('Skills Marketplace'), findsOneWidget);
      expect(find.text('Experts & Mentors'), findsOneWidget);
      expect(find.text('Services Marketplace'), findsOneWidget);
      expect(find.text('Peer to Peer Network'), findsOneWidget);
      expect(find.text('Events & Community'), findsOneWidget);
    });
  });

  group('ServicesMarketplaceScreen Widget Tests', () {
    testWidgets(
      'ServicesMarketplaceScreen renders CategoryTopHeader and ThemedCategoryBottomNav',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: ServicesMarketplaceScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CategoryTopHeader), findsOneWidget);
        expect(find.byType(ThemedCategoryBottomNav), findsOneWidget);
        expect(find.text('ON-DEMAND LOCAL EXPERTISE'), findsOneWidget);
        // "Not live yet" notice (user-friendly wording since 23 Sep)
        expect(
          find.text('Services Marketplace is coming soon'),
          findsOneWidget,
        );
        expect(find.text('Electrician Work'), findsOneWidget);
        expect(find.text('Plumbing Services'), findsOneWidget);
      },
    );
  });

  group('ThemedCategoryBottomNav Component Tests', () {
    testWidgets(
      'ThemedCategoryBottomNav renders correct label, icon, and dynamic theme colors',
      (WidgetTester tester) async {
        const themeColor = Color(0xFFEA580C);
        const secondaryColor = Color(0xFFC2410C);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: ThemedCategoryBottomNav(
                  activeColor: themeColor,
                  secondaryColor: secondaryColor,
                  categoryLabel: 'Instant Work',
                  categoryIcon: Icons.bolt_rounded,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 5 navigation destinations
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Instant Work'), findsOneWidget);
        expect(find.text('Chats'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        // Active category icon and center add (+) icon
        expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      },
    );
  });

  group('CategoryTopHeader Component Tests', () {
    testWidgets(
      'CategoryTopHeader displays branding, search hint, notifications, and hamburger drawer icon',
      (WidgetTester tester) async {
        final scaffoldKey = GlobalKey<ScaffoldState>();
        final searchController = TextEditingController();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                key: scaffoldKey,
                body: CategoryTopHeader(
                  scaffoldKey: scaffoldKey,
                  themeColor: const Color(0xFF10B981),
                  searchHint: 'Search skills & talent...',
                  searchController: searchController,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Search skills & talent...'), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsNWidgets(2));
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
        expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      },
    );
  });
}
