import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 青背景（ブルーバック）の GIF アニメーションを、青を透過して繰り返し再生する。
class ChromaKeyGif extends StatefulWidget {
  const ChromaKeyGif({
    super.key,
    required this.asset,
    this.height = 240,
    this.decodeWidth = 640,
  });

  final String asset;
  final double height;

  /// 変換時の横幅。大きいほど鮮明だがメモリを使う。
  final int decodeWidth;

  @override
  State<ChromaKeyGif> createState() => _ChromaKeyGifState();
}

class _Frame {
  _Frame(this.image, this.duration);

  final ui.Image image;
  final Duration duration;
}

class _ChromaKeyGifState extends State<ChromaKeyGif> {
  final List<_Frame> _frames = [];
  Timer? _timer;
  int _index = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: widget.decodeWidth,
      );
      for (var i = 0; i < codec.frameCount; i++) {
        final info = await codec.getNextFrame();
        final keyed = await _removeBlue(info.image);
        info.image.dispose();
        if (_disposed) {
          keyed.dispose();
          return;
        }
        final ms = info.duration.inMilliseconds;
        _frames.add(_Frame(keyed, Duration(milliseconds: ms < 20 ? 100 : ms)));
        if (i == 0 && mounted) {
          setState(() {});
          _scheduleNext();
        }
      }
      codec.dispose();
    } catch (_) {
      // 読み込めない場合は何も表示しない。
    }
  }

  Future<ui.Image> _removeBlue(ui.Image source) async {
    final bytes = (await source.toByteData())!;
    final pixels = Uint8List.fromList(bytes.buffer.asUint8List());
    for (var i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      // 青がどれだけ他の色より強いか。強いほど背景とみなす。
      final blueness = b - (r > g ? r : g);
      if (blueness >= 120) {
        // 透明部分は色も消す（半透明合成で青が滲まないように）。
        pixels[i] = 0;
        pixels[i + 1] = 0;
        pixels[i + 2] = 0;
        pixels[i + 3] = 0;
      } else if (blueness > 50) {
        // 輪郭は半透明にし、青の映り込みを抑える。
        final alpha = ((120 - blueness) * 255 / 70).round().clamp(0, 255);
        final base = r > g ? r : g;
        pixels[i] = r * alpha ~/ 255;
        pixels[i + 1] = g * alpha ~/ 255;
        pixels[i + 2] = base * alpha ~/ 255;
        pixels[i + 3] = alpha;
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      source.width,
      source.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_frames.isEmpty) return;
    final duration = _frames[_index % _frames.length].duration;
    _timer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _frames.length);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final frame in _frames) {
      frame.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) return SizedBox(height: widget.height);
    return SizedBox(
      height: widget.height,
      child: RawImage(
        image: _frames[_index % _frames.length].image,
        fit: BoxFit.contain,
      ),
    );
  }
}
