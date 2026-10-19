import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/paged_grid_layout.dart';
import 'package:pixez/component/swipe_paged_grid.dart';

Future<void> _mountPager(
  WidgetTester tester, {
  required SwipePagedGridController controller,
  required ValueNotifier<int> count,
  required bool Function() hasMore,
  required Future<bool> Function() onLoadMore,
  Future<bool> Function()? onRefresh,
  int rows = 1,
  int columns = 2,
  int resetToken = 0,
  double viewportWidth = 400,
  Widget? imageNavigation,
  Widget? footerAction,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewportWidth,
            height: 640,
            child: PagedGridLayout(
              rows: rows,
              columns: columns,
              child: ValueListenableBuilder<int>(
                valueListenable: count,
                builder: (context, itemCount, _) => SwipePagedGrid(
                  controller: controller,
                  firstPageBuilder: (_) => const _InfoPage(),
                  itemCount: itemCount,
                  crossAxisCount: columns,
                  usePageLayout: true,
                  resetToken: resetToken,
                  itemBuilder: (_, index) => Center(child: Text('art-$index')),
                  hasMore: hasMore,
                  onLoadMore: onLoadMore,
                  onRefresh: onRefresh ?? () async => true,
                  loadingLabel: 'Loading',
                  emptyLabel: 'Empty',
                  retryLabel: 'Retry',
                  refreshLabel: 'Refresh',
                  imageNavigation: imageNavigation,
                  footerAction: footerAction,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InfoPage extends StatefulWidget {
  const _InfoPage();

  @override
  State<_InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<_InfoPage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _counter++),
      child: Text('info-$_counter'),
    ),
  );
}

Future<void> _next(
  WidgetTester tester,
  SwipePagedGridController controller,
) async {
  controller.nextPage();
  await tester.pump();
}

bool _restoreEnabled(WidgetTester tester) =>
    tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == '返回刚才的推荐页',
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('detail footer orders both navigations in one narrow row', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(4);
    addTearDown(count.dispose);
    final controller = SwipePagedGridController();
    addTearDown(controller.dispose);
    const imageKey = ValueKey('image-navigation');
    const bookmarkKey = ValueKey('footer-bookmark');
    await _mountPager(
      tester,
      controller: controller,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
      viewportWidth: 320,
      imageNavigation: const Row(
        key: imageKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous image',
            onPressed: null,
            icon: Icon(Icons.chevron_left),
          ),
          Text('图 1/1'),
          IconButton(
            tooltip: 'Next image',
            onPressed: null,
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
      footerAction: IconButton(
        key: bookmarkKey,
        onPressed: () {},
        icon: const Icon(Icons.favorite_border),
      ),
    );
    final ordered = [
      find.byTooltip('Refresh'),
      find.byTooltip('回到第1页'),
      find.byTooltip('返回刚才的推荐页'),
      find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up),
      find.text('页 1/3'),
      find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
      find.byTooltip('Previous image'),
      find.text('图 1/1'),
      find.byTooltip('Next image'),
      find.byKey(bookmarkKey),
    ];
    final centers = ordered.map(tester.getCenter).toList();
    for (var index = 1; index < centers.length; index++) {
      expect(centers[index].dx, greaterThan(centers[index - 1].dx));
      expect(centers[index].dy, closeTo(centers.first.dy, 1));
    }
    expect(tester.getRect(find.byKey(imageKey)).bottom,
        tester.getRect(find.byKey(bookmarkKey)).bottom);
    expect(tester.takeException(), isNull);

    await _next(tester, controller);
    expect(find.byKey(imageKey), findsNothing);
    expect(find.text('页 2/3'), findsOneWidget);
    controller.firstPage();
    await tester.pump();
    expect(find.byKey(imageKey), findsOneWidget);
    controller.restoreReadingPage();
    await tester.pump();
    expect(find.text('页 2/3'), findsOneWidget);
    expect(find.text('art-0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('footer bookmark shares navigation space on a narrow screen', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(4);
    addTearDown(count.dispose);
    final controller = SwipePagedGridController();
    var taps = 0;
    var longPresses = 0;
    const bookmarkKey = ValueKey('footer-bookmark');
    await _mountPager(
      tester,
      controller: controller,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
      viewportWidth: 320,
      footerAction: GestureDetector(
        key: bookmarkKey,
        onLongPress: () => longPresses++,
        child: IconButton(
          onPressed: () => taps++,
          icon: const Icon(Icons.favorite_border),
        ),
      ),
    );
    final bookmark = find.byKey(bookmarkKey);
    final navigation = find.widgetWithIcon(IconButton, Icons.first_page);
    expect(tester.getRect(bookmark).top, tester.getRect(navigation).top);
    expect(tester.getRect(bookmark).bottom, tester.getRect(navigation).bottom);
    expect(tester.takeException(), isNull);

    await tester.tap(bookmark);
    await tester.pump();
    await tester.longPress(bookmark);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 1);

    await _next(tester, controller);
    expect(find.text('页 2/3'), findsOneWidget);
    await tester.tap(find.byTooltip('回到第1页'));
    await tester.pump();
    expect(find.text('info-0'), findsOneWidget);
    await tester.tap(find.byTooltip('返回刚才的推荐页'));
    await tester.pump();
    expect(find.text('页 2/3'), findsOneWidget);
    expect(find.text('art-0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail is page one and footer returns to the last recommendation',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final count = ValueNotifier(6);
      addTearDown(count.dispose);
      final controller = SwipePagedGridController();
      var requests = 0;
      await _mountPager(
        tester,
        controller: controller,
        count: count,
        hasMore: () => false,
        onLoadMore: () async {
          requests++;
          return true;
        },
      );
      expect(find.text('info-0'), findsOneWidget);
      expect(find.text('页 1/4'), findsOneWidget);
      expect(_restoreEnabled(tester), isFalse);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(_InfoPage)),
      );
      await gesture.moveBy(const Offset(0, -80));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(find.text('info-0'), findsOneWidget);
      expect(find.text('art-0'), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(find.text('页 2/4'), findsOneWidget);
      expect(find.text('art-0'), findsOneWidget);

      await _next(tester, controller);
      expect(find.text('页 3/4'), findsOneWidget);
      expect(find.text('art-2'), findsOneWidget);
      await tester.tap(find.byTooltip('回到第1页'));
      await tester.pump();
      expect(find.text('页 1/4'), findsOneWidget);
      expect(find.text('info-0'), findsOneWidget);
      expect(_restoreEnabled(tester), isTrue);
      await tester.tap(find.byTooltip('返回刚才的推荐页'));
      await tester.pump();
      expect(find.text('页 3/4'), findsOneWidget);
      expect(find.text('art-2'), findsOneWidget);
      expect(find.text('art-3'), findsOneWidget);
      expect(requests, 0);
    },
  );

  testWidgets('detail state and remembered artwork survive grid resizing', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(16);
    addTearDown(count.dispose);
    final controller = SwipePagedGridController();
    Future<void> configure(int rows) => _mountPager(
      tester,
      controller: controller,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
      rows: rows,
    );
    await configure(1);
    await tester.tap(find.text('info-0'));
    await tester.pump();
    await _next(tester, controller);
    await _next(tester, controller);
    expect(find.text('art-2'), findsOneWidget);
    controller.firstPage();
    await tester.pump();
    expect(find.text('info-1'), findsOneWidget);

    await configure(2);
    expect(find.text('info-1'), findsOneWidget);
    expect(find.text('页 1/5'), findsOneWidget);
    controller.restoreReadingPage();
    await tester.pump();
    expect(find.text('页 2/5'), findsOneWidget);
    expect(find.text('art-2'), findsOneWidget);
    expect(find.text('art-3'), findsOneWidget);
    controller.firstPage();
    await tester.pump();
    expect(find.text('info-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a pending recommendation load does not leave detail', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(2);
    addTearDown(count.dispose);
    final controller = SwipePagedGridController();
    final response = Completer<bool>();
    var more = true;
    var requests = 0;
    await _mountPager(
      tester,
      controller: controller,
      count: count,
      hasMore: () => more,
      onLoadMore: () async {
        requests++;
        final success = await response.future;
        count.value = 6;
        more = false;
        return success;
      },
    );
    await _next(tester, controller);
    await _next(tester, controller);
    expect(requests, 1);
    await tester.tap(find.byTooltip('回到第1页'));
    await tester.pump();
    expect(find.text('info-0'), findsOneWidget);
    response.complete(true);
    await tester.pump();
    expect(find.text('info-0'), findsOneWidget);
    expect(find.text('页 1/4'), findsOneWidget);
    controller.restoreReadingPage();
    await tester.pump();
    expect(find.text('art-0'), findsOneWidget);
    expect(find.text('页 2/4'), findsOneWidget);
    await _next(tester, controller);
    expect(find.text('art-2'), findsOneWidget);
    expect(requests, 1);
  });

  testWidgets('refresh and dataset reset clear the remembered recommendation', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final count = ValueNotifier(8);
    addTearDown(count.dispose);
    final controller = SwipePagedGridController();
    Future<void> configure(int resetToken) => _mountPager(
      tester,
      controller: controller,
      count: count,
      hasMore: () => false,
      onLoadMore: () async => true,
      resetToken: resetToken,
    );
    Future<void> rememberRecommendation() async {
      await _next(tester, controller);
      await _next(tester, controller);
      controller.firstPage();
      await tester.pump();
      expect(_restoreEnabled(tester), isTrue);
    }

    await configure(0);
    await rememberRecommendation();
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(find.text('页 1/5'), findsOneWidget);
    expect(_restoreEnabled(tester), isFalse);
    await rememberRecommendation();
    await configure(1);
    expect(find.text('页 1/5'), findsOneWidget);
    expect(find.text('info-0'), findsOneWidget);
    expect(_restoreEnabled(tester), isFalse);
  });

  testWidgets(
    'prefixed paging fills a partial recommendation page before moving',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final count = ValueNotifier(1);
      addTearDown(count.dispose);
      final controller = SwipePagedGridController();
      var more = true;
      var requests = 0;
      await _mountPager(
        tester,
        controller: controller,
        count: count,
        hasMore: () => more,
        onLoadMore: () async {
          requests++;
          count.value = 3;
          more = false;
          return true;
        },
      );
      await _next(tester, controller);
      expect(find.text('页 2/2+'), findsOneWidget);
      await _next(tester, controller);
      expect(find.text('页 2/3'), findsOneWidget);
      expect(find.text('art-0'), findsOneWidget);
      expect(find.text('art-1'), findsOneWidget);
      expect(find.text('art-2'), findsNothing);
      await _next(tester, controller);
      expect(find.text('页 3/3'), findsOneWidget);
      expect(find.text('art-2'), findsOneWidget);
      expect(requests, 1);
    },
  );
}
