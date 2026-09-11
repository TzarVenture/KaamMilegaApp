import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../models/job_filter.dart';

/// Interactive Filter Modal Sheet matching website filter accordion
class FilterModalSheet extends StatefulWidget {
  final JobFilter initialFilter;
  final ValueChanged<JobFilter> onApply;

  const FilterModalSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required JobFilter initialFilter,
    required ValueChanged<JobFilter> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterModalSheet(
        initialFilter: initialFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterModalSheet> createState() => _FilterModalSheetState();
}

class _FilterModalSheetState extends State<FilterModalSheet> {
  late List<String> _jobTypes;
  late String _salaryRange;
  late String _experience;
  late List<String> _genders;
  late List<String> _qualification;

  static const List<String> kJobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Internship',
  ];

  static const List<Map<String, String>> kSalaryRanges = [
    {'label': 'All', 'value': 'all'},
    {'label': 'More Than ₹ 5,000', 'value': '5000'},
    {'label': 'More Than ₹ 10,000', 'value': '10000'},
    {'label': 'More Than ₹ 20,000', 'value': '20000'},
    {'label': 'More Than ₹ 30,000', 'value': '30000'},
  ];

  static const List<Map<String, String>> kExperienceLevels = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Fresher', 'value': '0'},
    {'label': '1 Year', 'value': '1'},
    {'label': '2-4 Years', 'value': '4'},
    {'label': '5 Years', 'value': '5'},
    {'label': '> 5 Years', 'value': '30'},
  ];

  static const List<String> kGenders = ['Male', 'Female'];

  static const List<String> kQualifications = [
    '10th Pass',
    '12th Pass',
    'Diploma',
    'Graduation',
    'Post Graduation',
  ];

  @override
  void initState() {
    super.initState();
    _jobTypes = List.from(widget.initialFilter.jobTypes);
    _salaryRange = widget.initialFilter.salaryRange;
    _experience = widget.initialFilter.experience;
    _genders = List.from(widget.initialFilter.genders);
    _qualification = List.from(widget.initialFilter.qualification);
  }

  int get _activeCount {
    int c = _jobTypes.length + _genders.length + _qualification.length;
    if (_salaryRange != 'all') c++;
    if (_experience != 'all') c++;
    return c;
  }

  void _clearAll() {
    setState(() {
      _jobTypes.clear();
      _salaryRange = 'all';
      _experience = 'all';
      _genders.clear();
      _qualification.clear();
    });
  }

  void _submit() {
    final updated = widget.initialFilter.copyWith(
      jobTypes: _jobTypes,
      salaryRange: _salaryRange,
      experience: _experience,
      genders: _genders,
      qualification: _qualification,
      page: 1,
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filters${_activeCount > 0 ? ' ($_activeCount)' : ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Filter Sections List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 1. Monthly Salary
                _buildSection(
                  title: 'Monthly Salary',
                  initiallyExpanded: true,
                  children: kSalaryRanges.map((sal) {
                    final isSelected = _salaryRange == sal['value'];
                    return InkWell(
                      onTap: () => setState(() => _salaryRange = sal['value']!),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? AppColors.primary : AppColors.textLight,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              sal['label']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 2. Experience Level
                _buildSection(
                  title: 'Experience',
                  initiallyExpanded: true,
                  children: kExperienceLevels.map((exp) {
                    final isSelected = _experience == exp['value'];
                    return InkWell(
                      onTap: () => setState(() => _experience = exp['value']!),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? AppColors.primary : AppColors.textLight,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              exp['label']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 3. Job Type
                _buildSection(
                  title: 'Job Type',
                  initiallyExpanded: false,
                  children: kJobTypes.map((type) {
                    final isChecked = _jobTypes.contains(type);
                    return CheckboxListTile(
                      title: Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isChecked ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      value: isChecked,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _jobTypes.add(type);
                          } else {
                            _jobTypes.remove(type);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                // 4. Gender
                _buildSection(
                  title: 'Gender',
                  initiallyExpanded: false,
                  children: kGenders.map((gender) {
                    final isChecked = _genders.contains(gender);
                    return CheckboxListTile(
                      title: Text(
                        gender,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isChecked ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      value: isChecked,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _genders.add(gender);
                          } else {
                            _genders.remove(gender);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                // 5. Qualification
                _buildSection(
                  title: 'Qualification',
                  initiallyExpanded: false,
                  children: kQualifications.map((q) {
                    final isChecked = _qualification.contains(q);
                    return CheckboxListTile(
                      title: Text(
                        q,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isChecked ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      value: isChecked,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _qualification.add(q);
                          } else {
                            _qualification.remove(q);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        children: children,
      ),
    );
  }
}
