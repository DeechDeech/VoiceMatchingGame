import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_settings.dart';
import 'chroma_key_gif.dart';
import 'game_over_messages.dart';
import 'game_session.dart';
import 'stage.dart';
import 'start_screen.dart';
import 'voice_clip.dart';

const _ink = Color(0xFF193C3A);
const _teal = Color(0xFF2E7770);
const _coral = Color(0xFFE98266);
const _paper = Color(0xFFF6F2E9);
const _cardAspectRatio = 1 / 1.4;
const _cardBackAsset = 'assets/images/card_back.png';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const VoiceMatchingGameApp());
}

class VoiceMatchingGameApp extends StatelessWidget {
  const VoiceMatchingGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ボイス神経衰弱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _teal),
        fontFamily: 'sans-serif',
      ),
      home: Builder(
        builder: (context) => StartScreen(
          onStart: () => Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 700),
              pageBuilder: (_, _, _) => const GameScreen(),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  late GameSession _session;
  bool _audioReady = false;
  bool _musicStarted = false;
  bool _musicFadingIn = false;
  static const _musicFadeDuration = Duration(seconds: 2);
  int? _playingCardId;
  int _voiceToken = 0;
  bool _showingResult = false;
  final Stopwatch _clearTimer = Stopwatch();
  String? _audioError;
  final AudioSettings _settings = AudioSettings.instance;
  final MessageDeck _messageDeck = MessageDeck();
  static const _effectVolume = 0.65;
  double get _musicVolume => _settings.music;
  double get _voiceVolume => _settings.voice;

  @override
  void initState() {
    super.initState();
    _session = GameSession.newGame();
    _clearTimer.start();
    _settings.addListener(_applyVolumes);
    unawaited(_prepareAudio());
  }

  void _applyVolumes() {
    if (!_musicFadingIn) unawaited(_setMusicVolume(_musicVolume));
    unawaited(_setVoiceVolume(_voiceVolume));
  }

  Future<void> _prepareAudio() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0);
      await _effectPlayer.setVolume(_effectVolume);
      await _voicePlayer.setVolume(_voiceVolume);
      if (mounted) setState(() => _audioReady = true);
      unawaited(_startMusic());
    } catch (error) {
      _reportAudioError('音声を初期化できませんでした: $error');
    }
  }

  Future<void> _startMusic() async {
    if (_musicStarted || !_audioReady) return;
    _musicStarted = true;
    try {
      await _musicPlayer.setVolume(0);
      await _musicPlayer.play(AssetSource('audio/bgm.mp3'));
      await _fadeInMusic();
    } catch (error) {
      _musicStarted = false;
      _reportAudioError('BGMを再生できませんでした: $error');
    }
  }

  // 目標音量は設定の変更に追従させながら、2秒かけて上げる。
  Future<void> _fadeInMusic() async {
    _musicFadingIn = true;
    const steps = 20;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(_musicFadeDuration ~/ steps);
      if (!mounted) return;
      await _musicPlayer.setVolume(_musicVolume * i / steps);
    }
    _musicFadingIn = false;
  }

  Future<void> _playFlipEffect() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('audio/flip.wav'));
    } catch (error) {
      _reportAudioError('効果音を再生できませんでした: $error');
    }
  }

  Future<void> _setMusicVolume(double volume) async {
    try {
      await _musicPlayer.setVolume(volume);
    } catch (error) {
      _reportAudioError('BGMの音量を変更できませんでした: $error');
    }
  }

  Future<void> _setVoiceVolume(double volume) async {
    try {
      await _voicePlayer.setVolume(volume);
    } catch (error) {
      _reportAudioError('ボイスの音量を変更できませんでした: $error');
    }
  }

  Future<void> _playVoice(VoiceClip clip) async {
    final finished = _voicePlayer.onPlayerComplete.first;
    await _voicePlayer.play(AssetSource(clip.assetPath));
    // 完了通知が届かない環境でも進行が止まらないよう、再生時間で打ち切る。
    await Future.any([
      finished,
      Future<void>.delayed(clip.duration + const Duration(seconds: 1)),
    ]);
  }

  Future<void> _flipCard(VoiceCard card) async {
    final session = _session;
    if (_showingResult || !session.canSelect(card.id) || !_audioReady) return;

    // 新しい札のタップを優先し、再生中の音声を止めてから札を処理する。
    final token = ++_voiceToken;
    if (_playingCardId != null) {
      setState(() => _playingCardId = null);
    }
    try {
      await _voicePlayer.stop();
    } catch (error) {
      _reportAudioError('再生中の音声を停止できませんでした: $error');
      return;
    }
    if (!mounted || token != _voiceToken || session != _session) return;
    if (_showingResult || !session.canSelect(card.id)) return;

    setState(() {
      // 外れた2枚が表示されたままなら、先に閉じる。
      if (session.hasTwoRevealed) session.hideUnmatched();
      session.reveal(card.id);
      _playingCardId = card.id;
      _audioError = null;
    });
    unawaited(_startMusic());
    unawaited(_playFlipEffect());

    var matched = false;
    final turnEnded = session.hasTwoRevealed;
    if (turnEnded) {
      matched = session.resolveTurn();
      setState(() {});
    }

    try {
      await _playVoice(card.clip);
    } catch (error) {
      _reportAudioError('音声を再生できませんでした: $error');
    }

    bool stale() => !mounted || token != _voiceToken || session != _session;
    if (stale()) return;
    setState(() => _playingCardId = null);
    if (!turnEnded) return;

    if (!matched) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (stale()) return;
      setState(session.hideUnmatched);
      if (session.isGameOver) await _showGameResult();
    } else if (session.isComplete) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!stale()) await _showGameResult();
    }
  }

  Future<void> _showGameResult() async {
    if (_showingResult || !mounted) return;
    _showingResult = true;
    final cleared = _session.isComplete;
    if (cleared) _clearTimer.stop();
    final clearTime = _formatTime(_clearTimer.elapsed);
    final message = cleared ? null : _messageDeck.next();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _paper,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        icon: null,
        title: null,
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 520),
          child: cleared
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'おめでとうございます！\nおつゆるでした～',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'クリアタイム  $clearTime',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ChromaKeyGif(
                      asset: 'assets/images/clear.gif',
                      height: 240,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message ?? 'ライフがなくなりました…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Image.asset(
                        'assets/images/gameover.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (cleared) {
                _clearTimer
                  ..reset()
                  ..start();
              }
              _newGame();
            },
            icon: const Icon(Icons.replay_rounded, size: 28),
            label: Text(cleared ? 'もう一度遊ぶ' : 'リトライ'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    _showingResult = false;
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final cs = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  void _newGame() {
    _voiceToken++;
    unawaited(_voicePlayer.stop());
    setState(() {
      _session = GameSession.newGame();
      _playingCardId = null;
      _audioError = null;
    });
    unawaited(_startMusic());
  }

  void _reportAudioError(String message) {
    if (!mounted) return;
    setState(() => _audioError = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _showSettings() => showVolumeSheet(context);

  @override
  void dispose() {
    _settings.removeListener(_applyVolumes);
    unawaited(_musicPlayer.dispose());
    unawaited(_effectPlayer.dispose());
    unawaited(_voicePlayer.dispose());
    super.dispose();
  }

  static const _gridColumns = 6;
  static const _gridRows = 3;
  static const _tileWidth = 114.0;
  static const _gridSpacingX = 56.0;
  static const _gridSpacingY = 24.0;
  static const _gridWidth =
      _tileWidth * _gridColumns + _gridSpacingX * (_gridColumns - 1);
  static const _gridHeight =
      _tileWidth / _cardAspectRatio * _gridRows +
      _gridSpacingY * (_gridRows - 1);
  static const _gridLeft = 26.0;
  static const _gridTop = 98.0;
  Widget _buildCardGrid() {
    final count = _session.cards.length;
    return SizedBox(
      width: _gridWidth,
      height: _gridHeight,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: _gridSpacingX,
          mainAxisSpacing: _gridSpacingY,
          childAspectRatio: _cardAspectRatio,
        ),
        itemBuilder: (context, index) {
          final card = _session.cards[index];
          final isMatched = _session.isMatched(card.id);
          return _VoiceCardTile(
            key: ValueKey(card.id),
            cardNumber: index + 1,
            revealed: isMatched || _session.isRevealed(card.id),
            matched: isMatched,
            playing: _playingCardId == card.id,
            voiceDuration: card.clip.duration,
            enabled:
                !_showingResult && _session.canSelect(card.id) && _audioReady,
            onTap: () => _flipCard(card),
          );
        },
      ),
    );
  }

  Widget _buildLives() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ライフ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
        ),
        const SizedBox(width: 20),
        for (var i = 0; i < GameSession.maxLives; i++)
          SizedBox(
            width: 48,
            child: Opacity(
              opacity: i < _session.lives ? 1 : 0.25,
              child: Image.asset('assets/images/whisky.png', height: 62),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = _playingCardId != null
        ? '声を聴いてね…'
        : _audioReady
        ? 'カードをタップして音声を再生'
        : '音声を準備中…';
    return Scaffold(
      body: GameStage(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 28,
                child: Stack(
                  children: [
                    Text(
                      'ボイス神経衰弱',
                      style: TextStyle(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'ボイス神経衰弱',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 88,
                child: Image.asset(
                  'assets/images/board.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                left: 830,
                top: 602,
                width: 118 * 1.1 * 811 / 447,
                height: 118 * 1.1,
                child: Image.asset(
                  'assets/images/nameplate.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                right: 4,
                bottom: 8,
                height: 470,
                child: Image.asset('assets/images/person.png'),
              ),
              StageTopRight(
                children: [
                  StageButton(
                    icon: Icons.refresh_rounded,
                    label: 'リセット',
                    onPressed: _newGame,
                  ),
                  StageButton(
                    icon: Icons.tune_rounded,
                    label: '音量',
                    onPressed: _showSettings,
                  ),
                ],
              ),
              Positioned(
                left: _gridLeft,
                top: _gridTop,
                child: _buildCardGrid(),
              ),
              Positioned(left: 24, bottom: 12, child: _buildLives()),
              Positioned(
                left: 420,
                right: 420,
                top: 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '声を聴いて、同じ音声のカードを見つけよう',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hint,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: _playingCardId != null
                                ? FontWeight.w800
                                : FontWeight.w600,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black87),
                            ],
                          ),
                        ),
                        if (_audioError != null) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: _coral,
                            size: 30,
                          ),
                        ],
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

class _VoiceCardTile extends StatefulWidget {
  const _VoiceCardTile({
    super.key,
    required this.cardNumber,
    required this.revealed,
    required this.matched,
    required this.playing,
    required this.voiceDuration,
    required this.enabled,
    required this.onTap,
  });

  final int cardNumber;
  final bool revealed;
  final bool matched;
  final bool playing;
  final Duration voiceDuration;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_VoiceCardTile> createState() => _VoiceCardTileState();
}

class _VoiceCardTileState extends State<_VoiceCardTile>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.revealed ? 1 : 0,
  );
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.voiceDuration,
    value: widget.revealed && !widget.playing ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    _flip.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _progress.value = 0;
    });
    if (widget.playing) _startProgress();
  }

  void _startProgress() {
    _progress.duration = widget.voiceDuration;
    _progress.forward(from: 0);
  }

  @override
  void didUpdateWidget(_VoiceCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed != oldWidget.revealed) {
      widget.revealed ? _flip.forward() : _flip.reverse();
    }
    if (widget.playing && !oldWidget.playing) {
      _startProgress();
    } else if (!widget.playing && oldWidget.playing && widget.revealed) {
      _progress.animateTo(1, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '音声カード ${widget.cardNumber}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final showFront = _flip.value >= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _buildFront(),
                    )
                  : _buildBack(),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _decoration(Color color, {Color? border}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(12),
    border: border == null ? null : Border.all(color: border, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: _ink.withValues(alpha: 0.14),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // 背面画像は assets/images/card_back.png を差し替えるだけで変更できる。
  Widget _buildBack() {
    return DecoratedBox(
      decoration: _decoration(_teal),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          _cardBackAsset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.graphic_eq_rounded, color: _paper),
          ),
        ),
      ),
    );
  }

  Widget _buildFront() {
    final matched = widget.matched;
    return DecoratedBox(
      decoration: _decoration(
        matched ? const Color(0xFFDCEAE1) : const Color(0xFFFFFCF5),
        border: matched ? null : const Color(0xFFE8DCC8),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = math.min(box.maxWidth, box.maxHeight) * 0.68;
            return SizedBox(
              width: size,
              height: size,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: size * 0.1,
                      strokeCap: StrokeCap.round,
                      backgroundColor: _teal.withValues(alpha: 0.15),
                      color: matched ? _teal : _coral,
                    ),
                    Icon(
                      matched ? Icons.check_rounded : Icons.volume_up_rounded,
                      color: matched ? _teal : _coral,
                      size: size * 0.45,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
