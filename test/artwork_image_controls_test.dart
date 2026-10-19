import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/artwork_image_controls.dart';

void main() {
  test('selection stays in bounds and resets for another artwork', () {
    final controller = ArtworkImageController();
    addTearDown(controller.dispose);
    controller.configure(artworkId: 10, imageCount: 4);
    controller.next();
    controller.next();
    expect(controller.index, 2);

    controller.configure(artworkId: 10, imageCount: 2);
    expect(controller.index, 1);
    controller.next();
    expect(controller.index, 1);
    controller.previous();
    controller.previous();
    expect(controller.index, 0);

    controller.next();
    controller.configure(artworkId: 20, imageCount: 8);
    expect(controller.index, 0);
    expect(controller.count, 8);
    controller.configure(artworkId: 20, imageCount: 0);
    expect(controller.count, 1);
    expect(controller.index, 0);
  });

  testWidgets('single image keeps its counter and disables both arrows', (
    tester,
  ) async {
    final controller = ArtworkImageController()
      ..configure(artworkId: 10, imageCount: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArtworkImageControls(controller: controller)),
      ),
    );

    expect(find.text('图 1/1'), findsOneWidget);
    for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
      final button = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNull);
    }
    expect(tester.getSize(find.byType(ArtworkImageControls)).height, 48);
  });

  testWidgets(
    'image controls change selection independently of page controls',
    (tester) async {
      final controller = ArtworkImageController()
        ..configure(artworkId: 10, imageCount: 3);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const Text('页 1/6'),
                ArtworkImageControls(controller: controller, compact: true),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('下一张图'));
      await tester.pump();
      expect(find.text('图 2/3'), findsOneWidget);
      expect(find.text('页 1/6'), findsOneWidget);
      await tester.tap(find.byTooltip('上一张图'));
      await tester.pump();
      expect(find.text('图 1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
