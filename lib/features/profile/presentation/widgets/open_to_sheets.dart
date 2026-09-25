import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../../auth/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';

/// Opens the Open To Work sheet. Returns the success message when the
/// server saved the change, or null when the sheet was closed.
Future<String?> showOpenToWorkSheet(BuildContext context, UserProfile user) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OpenToWorkSheet(user: user),
  );
}

/// Opens the Providing Services sheet (same result as [showOpenToWorkSheet]).
Future<String?> showProvidingServicesSheet(
  BuildContext context,
  UserProfile user,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProvidingServicesSheet(user: user),
  );
}

/// Open To Work form matching the backend `open_to_work` object:
/// job titles, job types, locations and visibility.
class OpenToWorkSheet extends ConsumerStatefulWidget {
  const OpenToWorkSheet({super.key, required this.user});

  final UserProfile user;

  @override
  ConsumerState<OpenToWorkSheet> createState() => _OpenToWorkSheetState();
}

class _OpenToWorkSheetState extends ConsumerState<OpenToWorkSheet> {
  late final List<String> _titles;
  late final List<String> _jobTypes;
  late final List<String> _locations;
  late final List<String> _jobTypeOptions;
  late String _visibility;
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  OpenToWorkPreferences? get _saved => widget.user.openToWorkPreferences;

