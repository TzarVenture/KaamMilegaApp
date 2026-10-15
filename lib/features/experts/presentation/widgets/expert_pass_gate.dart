import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/network_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../providers/expert_plan_provider.dart';

/// Shows [child] only while the Expert Pass is active (GET
/// /subscriptions/expert/my says `is_active`). Otherwise the screen explains
/// that the Expert Portal needs the pass and links to the plans.
class ExpertPassGate extends ConsumerWidget {
  const ExpertPassGate({super.key, required this.title, required this.child});

  /// App bar title while the pass is being checked or is missing.
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myExpertSubscriptionProvider);
    final status = async.value;
    if (status != null && status.isActive) return child;

    final Widget body;
    if (async.hasError && status == null) {
      body = NetworkStateView.fromError(
        async.error!,
        onRetry: () => ref.invalidate(myExpertSubscriptionProvider),
      );
    } else if (status == null) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerLoadingList(count: 3, itemHeight: 120),
      );
    } else {
      body = const ExpertPassRequiredView();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// "Expert Portal only" card with a link to the Expert Pass plans.
class ExpertPassRequiredView extends StatelessWidget {
  const ExpertPassRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.moduleExpertsLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 34,
                  color: AppColors.moduleExperts,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Expert Portal only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get the Expert Pass to create events, publish video courses '
                'and host paid 1-on-1 mentorship sessions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/apply-expert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandNavy,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'View Expert Pass plans',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
