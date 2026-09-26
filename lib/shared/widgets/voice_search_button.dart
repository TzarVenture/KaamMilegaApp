import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/theme/app_colors.dart';

/// Microphone button for voice search (speech_to_text).
///
/// Tap to start listening, tap again to stop. The recognised words are
/// passed to [onText] (also while speaking, when [partialResults] is true);
/// [onDone] gets the final words. The microphone permission is asked on
/// first use; if speech recognition is not available a message is shown.
class VoiceSearchButton extends StatefulWidget {
  const VoiceSearchButton({
    super.key,
    required this.onDone,
    this.onText,
    this.color = AppColors.textSecondary,
    this.activeColor = AppColors.brandOrange,
    this.partialResults = true,
  });

  final ValueChanged<String> onDone;
  final ValueChanged<String>? onText;
  final Color color;
  final Color activeColor;
  final bool partialResults;

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _speech.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      setState(() => _listening = false);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() => _listening = false);
    // "No match" / "speech timeout" just mean nothing was heard.
    final nothingHeard =
        error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout';
    _showMessage(
      nothingHeard
          ? 'Didn\'t catch that. Tap the mic and try again.'
          : 'Voice search is not working right now. Please type instead.',
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;
    widget.onText?.call(words);
    if (result.finalResult) widget.onDone(words);
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      if (!_ready) {
        _ready = await _speech.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      }
    } catch (_) {
      _ready = false;
    }
    if (!_ready) {
      _showMessage(
        'Voice search needs microphone permission and speech recognition '
        'on this phone. Please type instead.',
      );
      return;
    }
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.search,
        partialResults: widget.partialResults,
      ),
    );
    if (mounted) setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _listening ? 'Stop voice search' : 'Search by voice',
      onPressed: _toggle,
      icon: Icon(
        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: _listening ? widget.activeColor : widget.color,
      ),
    );
  }
}