  @override
  void initState() {
    super.initState();
    final saved = _saved;
    _titles = [...?saved?.jobTitles];
    _jobTypes = [...?saved?.jobTypes];
    _locations = [...?saved?.locations];
    // Keep job types saved from elsewhere so they are not silently dropped.
    _jobTypeOptions = [
      ...OpenToWorkPreferences.jobTypeOptions,
      ..._jobTypes.where(
        (t) => !OpenToWorkPreferences.jobTypeOptions.contains(t),
      ),
    ];
    _visibility =
        saved?.visibility == OpenToWorkPreferences.visibilityRecruiters
        ? OpenToWorkPreferences.visibilityRecruiters
        : OpenToWorkPreferences.visibilityAll;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool isOpen}) async {
    if (isOpen) {
      // Text typed but not yet added counts as one more entry.
      addChipValue(_titles, _titleCtrl);
      addChipValue(_locations, _locationCtrl);
      if (_titles.isEmpty) {
        setState(() => _error = 'Add at least one job title.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // Turning off keeps what is saved on the server; only the status changes.
    final saved = _saved;
    final prefs = isOpen
        ? OpenToWorkPreferences(
            isOpen: true,
            jobTitles: List.of(_titles),
            jobTypes: List.of(_jobTypes),
            locations: List.of(_locations),
            visibility: _visibility,
          )
        : OpenToWorkPreferences(
            isOpen: false,
            jobTitles: saved?.jobTitles ?? const [],
            jobTypes: saved?.jobTypes ?? const [],
            locations: saved?.locations ?? const [],
            visibility: (saved?.visibility ?? '').isEmpty
                ? OpenToWorkPreferences.visibilityAll
                : saved!.visibility,
          );
    final ok = await ref.read(authProvider.notifier).saveOpenToWork(prefs);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context)
          .pop(isOpen ? 'Open To Work saved.' : 'Open To Work turned off.');
      return;
    }
    setState(() {
      _saving = false;
      _error =
          ref.read(authProvider).error ?? 'Could not save. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.user.isOpenToWork && _saved != null;
    return _SheetFrame(
      title: 'Open To Work',
      subtitle: 'Show recruiters the work you are looking for',
      saving: _saving,
      children: [
        if (_saved == null)
          _DeviceTextNote(text: widget.user.openToWork, label: 'job titles'),
        _ChipEntry(
          label: 'Job titles',
          hint: 'e.g. Electrician, Delivery Executive',
          controller: _titleCtrl,
          values: _titles,
          enabled: !_saving,
          onChanged: () => setState(() => _error = null),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Job types'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _jobTypeOptions)
              FilterChip(
                label: Text(type),
                selected: _jobTypes.contains(type),
                onSelected: _saving
                    ? null
                    : (on) => setState(() {
                        if (on) {
                          _jobTypes.add(type);
                        } else {
                          _jobTypes.remove(type);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _ChipEntry(
          label: 'Preferred locations',
          hint: 'e.g. Pune, Mumbai, Remote',
          controller: _locationCtrl,
          values: _locations,
          enabled: !_saving,
          icon: Icons.location_on_outlined,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Who can see this'),
        _ChoiceTile(
          title: 'All members',
          subtitle: 'Anyone who can view your profile can see this status.',
          selected: _visibility == OpenToWorkPreferences.visibilityAll,
          onTap: _saving
              ? null
              : () => setState(
                  () => _visibility = OpenToWorkPreferences.visibilityAll,
                ),
        ),
        const SizedBox(height: 8),
        _ChoiceTile(
          title: 'Recruiters only',
          subtitle:
              'Saved as your preference. KaamMilega does not yet limit who '
              'can see this status.',
          selected: _visibility == OpenToWorkPreferences.visibilityRecruiters,
          onTap: _saving
              ? null
              : () => setState(
                  () =>
                      _visibility = OpenToWorkPreferences.visibilityRecruiters,
                ),
        ),
        _ErrorText(_error),
        const SizedBox(height: 20),
        _SheetActions(
          saving: _saving,
          canTurnOff: isOn,
          turnOffLabel: 'Turn off Open To Work',
          onSave: () => _submit(isOpen: true),
          onTurnOff: () => _submit(isOpen: false),
        ),
      ],
    );
  }
}

/// Providing Services form matching the backend `providing_services`
/// object: services, hourly rate, currency and description.
class ProvidingServicesSheet extends ConsumerStatefulWidget {
  const ProvidingServicesSheet({super.key, required this.user});

  final UserProfile user;

  @override
  ConsumerState<ProvidingServicesSheet> createState() =>
      _ProvidingServicesSheetState();
}

class _ProvidingServicesSheetState
    extends ConsumerState<ProvidingServicesSheet> {
  late final List<String> _services;
  late final String _currency;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _descriptionCtrl;
  final _serviceCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  ProvidingServicesPreferences? get _saved =>
      widget.user.providingServicesPreferences;

  @override
  void initState() {
    super.initState();
    final saved = _saved;
    _services = [...?saved?.services];
    final savedCurrency = saved?.currency.trim() ?? '';
    _currency = savedCurrency.isEmpty
        ? ProvidingServicesPreferences.defaultCurrency
        : savedCurrency;
    final rate = saved?.hourlyRate ?? 0;
    _rateCtrl = TextEditingController(
      text: rate <= 0
          ? ''
          : (rate == rate.roundToDouble()
                ? rate.toInt().toString()
                : rate.toStringAsFixed(2)),
    );
    _descriptionCtrl = TextEditingController(text: saved?.description ?? '');
  }

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _rateCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool isProviding}) async {
    if (isProviding) addChipValue(_services, _serviceCtrl);
    final rateText = _rateCtrl.text.trim();
    final rate = rateText.isEmpty ? 0.0 : double.tryParse(rateText);
    if (isProviding) {
      if (_services.isEmpty) {
        setState(() => _error = 'Add at least one service.');
        return;
      }
      if (rate == null || rate < 0) {
        setState(() => _error = 'Enter a valid hourly rate.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = _saved;
    final prefs = isProviding
        ? ProvidingServicesPreferences(
            isProviding: true,
            services: List.of(_services),
            hourlyRate: rate ?? 0,
            currency: _currency,
            description: _descriptionCtrl.text.trim(),
          )
        : ProvidingServicesPreferences(
            isProviding: false,
            services: saved?.services ?? const [],
            hourlyRate: saved?.hourlyRate ?? 0,
            currency: _currency,
            description: saved?.description ?? '',
          );
    final ok = await ref
        .read(authProvider.notifier)
        .saveProvidingServices(prefs);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(
        isProviding
            ? 'Providing Services saved.'
            : 'Providing Services turned off.',
      );
      return;
    }
    setState(() {
      _saving = false;
      _error =
          ref.read(authProvider).error ?? 'Could not save. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.user.isProvidingServices && _saved != null;
    final currencyPrefix = _currency == 'INR' ? '₹ ' : '$_currency ';
    return _SheetFrame(
      title: 'Providing Services',
      subtitle: 'Showcase the trades and services you offer',
      saving: _saving,
      children: [
        if (_saved == null)
          _DeviceTextNote(
            text: widget.user.providingServices,
            label: 'services',
          ),
        _ChipEntry(
          label: 'Services',
          hint: 'e.g. AC Repair, Electrical Wiring',
          controller: _serviceCtrl,
          values: _services,
          enabled: !_saving,
          onChanged: () => setState(() => _error = null),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Hourly rate (optional)'),
        TextField(
          controller: _rateCtrl,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?')),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. 500',
            prefixText: currencyPrefix,
            suffixText: 'per hour',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Currency: $_currency',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Description (optional)'),
        TextField(
          controller: _descriptionCtrl,
          enabled: !_saving,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Describe your experience and what clients can expect',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        _ErrorText(_error),
        const SizedBox(height: 20),
        _SheetActions(
          saving: _saving,
          canTurnOff: isOn,
          turnOffLabel: 'Turn off Providing Services',
          onSave: () => _submit(isProviding: true),
          onTurnOff: () => _submit(isProviding: false),
        ),
      ],
    );
  }
}

/// Adds the controller's text to [values] (trimmed, ignoring case
/// duplicates) and clears the field. Returns true when something was added.
bool addChipValue(List<String> values, TextEditingController controller) {
  final text = controller.text.trim();
  controller.clear();
  if (text.isEmpty) return false;
  final exists = values.any((v) => v.toLowerCase() == text.toLowerCase());
  if (exists) return false;
  values.add(text);
  return true;
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.children,
  });

  final String title;
  final String subtitle;
  final bool saving;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PopScope(
      // Keep the sheet open until the server has answered.
      canPop: !saving,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetDragHandle(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a single-choice list (selected option is highlighted).
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// Text field with an Add button; each added value becomes a removable chip.
class _ChipEntry extends StatelessWidget {
  const _ChipEntry({
    required this.label,
    required this.hint,
    required this.controller,
    required this.values,
    required this.enabled,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final List<String> values;
  final bool enabled;
  final VoidCallback onChanged;
  final IconData? icon;

  void _add() {
    if (addChipValue(values, controller)) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: enabled ? _add : null,
              child: const Text('Add'),
            ),
          ],
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                InputChip(
                  avatar: icon == null ? null : Icon(icon, size: 16),
                  label: Text(value),
                  onDeleted: enabled
                      ? () {
                          values.remove(value);
                          onChanged();
                        }
                      : null,
                  deleteButtonTooltipMessage: 'Remove $value',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shows text the user typed in the old Open To sheet (kept on this device
/// only). It is not converted or sent automatically.
class _DeviceTextNote extends StatelessWidget {
  const _DeviceTextNote({required this.text, required this.label});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Saved earlier on this phone only: "${text.trim()}". '
        'Add the $label you still want below to save them to your profile.',
        style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        error!,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.saving,
    required this.canTurnOff,
    required this.turnOffLabel,
    required this.onSave,
    required this.onTurnOff,
  });

  final bool saving;
  final bool canTurnOff;
  final String turnOffLabel;
  final VoidCallback onSave;
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        if (canTurnOff) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onTurnOff,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(turnOffLabel),
          ),
        ],
      ],
    );
  }
}
