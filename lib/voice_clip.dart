class VoiceClip {
  const VoiceClip({
    required this.id,
    required this.name,
    required this.durationMs,
    this.extension = 'wav',
  });

  final String id;
  final String name;
  final int durationMs;
  final String extension; // 'wav' / 'mp3' / 'm4a'

  /// audioplayers の AssetSource に渡すパス（assets/ からの相対）。
  String get assetPath => 'audio/voices/$id.$extension';

  Duration get duration => Duration(milliseconds: durationMs);
}
