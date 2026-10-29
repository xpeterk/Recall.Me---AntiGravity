import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:recall_me_native/features/recall/domain/transcription_segment.dart';
import 'package:recall_me_native/features/recall/presentation/transcription_bubble.dart';
import 'package:recall_me_native/features/starters/data/starters_repository.dart';
import 'package:recall_me_native/features/starters/presentation/create_starter_page.dart';

void main() {
  group('Select Mode & Transcription Bubble Widget Tests', () {
    testWidgets('shows checkbox when isSelectionMode is true and triggers onTap', (WidgetTester tester) async {
      final testSegment = TranscriptionSegment(
        id: 'seg_1',
        text: 'AI capex has surged past forecasts.',
        timestamp: DateTime(2026, 10, 28, 12, 0),
        type: SegmentType.aiResponse,
      );

      String? tappedId;
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptionBubble(
              segment: testSegment,
              isSelectionMode: true,
              isSelected: false,
              onTap: (id) => tappedId = id,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );

      // Verify checkbox is rendered in selection mode
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap on the bubble
      await tester.tap(find.byType(TranscriptionBubble));
      await tester.pump();
      expect(tappedId, equals('seg_1'));

      // Long press triggers onLongPress
      await tester.longPress(find.byType(TranscriptionBubble));
      await tester.pump();
      expect(longPressed, isTrue);
    });

    testWidgets('checkbox is checked when isSelected is true', (WidgetTester tester) async {
      final testSegment = TranscriptionSegment(
        id: 'seg_2',
        text: 'User question about energy',
        timestamp: DateTime(2026, 10, 28, 12, 0),
        type: SegmentType.audio,
        isUser: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptionBubble(
              segment: testSegment,
              isSelectionMode: true,
              isSelected: true,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });
  });

  group('CreateStarterPage Form Widget Tests', () {
    late StartersRepository fakeRepo;

    setUp(() {
      fakeRepo = StartersRepository();
    });

    Widget createTestWidget({List<TranscriptionSegment>? prefill}) {
      return ChangeNotifierProvider<StartersRepository>.value(
        value: fakeRepo,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1400)),
            child: CreateStarterPage(
              prefillFromBubbles: prefill,
            ),
          ),
        ),
      );
    }

    testWidgets('renders Title, Summary, Categories, and Action Buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('New starter'), findsOneWidget);
      expect(find.text('TITLE'), findsOneWidget);
      expect(find.text('SUMMARY / CONTEXT'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Save starter'), findsOneWidget);
      expect(find.text('Save & start'), findsOneWidget);
    });

    testWidgets('validates required title when Save starter is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final saveButton = find.text('Save starter');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a starter title'), findsOneWidget);
    });

    testWidgets('adds angle chip when angle input is typed and submitted', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Add'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final angleInput = find.byType(TextField).last;
      await tester.enterText(angleInput, 'Water and power cooling');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Angle chip should be displayed
      expect(find.text('Water and power cooling'), findsOneWidget);
    });

    testWidgets('prefills form with bubbles context when provided', (WidgetTester tester) async {
      final prefilledBubbles = [
        TranscriptionSegment(
          id: 'pre_1',
          text: 'Nuclear SMRs are gaining momentum across cloud providers.',
          timestamp: DateTime(2026, 10, 28, 12, 0),
          type: SegmentType.aiResponse,
        )
      ];

      await tester.pumpWidget(createTestWidget(prefill: prefilledBubbles));
      await tester.pumpAndSettle();

      expect(find.textContaining('Prefilled from 1 selected bubbles'), findsOneWidget);
      expect(find.textContaining('Nuclear SMRs are gaining momentum'), findsOneWidget);
    });
  });
}
