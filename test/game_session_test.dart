import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_matching_game/game_session.dart';
import 'package:voice_matching_game/voice_catalog.dart';

void main() {
  group('GameSession', () {
    test('creates nine voice pairs with unique card IDs', () {
      final session = GameSession.newGame(random: Random(1));
      final clipIdCounts = <String, int>{};

      for (final card in session.cards) {
        clipIdCounts.update(
          card.clip.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      expect(session.cards, hasLength(GameSession.pairCount * 2));
      expect(
        session.cards.map((card) => card.id).toSet(),
        hasLength(GameSession.pairCount * 2),
      );
      expect(clipIdCounts, hasLength(GameSession.pairCount));
      expect(clipIdCounts.values, everyElement(2));
      expect(session.turns, 0);
    });

    test('picks a random subset of the catalog per game', () {
      final a = GameSession.newGame(
        random: Random(10),
      ).cards.map((c) => c.clip.id).toSet();
      final b = GameSession.newGame(
        random: Random(11),
      ).cards.map((c) => c.clip.id).toSet();
      expect(a, hasLength(GameSession.pairCount));
      if (voiceCatalog.length > GameSession.pairCount) {
        expect(a, isNot(equals(b)));
      }
    });

    test('allows selecting the next card while a miss is still shown', () {
      final session = GameSession.newGame(random: Random(6));
      final first = session.cards.first;
      final other = session.cards.firstWhere((c) => c.clip.id != first.clip.id);
      final next = session.cards.firstWhere(
        (c) => c.id != first.id && c.id != other.id,
      );
      session.reveal(first.id);
      session.reveal(other.id);
      session.resolveTurn();

      expect(session.canReveal(next.id), isFalse);
      expect(session.canSelect(next.id), isTrue);
      expect(session.canSelect(first.id), isFalse);

      session.hideUnmatched();
      session.reveal(next.id);
      expect(session.isRevealed(next.id), isTrue);
      expect(session.isRevealed(first.id), isFalse);
    });

    test('loses a life on each miss and ends the game at zero', () {
      final session = GameSession.newGame(random: Random(6));
      expect(session.lives, GameSession.maxLives);
      for (var i = 0; i < GameSession.maxLives; i++) {
        final ids = session.cards.map((c) => c.id).toList();
        final first = session.cards.first;
        final other = session.cards.firstWhere(
          (c) => c.clip.id != first.clip.id,
        );
        expect(ids, isNotEmpty);
        session.reveal(first.id);
        session.reveal(other.id);
        expect(session.resolveTurn(), isFalse);
        session.hideUnmatched();
      }
      expect(session.lives, 0);
      expect(session.isGameOver, isTrue);
      expect(session.canReveal(session.cards.first.id), isFalse);
    });

    test('a match does not cost a life', () {
      final session = GameSession.newGame(random: Random(7));
      final pair = _cardsForClip(session.cards.first.clip.id, session.cards);
      session.reveal(pair[0].id);
      session.reveal(pair[1].id);
      session.resolveTurn();
      expect(session.lives, GameSession.maxLives);
    });

    test('counts a matched pair as one turn', () {
      final session = GameSession.newGame(random: Random(2));
      final pair = _cardsForClip(session.cards.first.clip.id, session.cards);

      session.reveal(pair[0].id);
      session.reveal(pair[1].id);
      expect(session.resolveTurn(), isTrue);

      expect(session.turns, 1);
      expect(session.matchedPairs, 1);
      expect(session.isMatched(pair[0].id), isTrue);
      expect(session.hasTwoRevealed, isFalse);
    });

    test('keeps a miss visible until it is hidden and counts the turn', () {
      final session = GameSession.newGame(random: Random(3));
      final first = session.cards.first;
      final second = session.cards.firstWhere(
        (card) => card.clip.id != first.clip.id,
      );

      session.reveal(first.id);
      session.reveal(second.id);
      expect(session.resolveTurn(), isFalse);

      expect(session.turns, 1);
      expect(session.matchedPairs, 0);
      expect(session.isRevealed(first.id), isTrue);
      expect(session.isRevealed(second.id), isTrue);
      session.hideUnmatched();
      expect(session.isRevealed(first.id), isFalse);
      expect(session.isRevealed(second.id), isFalse);
    });

    test('finishes after all pairs are matched', () {
      final session = GameSession.newGame(random: Random(4));
      final clipIds = session.cards.map((card) => card.clip.id).toSet();

      for (final clipId in clipIds) {
        final pair = _cardsForClip(clipId, session.cards);
        session.reveal(pair[0].id);
        session.reveal(pair[1].id);
        expect(session.resolveTurn(), isTrue);
      }

      expect(session.isComplete, isTrue);
      expect(session.turns, GameSession.pairCount);
      expect(session.matchedPairs, GameSession.pairCount);
    });

    test('rejects a card that is already open or matched', () {
      final session = GameSession.newGame(random: Random(5));
      final pair = _cardsForClip(session.cards.first.clip.id, session.cards);

      session.reveal(pair[0].id);
      expect(session.canReveal(pair[0].id), isFalse);
      session.reveal(pair[1].id);
      session.resolveTurn();
      expect(session.canReveal(pair[0].id), isFalse);
      expect(() => session.reveal(pair[0].id), throwsStateError);
    });
  });
}

List<VoiceCard> _cardsForClip(String clipId, List<VoiceCard> cards) =>
    cards.where((card) => card.clip.id == clipId).toList(growable: false);
