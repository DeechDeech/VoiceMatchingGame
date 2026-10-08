import 'package:flutter/material.dart';

/// 画面サイズに関わらず 16:9 を保つ固定サイズのステージ。
/// 子は 1280x720 の座標系で配置し、余った領域は黒帯になる。
class GameStage extends StatelessWidget {
  const GameStage({super.key, required this.child});

  static const double width = 1280;
  static const double height = 720;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: width / height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: width,
                height: height,
                child: ClipRect(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// スタート画面とゲーム画面で共通の、右上に置く白背景ボタン。
class StageButton extends StatelessWidget {
  const StageButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 30),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF193C3A),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// ステージ右上の共通ボタン配置。右端が音量ボタンの位置になる。
class StageTopRight extends StatelessWidget {
  const StageTopRight({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}
