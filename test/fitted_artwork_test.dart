import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/fitted_artwork.dart';

const artworkKey = ValueKey('artwork');

Rect paintedArtwork(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(artworkKey));
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

void main() {
  testWidgets('long artwork fits above details and remains tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              height: 580,
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 56)),
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () => taps++,
                      child: const FittedArtwork(
                        maxHeight: 500,
                        child: SizedBox(
                          key: artworkKey,
                          width: 1000,
                          height: 5000,
                          child: ColoredBox(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Text('details')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final image = paintedArtwork(tester);
    expect(image.top, 56);
    expect(image.bottom, 556);
    expect(image.width / image.height, closeTo(0.2, 0.001));
    expect(tester.getTopLeft(find.text('details')).dy, image.bottom);
    await tester.tapAt(image.center);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide artwork fits a split panel and responds to resizing', (
    tester,
  ) async {
    Future<void> mount(double width, double height) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: FittedArtwork(
                        maxHeight: height,
                        child: const SizedBox(
                          key: artworkKey,
                          width: 3000,
                          height: 900,
                          child: ColoredBox(color: Colors.blue),
                        ),
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

    await mount(320, 550);
    var image = paintedArtwork(tester);
    expect(image.width, closeTo(320, 0.001));
    expect(image.height, closeTo(96, 0.001));
    expect(image.top, greaterThanOrEqualTo(0));
    expect(image.bottom, lessThanOrEqualTo(550));

    await mount(600, 120);
    image = paintedArtwork(tester);
    expect(image.height, closeTo(120, 0.001));
    expect(image.width, closeTo(400, 0.001));
    expect(image.left, greaterThanOrEqualTo(0));
    expect(image.right, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });
}
