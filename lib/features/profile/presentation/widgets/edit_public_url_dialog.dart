import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/app_exception.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/repositories/auth_repository.dart';

/// Opens the custom profile URL editor. Returns true when a new URL was
/// saved on the server.
Future<bool?> showEditPublicUrlDialog(
  BuildContext context, {
  required String currentUsername,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => EditPublicUrlDialog(currentUsername: currentUsername),
  );
}

/// Same rules as the backend (`ValidateUsernameFormat`); reserved names are
/// checked by the server.
String? validateUsernameFormat(String value) {
  if (value.length < 3 || value.length > 30) {
    return 'Must be between 3 and 30 characters';
  }
  if (value.contains('--')) {
    return 'Cannot contain two hyphens in a row';
  }
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]{1,28}[a-z0-9])?$').hasMatch(value)) {
    return 'Use lowercase letters, numbers and hyphens only. It cannot start '
        'or end with a hyphen.';
  }
  return null;
}

enum _UrlStatus { invalid, checking, available, unavailable, checkFailed }

/// Edit the public profile link `kaammilega.com/profile/{username}`.
/// Availability is checked live on the server (GET /user/username/check)
/// and saved with PATCH /user/username.
class EditPublicUrlDialog extends ConsumerStatefulWidget {
  const EditPublicUrlDialog({super.key, required this.currentUsername});

  final String currentUsername;

  @override
  ConsumerState<EditPublicUrlDialog> createState() =>
      _EditPublicUrlDialogState();
}

class _EditPublicUrlDialogState extends ConsumerState<EditPublicUrlDialog> {
  static const _displayPrefix = 'kaammilega.com/profile/';
  static const _debounce = Duration(milliseconds: 400);

  late final TextEditingController _controller;
  Timer? _timer;
  int _checkId = 0;
  _UrlStatus _status = _UrlStatus.invalid;
  String _message = '';
  bool _saving = false;
  String? _saveError;

  String get _value => _controller.text.trim().toLowerCase();
  String get _current => widget.currentUsername.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _current);
    _evaluate(immediate: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() => _saveError = null);
    _evaluate();
  }

  /// Local rules first (no request for a name that cannot be valid), then
  /// the server check after a short pause in typing.
  void _evaluate({bool immediate = false}) {
    _timer?.cancel();
    final value = _value;
    final formatError = validateUsernameFormat(value);
    // Any answer still on its way is for an older value.
    _checkId++;
    if (formatError != null) {
      _setStatus(_UrlStatus.invalid, formatError, immediate);
      return;
    }
    if (value == _current) {
      _setStatus(_UrlStatus.available, 'This is your current URL', immediate);
      return;
    }
    _setStatus(_UrlStatus.checking, 'Checking availability...', immediate);
    final id = _checkId;
    _timer = Timer(_debounce, () => _check(value, id));
  }

  void _setStatus(_UrlStatus status, String message, bool immediate) {
    if (immediate) {
      _status = status;
      _message = message;
    } else {
      setState(() {
        _status = status;
        _message = message;
      });
    }
  }

  Future<void> _check(String value, int id) async {
    UsernameAvailability? result;
    String? failure;
    try {
      result = await ref.read(authRepositoryProvider).checkUsername(value);
    } on AppException catch (e) {
      failure = e.message;
    }
    if (!mounted || id != _checkId) return;
    setState(() {
      if (result == null) {
        _status = _UrlStatus.checkFailed;
        _message = failure ?? 'Could not check availability.';
      } else {
        _status = result.available
            ? _UrlStatus.available
            : _UrlStatus.unavailable;
        _message = result.message.isNotEmpty
            ? result.message
            : (result.available ? 'Available' : 'Not available');
      }
    });
  }

  bool get _canSave =>
      !_saving && _status == _UrlStatus.available && _value != _current;

  Future<void> _save() async {
    if (!_canSave) return;
    final value = _value;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final ok = await ref.read(authProvider.notifier).saveUsername(value);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _saveError =
          ref.read(authProvider).error ??
          'Could not save your URL. Please try again.';
    });
    // Someone may have taken it meanwhile: show the server's current answer.
    _evaluate();
  }

  Future<void> _copy() async {
    final url = ApiConstants.publicProfileUrl(_current);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile link copied: $url'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows the full site prefix when there is room, else a short one.
  Widget _buildField(double width) {
    final prefix = width >= 300 ? _displayPrefix : '/profile/';
    return TextField(
      controller: _controller,
      autofocus: true,
      enabled: !_saving,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
        _LowercaseFormatter(),
        LengthLimitingTextInputFormatter(30),
      ],
      onChanged: _onChanged,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        hintText: 'your-name',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 2),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.6),
            child: Text(
              prefix,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final preview = '$_displayPrefix${value.isEmpty ? 'your-name' : value}';
    // Copy only the link that is live now, never an unsaved one.
    final canCopy = _current.isNotEmpty && value == _current;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: _saving ? null : () => Navigator.pop(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'PUBLIC PROFILE LINK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildField(constraints.maxWidth),
                    ),
                    const SizedBox(height: 8),
                    _StatusLine(status: _status, message: _message),
                    if (_saveError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _saveError!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PreviewBox(
                      preview: preview,
                      onCopy: canCopy ? _copy : null,
                    ),
                    const SizedBox(height: 16),
                    const _Guidelines(),
                  ],
                ),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save URL'),
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

class _LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toLowerCase());
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryLightBorder),
            ),
            child: const Icon(Icons.language_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Custom URL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Personalize your public profile link',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.message});

  final _UrlStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Widget icon;
    switch (status) {
      case _UrlStatus.available:
        color = AppColors.success;
        icon = const Icon(Icons.check_circle_outline, size: 18);
        break;
      case _UrlStatus.checking:
        color = AppColors.textSecondary;
        icon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case _UrlStatus.invalid:
      case _UrlStatus.unavailable:
      case _UrlStatus.checkFailed:
        color = AppColors.error;
        icon = const Icon(Icons.error_outline, size: 18);
        break;
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: IconThemeData(color: color),
            child: icon,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.preview, required this.onCopy});

  final String preview;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR PUBLIC URL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _Guidelines extends StatelessWidget {
  const _Guidelines();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Must be between 3 and 30 characters.',
      'Use lowercase letters, numbers, and hyphens only.',
      'Cannot start or end with a hyphen.',
      'Some names, like admin or jobs, are reserved.',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'URL Guidelines:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• $rule',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
