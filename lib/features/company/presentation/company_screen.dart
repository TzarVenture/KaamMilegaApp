import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  final String companyId;

  const CompanyScreen({super.key, required this.companyId});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(title: const Text('Company Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Company Header Banner & Logo
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        color: AppColors.heroBg,
                        child: const Center(
                          child: Icon(
                            Icons.business_rounded,
                            size: 48,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 70,
                        left: 20,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.apartment_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Company Title & Follow Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reliance Logistics & Retail',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (!ref.read(authProvider).isAuthenticated) {
                                  showAuthPromptDialog(
                                    context,
                                    title: 'Sign In to Follow',
                                    message:
                                        'Please sign in to follow companies and receive hiring alerts.',
                                  );
                                  return;
                                }
                                setState(() => _isFollowing = !_isFollowing);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _isFollowing
                                          ? 'Now following Reliance Logistics!'
                                          : 'Unfollowed Reliance Logistics.',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                _isFollowing ? Icons.check : Icons.add,
                                size: 18,
                              ),
                              label: Text(
                                _isFollowing ? 'Following' : 'Follow',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.grey.shade200
                                    : AppColors.primary,
                                foregroundColor: _isFollowing
                                    ? AppColors.textPrimary
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Logistics & Supply Chain • Mumbai, Maharashtra • 10,000+ employees',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Leading supply chain, warehousing, and instant retail delivery network across 500+ Indian cities.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Open Vacancies Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open Positions at Company',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.drive_eta_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text(
                      'Senior Delivery Driver',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Mumbai • ₹25,000 - ₹35,000/mo'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text(
                      'Warehouse Operations Manager',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Thane, Navi Mumbai • ₹40,000/mo'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
