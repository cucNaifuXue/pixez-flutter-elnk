import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/artwork_image_controls.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/picture/illust_overview_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const _firstImageUrl = 'https://example.invalid/overview-first.png';
const _secondImageUrl = 'https://example.invalid/overview-second.png';
const _title = 'Portrait artwork with a title that can wrap onto another line';
const _author = 'Overview fixture artist';

Map<String, Object?> _imageUrls(String url) => {
  'square_medium': url,
  'medium': url,
  'large': url,
  'original': url,
};

Illusts _artwork({bool multipleImages = false}) => Illusts.fromJson({
  'id': 12345678,
  'title': _title,
  'type': 'illust',
  'image_urls': _imageUrls(_firstImageUrl),
  'caption': '<p>Full fixture description remains available.</p>',
  'restrict': 0,
  'user': {
    'id': 99,
    'name': _author,
    'account': 'test-artist',
    'profile_image_urls': {'medium': _firstImageUrl},
    'is_followed': false,
  },
  'tags': List.generate(
    10,
    (index) => {'name': 'fixture-tag-$index', 'translated_name': 'Tag $index'},
  ),
  'tools': <Object>[],
  'create_date': '2026-01-01T00:00:00+00:00',
  'page_count': multipleImages ? 2 : 1,
  'width': 600,
  'height': 1600,
  'sanity_level': 2,
  'x_restrict': 0,
  'meta_single_page': {'original_image_url': _firstImageUrl},
  'meta_pages': multipleImages
      ? [
          {'image_urls': _imageUrls(_firstImageUrl)},
          {'image_urls': _imageUrls(_secondImageUrl)},
        ]
      : <Object>[],
  'total_view': 1200,
  'total_bookmarks': 321,
  'is_bookmarked': false,
  'visible': true,
  'is_muted': false,
  'illust_ai_type': 1,
  'total_comments': 8,
});

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: [AppLocalizations.delegate],
  supportedLocales: const [Locale('en')],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

Finder get _lastTag => find.text('#fixture-tag-9 Tag 9');

