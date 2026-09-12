import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';

/// Reusable Shimmer Wrapper
class AppShimmer extends StatelessWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Shimmer Container Box (Placeholder)
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer Circle Placeholder
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Job Card Skeleton Loading View
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerCircle(size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 160, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 110, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                ShimmerBox(width: 90, height: 24, borderRadius: 12),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 24, borderRadius: 12),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 100, height: 16, borderRadius: 4),
                ShimmerBox(width: 80, height: 36, borderRadius: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Job Detail Screen Skeleton
class JobDetailSkeleton extends StatelessWidget {
  const JobDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Row(
              children: [
                ShimmerCircle(size: 56),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 180, height: 20, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerBox(width: 120, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const ShimmerBox(width: double.infinity, height: 90, borderRadius: 20),
            const SizedBox(height: 24),
            const ShimmerBox(width: 140, height: 18, borderRadius: 4),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
            const SizedBox(height: 8),
            const ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
            const SizedBox(height: 8),
            const ShimmerBox(width: 200, height: 14, borderRadius: 4),
            const SizedBox(height: 24),
            const ShimmerBox(width: 140, height: 18, borderRadius: 4),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ShimmerBox(width: 80, height: 30, borderRadius: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// My Applications Screen Skeleton
class MyApplicationsSkeleton extends StatelessWidget {
  const MyApplicationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 140, height: 16, borderRadius: 4),
                  ShimmerBox(width: 70, height: 22, borderRadius: 10),
                ],
              ),
              SizedBox(height: 8),
              ShimmerBox(width: 100, height: 12, borderRadius: 4),
              SizedBox(height: 16),
              ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Candidate Profile Skeleton
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 70, borderRadius: 20),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 160, borderRadius: 20),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 120, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}
