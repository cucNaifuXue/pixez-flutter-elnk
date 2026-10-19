import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/artwork_page_route.dart';

void main() {
  testWidgets('artwork opens and returns immediately without a hero flight', (
    tester,
  ) async {
    late ArtworkPageRoute<void> route;
    const imageKey = ValueKey('artwork-image');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Hero(
                  tag: 'artwork',
                  child: SizedBox.square(dimension: 40),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    route = ArtworkPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Align(
                          alignment: Alignment.topRight,
                          child: Hero(
                            tag: 'artwork',
                            child: SizedBox(
                              key: imageKey,
                              width: 200,
                              height: 400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);
    expect(
      tester.getRect(find.byKey(imageKey)),
      const Rect.fromLTWH(600, 0, 200, 400),
    );
    final heroMode = tester.widget<HeroMode>(
      find.ancestor(of: find.byKey(imageKey), matching: find.byType(HeroMode)),
    );
    expect(heroMode.enabled, isFalse);

    route.navigator!.pop();
    await tester.pump();
    expect(find.byKey(imageKey), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
