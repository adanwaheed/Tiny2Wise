import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class AvatarWebViewWidget extends StatefulWidget {
  const AvatarWebViewWidget({
    super.key,
    this.initialMessage = 'السلام علیکم، میں شیرو ہوں',
  });

  final String initialMessage;

  @override
  State<AvatarWebViewWidget> createState() => AvatarWebViewWidgetState();
}

class AvatarWebViewWidgetState extends State<AvatarWebViewWidget> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _setupChildLikeTts();
  }

  Future<void> _setupChildLikeTts() async {
    await _flutterTts.setLanguage('ur-PK');

    // Higher pitch makes voice slightly more child-like.
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.45);
    await _flutterTts.setVolume(1.0);

    await _selectBestAvailableVoice();
  }

  Future<void> _selectBestAvailableVoice() async {
    try {
      final voices = await _flutterTts.getVoices;

      if (voices is! List) return;

      Map<String, String>? selectedVoice;

      for (final voice in voices) {
        if (voice is Map) {
          final name = (voice['name'] ?? '').toString().toLowerCase();
          final locale = (voice['locale'] ?? '').toString().toLowerCase();

          final originalName = (voice['name'] ?? '').toString();
          final originalLocale = (voice['locale'] ?? '').toString();

          if (originalName.isEmpty || originalLocale.isEmpty) continue;

          if (locale.contains('ur')) {
            selectedVoice = {
              'name': originalName,
              'locale': originalLocale,
            };
            break;
          }

          if (name.contains('female') ||
              name.contains('girl') ||
              name.contains('child')) {
            selectedVoice = {
              'name': originalName,
              'locale': originalLocale,
            };
          }
        }
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
      }
    } catch (_) {
      // Pitch/rate still work even if voice selection is unavailable.
    }
  }

  bool _containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    await _flutterTts.stop();

    final isUrdu = _containsUrdu(cleanText);

    await _flutterTts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');
    await _flutterTts.setSpeechRate(isUrdu ? 0.45 : 0.48);
    await _flutterTts.setPitch(1.45);
    await _flutterTts.setVolume(1.0);

    try {
      if (isUrdu) {
        await _selectBestAvailableVoice();
      }
      await _flutterTts.speak(cleanText);
    } catch (_) {
      // If TTS voice is unavailable, the top bubble still shows the reply.
    }
  }

  Future<void> playListening() async {
    await _flutterTts.stop();
  }

  Future<void> playHappy() async {
    // Fox stays still.
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ModelViewer(
      src: 'assets/avatar/fox.glb',
      alt: 'Tiny2Wise Fox Avatar',

      // Keep model still
      autoRotate: false,
      cameraControls: false,
      disableZoom: true,
      animationName: '',

      backgroundColor: Colors.transparent,
      ar: false,

      // Front-facing camera. Change 0deg to 90/180/270 if your model faces wrong.
      cameraOrbit: '0deg 80deg 4.4m',
      cameraTarget: '0m 0.8m 0m',
      fieldOfView: '30deg',

      exposure: 1.15,
      shadowIntensity: 0,
    );
  }
}