import 'dart:io';
import 'dart:typed_data';

/// 音声フォルダーから assets/audio/voices へ連番名でコピーし、
/// lib/voice_catalog.dart（名前・再生時間つきの一覧）を生成する。
///
/// 使い方: dart run tool/generate_voice_catalog.dart <音声フォルダー>
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/generate_voice_catalog.dart <dir>');
    exit(64);
  }
  final source = Directory(args.first);
  final files = source.listSync().whereType<File>().where((f) {
    final p = f.path.toLowerCase();
    return p.endsWith('.wav') || p.endsWith('.mp3') || p.endsWith('.m4a');
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  final target = Directory('assets/audio/voices');
  if (target.existsSync()) target.deleteSync(recursive: true);
  target.createSync(recursive: true);

  final buffer = StringBuffer()
    ..writeln('// このファイルは tool/generate_voice_catalog.dart で自動生成されます。')
    ..writeln()
    ..writeln("import 'voice_clip.dart';")
    ..writeln()
    ..writeln('const voiceCatalog = <VoiceClip>[');

  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    final fileName = file.uri.pathSegments.last;
    final name = fileName.substring(0, fileName.length - 4);
    final id = 'v${(i + 1).toString().padLeft(3, '0')}';
    final lower = fileName.toLowerCase();
    final ext = lower.endsWith('.mp3')
        ? 'mp3'
        : lower.endsWith('.m4a')
        ? 'm4a'
        : 'wav';
    file.copySync('${target.path}/$id.$ext');
    final bytes = file.readAsBytesSync();
    final ms = switch (ext) {
      'mp3' => _mp3DurationMs(bytes),
      'm4a' => _m4aDurationMs(bytes),
      _ => _wavDurationMs(bytes),
    };
    final extArg = ext == 'wav' ? '' : ", extension: '$ext'";
    final safeName = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    buffer.writeln(
      "  VoiceClip(id: '$id', name: '$safeName', durationMs: $ms$extArg),",
    );
  }
  buffer.writeln('];');
  File('lib/voice_catalog.dart').writeAsStringSync(buffer.toString());
  stdout.writeln('Generated ${files.length} clips.');
}

int _wavDurationMs(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var byteRate = 0;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ') {
      byteRate = data.getUint32(offset + 16, Endian.little);
    } else if (id == 'data') {
      final available = bytes.length - (offset + 8);
      final length = size > available ? available : size;
      return byteRate == 0 ? 0 : (length * 1000 / byteRate).round();
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  return 0;
}

int _mp3DurationMs(Uint8List b) {
  const bitrates = [
    [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
  ];
  const rates = [44100, 48000, 32000];
  var pos = 0;
  if (b.length > 10 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
    pos = 10 + ((b[6] << 21) | (b[7] << 14) | (b[8] << 7) | b[9]);
  }
  var seconds = 0.0;
  while (pos + 4 <= b.length) {
    if (b[pos] != 0xFF || (b[pos + 1] & 0xE0) != 0xE0) {
      pos++;
      continue;
    }
    final versionBits = (b[pos + 1] >> 3) & 3; // 3: MPEG1, 2: MPEG2, 0: 2.5
    final layerBits = (b[pos + 1] >> 1) & 3; // 1: Layer III
    final brIndex = b[pos + 2] >> 4;
    final srIndex = (b[pos + 2] >> 2) & 3;
    final padding = (b[pos + 2] >> 1) & 1;
    if (versionBits == 1 ||
        layerBits != 1 ||
        brIndex == 0 ||
        brIndex == 15 ||
        srIndex == 3) {
      pos++;
      continue;
    }
    final mpeg1 = versionBits == 3;
    final bitrate = bitrates[mpeg1 ? 0 : 1][brIndex] * 1000;
    final rate = rates[srIndex] ~/ (mpeg1 ? 1 : (versionBits == 2 ? 2 : 4));
    final samples = mpeg1 ? 1152 : 576;
    final frameLength = (mpeg1 ? 144 : 72) * bitrate ~/ rate + padding;
    seconds += samples / rate;
    pos += frameLength;
  }
  return (seconds * 1000).round();
}

/// moov > mvhd の timescale / duration から再生時間を求める。
int _m4aDurationMs(Uint8List b) {
  final d = ByteData.sublistView(b);
  int? find(int start, int end, String target, {bool descend = false}) {
    var pos = start;
    while (pos + 8 <= end) {
      var size = d.getUint32(pos);
      final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
      var header = 8;
      if (size == 1 && pos + 16 <= end) {
        size = d.getUint64(pos + 8);
        header = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < header || pos + size > end) return null;
      if (type == target) return pos + header;
      if (descend && type == 'moov') {
        final r = find(pos + header, pos + size, target);
        if (r != null) return r;
      }
      pos += size;
    }
    return null;
  }

  final body = find(0, b.length, 'mvhd', descend: true);
  if (body == null) return 0;
  final version = b[body];
  final int timescale;
  final int duration;
  if (version == 1) {
    timescale = d.getUint32(body + 20);
    duration = d.getUint64(body + 24);
  } else {
    timescale = d.getUint32(body + 12);
    duration = d.getUint32(body + 16);
  }
  return timescale == 0 ? 0 : (duration * 1000 / timescale).round();
}
