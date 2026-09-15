import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/city.dart';
import '../repositories/city_repository.dart';

/// Modal bottom sheet for choosing a city (matching website header city selector)
class CitySelectorSheet extends ConsumerStatefulWidget {
  final String currentCity;
  final ValueChanged<String> onSelected;

  const CitySelectorSheet({
    super.key,
    required this.currentCity,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentCity,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CitySelectorSheet(currentCity: currentCity, onSelected: onSelected),
    );
  }

  @override
  ConsumerState<CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends ConsumerState<CitySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesFutureProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select City',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search city...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Popular Cities Quick Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'All',
                      'Mumbai',
                      'Delhi',
                      'Bengaluru',
                      'Pune',
                      'Hyderabad',
                      'Ahmedabad',
                    ].map((city) {
                      final isSelected =
                          widget.currentCity.toLowerCase() ==
                          city.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(city),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          backgroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          onSelected: (_) {
                            widget.onSelected(city);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // Cities List
          Expanded(
            child: citiesAsync.when(
              data: (cities) {
                final filtered = cities.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  return c.name.toLowerCase().contains(_searchQuery);
                }).toList();

                // Ensure "All" option is at the top if not searching
                if (_searchQuery.isEmpty &&
                    !filtered.any((c) => c.name.toLowerCase() == 'all')) {
                  filtered.insert(0, const City(id: 'all', name: 'All'));
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No cities found',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) =>
                      const Divider(height: 1, indent: 20),
                  itemBuilder: (context, index) {
                    final city = filtered[index];
                    final isSelected =
                        widget.currentCity.toLowerCase() ==
                        city.name.toLowerCase();

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.apartment_rounded,
                          size: 20,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                        title: Text(
                          city.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          widget.onSelected(city.name);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => AppShimmer(
                child: ListView.builder(
                  itemCount: 8,
                  itemBuilder: (_, index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        ShimmerCircle(size: 20),
                        SizedBox(width: 14),
                        ShimmerBox(width: 140, height: 16, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading cities: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
