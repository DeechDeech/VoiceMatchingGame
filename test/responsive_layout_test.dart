import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_matching_game/main.dart';
import 'package:voice_matching_game/start_screen.dart';

void main() {
  testWidgets('renders without overflow on a narrow phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VoiceMatchingGameApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  Finder tiles() => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_VoiceCardTile',
  );

  testWidgets('shows all 18 cards at a 1:1.40 ratio on a landscape phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VoiceMatchingGameApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(StartScreen));
    await tester.pump();
    await tester.tap(find.byType(StartScreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tiles(), findsNWidgets(18));
    final screen = Offset.zero & const Size(800, 360);
    for (final element in tiles().evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(rect.width / rect.height, closeTo(1 / 1.4, 0.01));
      expect(screen.contains(rect.topLeft), isTrue);
      expect(screen.contains(rect.bottomRight), isTrue);
    }
  });
}
