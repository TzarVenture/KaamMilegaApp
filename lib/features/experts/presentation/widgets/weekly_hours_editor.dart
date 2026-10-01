import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/network_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../models/expert_offering.dart';
import '../../providers/expert_dashboard_provider.dart';

/// The Expert's weekly hours: a switch and a time range per day, saved
/// together (PUT /mentorships/availability replaces all days).
class WeeklyHoursEditor extends ConsumerStatefulWidget {
  const WeeklyHoursEditor({super.key});

  /// Monday first, as people read a week; values are the backend's
  /// `day_of_week` (0 = Sunday).
  static const dayOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  ConsumerState<WeeklyHoursEditor> createState() => _WeeklyHoursEditorState();
}

class _DayState {
  _DayState({required this.on, required this.start, required this.end});

  bool on;
  TimeOfDay start;
  TimeOfDay end;
}

class _WeeklyHoursEditorState extends ConsumerState<WeeklyHoursEditor> {
  static const _defaultStart = TimeOfDay(hour: 9, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 17, minute: 0);

  Map<int, _DayState>? _days;
  List<WeeklyHours>? _loadedFrom;
  bool _saving = false;
  String? _error;

  void _takeServerHours(List<WeeklyHours> hours) {
    if (identical(hours, _loadedFrom)) return;
    _loadedFrom = hours;
    _days = {
      for (final d in WeeklyHoursEditor.dayOrder)
        d: () {
          final saved = hours.where((h) => h.dayOfWeek == d).firstOrNull;
          return _DayState(
            on: saved != null,
            start: saved?.start ?? _defaultStart,
            end: saved?.end ?? _defaultEnd,
          );
        }(),
    };
  }

  Future<void> _pick(_DayState day, {required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? day.start : day.end,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        day.start = picked;
      } else {
        day.end = picked;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final days = _days;
    if (days == null) return;
    final hours = [
      for (final d in WeeklyHoursEditor.dayOrder)
        if (days[d]!.on)
          WeeklyHours(dayOfWeek: d, start: days[d]!.start, end: days[d]!.end),
    ];
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(expertDashboardActionsProvider)
        .saveAvailability(hours);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your hours are saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myAvailabilityProvider);
    return async.when(
      loading: () => const ShimmerLoadingList(count: 4, itemHeight: 70),
      error: (e, _) => NetworkStateView.fromError(
        e,
        onRetry: () => ref.invalidate(myAvailabilityProvider),
      ),
      data: (hours) {
        _takeServerHours(hours);
        final days = _days!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            const Text(
              'People can book you only inside these hours.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final d in WeeklyHoursEditor.dayOrder)
              _DayRow(
                name: WeeklyHours.dayNames[d],
                day: days[d]!,
                onToggle: (v) => setState(() {
                  days[d]!.on = v;
                  _error = null;
                }),
                onPickStart: () => _pick(days[d]!, start: true),
                onPickEnd: () => _pick(days[d]!, start: false),
              ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
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
                    : const Text('Save hours'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.name,
    required this.day,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String name;
  final _DayState day;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String label(TimeOfDay t) => localizations.formatTimeOfDay(t);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(value: day.on, onChanged: onToggle),
            ],
          ),
          if (day.on)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPickStart,
                    child: Text(
                      label(day.start),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'to',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPickEnd,
                    child: Text(
                      label(day.end),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            )
          else
            const Text(
              'Not available',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
