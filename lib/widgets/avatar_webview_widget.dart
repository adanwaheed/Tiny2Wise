import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AvatarWebViewWidget extends StatefulWidget {
  const AvatarWebViewWidget({
    super.key,
    this.initialMessage = 'السلام علیکم، میں نور ہوں۔',
  });

  final String initialMessage;

  @override
  State<AvatarWebViewWidget> createState() => AvatarWebViewWidgetState();
}

class AvatarWebViewWidgetState extends State<AvatarWebViewWidget> {
  late final WebViewController _controller;
  final FlutterTts _tts = FlutterTts();

  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    _setupTts();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _pageReady = true;
            await playHappy();
          },
        ),
      )
      ..loadHtmlString(_avatarHtml);
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('ur-PK');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.18);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _runJs('window.tinyAvatarStop();');
    });
    _tts.setCancelHandler(() {
      _runJs('window.tinyAvatarStop();');
    });
    _tts.setErrorHandler((_) {
      _runJs('window.tinyAvatarStop();');
    });
  }

  bool _containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  int _estimateSpeechMs(String text, String lang) {
    final clean = text.trim();
    final base = lang.startsWith('ur') ? 95 : 72;
    final value = clean.length * base;
    if (value < 1600) return 1600;
    if (value > 11000) return 11000;
    return value;
  }

  Future<void> speak(
      String text, {
        String? languageCode,
        String action = 'talk',
        String emotion = 'friendly',
      }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final lang = languageCode ?? (_containsUrdu(cleanText) ? 'ur-PK' : 'en-US');
    final durationMs = _estimateSpeechMs(cleanText, lang);

    await stopSpeaking();

    final payload = jsonEncode({
      'text': cleanText,
      'lang': lang,
      'action': action,
      'emotion': emotion,
      'durationMs': durationMs,
    });

    await _runJs('window.tinyAvatarSpeak($payload);');

    try {
      await _tts.setLanguage(lang.startsWith('ur') ? 'ur-PK' : 'en-US');
      await _tts.setSpeechRate(lang.startsWith('ur') ? 0.43 : 0.48);
      await _tts.setPitch(1.18);
      await _tts.setVolume(1.0);
      await _tts.speak(cleanText);
    } catch (_) {
      // The top bubble still shows the answer even if a device has no Urdu/English TTS voice.
    }
  }

  Future<void> playListening() async {
    await _tts.stop();
    await _runJs('window.tinyAvatarListening();');
  }

  Future<void> playThinking() async {
    await _runJs('window.tinyAvatarThinking();');
  }

  Future<void> playHappy() async {
    await _runJs('window.tinyAvatarHappy();');
  }

  Future<void> playGentle() async {
    await _runJs('window.tinyAvatarGentle();');
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _runJs('window.tinyAvatarStop();');
  }

  Future<void> _runJs(String script) async {
    if (!_pageReady) return;
    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      // Ignore lifecycle timing issues.
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: WebViewWidget(controller: _controller),
    );
  }
}

const String _avatarHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
  <title>Tiny2Wise Noor Avatar</title>
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: transparent;
      -webkit-user-select: none;
      user-select: none;
      touch-action: manipulation;
    }
    #stage {
      width: 100vw;
      height: 100vh;
      background: radial-gradient(circle at 50% 42%, rgba(255,255,255,.95), rgba(255,228,130,.35) 48%, rgba(255,255,255,0) 76%);
    }
  </style>
