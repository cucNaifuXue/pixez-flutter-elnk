import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/search/search_tag_panel.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

Future<void> mountPanel(
  WidgetTester tester,
  ValueNotifier<int> historyCount,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 528,
            child: Column(
              children: [
                const SizedBox(height: 48, child: Text('fixed-search')),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: historyCount,
                    builder: (_, count, __) => SearchTagPanel(
                      tagCount: 30,
                      historyCount: count,
                      tagBuilder: (_, index) =>
                          Center(child: Text('tag-$index')),
                      historyBuilder: (_, index) =>
                          Center(child: Text('history-$index')),
                      onRefresh: () async => true,
                      onClearHistory: () => historyCount.value = 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('recommended tags switch whole pages below a fixed search bar', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final historyCount = ValueNotifier(60);
    addTearDown(historyCount.dispose);
    await mountPanel(tester, historyCount);
    final headerPosition = tester.getTopLeft(find.text('fixed-search'));
    expect(
      find.descendant(
        of: find.byType(SearchTagPanel),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(find.text('tag-8'), findsOneWidget);
    expect(find.text('tag-9'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('recommended-tag-pages'))),
    );
    await gesture.moveBy(const Offset(0, -60));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(find.text('tag-0'), findsOneWidget);
    expect(find.text('tag-9'), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.text('tag-9'), findsOneWidget);
    expect(find.text('tag-0'), findsNothing);
    expect(tester.getTopLeft(find.text('fixed-search')), headerPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history pages retain tag position and clearing returns to tags',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final historyCount = ValueNotifier(60);
      addTearDown(historyCount.dispose);
      await mountPanel(tester, historyCount);
      await tester.drag(
        find.byKey(const ValueKey('recommended-tag-pages')),
        const Offset(0, -120),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('search-tag-section')));
      await tester.pump();
      expect(find.text('history-0'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('search-history-pages')),
        const Offset(0, -120),
      );
      await tester.pump();
      expect(find.text('history-21'), findsOneWidget);
      expect(find.text('history-0'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('search-tag-section')));
      await tester.pump();
      expect(find.text('tag-9'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('search-tag-section')));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(find.text('tag-9'), findsOneWidget);
      expect(find.byKey(const ValueKey('search-tag-section')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
