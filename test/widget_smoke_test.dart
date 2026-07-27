import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/app/app.dart';

void main() {
  testWidgets('App boots and shows splash', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: Rent95App()));
    // Splash renders the app name.
    await tester.pump();
    expect(find.text('Rent95'), findsOneWidget);
  });
}
