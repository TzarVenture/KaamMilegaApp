import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Navy header of the Expert Portal screens (Create Event, My Courses):
/// back button, an "EXPERT PORTAL" tag, a title with one orange word and a
/// short line, like the website's portal pages.
class ExpertPortalHero extends StatelessWidget {
  const ExpertPortalHero({
    super.key,
    required this.title,
    required this.highlight,
    required this.subtitle,
    this.trailing,
    this.bottom,
  });

  /// "Create New" + [highlight] "Event".
  final String title;
  final String highlight;
  final String subtitle;

  /// Optional action at the top right (for example "Add course").
  final Widget? trailing;

  /// Optional content under the subtitle (for example stats).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavy, AppColors.deepNavy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canPop)
                    Material(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 13,
                      color: AppColors.accentBright,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'EXPERT PORTAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.accentBright,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$title '),
                    TextSpan(
                      text: highlight,
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (bottom != null) ...[const SizedBox(height: 16), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a small icon title, used to group form fields.
class ExpertFormSection extends StatelessWidget {
  const ExpertFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppColors.brandNavy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Field title above an input, with an optional counter on the right
/// ("3/10 words"), red when over the limit.
class ExpertFieldLabel extends StatelessWidget {
  const ExpertFieldLabel(
    this.text, {
    super.key,
    this.counter,
    this.over = false,
    this.optional = false,
  });

  final String text;
  final String? counter;
  final bool over;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (optional)
                    const TextSpan(
                      text: '  (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (counter != null)
            Text(
              counter!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: over ? AppColors.error : AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom bar with the main action, above the keyboard and system bar.
class ExpertSubmitBar extends StatelessWidget {
  const ExpertSubmitBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: child,
        ),
      ),
    );
  }
}

/// Number of words, counted like the website and the server (split on
/// spaces).
int countWords(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
