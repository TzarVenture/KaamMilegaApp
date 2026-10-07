import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/expert_offering.dart';
import '../../providers/expert_dashboard_provider.dart';

/// Create a session offer, or edit [editing].
Future<void> showExpertOfferingSheet(
  BuildContext context, {
  ExpertOffering? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExpertOfferingSheet(editing: editing),
  );
}

class ExpertOfferingSheet extends ConsumerStatefulWidget {
  const ExpertOfferingSheet({super.key, this.editing});

  final ExpertOffering? editing;

  /// The same topics people filter by on the Experts page.
  static const categories = [
    'Interview Prep',
    'Career Guidance',
    'Technical Skills',
    'Soft Skills',
    'Resume Review',
    'Entrepreneurship',
  ];

  static const durations = [15, 30, 45, 60, 90];

  @override
  ConsumerState<ExpertOfferingSheet> createState() =>
      _ExpertOfferingSheetState();
}

class _ExpertOfferingSheetState extends ConsumerState<ExpertOfferingSheet> {
  late final ExpertOffering? _e = widget.editing;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _description = TextEditingController(text: _e?.description ?? '');
  late final _price = TextEditingController(text: _priceText(_e));
  late String _category = _e?.category ?? '';
  late int _duration = _e?.durationMinutes ?? 0;
  late bool _free = _e?.isFree ?? false;
  bool _saving = false;
  String? _error;

  static String _priceText(ExpertOffering? e) {
    if (e == null || e.isFree) return '';
    return e.price.toStringAsFixed(e.price % 1 == 0 ? 0 : 2);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final price = _free ? 0.0 : double.tryParse(_price.text.trim());
    if (price == null) {
      setState(() => _error = 'Please enter a price, or choose Free.');
      return;
    }
    final draft = ExpertOfferingDraft(
      title: _title.text,
      description: _description.text,
      category: _category,
      durationMinutes: _duration,
      price: price,
    );
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(expertDashboardActionsProvider)
        .saveOffering(draft, id: _e?.id);
    if (!mounted) return;
    if (error == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_e == null ? 'Session created.' : 'Session updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A category saved earlier that is not in the list stays selectable.
    final categories = {
      ...ExpertOfferingSheet.categories,
      if (_category.isNotEmpty) _category,
    };
    final durations = {
      ...ExpertOfferingSheet.durations,
      if (_duration > 0) _duration,
    }.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: SheetDragHandle()),
            Text(
              _e == null ? 'Create a session' : 'Edit session',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'People see this on the Experts page and can book it.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Mock interview for electricians',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What you will cover',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            const _Label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Duration'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in durations)
                  ChoiceChip(
                    label: Text('$d min'),
                    selected: _duration == d,
                    onSelected: (_) => setState(() => _duration = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Price'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Free session'),
              value: _free,
              onChanged: (v) => setState(() => _free = v),
            ),
            if (!_free)
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price per session',
                  prefixText: '₹ ',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(_e == null ? 'Create session' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
