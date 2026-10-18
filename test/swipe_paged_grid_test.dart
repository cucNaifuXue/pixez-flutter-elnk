import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/swipe_paged_grid.dart';

Future<void> mountGrid(
  WidgetTester tester, {
  required ValueNotifier<int> count,
  required Future<bool> Function() onLoadMore,
  required bool Function() hasMore,
  Future<bool> Function()? onRefresh,
  int columns = 2,
  int resetToken = 0,
  double? rowExtent,
  VoidCallback? onInteractionStart,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 640,
            child: ValueListenableBuilder<int>(
              valueListenable: count,
              builder: (context, itemCount, _) => SwipePagedGrid(
                itemCount: itemCount,
                crossAxisCount: columns,
                resetToken: resetToken,
                rowExtent: rowExtent,
                onInteractionStart: onInteractionStart,
                itemBuilder: (_, index) => Center(child: Text('art-$index')),
                hasMore: hasMore,
                onLoadMore: onLoadMore,
                onRefresh: onRefresh ?? () async => true,
                loadingLabel: 'Loading',
                emptyLabel: 'Empty',
                retryLabel: 'Retry',
                refreshLabel: 'Refresh',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> nextPage(WidgetTester tester) async {
  await tester.drag(find.byType(SwipePagedGrid), const Offset(0, -160));
  await tester.pump();
}

void main() {
  testWidgets('swipe changes a whole page only after release', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(12);
    addTearDown(count.dispose);
    var alignments = 0;
    await mountGrid(
      tester,
      count: count,
      onLoadMore: () async => true,
      hasMore: () => false,
      onInteractionStart: () => alignments++,
    );
    expect(find.text('1 / 3'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipePagedGrid)),
    );
    await gesture.moveBy(const Offset(0, -80));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(find.text('art-0'), findsOneWidget);
    expect(find.text('art-4'), findsNothing);
    expect(alignments, greaterThan(0));

    await gesture.up();
    await tester.pump();
    expect(find.text('art-0'), findsNothing);
    expect(find.text('art-4'), findsOneWidget);
    expect(find.text('art-7'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.drag(find.byType(SwipePagedGrid), const Offset(0, 160));
    await tester.pump();
    expect(find.text('art-0'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('last full page loads once and advances', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(4);
    addTearDown(count.dispose);
    final response = Completer<bool>();
    var requests = 0;
    var more = true;
    await mountGrid(
      tester,
      count: count,
      hasMore: () => more,
      onLoadMore: () async {
        requests++;
        final success = await response.future;
        count.value = 8;
        more = false;
        return success;
      },
    );
    await nextPage(tester);
    await nextPage(tester);
    expect(requests, 1);
    expect(find.text('art-0'), findsOneWidget);
    response.complete(true);
    await tester.pump();
    expect(find.text('art-4'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('new items fill a partial page before advancing', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(3);
    addTearDown(count.dispose);
    var more = true;
    await mountGrid(
      tester,
      count: count,
      hasMore: () => more,
      onLoadMore: () async {
        count.value = 7;
        more = false;
        return true;
      },
    );
    await nextPage(tester);
    expect(find.text('art-3'), findsOneWidget);
    expect(find.text('art-4'), findsNothing);
    await nextPage(tester);
    expect(find.text('art-4'), findsOneWidget);
    expect(find.text('art-6'), findsOneWidget);
  });

  testWidgets('failed load keeps the page and refresh recovers', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(4);
    addTearDown(count.dispose);
    await mountGrid(
      tester,
      count: count,
      hasMore: () => true,
      onLoadMore: () async => false,
      onRefresh: () async {
        count.value = 8;
        return true;
      },
    );
    await nextPage(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('art-0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('art-0'), findsOneWidget);
    expect(find.text('1 / 2+'), findsOneWidget);
  });

  testWidgets('changing the grid keeps the current artwork in view', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(12);
    addTearDown(count.dispose);
    await mountGrid(
      tester,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
    );
    await nextPage(tester);
    expect(find.text('art-4'), findsOneWidget);
    await mountGrid(
      tester,
      count: count,
      columns: 1,
      hasMore: () => false,
      onLoadMore: () async => true,
    );
    expect(find.text('art-4'), findsOneWidget);
    expect(find.text('5 / 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit row height paginates compact cards', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(12);
    addTearDown(count.dispose);
    await mountGrid(
      tester,
      count: count,
      rowExtent: 128,
      hasMore: () => false,
      onLoadMore: () async => true,
    );
    expect(find.text('art-7'), findsOneWidget);
    expect(find.text('art-8'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
    await nextPage(tester);
    expect(find.text('art-8'), findsOneWidget);
    expect(find.text('art-11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset token returns a paged tab to its first page', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(12);
    addTearDown(count.dispose);
    await mountGrid(
      tester,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
    );
    await nextPage(tester);
    expect(find.text('art-4'), findsOneWidget);
    await mountGrid(
      tester,
      count: count,
      resetToken: 1,
      hasMore: () => false,
      onLoadMore: () async => true,
    );
    expect(find.text('art-0'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });
}
