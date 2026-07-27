import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/shared/components/initial_avatar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('InitialAvatar', () {
    testWidgets('renders first grapheme of the name', (tester) async {
      await tester.pumpWidget(_wrap(const InitialAvatar(name: 'Alex Rivera')));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('uppercases lowercase names', (tester) async {
      await tester.pumpWidget(_wrap(const InitialAvatar(name: 'alex')));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('falls back to ? on empty string', (tester) async {
      await tester.pumpWidget(_wrap(const InitialAvatar(name: '')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('falls back to ? on whitespace-only', (tester) async {
      await tester.pumpWidget(_wrap(const InitialAvatar(name: '   ')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('falls back to ? on null', (tester) async {
      await tester.pumpWidget(_wrap(const InitialAvatar(name: null)));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('handles emoji cluster as first grapheme', (tester) async {
      // Regression against `substring(0, 1)` which would emit a broken
      // surrogate half. Uses Dart's Characters (extended grapheme).
      await tester.pumpWidget(_wrap(const InitialAvatar(name: '😀 Ollie')));
      expect(find.text('😀'), findsOneWidget);
    });

    testWidgets('renders fallback letter (not blank) when imageUrl is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const InitialAvatar(name: 'Bob', imageUrl: ''),
      ));
      expect(find.text('B'), findsOneWidget);
    });
  });
}
