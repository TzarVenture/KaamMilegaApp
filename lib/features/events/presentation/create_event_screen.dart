import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../experts/presentation/widgets/expert_pass_gate.dart';
import '../../experts/presentation/widgets/expert_portal_widgets.dart';
import '../../posts/providers/post_image_picker.dart';
import '../providers/create_event_provider.dart';
import 'event_detail_screen.dart';

/// Expert Portal: "Create New Event" (website /user/events/create). Title,
/// organizer, description, date, time, location and an optional banner
/// photo. Only while the Expert Pass is active.
class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExpertPassGate(
      title: 'Create Event',
      child: _CreateEventForm(),
    );
  }
}

class _CreateEventForm extends ConsumerStatefulWidget {
  const _CreateEventForm();

  @override
  ConsumerState<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends ConsumerState<_CreateEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _organizer = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();

  DateTime? _date;
  TimeOfDay? _time;
  String? _bannerName;
  Uint8List? _bannerBytes;
  bool _showErrors = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The organizer is usually the Expert; they can change it.
    final name = ref.read(authProvider).user?.name.trim() ?? '';
    _organizer.text = name;
  }

  @override
  void dispose() {
    _title.dispose();
    _organizer.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? 'Please enter $what' : null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Event date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Start time',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickBanner() async {
    final images = await ref.read(postImagePickerProvider)(limit: 1);
    if (images.isEmpty || !mounted) return;
    setState(() {
      _bannerName = images.first.name;
      _bannerBytes = images.first.bytes;
    });
  }

  /// A time already passed today cannot be chosen.
  bool get _timeInPast {
    final d = _date, t = _time;
    if (d == null || t == null) return false;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    return at.isBefore(DateTime.now());
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final fieldsOk = _formKey.currentState?.validate() ?? false;
    if (!fieldsOk || _date == null || _time == null || _timeInPast) return;

    setState(() => _saving = true);
    final result = await ref
        .read(eventCreatorProvider)
        .create(
          EventDraft(
            title: _title.text,
            organizer: _organizer.text,
            description: _description.text,
            date: _date!,
            time: _time!,
            location: _location.text,
            bannerName: _bannerName,
            bannerBytes: _bannerBytes,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final event = result.event;
    if (event == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? 'Could not create event.')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Event created successfully.')),
    );
    // Close the form and open the new event (the form is a router page,
    // so it is popped rather than replaced).
    final navigator = Navigator.of(context)..pop();
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => EventDetailScreen(event: event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null
        ? null
        : DateFormat('EEE, d MMM yyyy').format(_date!);
    final timeLabel = _time?.format(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: ExpertSubmitBar(
          child: AppButton(
            text: 'Create Event',
            icon: Icons.event_available_rounded,
            accent: true,
            isLoading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(
                child: ExpertPortalHero(
                  title: 'Create New',
                  highlight: 'Event',
                  subtitle:
                      'Host a networking session, webinar, or community '
                      'meetup.',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList.list(
                  children: [
                    _BannerPicker(
                      bytes: _bannerBytes,
                      onPick: _saving ? null : _pickBanner,
                      onRemove: _saving
                          ? null
                          : () => setState(() {
                              _bannerBytes = null;
                              _bannerName = null;
                            }),
                    ),
                    const SizedBox(height: 14),
                    ExpertFormSection(
                      icon: Icons.edit_note_rounded,
                      title: 'Event details',
                      children: [
                        const ExpertFieldLabel('Event Title'),
                        AppTextField(
                          controller: _title,
                          hintText: 'e.g. Resume Building Masterclass',
                          maxLength: 120,
                          validator: (v) => _required(v, 'the event title'),
                        ),
                        const SizedBox(height: 6),
                        const ExpertFieldLabel('Organizer Name'),
                        AppTextField(
                          controller: _organizer,
                          hintText: 'Your name or company',
                          maxLength: 80,
                          validator: (v) => _required(v, 'the organizer name'),
                        ),
                        const SizedBox(height: 6),
                        const ExpertFieldLabel('Description'),
                        AppTextField(
                          controller: _description,
                          hintText: 'What is this event about?',
                          maxLines: 5,
                          maxLength: 1000,
                          keyboardType: TextInputType.multiline,
                          validator: (v) => _required(v, 'a description'),
                        ),
                      ],
                    ),
                    ExpertFormSection(
                      icon: Icons.schedule_rounded,
                      title: 'When and where',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: 'Date',
                                value: dateLabel,
                                placeholder: 'Select date',
                                icon: Icons.calendar_month_rounded,
                                error: _showErrors && _date == null
                                    ? 'Pick a date'
                                    : null,
                                onTap: _saving ? null : _pickDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PickerField(
                                label: 'Time',
                                value: timeLabel,
                                placeholder: 'Select time',
                                icon: Icons.access_time_rounded,
                                error: _showErrors && _time == null
                                    ? 'Pick a time'
                                    : (_showErrors && _timeInPast
                                          ? 'Time has passed'
                                          : null),
                                onTap: _saving ? null : _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const ExpertFieldLabel('Location'),
                        AppTextField(
                          controller: _location,
                          hintText: 'Online (Zoom / Meet) or office address',
                          maxLength: 200,
                          prefixIcon: const Icon(Icons.place_outlined),
                          validator: (v) => _required(v, 'the location'),
                        ),
                      ],
                    ),
                    const _FreeEventNote(),
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

/// 16:9 banner area: dashed "Add a banner photo" box, or the chosen photo
/// with Change / Remove.
class _BannerPicker extends StatelessWidget {
  const _BannerPicker({
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? InkWell(
                onTap: onPick,
                child: CustomPaint(
                  painter: _DashedBorder(),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.accentLight,
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.accent,
                            size: 26,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Add a banner photo',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Optional. Wide photos look best.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(image, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        _ImageAction(
                          icon: Icons.photo_library_outlined,
                          label: 'Change',
                          onTap: onPick,
                        ),
                        const SizedBox(width: 8),
                        _ImageAction(
                          icon: Icons.delete_outline_rounded,
                          label: 'Remove',
                          onTap: onRemove,
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

class _ImageAction extends StatelessWidget {
  const _ImageAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandNavy.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(19),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}

/// Date or time chooser that looks like a text field.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.error,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpertFieldLabel(label),
        Semantics(
          button: true,
          label: '$label: ${value ?? placeholder}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: value == null,
              decoration: InputDecoration(
                hintText: placeholder,
                errorText: error,
                prefixIcon: Icon(icon, size: 20),
              ),
              child: Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The website form has no price or seat limit, so events made here are
/// free to join; said plainly so the Expert is not surprised.
class _FreeEventNote extends StatelessWidget {
  const _FreeEventNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verifiedBlueBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verifiedBlueBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your event is listed on the Events page as free to join. '
              'Members register there and get a ticket.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
