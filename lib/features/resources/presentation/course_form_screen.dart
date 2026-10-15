import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../experts/presentation/widgets/expert_portal_widgets.dart';
import '../models/course.dart';
import '../providers/my_courses_provider.dart';

/// Publish a new course (YouTube link, title, duration, category,
/// description) or edit one of mine. Same fields and limits as the
/// website's Course Studio; the server checks them again.
class CourseFormScreen extends ConsumerStatefulWidget {
  const CourseFormScreen({super.key, this.course});

  /// The course to edit; null to publish a new one.
  final Course? course;

  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  static const List<String> _durationSuggestions = [
    '15 Min',
    '30 Min',
    '45 Min',
    '1 Hr',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late final TextEditingController _customCategory;
  late String _category;
  bool _showErrors = false;
  bool _saving = false;

  bool get _isEdit => widget.course != null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _url = TextEditingController(text: c?.watchUrl ?? '');
    _title = TextEditingController(text: c?.title ?? '');
    _duration = TextEditingController(text: c?.duration ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    final existing = c?.category ?? '';
    if (c == null) {
      _category = kCourseCategories.first;
      _customCategory = TextEditingController();
    } else if (kCourseCategories.contains(existing) && existing != 'Others') {
      _category = existing;
      _customCategory = TextEditingController();
    } else {
      _category = 'Others';
      _customCategory = TextEditingController(
        text: existing == 'Others' ? '' : existing,
      );
    }
    for (final field in [_url, _title, _duration, _description]) {
      field.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    for (final field in [
      _url,
      _title,
      _duration,
      _description,
      _customCategory,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  String? get _videoId => _isEdit
      ? (widget.course!.youtubeVideoId.isNotEmpty
            ? widget.course!.youtubeVideoId
            : Course.extractVideoId(widget.course!.watchUrl))
      : Course.extractVideoId(_url.text);

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _url.text = text;
  }

  String _finalCategory() {
    if (_category != 'Others') return _category;
    final custom = _customCategory.text.trim();
    // Website: an empty custom category is "General" for a new course and
    // "Others" when editing.
    return custom.isNotEmpty ? custom : (_isEdit ? 'Others' : 'General');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final draft = CourseDraft(
      title: _title.text,
      duration: _duration.text,
      category: _finalCategory(),
      description: _description.text,
      youtubeUrl: _isEdit ? '' : _url.text,
    );
    setState(() => _saving = true);
    final notifier = ref.read(myCoursesProvider.notifier);
    final error = _isEdit
        ? await notifier.edit(widget.course!, draft)
        : await notifier.publish(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isEdit ? 'Course updated.' : 'Course published to Resources.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the list alive while this screen is open.
    ref.watch(myCoursesProvider.select((s) => s.total));

    final titleWords = countWords(_title.text);
    final descWords = countWords(_description.text);
    final videoId = _videoId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: ExpertSubmitBar(
          child: AppButton(
            text: _isEdit ? 'Save Changes' : 'Publish Course',
            icon: _isEdit ? Icons.check_rounded : Icons.publish_rounded,
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
              SliverToBoxAdapter(
                child: ExpertPortalHero(
                  title: _isEdit ? 'Edit' : 'Add a New',
                  highlight: 'Course',
                  subtitle: _isEdit
                      ? 'Update the title, duration, category or '
                            'description.'
                      : 'Share a YouTube training video with everyone on '
                            'KaamMilega.',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList.list(
                  children: [
                    ExpertFormSection(
                      icon: Icons.smart_display_outlined,
                      title: 'YouTube video',
                      children: [
                        if (!_isEdit) ...[
                          const ExpertFieldLabel('Video link'),
                          AppTextField(
                            controller: _url,
                            hintText: 'https://www.youtube.com/watch?v=...',
                            keyboardType: TextInputType.url,
                            prefixIcon: const Icon(Icons.link_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Paste link',
                              onPressed: _saving ? null : _paste,
                              icon: const Icon(Icons.content_paste_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please paste the YouTube video link';
                              }
                              if (Course.extractVideoId(v) == null) {
                                return 'This is not a YouTube video link';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        _VideoPreview(
                          videoId: videoId,
                          hasText: _url.text.trim().isNotEmpty,
                        ),
                        if (_isEdit)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'The video cannot be changed. To use another '
                              'video, delete this course and add a new one.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    ExpertFormSection(
                      icon: Icons.edit_note_rounded,
                      title: 'Course details',
                      children: [
                        ExpertFieldLabel(
                          'Course title',
                          counter:
                              '$titleWords/${CourseDraft.maxTitleWords} words',
                          over: titleWords > CourseDraft.maxTitleWords,
                        ),
                        AppTextField(
                          controller: _title,
                          hintText: 'e.g. Basics of House Wiring',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a course title';
                            }
                            if (countWords(v) > CourseDraft.maxTitleWords) {
                              return 'Use 10 words or fewer';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        const ExpertFieldLabel('Video duration'),
                        AppTextField(
                          controller: _duration,
                          hintText: 'e.g. 45 Min or 1 Hr 20 Min',
                          maxLength: 30,
                          prefixIcon: const Icon(Icons.schedule_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter the video duration'
                              : null,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in _durationSuggestions)
                              _QuickChip(
                                label: d,
                                selected: _duration.text.trim() == d,
                                onTap: () => _duration.text = d,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const ExpertFieldLabel('Category'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cat in kCourseCategories)
                              _QuickChip(
                                label: cat,
                                selected: _category == cat,
                                onTap: () => setState(() => _category = cat),
                              ),
                          ],
                        ),
                        if (_category == 'Others') ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _customCategory,
                            hintText:
                                'Your category, e.g. Solar Panel Technician',
                            maxLength: 40,
                          ),
                        ],
                        const SizedBox(height: 14),
                        ExpertFieldLabel(
                          'Description',
                          optional: true,
                          counter:
                              '$descWords/${CourseDraft.maxDescriptionWords} '
                              'words',
                          over: descWords > CourseDraft.maxDescriptionWords,
                        ),
                        AppTextField(
                          controller: _description,
                          hintText: 'What will people learn from this video?',
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          validator: (v) =>
                              countWords(v ?? '') >
                                  CourseDraft.maxDescriptionWords
                              ? 'Use 50 words or fewer'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
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

/// YouTube thumbnail once a valid link is found, or a hint.
class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.videoId, required this.hasText});

  final String? videoId;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    final id = videoId;
    if (id == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(
              hasText ? Icons.link_off_rounded : Icons.smart_display_outlined,
              color: hasText ? AppColors.warning : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasText
                    ? 'We could not find a YouTube video in this link.'
                    : 'Paste a YouTube video or Shorts link to see a preview.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.brandNavy,
              child: Image.network(
                'https://img.youtube.com/vi/$id/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.ondemand_video_rounded,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const ColoredBox(color: Color(0x1F000000)),
            Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: AppColors.brandNavy,
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Video found',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small selectable pill (duration suggestions, categories).
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.brandNavy : AppColors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.brandNavy : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
