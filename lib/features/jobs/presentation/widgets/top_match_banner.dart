import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Top Match Highlights banner card matching kaammilega.com/jobs
class TopMatchBanner extends StatelessWidget {
  const TopMatchBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.topMatchCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.topMatchBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.topMatchGold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Match Jobs For You',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: const [
                    _FeatureTag(text: 'Near You'),
                    _FeatureTag(text: 'Good Salary'),
                    _FeatureTag(text: 'Matching Experience'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final String text;

  const _FeatureTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
