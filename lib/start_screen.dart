import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'audio_settings.dart';
import 'stage.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late final VideoPlayerController _video;
  final AudioPlayer _music = AudioPlayer();
  final AudioSettings _settings = AudioSettings.instance;
  bool _ready = false;
  bool _musicPlaying = false;
  bool _fading = false;
  bool _tapLocked = true;
  int _tapCount = 0;
  Timer? _lockTimer;

  static const _tapLockDuration = Duration(seconds: 3);
  static const _fadeDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset('assets/video/start.mp4');
    _settings.addListener(_applyVolume);
    _lockTimer = Timer(_tapLockDuration, () => _tapLocked = false);
    _initVideo();
    unawaited(_startMusic());
  }

  void _applyVolume() {
    if (_fading) return;
    unawaited(_music.setVolume(_settings.music));
  }

  Future<void> _handleTap() async {
    if (_fading || _tapLocked) {
      return;
    }
    _tapCount++;
    if (_tapCount < 2) {
      return;
    }
    _fading = true;
    setState(() {});
    const steps = 20;
    final startVolume = _settings.music;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_fadeDuration ~/ steps);
      if (!mounted) return;
      unawaited(_music.setVolume(startVolume * (1 - i / steps)));
    }
    if (mounted) widget.onStart();
  }

  // Web は操作前の自動再生が拒否されるため、操作のたびに再試行する。
  Future<void> _startMusic() async {
    if (_musicPlaying) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_settings.music);
      await _music.play(AssetSource('audio/start_bgm.mp3'));
      _musicPlaying = true;
    } catch (_) {
      _musicPlaying = false;
    }
  }

  Future<void> _initVideo() async {
    try {
      await _video.initialize();
      await _video.setLooping(true);
      await _video.setVolume(0);
      await _video.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // 動画を再生できない環境では背景色のまま表示する。
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _settings.removeListener(_applyVolume);
    unawaited(_music.dispose());
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameStage(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: VideoPlayer(_video),
                  ),
                ),
              ),
            // Web では動画の HTML 要素がクリックを奪うため、透明な層で受け取る。
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => unawaited(_startMusic()),
                  onPointerUp: (_) => unawaited(_handleTap()),
                ),
              ),
            ),
            ..._overlays(),
          ],
        ),
      ),
    );
  }

  List<Widget> _overlays() {
    return [
      StageTopRight(
        children: [
          StageButton(
            icon: Icons.tune_rounded,
            label: '音量',
            onPressed: () {
              unawaited(_startMusic());
              showVolumeSheet(context);
            },
          ),
        ],
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _fading ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeIn,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    ];
  }
}