</head>
<body>
  <div id="stage"></div>

  <script type="module">
    import * as THREE from 'https://unpkg.com/three@0.164.1/build/three.module.js';

    const stage = document.getElementById('stage');

    let renderer, scene, camera;
    let avatar, head, mouth, eyesGroup, leftArm, rightArm, leftHand, rightHand;
    let mode = 'idle';
    let mouthTarget = 0;
    let mouthCurrent = 0;
    let speakingTimer = null;
    const clock = new THREE.Clock();

    function makeMat(color, roughness = 0.7, metalness = 0.02) {
      return new THREE.MeshStandardMaterial({ color, roughness, metalness });
    }

    function addSphere(parent, name, radius, color, position, scale = [1, 1, 1]) {
      const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, 56, 36), makeMat(color));
      mesh.name = name;
      mesh.position.set(position[0], position[1], position[2]);
      mesh.scale.set(scale[0], scale[1], scale[2]);
      parent.add(mesh);
      return mesh;
    }

    function addCylinder(parent, name, radiusTop, radiusBottom, height, color, position, rotation = [0,0,0]) {
      const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radiusTop, radiusBottom, height, 44), makeMat(color));
      mesh.name = name;
      mesh.position.set(position[0], position[1], position[2]);
      mesh.rotation.set(rotation[0], rotation[1], rotation[2]);
      parent.add(mesh);
      return mesh;
    }

    function addBox(parent, name, size, color, position, rotation = [0,0,0]) {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), makeMat(color));
      mesh.name = name;
      mesh.position.set(position[0], position[1], position[2]);
      mesh.rotation.set(rotation[0], rotation[1], rotation[2]);
      parent.add(mesh);
      return mesh;
    }

    function createSparkles() {
      const sparkleMat = makeMat(0xffffff, 0.35, 0.0);
      for (let i = 0; i < 18; i++) {
        const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.018 + Math.random() * 0.018), sparkleMat);
        star.position.set((Math.random() - 0.5) * 2.2, -0.8 + Math.random() * 2.1, -0.25 + Math.random() * 0.5);
        star.userData.speed = 0.55 + Math.random() * 0.8;
        star.userData.phase = Math.random() * Math.PI * 2;
        scene.add(star);
      }
    }

    function createAvatar() {
      avatar = new THREE.Group();
      avatar.position.y = -0.62;
      scene.add(avatar);

      // Body: friendly teacher style, rounded and child-safe.
      addCylinder(avatar, 'teacherDress', 0.43, 0.56, 0.95, 0x8f57d7, [0, -0.12, 0]);
      addSphere(avatar, 'softShirtGlow', 0.36, 0xb98cff, [0, 0.1, 0.03], [1.25, 0.55, 0.26]);
      addSphere(avatar, 'collar', 0.22, 0xffffff, [0, 0.36, 0.05], [1.45, 0.36, 0.22]);
      addCylinder(avatar, 'neck', 0.11, 0.12, 0.22, 0xf5bd8e, [0, 0.5, 0]);

      head = new THREE.Group();
      head.position.set(0, 0.88, 0);
      avatar.add(head);

      addSphere(head, 'face', 0.43, 0xf5bd8e, [0, 0, 0], [0.93, 1.06, 0.88]);

      // Soft hair style.
      addSphere(head, 'hairCap', 0.45, 0x2b1d16, [0, 0.17, -0.045], [1.0, 0.62, 0.95]);
      addSphere(head, 'leftHair', 0.19, 0x2b1d16, [-0.34, -0.04, 0.02], [0.72, 1.2, 0.74]);
      addSphere(head, 'rightHair', 0.19, 0x2b1d16, [0.34, -0.04, 0.02], [0.72, 1.2, 0.74]);
      addBox(head, 'frontFringe', [0.55, 0.12, 0.1], 0x2b1d16, [0, 0.24, 0.31], [0, 0, 0.02]);

      eyesGroup = new THREE.Group();
      head.add(eyesGroup);
      addSphere(eyesGroup, 'leftEyeWhite', 0.055, 0xffffff, [-0.14, 0.05, 0.36], [1.2, 0.84, 0.42]);
      addSphere(eyesGroup, 'rightEyeWhite', 0.055, 0xffffff, [0.14, 0.05, 0.36], [1.2, 0.84, 0.42]);
      addSphere(eyesGroup, 'leftPupil', 0.025, 0x21142a, [-0.14, 0.045, 0.398], [1, 1, 0.36]);
      addSphere(eyesGroup, 'rightPupil', 0.025, 0x21142a, [0.14, 0.045, 0.398], [1, 1, 0.36]);

      addSphere(head, 'cheekLeft', 0.05, 0xf1a7a7, [-0.24, -0.11, 0.365], [1.55, 0.7, 0.25]);
      addSphere(head, 'cheekRight', 0.05, 0xf1a7a7, [0.24, -0.11, 0.365], [1.55, 0.7, 0.25]);
      addSphere(head, 'nose', 0.035, 0xe89c78, [0, -0.02, 0.405], [0.85, 0.7, 0.58]);
      mouth = addSphere(head, 'mouth', 0.052, 0xc94864, [0, -0.18, 0.392], [1.85, 0.24, 0.34]);

      leftArm = addCylinder(avatar, 'leftArm', 0.055, 0.07, 0.72, 0xf5bd8e, [-0.54, 0.05, 0], [0, 0, -0.42]);
      rightArm = addCylinder(avatar, 'rightArm', 0.055, 0.07, 0.72, 0xf5bd8e, [0.54, 0.05, 0], [0, 0, 0.42]);
      leftHand = addSphere(avatar, 'leftHand', 0.085, 0xf5bd8e, [-0.72, -0.22, 0.02]);
      rightHand = addSphere(avatar, 'rightHand', 0.085, 0xf5bd8e, [0.72, -0.22, 0.02]);

      addCylinder(avatar, 'leftLeg', 0.07, 0.075, 0.48, 0x3a3a60, [-0.18, -0.88, 0]);
      addCylinder(avatar, 'rightLeg', 0.07, 0.075, 0.48, 0x3a3a60, [0.18, -0.88, 0]);
      addSphere(avatar, 'leftShoe', 0.11, 0x30303b, [-0.18, -1.13, 0.08], [1.35, 0.46, 0.85]);
      addSphere(avatar, 'rightShoe', 0.11, 0x30303b, [0.18, -1.13, 0.08], [1.35, 0.46, 0.85]);
    }

    function initScene() {
      scene = new THREE.Scene();
      camera = new THREE.PerspectiveCamera(33, window.innerWidth / window.innerHeight, 0.1, 100);
      camera.position.set(0, 0.18, 4.05);
      camera.lookAt(0, 0.08, 0);

      renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
      renderer.setSize(window.innerWidth, window.innerHeight);
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      stage.appendChild(renderer.domElement);

      scene.add(new THREE.HemisphereLight(0xffffff, 0xffd9a6, 2.35));
      const key = new THREE.DirectionalLight(0xffffff, 2.0);
      key.position.set(2.2, 4.5, 3.6);
      scene.add(key);
      const fill = new THREE.DirectionalLight(0xbca7ff, 0.95);
      fill.position.set(-2.4, 2.1, 2.4);
      scene.add(fill);

      createSparkles();
      createAvatar();
      window.addEventListener('resize', onResize);
      window.addEventListener('click', () => window.tinyAvatarHappy());
      animate();
    }

    function onResize() {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    }

    function setMode(nextMode) {
      mode = nextMode || 'idle';
    }

    function stopMouthTimer(goIdle = true) {
      if (speakingTimer) {
        clearInterval(speakingTimer);
        speakingTimer = null;
      }
      mouthTarget = 0;
      if (goIdle) setMode('idle');
    }

    function startMouthTimer(durationMs) {
      stopMouthTimer(false);
      const start = Date.now();
      speakingTimer = setInterval(() => {
        const elapsed = Date.now() - start;
        if (elapsed > durationMs) {
          stopMouthTimer(true);
          return;
        }
        const fast = Math.sin(elapsed / 54) * 0.5 + 0.5;
        const slow = Math.sin(elapsed / 160) * 0.5 + 0.5;
        mouthTarget = 0.08 + (fast * 0.6 + slow * 0.22);
      }, 34);
    }

    window.tinyAvatarSpeak = function(payload) {
      const durationMs = payload && payload.durationMs ? Number(payload.durationMs) : 2600;
      const action = payload && payload.action ? String(payload.action) : 'talk';
      setMode(action === 'celebrate' ? 'happy' : action === 'gentle' ? 'gentle' : action === 'explain' ? 'explain' : 'talking');
      startMouthTimer(durationMs);
    };

    window.tinyAvatarListening = function() {
      stopMouthTimer(false);
      setMode('listening');
    };

    window.tinyAvatarThinking = function() {
      stopMouthTimer(false);
      setMode('thinking');
    };

    window.tinyAvatarHappy = function() {
      stopMouthTimer(false);
      setMode('happy');
      setTimeout(() => setMode('idle'), 1200);
    };

    window.tinyAvatarGentle = function() {
      stopMouthTimer(false);
      setMode('gentle');
    };

    window.tinyAvatarStop = function() {
      stopMouthTimer(true);
    };

    function animate() {
      requestAnimationFrame(animate);
      const t = clock.getElapsedTime();

      mouthCurrent += (mouthTarget - mouthCurrent) * 0.32;
      if (mouth) {
        mouth.scale.y = 0.24 + mouthCurrent * 1.35;
        mouth.scale.x = 1.85 - mouthCurrent * 0.28;
      }

      if (avatar) {
        avatar.rotation.y = Math.sin(t * 0.55) * 0.035;
        avatar.position.y = -0.62 + Math.sin(t * 1.15) * 0.013;
      }

      if (head) {
        const talkNod = mode === 'talking' || mode === 'explain' ? Math.sin(t * 4.2) * 0.055 : 0;
        const listenTilt = mode === 'listening' ? Math.sin(t * 2.8) * 0.08 : 0;
        const happyTilt = mode === 'happy' ? Math.sin(t * 6.5) * 0.07 : 0;
        head.rotation.x = talkNod;
        head.rotation.z = listenTilt + happyTilt;
      }

      if (eyesGroup) {
        const blink = Math.sin(t * 2.1) > 0.985 ? 0.18 : 1;
        eyesGroup.scale.y += (blink - eyesGroup.scale.y) * 0.42;
      }

      if (leftArm && rightArm) {
        const baseWave = mode === 'happy' ? 0.55 : mode === 'listening' ? 0.22 : mode === 'explain' ? 0.35 : 0.08;
        leftArm.rotation.z = -0.42 - Math.sin(t * 3.2) * baseWave * 0.28;
        rightArm.rotation.z = 0.42 + Math.sin(t * 3.0) * baseWave * 0.42;
      }

      if (leftHand && rightHand) {
        const lift = mode === 'happy' ? 0.09 : mode === 'listening' ? 0.04 : 0.0;
        leftHand.position.y = -0.22 + Math.sin(t * 3.2) * lift;
        rightHand.position.y = -0.22 + Math.cos(t * 3.3) * lift;
      }

      if (mode === 'thinking' && avatar) {
        avatar.rotation.z = Math.sin(t * 3.1) * 0.018;
      } else if (avatar) {
        avatar.rotation.z *= 0.9;
      }

      for (const obj of scene.children) {
        if (obj.geometry && obj.geometry.type === 'OctahedronGeometry') {
          obj.rotation.y += 0.01;
          obj.position.y += Math.sin(t * obj.userData.speed + obj.userData.phase) * 0.0008;
        }
      }

      renderer.render(scene, camera);
    }

    initScene();
  </script>
</body>
</html>
''';
