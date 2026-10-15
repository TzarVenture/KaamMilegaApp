import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/nearby_professional.dart';
import '../providers/instant_hire_provider.dart';
import '../repositories/instant_hire_repository.dart';
import '../services/location_service.dart';

/// Hire: post a quick job to workers who are free near [location]
/// (POST /instant-work/dispatch). Pops `true` once the server saved it.
class HireRequestScreen extends ConsumerStatefulWidget {
  const HireRequestScreen({super.key, required this.location});

  final DeviceLocation location;

  @override
  ConsumerState<HireRequestScreen> createState() => _HireRequestScreenState();
}

class _HireRequestScreenState extends ConsumerState<HireRequestScreen> {
  static const List<double> _radii = [3, 5, 10];

  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _pay = TextEditingController();
  final _notes = TextEditingController();

  /// Trades workers can choose (same list as their "primary trade").
  final List<InstantServiceCategory> _trades = [
    for (final c in InstantServiceCategory.values)
      if (c.id != InstantServiceCategory.allId) c,
  ];

  String? _trade;
  bool _hourly = true;
  int _hours = 2;
  double _radius = 5;
  bool _showErrors = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _pay.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _address.dispose();
    _pay.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? get _payValue {
    final v = double.tryParse(_pay.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  /// "₹1,400 for 4 hours", shown under the pay when it can be worked out.
  String? get _totalLabel {
    final p = _payValue;
    if (!_hourly || p == null) return null;
    final total = (p * _hours).round();
    return 'About ₹$total for $_hours ${_hours == 1 ? 'hour' : 'hours'}';
  }

  Future<void> _submit() async {
    if (_sending) return; // one request per tap
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || _trade == null) return;

    setState(() => _sending = true);
    final result = await ref
        .read(instantHireActionsProvider)
        .post(
          HireRequestDraft(
            skill: _trade!,
            address: _address.text,
            lat: widget.location.latitude,
            lng: widget.location.longitude,
            payRate: _payValue!,
            hourly: _hourly,
            durationHours: _hours,
            radiusKm: _radius,
            notes: _notes.text,
          ),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
    if (result.outcome != HirePostOutcome.failed) {
      // Posted, or not confirmed: the status card shows what the server
      // has, so the form is closed either way.
      Navigator.of(context).maybePop(result.outcome == HirePostOutcome.posted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.moduleInstantWork,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Post a quick job',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            text: 'Send to workers near me',
            icon: Icons.bolt_rounded,
            accent: true,
            isLoading: _sending,
            onPressed: _sending ? null : _submit,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _showErrors
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Section(
              title: 'Who do you need?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _trades)
                        ChoiceChip(
                          avatar: Icon(
                            t.icon,
                            size: 16,
                            color: _trade == t.label
                                ? AppColors.white
                                : AppColors.moduleInstantWork,
                          ),
                          label: Text(t.label),
                          selected: _trade == t.label,
                          showCheckmark: false,
                          selectedColor: AppColors.moduleInstantWork,
                          backgroundColor: AppColors.white,
                          side: BorderSide(
                            color: _trade == t.label
                                ? AppColors.moduleInstantWork
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _trade == t.label
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                          onSelected: _sending
                              ? null
                              : (_) => setState(() => _trade = t.label),
                        ),
                    ],
                  ),
                  if (_showErrors && _trade == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Choose the kind of worker you need',
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Where?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _address,
                    hintText: 'House / shop, street and area',
                    maxLength: 200,
                    prefixIcon: const Icon(Icons.place_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter the address'
                        : null,
                  ),
                  const Text(
                    'Workers within this distance of your current location '
                    'will see the job:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in _radii)
                        ChoiceChip(
                          label: Text('${r.toStringAsFixed(0)} km'),
                          selected: _radius == r,
                          showCheckmark: false,
                          selectedColor: AppColors.brandNavy,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _radius == r
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                          onSelected: _sending
                              ? null
                              : (_) => setState(() => _radius = r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Pay and time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Per hour')),
                      ButtonSegment(value: false, label: Text('Fixed price')),
                    ],
                    selected: {_hourly},
                    showSelectedIcon: false,
                    onSelectionChanged: _sending
                        ? null
                        : (v) => setState(() => _hourly = v.first),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _pay,
                    hintText: _hourly ? 'Pay per hour (₹)' : 'Total pay (₹)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    validator: (_) =>
                        _payValue == null ? 'Please enter the pay' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'How long will it take?',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fewer hours',
                        onPressed: _sending || _hours <= 1
                            ? null
                            : () => setState(() => _hours--),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(
                        '$_hours h',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'More hours',
                        onPressed: _sending || _hours >= 12
                            ? null
                            : () => setState(() => _hours++),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                  if (_totalLabel != null)
                    Text(
                      _totalLabel!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandNavy,
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Anything else?',
              child: AppTextField(
                controller: _notes,
                hintText: 'Optional: tools needed, floor, landmark…',
                maxLines: 3,
                maxLength: 300,
              ),
            ),
            const _HowItWorks(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brandNavy,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// How the request works, in plain words, including payment.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const lines = [
      'Workers who are free now near you see your job for 3 minutes.',
      'The first worker to accept gets it. You will see their name and can '
          'call them.',
      'Pay the worker directly when the work is done. In-app payment for '
          'Instant Milega is not available yet.',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verifiedBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verifiedBlueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
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
}
