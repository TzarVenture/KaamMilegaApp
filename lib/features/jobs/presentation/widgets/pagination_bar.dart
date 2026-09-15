import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Pagination Bar with page numbers and next/prev controls
class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.textPrimary,
            disabledColor: AppColors.textLight.withValues(alpha: 0.4),
          ),

          const SizedBox(width: 4),

          // Dynamic page buttons (show up to 5 surrounding pages)
          ...List.generate(totalPages, (i) => i + 1)
              .where((page) {
                return page == 1 ||
                    page == totalPages ||
                    (page >= currentPage - 1 && page <= currentPage + 1);
              })
              .map((page) {
                final isSelected = page == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => onPageChanged(page),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.white,
                        foregroundColor: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        elevation: isSelected ? 2 : 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),

          const SizedBox(width: 4),

          // Next button
          IconButton(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.textPrimary,
            disabledColor: AppColors.textLight.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
