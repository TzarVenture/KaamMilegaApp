import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../company/models/top_company.dart';
import '../../../company/providers/company_provider.dart';
import 'home_section_header.dart';

/// Home: "Featured Companies Actively Hiring" from GET /companies/top.
/// Only real employers are shown (no invented brands, counts or badges);
/// "Verified Employer" appears only when the server says so.
class FeaturedCompaniesSection extends ConsumerWidget {
  const FeaturedCompaniesSection({super.key});

  static const double cardWidth = 272;
  static const double rowHeight = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(topCompaniesProvider);

    return companiesAsync.when(
      // No employers yet: the section is hidden.
      data: (companies) => companies.isEmpty
          ? const SizedBox.shrink()
          : _Section(
              child: SizedBox(
                height: rowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: companies.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      CompanyCard(company: companies[index]),
                ),
              ),
            ),
      loading: () => _Section(
        child: SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const ShimmerBox(
              width: cardWidth,
              height: rowHeight,
              borderRadius: 16,
            ),
          ),
        ),
      ),
      // A failure is shown as a failure (with Retry), never as "no companies".
      error: (_, _) => _Section(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load companies right now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(topCompaniesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Featured Companies Actively Hiring',
          subtitle: 'Employers hiring on KaamMilega',
        ),
        const SizedBox(height: HomeSectionHeader.gap),
        child,
      ],
    );
  }
}

/// One employer: logo, name, (verified), category, city, and View Jobs.
class CompanyCard extends StatelessWidget {
  const CompanyCard({super.key, required this.company});

  final TopCompany company;

  void _open(BuildContext context) =>
      context.push('/company/${company.id}', extra: company);

  @override
  Widget build(BuildContext context) {
    final details = [
      company.category,
      company.location,
    ].where((v) => v.isNotEmpty).join(' · ');

    return HomeCardShadow(
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Container(
            width: FeaturedCompaniesSection.cardWidth,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CompanyLogo(company: company, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  company.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (company.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: AppColors.blue,
                                  semanticLabel: 'Verified',
                                ),
                              ],
                            ],
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (company.verified) ...[
                            const SizedBox(height: 6),
                            const VerifiedEmployerPill(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _open(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandNavy,
                      backgroundColor: AppColors.primaryLight,
                      side: BorderSide.none,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Jobs →',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

/// Company logo, or its initials when there is no logo (or it fails).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.company, this.size = 52});

  final TopCompany company;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        company.initials.isNotEmpty ? company.initials : '?',
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: company.logo.isEmpty
          ? fallback
          : Image.network(
              company.logo,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class VerifiedEmployerPill extends StatelessWidget {
  const VerifiedEmployerPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.verifiedBlueBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.verifiedBlueBorder),
      ),
      child: const Text(
        'Verified Employer',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.verifiedBlue,
        ),
      ),
    );
  }
}
