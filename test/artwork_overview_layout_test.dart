import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/artwork_overview_layout.dart';

const _pageKey = ValueKey('overview-page');
const _imageKey = ValueKey('contained-image');
const _metadataKey = ValueKey('overview-metadata');

Widget overview({
  Size size = const Size(560, 760),
  Widget? metadata,
  double textScale = 1,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            key: _pageKey,
            size: size,
            child: ArtworkOverviewLayout(
              artwork: const FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(key: _imageKey, width: 300, height: 1600),
              ),
              metadata:
                  metadata ??
                  const SizedBox(
                    key: _metadataKey,
                    height: 220,
                    child: Text('Title, ID, author and tags'),
                  ),
            ),
          ),
        ),
      ),
    ),
  );
}

void expectWithin(Rect child, Rect page) {
  const tolerance = .001;
  expect(child.left, greaterThanOrEqualTo(page.left - tolerance));
  expect(child.top, greaterThanOrEqualTo(page.top - tolerance));
  expect(child.right, lessThanOrEqualTo(page.right + tolerance));
  expect(child.bottom, lessThanOrEqualTo(page.bottom + tolerance));
}

void main() {
  testWidgets('long portrait shrinks into the space above natural metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(overview());

    final page = tester.getRect(find.byKey(_pageKey));
    final image = tester.getRect(find.byKey(_imageKey));
    final metadata = tester.getRect(find.byKey(_metadataKey));
    expectWithin(image, page);
    expectWithin(metadata, page);
    expect(image.height, closeTo(540, .001));
    expect(image.width / image.height, closeTo(300 / 1600, .001));
    expect(metadata.height, 220);
    expect(image.bottom, lessThanOrEqualTo(metadata.top));
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long tags and large text fit a small landscape without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var taps = 0;
      await tester.pumpWidget(
        overview(
          size: const Size(360, 160),
          textScale: 2,
          metadata: Column(
            key: _metadataKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A long artwork title and author'),
              Wrap(
                spacing: 8,
                children: List.generate(
                  24,
                  (index) => Text('#Long-tag-$index'),
                ),
              ),
              TextButton(onPressed: () => taps++, child: const Text('Author')),
            ],
          ),
        ),
      );

      final page = tester.getRect(find.byKey(_pageKey));
      final image = tester.getRect(find.byKey(_imageKey));
      final metadata = tester.getRect(find.byKey(_metadataKey));
      expectWithin(image, page);
      expectWithin(metadata, page);
      expect(image.height, closeTo(32, .001));
      expect(image.bottom, lessThanOrEqualTo(metadata.top + .001));
      await tester.tap(find.text('Author'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('metadata changes resize the image in the same layout frame', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final height = ValueNotifier(100.0);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: height,
        builder: (_, value, __) => overview(
          metadata: SizedBox(key: _metadataKey, height: value),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(_imageKey)).height, closeTo(660, .001));

    height.value = 340;
    await tester.pump();
    final image = tester.getRect(find.byKey(_imageKey));
    final metadata = tester.getRect(find.byKey(_metadataKey));
    expect(image.height, closeTo(420, .001));
    expect(metadata.height, 340);
    expect(image.bottom, lessThanOrEqualTo(metadata.top));
    expectWithin(metadata, tester.getRect(find.byKey(_pageKey)));
    expect(tester.takeException(), isNull);
  });
}
