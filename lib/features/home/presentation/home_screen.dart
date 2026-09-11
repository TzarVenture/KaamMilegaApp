import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KaamMilega'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find Local Jobs',
              style: AppTextStyles.heading1,
            ),

            const SizedBox(height: 4),

            const Text(
              'Find your next opportunity near you.',
              style: AppTextStyles.bodySecondary,
            ),

            const SizedBox(height: 24),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.tune_rounded,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Popular Categories',
              style: AppTextStyles.heading2,
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CategoryCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Delivery',
                  ),
                  _CategoryCard(
                    icon: Icons.directions_car_outlined,
                    title: 'Driver',
                  ),
                  _CategoryCard(
                    icon: Icons.security_outlined,
                    title: 'Security',
                  ),
                  _CategoryCard(
                    icon: Icons.storefront_outlined,
                    title: 'Sales',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Recommended Jobs',
              style: AppTextStyles.heading2,
            ),

            const SizedBox(height: 16),

            const _JobCard(
              title: 'Delivery Executive',
              company: 'ABC Logistics',
              location: 'Andheri, Mumbai',
              salary: '₹20,000 - ₹25,000',
            ),

            const SizedBox(height: 12),

            const _JobCard(
              title: 'Security Guard',
              company: 'XYZ Services',
              location: 'Bandra, Mumbai',
              salary: '₹18,000 - ₹22,000',
            ),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {},
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CategoryCard({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 28,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final String title;
  final String company;
  final String location;
  final String salary;

  const _JobCard({
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.bookmark_border,
                color: AppColors.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Text(
                  location,
                  style: AppTextStyles.bodySecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.currency_rupee,
                size: 18,
                color: AppColors.success,
              ),

              const SizedBox(width: 4),

              Text(
                salary,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('View Job'),
            ),
          ),
        ],
      ),
    );
  }
}
