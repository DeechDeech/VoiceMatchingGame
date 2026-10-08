import 'dart:math';

/// ゲームオーバー時に表示するワード。増減してもここを編集するだけでよい。
const gameOverMessages = <String>[
  '左手を骨折した',
  '海だ～',
  '米をぶちまけた',
  '牛乳をぶちまけた',
  '・・・力',
  '黒魔術の副作用が？！',
  '知育から逃げるな',
  'おつゆるでした...',
  '寝坊した',
  'あなたのせいじゃないよ\n…責任はさかやんが負うからね',
];

/// 全ワードを1巡するまで重複させずランダムに返す。1巡したら仕切り直す。
class MessageDeck {
  MessageDeck({List<String>? messages, Random? random})
    : _messages = messages ?? gameOverMessages,
      _random = random ?? Random();

  final List<String> _messages;
  final Random _random;
  final Set<String> _shown = {};
  String? _last;

  String? next() {
    if (_messages.isEmpty) return null;
    // ワードが増減しても整合するよう、現在の一覧にあるものだけを数える。
    _shown.retainAll(_messages);
    var pool = _messages.where((m) => !_shown.contains(m)).toList();
    if (pool.isEmpty) {
      _shown.clear();
      pool = [..._messages];
      // 仕切り直し直後に同じワードが連続しないようにする。
      if (pool.length > 1 && _last != null) pool.remove(_last);
    }
    final message = pool[_random.nextInt(pool.length)];
    _shown.add(message);
    _last = message;
    return message;
  }
}
