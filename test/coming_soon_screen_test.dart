import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ui/coming_soon_screen.dart';

void main() {
  testWidgets('ComingSoonScreen shows the tool title and description',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComingSoonScreen(
          title: 'Redact & Sanitize',
          description: 'Permanently remove sensitive text.',
        ),
      ),
    );

    expect(find.text('Redact & Sanitize'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Permanently remove sensitive text.'), findsOneWidget);
  });
}
