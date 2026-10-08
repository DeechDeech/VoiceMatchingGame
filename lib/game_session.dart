import 'dart:math';

import 'voice_catalog.dart';
import 'voice_clip.dart';

class VoiceCard {
  const VoiceCard({required this.id, required this.clip});

  final int id;
  final VoiceClip clip;
}

class GameSession {
  GameSession._(this.cards);

  /// 1ゲームで使う音声の数（札はこの2倍の枚数）。
  static const int pairCount = 9;

  /// 最初のライフ数。札がそろわなかった（ミスした）ターンごとに1つ減る。
  static const int maxLives = 5;

  final List<VoiceCard> cards;
  final Set<int> _revealed = {};
  final Set<int> _matched = {};
  int turns = 0;
  int lives = maxLives;

  /// [clips] からランダムに [pairCount] 種類を選び、それぞれ2枚ずつ配る。
  static GameSession newGame({Random? random, List<VoiceClip>? clips}) {
    final pool = [...(clips ?? voiceCatalog)];
    if (pool.length < pairCount) {
      throw ArgumentError('At least $pairCount voice clips are required.');
    }
    pool.shuffle(random);
    final deck = [
      for (final clip in pool.take(pairCount)) ...[clip, clip],
    ]..shuffle(random);
    final cards = List.generate(
      deck.length,
      (index) => VoiceCard(id: index, clip: deck[index]),
      growable: false,
    );
    return GameSession._(List.unmodifiable(cards));
  }

  int get matchedPairs => _matched.length ~/ 2;
  bool get isComplete => _matched.length == cards.length;
  bool get isGameOver => lives <= 0 && !isComplete;
  bool get isFinished => isComplete || isGameOver;
  bool get hasTwoRevealed => _revealed.length == 2;

  bool isMatched(int cardId) => _matched.contains(cardId);
  bool isRevealed(int cardId) => _revealed.contains(cardId);

  bool canReveal(int cardId) =>
      cardId >= 0 &&
      cardId < cards.length &&
      !_matched.contains(cardId) &&
      !_revealed.contains(cardId) &&
      _revealed.length < 2 &&
      !isFinished;

  /// タップを受け付けられるか。外れた2枚が表示中でも、次の札は選べる
  /// （[reveal] の前に [hideUnmatched] で外れた札を閉じる）。
  bool canSelect(int cardId) =>
      cardId >= 0 &&
      cardId < cards.length &&
      !_matched.contains(cardId) &&
      !_revealed.contains(cardId) &&
      !isFinished;

  void reveal(int cardId) {
    if (!canReveal(cardId)) {
      throw StateError('This card cannot be revealed.');
    }
    _revealed.add(cardId);
  }

  bool resolveTurn() {
    if (!hasTwoRevealed) {
      throw StateError('A turn can only be resolved after two cards are open.');
    }
    turns++;
    final ids = _revealed.toList(growable: false);
    final matched = cards[ids[0]].clip.id == cards[ids[1]].clip.id;
    if (matched) {
      _matched.addAll(ids);
      _revealed.clear();
    } else {
      lives--;
    }
    return matched;
  }

  void hideUnmatched() {
    if (_revealed.length != 2 ||
        cards[_revealed.first].clip.id == cards[_revealed.last].clip.id) {
      throw StateError('There are no unmatched cards to hide.');
    }
    _revealed.clear();
  }
}
