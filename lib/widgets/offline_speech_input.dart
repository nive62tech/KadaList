import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/offline_speech.dart';

enum _SpeechStatus {
  ready('Ready'),
  modelRequired('Model required'),
  preparing('Preparing microphone'),
  importing('Importing model'),
  recording('Recording'),
  processing('Processing on device'),
  error('Speech error'),
  permissionDenied('Microphone permission denied');

  const _SpeechStatus(this.label);
  final String label;
}

class OfflineSpeechInput extends StatefulWidget {
  const OfflineSpeechInput({
    super.key,
    required this.onTranscript,
    this.onActiveChanged,
    this.speech = const OfflineSpeech(),
  });
  final ValueChanged<String> onTranscript;
  final ValueChanged<bool>? onActiveChanged;
  final OfflineSpeech speech;

  @override
  State<OfflineSpeechInput> createState() => _OfflineSpeechInputState();
}

class _OfflineSpeechInputState extends State<OfflineSpeechInput>
    with WidgetsBindingObserver {
  bool _recording = false, _busy = false;
  String _language = 'ml';
  String _message =
      'Import a multilingual Whisper model once, then speak offline. Audio stays in memory. Clips are limited to 20 seconds.';
  Timer? _timer;
  Timer? _clockTimer;
  final _captureWatch = Stopwatch();
  final _inferenceWatch = Stopwatch();
  Map<String, dynamic>? _diagnostics;
  int _generation = 0;
  bool _transcribing = false;
  _SpeechStatus _status = _SpeechStatus.ready;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (_recording || _transcribing)) {
      _generation++;
      _timer?.cancel();
      _clockTimer?.cancel();
      _captureWatch.stop();
      _inferenceWatch.stop();
      unawaited(widget.speech.cancel().catchError((Object _) {}));
      setState(() {
        _recording = false;
        _transcribing = false;
        _status = _SpeechStatus.ready;
        _message = 'Recording discarded when app left the foreground.';
      });
      widget.onActiveChanged?.call(_busy);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    _SpeechStatus status = _SpeechStatus.preparing,
  }) async {
    final generation = _generation;
    setState(() {
      _busy = true;
      _status = status;
    });
    widget.onActiveChanged?.call(true);
    try {
      await action();
    } on PlatformException catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _status = e.code == 'permission'
              ? _SpeechStatus.permissionDenied
              : _SpeechStatus.error;
          _message = e.code == 'permission'
              ? 'Allow microphone access when you try again, or enable it in Android Settings → Apps → KadaList → Permissions. You can also type your list.'
              : e.message ??
                    'Offline speech failed. Try again or type your list.';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _status = _SpeechStatus.error;
          _message = 'Offline speech is available in the Android app.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_status == _SpeechStatus.preparing ||
              _status == _SpeechStatus.importing) {
            _status = _SpeechStatus.ready;
          }
        });
        widget.onActiveChanged?.call(_recording);
      }
    }
  }

  Future<void> _record() => _run(() async {
    if (!await widget.speech.hasModel()) {
      if (mounted) {
        setState(() {
          _status = _SpeechStatus.modelRequired;
          _message =
              'Import a multilingual ggml-tiny, base or small .bin model first. Tap Import model file below and select a local file. English-only .en models are rejected. You can also type your list.';
        });
      }
      return;
    }
    await widget.speech.start(_language);
    if (!mounted) {
      await widget.speech.cancel();
      return;
    }
    setState(() {
      _recording = true;
      _captureWatch.reset();
      _captureWatch.start();
      _inferenceWatch.reset();
      _diagnostics = null;
      _status = _SpeechStatus.recording;
      _message = 'Listening on device… Tap Stop and transcribe when finished.';
    });
    _timer = Timer(const Duration(seconds: 20), _stop);
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  });

  Future<void> _stop() async {
    final generation = _generation;
    _timer?.cancel();
    _captureWatch.stop();
    _inferenceWatch.reset();
    _inferenceWatch.start();
    setState(() {
      _recording = false;
      _transcribing = true;
      _message = 'Transcribing on device… This can take a while.';
    });
    await _run(() async {
      final result = await widget.speech.stop();
      _inferenceWatch.stop();
      _clockTimer?.cancel();
      if (!mounted || generation != _generation) return;
      final text = result.text.trim();
      setState(() {
        _diagnostics = result.diagnostics;
        _status = text.trim().isEmpty
            ? _SpeechStatus.error
            : _SpeechStatus.ready;
        _message = text.trim().isEmpty
            ? 'No speech recognized. Try again or type your list.'
            : 'Check the transcript, especially quantities, before reviewing items.';
      });
      if (text.isNotEmpty) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Review speech transcript'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognition can be wrong. Add only if this matches what you said. You can edit it in Grocery text before reviewing items.',
                  ),
                  if (result.diagnostics['limitReached'] == true)
                    const Text(
                      'The 20-second limit was reached. The end of your list may be missing.',
                    ),
                  const SizedBox(height: 12),
                  SelectableText(text),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add to grocery text'),
              ),
            ],
          ),
        );
        if (mounted && generation == _generation && accepted == true) {
          widget.onTranscript(text);
        }
      }
    }, status: _SpeechStatus.processing);
    _clockTimer?.cancel();
    _inferenceWatch.stop();
    if (mounted) setState(() => _transcribing = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.speech.cancel().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Offline voice input',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        DropdownButton<String>(
          value: _language,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'ml', child: Text('Malayalam')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(
              value: 'auto',
              child: Text('Automatic / mixed (experimental)'),
            ),
          ],
          onChanged: _busy || _recording
              ? null
              : (value) => setState(() => _language = value!),
        ),
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _status.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_message),
              if (_recording || _transcribing || _diagnostics != null)
                Text(
                  'Recording: ${(_captureWatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s; '
                  'processing: ${(_inferenceWatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
                ),
              if (_diagnostics != null)
                ExpansionTile(
                  title: const Text('Speech diagnostics (no audio)'),
                  children: [
                    SelectableText(
                      _diagnostics!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy || _recording
                  ? null
                  : () => _run(() async {
                      final imported = await widget.speech.importModel();
                      if (mounted) {
                        setState(
                          () => _message = imported
                              ? 'Model imported and validated. Try a recording and check the transcript on this device.'
                              : 'Model import cancelled.',
                        );
                      }
                    }, status: _SpeechStatus.importing),
              child: const Text('Import model file'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : (_recording ? _stop : _record),
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? 'Stop and transcribe' : 'Speak offline'),
            ),
          ],
        ),
        if (_busy &&
            (_status == _SpeechStatus.preparing ||
                _status == _SpeechStatus.importing ||
                _status == _SpeechStatus.processing))
          const LinearProgressIndicator(),
      ],
    );
  }
}
