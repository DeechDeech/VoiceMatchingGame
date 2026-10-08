const fs = require('fs');
const p = 'lib/main.dart';
const lines = fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/);
const fix = {
  33: "title: 'ボイス神経衰弱',",
  86: "_reportAudioError('音声を初期化できませんでした: $error');",
  96: "_reportAudioError('BGMを再生できませんでした: $error');",
  105: "_reportAudioError('効果音を再生できませんでした: $error');",
  113: "_reportAudioError('BGMの音量を変更できませんでした: $error');",
  121: "_reportAudioError('効果音の音量を変更できませんでした: $error');",
  129: "_reportAudioError('読み上げ音声の音量を変更できませんでした: $error');",
  140: '// 再生中でも次の札を選べる。前の音声は止めて、新しい札の音声に切り替える。',
  161: "_reportAudioError('音声を再生できませんでした: $error');",
  188: "title: const Text('全札コンプリート！'),",
  190: "'${_session.turns}ターンでそろいました。\\n耳の記憶力、すばらしい！',",
  202: "label: const Text('もう一度あそぶ'),",
  244: "'音量設定',",
  264: "title: 'カードをめくる音',",
  274: "title: '読み上げ音声',",
  317: '// 全札が収まらないほど小さくなる場合は、最小サイズを保ってスクロールさせる。',
  387: "'ボイス神経衰弱',",
  401: "'声を聴いて、同じ音声のカードを見つけよう',",
  412: "label: '音量',",
  419: "label: 'やりなおす',",
  436: "text: 'ターン  ${_session.turns}',",
  442: "'ペア  ${_session.matchedPairs} / ${GameSession.pairCount}',",
  448: "? '声を聴いてね…'",
  450: "? 'カードをタップして音声を再生'",
  451: ": '音声を準備中…',",
  558: "label: '音声カード ${widget.cardNumber}',",
  599: '// 背面画像は assets/images/card_back.png を差し替えるだけで変更できる。',
};
for (const [n, t] of Object.entries(fix)) {
  const old = lines[n - 1];
  const indent = old.match(/^\s*/)[0];
  lines[n - 1] = indent + t;
}
fs.writeFileSync(p, lines.join('\n'), 'utf8');