void _expectMetadataVisible(WidgetTester tester) {
  final pageBounds = tester.getRect(find.byType(IllustOverviewPage));
  for (final finder in [
    find.text(_title),
    find.textContaining('12345678'),
    find.text(_author),
    _lastTag,
  ]) {
    expect(finder, findsOneWidget);
    final bounds = tester.getRect(finder);
    expect(bounds.left, greaterThanOrEqualTo(pageBounds.left - .01));
    expect(bounds.top, greaterThanOrEqualTo(pageBounds.top - .01));
    expect(bounds.right, lessThanOrEqualTo(pageBounds.right + .01));
    expect(bounds.bottom, lessThanOrEqualTo(pageBounds.bottom + .01));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => pixivCacheManager = null);

  setUp(() async {
    for (final url in [_firstImageUrl, _secondImageUrl]) {
      final image = await createTestImage(width: 600, height: 1600);
      PaintingBinding.instance.imageCache.putIfAbsent(
        CachedNetworkImageProvider(url),
        () =>
            OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
      );
    }
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'portrait overview fits image and all metadata on one static page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(992, 1323));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final artwork = _artwork();
      var aboutLoads = 0;
      await tester.pumpWidget(
        _app(
          IllustOverviewPage(
            illusts: artwork,
            illustStore: IllustStore(artwork.id, artwork),
            loadAbout: () => aboutLoads++,
            onLongPressImage: (_) {},
            onShowRelated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectMetadataVisible(tester);
      expect(find.byType(Scrollable), findsNothing);
      expect(aboutLoads, 1);
      final image = tester.widget<PixivImage>(find.byType(PixivImage).first);
      expect(image.fit, BoxFit.contain);
      final imageBounds = tester.getRect(find.byType(PixivImage).first);
      expect(imageBounds.height, greaterThan(96));
      expect(
        imageBounds.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text(_title)).dy),
      );
      expect(find.textContaining('Full fixture description'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Full fixture description', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.text('View comments(8)'), findsOneWidget);
      expect(aboutLoads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'multi-image controls retain metadata and operate on selected image',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final artwork = _artwork(multipleImages: true);
      var aboutLoads = 0;
      final longPressed = <int>[];
      await tester.pumpWidget(
        _app(
          IllustOverviewPage(
            illusts: artwork,
            illustStore: IllustStore(artwork.id, artwork),
            loadAbout: () => aboutLoads++,
            onLongPressImage: longPressed.add,
            onShowRelated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('图 1/2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('图 2/2'), findsOneWidget);
      expect(
        tester.widget<PixivImage>(find.byType(PixivImage).first).url,
        _secondImageUrl,
      );
      _expectMetadataVisible(tester);
      await tester.longPress(find.byType(PixivImage).first);
      expect(longPressed, [1]);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('图 1/2'), findsOneWidget);
      expect(
        tester.widget<PixivImage>(find.byType(PixivImage).first).url,
        _firstImageUrl,
      );
      expect(aboutLoads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('embedded overview shares image controls with the page footer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(992, 1323));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final artwork = _artwork(multipleImages: true);
    final images = ArtworkImageController()
      ..configure(artworkId: artwork.id, imageCount: artwork.metaPages.length);
    final pages = SwipePagedGridController();
    await tester.pumpWidget(
      _app(
        SwipePagedGrid(
          controller: pages,
          itemCount: 8,
          crossAxisCount: 2,
          firstPageBuilder: (_) => IllustOverviewPage(
            illusts: artwork,
            illustStore: IllustStore(artwork.id, artwork),
            imageController: images,
            embedded: true,
            loadAbout: () {},
            onLongPressImage: (_) {},
            onShowRelated: pages.nextPage,
          ),
          imageNavigation: ArtworkImageControls(controller: images),
          footerAction: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),
          itemBuilder: (_, index) => Text('recommendation-$index'),
          hasMore: () => false,
          onLoadMore: () async => true,
          onRefresh: () async => true,
          loadingLabel: 'Loading',
          emptyLabel: 'Empty',
          retryLabel: 'Retry',
          refreshLabel: 'Refresh',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('页 1/3'), findsOneWidget);
    expect(find.text('图 1/2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(IllustOverviewPage),
        matching: find.byType(ArtworkImageControls),
      ),
      findsNothing,
    );
    expect(
      tester.getRect(find.byType(ArtworkImageControls)).center.dy,
      tester.getRect(find.byTooltip('Refresh')).center.dy,
    );
    await tester.tap(find.byTooltip('下一张图'));
    await tester.pumpAndSettle();
    expect(find.text('图 2/2'), findsOneWidget);
    expect(
      tester.widget<PixivImage>(find.byType(PixivImage).first).url,
      _secondImageUrl,
    );
    _expectMetadataVisible(tester);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(find.text('页 2/3'), findsOneWidget);
    expect(find.byType(ArtworkImageControls), findsNothing);
    await tester.tap(find.byIcon(Icons.first_page));
    await tester.pump();
    expect(find.text('图 2/2'), findsOneWidget);
    expect(
      tester.widget<PixivImage>(find.byType(PixivImage).first).url,
      _secondImageUrl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pages.dispose();
    images.dispose();
  });

  testWidgets('upward swipe opens recommendations only after finger release', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final artwork = _artwork();
    var relatedRequests = 0;
    await tester.pumpWidget(
      _app(
        IllustOverviewPage(
          illusts: artwork,
          illustStore: IllustStore(artwork.id, artwork),
          loadAbout: () {},
          onLongPressImage: (_) {},
          onShowRelated: () => relatedRequests++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final titleBefore = tester.getRect(find.text(_title));
    final imageBefore = tester.getRect(find.byType(PixivImage).first);
    final gesture = await tester.startGesture(imageBefore.center);
    await gesture.moveBy(const Offset(0, -25));
    await gesture.moveBy(const Offset(0, -95));
    await tester.pump();
    expect(relatedRequests, 0);
    expect(tester.getRect(find.text(_title)), titleBefore);
    expect(tester.getRect(find.byType(PixivImage).first), imageBefore);
    await gesture.up();
    await tester.pump();
    expect(relatedRequests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('landscape overview fits scaled metadata beside the artwork', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final artwork = _artwork();
    await tester.pumpWidget(
      _app(
        IllustOverviewPage(
          illusts: artwork,
          illustStore: IllustStore(artwork.id, artwork),
          loadAbout: () {},
          onLongPressImage: (_) {},
          onShowRelated: () {},
          sideBySide: true,
        ),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    _expectMetadataVisible(tester);
    expect(find.byType(Scrollable), findsNothing);
    final imageBounds = tester.getRect(find.byType(PixivImage).first);
    expect(
      imageBounds.right,
      lessThan(tester.getTopLeft(find.text(_title)).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
