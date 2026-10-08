import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_matching_game/game_over_messages.dart';

void main() {
  test('shows every message once before repeating', () {
    final words = ['a', 'b', 'c', 'd'];
    final deck = MessageDeck(messages: words, random: Random(1));
    final first = [for (var i = 0; i < 4; i++) deck.next()];
    expect(first.toSet(), words.toSet());
    final second = [for (var i = 0; i < 4; i++) deck.next()];
    expect(second.toSet(), words.toSet());
    expect(second.first, isNot(first.last));
  });

  test('handles words being added or removed', () {
    final words = ['a', 'b'];
    final deck = MessageDeck(messages: words, random: Random(2));
    final seen = {deck.next(), deck.next()};
    expect(seen, {'a', 'b'});
    words
      ..remove('a')
      ..add('c');
    expect(deck.next(), 'c');
  });

  test('returns null when there are no messages', () {
    expect(MessageDeck(messages: []).next(), isNull);
  });
}
