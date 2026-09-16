import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mental_health_chatbot/data/resources_data.dart';
import 'package:mental_health_chatbot/ui/screens/resource_detail_screen.dart';

void main() {
  group('resource catalogue', () {
    test('every resource carries readable body content', () {
      expect(kResources, isNotEmpty);
      for (final r in kResources) {
        expect(r.body, isNotEmpty, reason: '${r.title} has an empty body');
        expect(resourceTopics, contains(r.topic),
            reason: '${r.title} has an unlisted topic');
      }
    });

    test('every block is well formed for its kind', () {
      for (final r in kResources) {
        for (final b in r.body) {
          switch (b.kind) {
            case BlockKind.paragraph:
              expect(b.text, isNotNull, reason: '${r.title}: empty paragraph');
              expect(b.text!.trim(), isNotEmpty);
            case BlockKind.bullets:
            case BlockKind.steps:
              expect(b.items, isNotEmpty,
                  reason: '${r.title}: list block with no items');
            case BlockKind.callout:
              // The detail screen force-unwraps both on a callout.
              expect(b.text, isNotNull, reason: '${r.title}: callout w/o text');
              expect(b.label, isNotNull, reason: '${r.title}: callout w/o label');
          }
        }
      }
    });

    test('every topic filter matches at least one resource', () {
      for (final topic in resourceTopics) {
        expect(kResources.where((r) => r.topic == topic), isNotEmpty,
            reason: 'no resources under $topic');
      }
    });
  });

  group('ResourceDetailScreen', () {
    // Renders each resource end to end: catches null unwraps in the block
    // switch and any layout overflow in the long bodies.
    for (final resource in kResources) {
      testWidgets('renders "${resource.title}" without error',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: ResourceDetailScreen(resource: resource),
        ));

        expect(tester.takeException(), isNull);
        // Title appears in both the app bar and the body heading.
        expect(find.text(resource.title), findsWidgets);

        if (resource.subtitle != null) {
          expect(find.text(resource.subtitle!), findsOneWidget);
        }
        // The first paragraph should be on screen without scrolling.
        final firstParagraph = resource.body
            .firstWhere((b) => b.kind == BlockKind.paragraph)
            .text!;
        expect(find.text(firstParagraph), findsOneWidget);
      });
    }

    testWidgets('scrolls to the closing support note', (tester) async {
      // Mindful Journaling is one of the longer bodies.
      final resource =
          kResources.firstWhere((r) => r.title == 'Mindful Journaling');
      await tester.pumpWidget(MaterialApp(
        home: ResourceDetailScreen(resource: resource),
      ));

      await tester.scrollUntilVisible(
        find.textContaining('not medical advice'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('not medical advice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
