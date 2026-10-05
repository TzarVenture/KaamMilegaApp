import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'home_section_header.dart';

/// A photo tile that opens the Jobs tab searching for [query].
class JobCategory {
  const JobCategory({
    required this.title,
    required this.image,
    required this.query,
  });

  final String title;

  /// Photo from the KaamMilega website (resized for the app).
  final String image;

  /// Search text sent to GET /jobs (matched against title, description and
  /// company by the backend).
  final String query;
}

const _dir = 'assets/images/categories';

/// Same trades as the website's "Explore Popular Job Categories".
const popularJobCategories = <JobCategory>[
  JobCategory(
    title: 'Bike Courier',
    image: '$_dir/delivery.jpg',
    query: 'Delivery',
  ),
  JobCategory(
    title: 'Commercial Vehicle Driver',
    image: '$_dir/driver.jpg',
    query: 'Driver',
  ),
  JobCategory(
    title: 'Inventory Clerk',
    image: '$_dir/warehouse.jpg',
    query: 'Warehouse',
  ),
  JobCategory(
    title: 'Electrician',
    image: '$_dir/electrician.jpg',
    query: 'Electrician',
  ),
  JobCategory(
    title: 'Security Guard',
    image: '$_dir/security.jpg',
    query: 'Security',
  ),
  JobCategory(title: 'Plumber', image: '$_dir/plumber.jpg', query: 'Plumber'),
  JobCategory(
    title: 'Painter & Decorator',
    image: '$_dir/painter.jpg',
    query: 'Painter',
  ),
  JobCategory(
    title: 'AC & HVAC Technician',
    image: '$_dir/ac_technician.jpg',
    query: 'AC Technician',
  ),
  JobCategory(
    title: 'Housekeeping Executive',
    image: '$_dir/housekeeping.jpg',
    query: 'Housekeeping',
  ),
  JobCategory(
    title: 'Data Entry Operator',
    image: '$_dir/data_entry.jpg',
    query: 'Data Entry',
  ),
];

/// Home: "Explore Popular Job Categories", a sideways row of photo tiles.
/// No opening counts (the website's numbers are not real data).
class JobCategoriesSection extends StatelessWidget {
  const JobCategoriesSection({
    super.key,
    required this.onSelected,
    required this.onViewAll,
  });

  final ValueChanged<JobCategory> onSelected;
  final VoidCallback onViewAll;

  static const double tileWidth = 140;
  static const double tileHeight = 176;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Explore Popular Job Categories',
          subtitle: 'Logistics, technical trades, facility and office work',
          onSeeAll: onViewAll,
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        SizedBox(
          height: tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: popularJobCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = popularJobCategories[index];
              return JobCategoryTile(
                category: category,
                onTap: () => onSelected(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Photo with a dark fade at the bottom and the title on top of it.
class JobCategoryTile extends StatelessWidget {
  const JobCategoryTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  final JobCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      label: '${category.title} jobs',
      excludeSemantics: true,
      child: SizedBox(
        width: JobCategoriesSection.tileWidth,
        child: Material(
          color: AppColors.brandNavy,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  category.image,
                  fit: BoxFit.cover,
                  cacheWidth: (JobCategoriesSection.tileWidth * dpr).round(),
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.brandNavy,
                    child: Center(
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white54,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1],
                      colors: [
                        AppColors.brandNavy.withValues(alpha: 0),
                        AppColors.brandNavy.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    category.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
