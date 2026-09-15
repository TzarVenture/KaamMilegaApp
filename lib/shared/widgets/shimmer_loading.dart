import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';

/// AppShimmer wrapper for general shimmer effects
class AppShimmer extends StatelessWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}

/// Shimmer Box placeholder
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer Circle placeholder
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Shimmer Loading List placeholder
class ShimmerLoadingList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ShimmerLoadingList({super.key, this.count = 4, this.itemHeight = 90});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerBox(
            width: double.infinity,
            height: itemHeight,
            borderRadius: 16,
          ),
        );
      },
    );
  }
}

/// Skeleton loader for Job Cards
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 180, height: 18, borderRadius: 4),
          SizedBox(height: 8),
          ShimmerBox(width: 130, height: 14, borderRadius: 4),
          SizedBox(height: 14),
          Row(
            children: [
              ShimmerBox(width: 70, height: 22, borderRadius: 12),
              SizedBox(width: 8),
              ShimmerBox(width: 90, height: 22, borderRadius: 12),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 14, borderRadius: 4),
              ShimmerBox(width: 80, height: 36, borderRadius: 18),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for My Applications screen
class MyApplicationsSkeleton extends StatelessWidget {
  const MyApplicationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(width: 160, height: 16, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerBox(width: 110, height: 12, borderRadius: 4),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 80, height: 20, borderRadius: 10),
                  ShimmerBox(width: 70, height: 12, borderRadius: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Skeleton loader for Job Detail screen
class JobDetailSkeleton extends StatelessWidget {
  const JobDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: double.infinity, height: 160, borderRadius: 24),
          SizedBox(height: 20),
          ShimmerBox(width: 220, height: 22, borderRadius: 4),
          SizedBox(height: 10),
          ShimmerBox(width: 140, height: 14, borderRadius: 4),
          SizedBox(height: 20),
          ShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
        ],
      ),
    );
  }
}
