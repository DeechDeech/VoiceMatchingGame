import 'package:flutter/material.dart';

const _ink = Color(0xFF193C3A);
const _teal = Color(0xFF2E7770);
const _paper = Color(0xFFF6F2E9);

/// スタート画面とゲーム画面で共有する音量設定。
class AudioSettings extends ChangeNotifier {
  AudioSettings._();

  static final AudioSettings instance = AudioSettings._();

  double _music = 0.28;
  double _voice = 1;

  double get music => _music;
  double get voice => _voice;

  set music(double value) {
    _music = value;
    notifyListeners();
  }

  set voice(double value) {
    _voice = value;
    notifyListeners();
  }
}

Future<void> showVolumeSheet(BuildContext context) {
  final settings = AudioSettings.instance;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _paper,
    builder: (context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '音量設定',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _VolumeControl(
                icon: Icons.music_note_rounded,
                title: 'BGM',
                value: settings.music,
                onChanged: (value) => settings.music = value,
              ),
              _VolumeControl(
                icon: Icons.record_voice_over_rounded,
                title: 'ボイス',
                value: settings.voice,
                onChanged: (value) => settings.voice = value,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _teal, size: 22),
        const SizedBox(width: 12),
        SizedBox(
          width: 128,
          child: Text(
            title,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
            activeColor: _teal,
            divisions: 10,
            label: '${(value * 100).round()}%',
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
