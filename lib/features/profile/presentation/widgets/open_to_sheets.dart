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

/// Ready-made job titles shown as one-tap suggestions (the same list as
/// the website's Open To Work form). Hardcoded UI constants.
const List<String> kJobTitleSuggestions = [
  'Electrician',
  'Technician',
  'Full Stack Developer',
  'Plumber',
  'Driver',
  'Delivery Executive',
  'Sales Associate',
  'AC Mechanic',
];

/// Ready-made services shown as one-tap suggestions (the same list as the
/// website's Providing Services form). Hardcoded UI constants.
const List<String> kServiceSuggestions = [
  'AC Repair & Service',
  'Electrical Wiring',
  'Plumbing Maintenance',
  'Carpentry & Furniture',
  'Painting & Waterproofing',
  'Technical Mentorship',
  'Vehicle Mechanics',
  'Welding & Fabrication',
];

/// Longest job title, location or service name accepted by the forms.
const int _maxTagLength = 60;

// ---------------------------------------------------------------------
// OPEN TO WORK
// ---------------------------------------------------------------------

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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    // Removing keeps what is saved on the server; only the status changes.
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
      Navigator.of(context).pop(
        isOpen
            ? 'Open To Work saved.'
            : 'Open To Work status removed from your profile.',
      );
      return;
    }
    setState(() {
      _saving = false;
      _error =
          ref.read(authProvider).error ?? 'Could not save. Please try again.';
    });
  }

  void _setVisibility(String value) {
    if (_saving) return;
    setState(() => _visibility = value);
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.user.isOpenToWork && _saved != null;
    return _FormSheet(
      icon: Icons.work_outline_rounded,
      tone: _Tone.blue,
      title: 'Open To Work',
      subtitle: 'Show recruiters the opportunities you are seeking',
      saving: _saving,
      footer: _FormFooter(
        saving: _saving,
        canRemove: isOn,
        saveLabel: 'Save Preferences',
        removeLabel: 'Remove Status',
        onSave: () => _submit(isOpen: true),
        onRemove: () => _submit(isOpen: false),
        onCancel: () => Navigator.of(context).pop(),
      ),
      children: [
        if (_saved == null)
          _DeviceTextNote(text: widget.user.openToWork, label: 'job titles'),
        const _UpperLabel('Job titles'),
        _TagField(
          controller: _titleCtrl,
          values: _titles,
          hint: 'Add a role, e.g. Electrician, Web Developer',
          tone: _Tone.blue,
          suggestions: kJobTitleSuggestions,
          enabled: !_saving,
          onChanged: () => setState(() => _error = null),
        ),
        const SizedBox(height: 24),
        const _UpperLabel('Job types'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _jobTypeOptions)
              _JobTypeChip(
                label: type,
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
        const SizedBox(height: 24),
        const _UpperLabel('Preferred locations'),
        _TagField(
          controller: _locationCtrl,
          values: _locations,
          hint: "Add a city or 'Remote', e.g. Mumbai",
          tone: _Tone.neutral,
          icon: Icons.location_on_outlined,
          enabled: !_saving,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        const _UpperLabel('Visibility scope'),
        _TwoChoices(
          first: _ChoiceTile(
            title: 'All members',
            subtitle:
                'Adds the Open to Work badge to your profile so anyone can '
                'find you.',
            selected: _visibility == OpenToWorkPreferences.visibilityAll,
            onTap: () => _setVisibility(OpenToWorkPreferences.visibilityAll),
          ),
          second: _ChoiceTile(
            title: 'Recruiters only',
            // Honest: the backend saves this choice but does not yet
            // restrict who can see the status.
            subtitle:
                'Saved as your preference. KaamMilega does not yet limit who '
                'can see this status.',
            selected: _visibility == OpenToWorkPreferences.visibilityRecruiters,
            onTap: () =>
                _setVisibility(OpenToWorkPreferences.visibilityRecruiters),
          ),
        ),
        _ErrorText(_error),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// PROVIDING SERVICES
// ---------------------------------------------------------------------

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
  /// Longest description accepted by the form.
  static const int _maxDescriptionLength = 1000;

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
      text: rate <= 0 ? '' : ProvidingServicesPreferences.formatAmount(rate),
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = _saved;
    // Removing keeps the saved values on the server (only is_providing
    // changes), so they come back prefilled next time.
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
            : 'Services removed from your profile.',
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
    final symbol = _currency.toUpperCase() == 'INR' ? '₹  ' : '$_currency  ';
    return _FormSheet(
      icon: Icons.build_outlined,
      tone: _Tone.orange,
      title: 'Providing Services',
      subtitle: 'Showcase the trades and services you offer to clients',
      saving: _saving,
      footer: _FormFooter(
        saving: _saving,
        canRemove: isOn,
        saveLabel: 'Save Services',
        removeLabel: 'Remove Services',
        onSave: () => _submit(isProviding: true),
        onRemove: () => _submit(isProviding: false),
        onCancel: () => Navigator.of(context).pop(),
      ),
      children: [
        if (_saved == null)
          _DeviceTextNote(
            text: widget.user.providingServices,
            label: 'services',
          ),
        const _UpperLabel('Services you offer'),
        _TagField(
          controller: _serviceCtrl,
          values: _services,
          hint: 'Add a service, e.g. Electrical Fitting',
          tone: _Tone.orange,
          suggestions: kServiceSuggestions,
          enabled: !_saving,
          onChanged: () => setState(() => _error = null),
        ),
        const SizedBox(height: 24),
        const _UpperLabel('Starting / hourly rate (optional)'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            controller: _rateCtrl,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,7}(\.\d{0,2})?'),
              ),
            ],
            decoration: _fieldDecoration(
              hint: '500',
              prefix: symbol,
              suffix: '/ hour',
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _UpperLabel('Service details & scope'),
        TextField(
          controller: _descriptionCtrl,
          enabled: !_saving,
          minLines: 3,
          maxLines: 6,
          maxLength: _maxDescriptionLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: _fieldDecoration(
            hint:
                'Describe how you work with clients, equipment provided, '
                'warranty or response time',
          ),
        ),
        _ErrorText(_error),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// SHARED PIECES
// ---------------------------------------------------------------------

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

/// Colour family of a form: blue for Open To Work, orange for services,
/// neutral for secondary chips such as locations.
enum _Tone { blue, orange, neutral }

extension on _Tone {
  Color get background => switch (this) {
    _Tone.blue => AppColors.primaryLight,
    _Tone.orange => AppColors.accentLight,
    _Tone.neutral => AppColors.background,
  };

  Color get border => switch (this) {
    _Tone.blue => AppColors.primaryLightBorder,
    _Tone.orange => AppColors.accentBorder,
    _Tone.neutral => AppColors.border,
  };

  Color get foreground => switch (this) {
    _Tone.blue => AppColors.primary,
    _Tone.orange => AppColors.accentText,
    _Tone.neutral => AppColors.textPrimary,
  };

  Color get icon => switch (this) {
    _Tone.blue => AppColors.primary,
    _Tone.orange => AppColors.accent,
    _Tone.neutral => AppColors.textSecondary,
  };
}

InputDecoration _fieldDecoration({
  required String hint,
  String? prefix,
  String? suffix,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
    hintMaxLines: 3,
    prefixText: prefix,
    prefixStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    ),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13.5,
    ),
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: outline(AppColors.border),
    enabledBorder: outline(AppColors.border),
    disabledBorder: outline(AppColors.borderLight),
    focusedBorder: outline(AppColors.primary, 1.5),
  );
}

/// Bottom sheet with a fixed header, a scrolling form and buttons that
/// stay at the bottom (also while the keyboard is open).
class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.footer,
    required this.children,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String subtitle;
  final bool saving;
  final Widget footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PopScope(
      // Keep the sheet open until the server has answered.
      canPop: !saving,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormHeader(
                icon: icon,
                tone: tone,
                title: title,
                subtitle: subtitle,
                onClose: saving ? null : () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        children: [
          const SheetDragHandle(bottomSpacing: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.border),
                ),
                child: Icon(icon, color: tone.icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondary,
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small uppercase section label, as on the website forms.
class _UpperLabel extends StatelessWidget {
  const _UpperLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// One input box that holds what the user picked: each chosen value is a
/// removable chip inside the box, with the text field for typing a new one
/// under them and an Add button at its end. [suggestions] not yet chosen
/// appear below the box; tapping one moves it into the box.
class _TagField extends StatefulWidget {
  const _TagField({
    required this.controller,
    required this.values,
    required this.hint,
    required this.tone,
    required this.enabled,
    required this.onChanged,
    this.suggestions = const [],
    this.icon,
  });

  final TextEditingController controller;
  final List<String> values;
  final String hint;
  final _Tone tone;
  final bool enabled;
  final VoidCallback onChanged;
  final List<String> suggestions;
  final IconData? icon;

  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Repaint the box border when the field gains or loses focus.
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  bool _has(String value) =>
      widget.values.any((v) => v.toLowerCase() == value.toLowerCase());

  void _addTyped() {
    if (addChipValue(widget.values, widget.controller)) widget.onChanged();
  }

  void _addSuggestion(String value) {
    if (_has(value)) return;
    widget.values.add(value);
    widget.onChanged();
  }

  void _remove(String value) {
    widget.values.remove(value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final values = widget.values;
    final open = widget.suggestions.where((s) => !_has(s)).take(6).toList();
    // A chip never gets wider than the box.
    final chipMaxWidth = (MediaQuery.of(context).size.width - 120)
        .clamp(120.0, 520.0)
        .toDouble();
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          // Tapping anywhere in the box (not only the text line) types.
          onTap: widget.enabled ? _focus.requestFocus : null,
          behavior: HitTestBehavior.translucent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.fromLTRB(10, values.isEmpty ? 2 : 10, 6, 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !widget.enabled
                    ? AppColors.borderLight
                    : (focused ? AppColors.primary : AppColors.border),
                width: focused ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (values.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final value in values)
                        InputChip(
                          avatar: widget.icon == null
                              ? null
                              : Icon(
                                  widget.icon,
                                  size: 16,
                                  color: tone.foreground,
                                ),
                          label: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: chipMaxWidth),
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: tone.foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          backgroundColor: tone.background,
                          side: BorderSide(color: tone.border),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          deleteIconColor: tone.foreground,
                          deleteButtonTooltipMessage: 'Remove $value',
                          onDeleted: widget.enabled
                              ? () => _remove(value)
                              : null,
                        ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        enabled: widget.enabled,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_maxTagLength),
                        ],
                        // Keep the keyboard open to add the next one.
                        onSubmitted: (_) {
                          _addTyped();
                          _focus.requestFocus();
                        },
                        decoration: InputDecoration(
                          hintText: values.isEmpty
                              ? widget.hint
                              : 'Add another',
                          hintStyle: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.enabled ? _addTyped : null,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(56, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (open.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'SUGGESTIONS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              for (final s in open)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(s),
                  tooltip: 'Add $s',
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.enabled ? () => _addSuggestion(s) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Job type pill: navy with a tick when selected, white otherwise.
class _JobTypeChip extends StatelessWidget {
  const _JobTypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }
}

/// Two options side by side on wide screens, one under the other on
/// phones.
class _TwoChoices extends StatelessWidget {
  const _TwoChoices({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                const SizedBox(width: 12),
                Expanded(child: second),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        );
      },
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
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

/// Buttons that stay at the bottom of the sheet. On a phone the save
/// button is full width on top; on wide screens the three sit in one row.
class _FormFooter extends StatelessWidget {
  const _FormFooter({
    required this.saving,
    required this.canRemove,
    required this.saveLabel,
    required this.removeLabel,
    required this.onSave,
    required this.onRemove,
    required this.onCancel,
  });

  final bool saving;
  final bool canRemove;
  final String saveLabel;
  final String removeLabel;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final save = ElevatedButton(
      onPressed: saving ? null : onSave,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          : Text(
              saveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
    final cancel = TextButton(
      onPressed: saving ? null : onCancel,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 48),
      ),
      child: const Text(
        'Cancel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
    final remove = OutlinedButton.icon(
      onPressed: saving ? null : onRemove,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(
        removeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 520) {
            // Every slot can shrink, so large text never pushes a button
            // off the edge (labels shorten with "..." instead).
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: canRemove
                      ? Align(alignment: Alignment.centerLeft, child: remove)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Flexible(child: cancel),
                const SizedBox(width: 8),
                Flexible(flex: 2, child: save),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              save,
              const SizedBox(height: 8),
              Row(
                children: [
                  if (canRemove) ...[
                    Expanded(child: remove),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: cancel),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
