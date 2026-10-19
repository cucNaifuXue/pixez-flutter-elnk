import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/paged_grid_layout.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/hello/new/new_page.dart';
import 'package:pixez/page/user/bookmark/bookmark_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const _imageUrl = 'https://example.invalid/bookmark-test.png';

Map<String, Object?> _artwork(int index) => {
  'id': 1000 + index,
  'title': 'bookmark-$index',
  'type': 'illust',
  'image_urls': {
    'square_medium': _imageUrl,
    'medium': _imageUrl,
    'large': _imageUrl,
  },
  'caption': '',
  'restrict': 0,
  'user': {
    'id': 99,
    'name': 'Test artist',
    'account': 'test-artist',
    'profile_image_urls': {'medium': _imageUrl},
  },
  'tags': <Object>[],
  'tools': <Object>[],
  'create_date': '2026-01-01T00:00:00+00:00',
  'page_count': 1,
  'width': 600,
  'height': 800,
  'sanity_level': 2,
  'x_restrict': 0,
  'meta_single_page': {'original_image_url': _imageUrl},
  'meta_pages': <Object>[],
  'total_view': 1,
  'total_bookmarks': 1,
  'is_bookmarked': true,
  'visible': true,
  'is_muted': false,
  'illust_ai_type': 1,
};

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: PagedGridLayout(rows: 1, columns: 2, child: child)),
  ),
);

Widget _tabHost(Widget bookmark, {bool nested = false}) => DefaultTabController(
  length: 4,
  child: Builder(
    builder: (context) {
      const tabs = TabBar(
        tabs: [
          Tab(text: 'Bookmarks'),
          Tab(text: 'Other 1'),
          Tab(text: 'Other 2'),
          Tab(text: 'Far away'),
        ],
      );
      final body = TabBarView(
        children: [
          bookmark,
          const Center(child: Text('Other content 1')),
          const Center(child: Text('Other content 2')),
          const Center(child: Text('Other content 3')),
        ],
      );
      if (nested) {
        return NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: const SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                bottom: tabs,
              ),
            ),
          ],
          body: body,
        );
      }
      return Column(
        children: [
          tabs,
          Expanded(child: body),
        ],
      );
    },
  ),
);

Future<void> _advance(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
  await tester.pumpAndSettle();
}

List<int> _visibleArtworkIds(WidgetTester tester) => tester
    .widgetList<IllustCard>(find.byType(IllustCard))
    .map((card) => card.store.id)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio originalClient;
  late Dio fixtureClient;
  late AccountPersist? originalAccount;
  late int bookmarkRequests;

  setUpAll(() {
    // Widgets use the normal image provider, with one in-memory fixture image.
    pixivCacheManager = null;
  });

  setUp(() async {
    originalClient = apiClient.httpClient;
    originalAccount = accountStore.now;
    bookmarkRequests = 0;
    fixtureClient = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final isBookmark = options.path == '/v1/user/bookmarks/illust';
            if (isBookmark) bookmarkRequests++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'illusts': isBookmark
                      ? List.generate(24, _artwork)
                      : <Object>[],
                  'user_previews': <Object>[],
                  'series': <Object>[],
                  'next_url': null,
                },
              ),
            );
          },
        ),
      );
    apiClient.httpClient = fixtureClient;
    accountStore.now = AccountPersist(
      userId: '7',
      userImage: _imageUrl,
      accessToken: 'test-token',
      refreshToken: '',
      deviceToken: '',
      passWord: '',
      name: 'Test reader',
      account: 'test-reader',
      mailAddress: 'reader@example.invalid',
      isPremium: 0,
      xRestrict: 0,
      isMailAuthorized: 1,
    );
    final image = await createTestImage();
    PaintingBinding.instance.imageCache.putIfAbsent(
      const CachedNetworkImageProvider(_imageUrl),
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
    );
  });

  tearDown(() {
    apiClient.httpClient = originalClient;
    accountStore.now = originalAccount;
    fixtureClient.close();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('my bookmarks retain page and loaded works across distant tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(_tabHost(const BookmarkPage(id: 7))));
    await tester.pumpAndSettle();
    await _advance(tester);
    await _advance(tester);
    final bookmarkState = tester.state(find.byType(BookmarkPage));
    final gridState = tester.state(find.byType(SwipePagedGrid));
    expect(_visibleArtworkIds(tester), [1004, 1005]);
    expect(find.text('3 / 12'), findsOneWidget);
    expect(bookmarkRequests, 1);

    await tester.tap(find.text('Far away'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(BookmarkPage)), same(bookmarkState));
    expect(tester.state(find.byType(SwipePagedGrid)), same(gridState));
    expect(_visibleArtworkIds(tester), [1004, 1005]);
    expect(find.text('3 / 12'), findsOneWidget);
    expect(bookmarkRequests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'profile bookmarks retain page without refetching on tab return',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LightingStore(
        ApiSource(
          futureGet: () => apiClient.getBookmarksIllust(99, 'public', null),
        ),
      );
      await tester.pumpWidget(
        _app(
          _tabHost(
            BookMarkNestedPage(id: 99, store: store, portal: 'test-bookmarks'),
            nested: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _advance(tester);
      await _advance(tester);
      expect(_visibleArtworkIds(tester), [1004, 1005]);
      expect(bookmarkRequests, 1);

      await tester.tap(find.text('Far away'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      expect(_visibleArtworkIds(tester), [1004, 1005]);
      expect(find.text('3 / 12'), findsOneWidget);
      expect(bookmarkRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('quick-view tab switches preserve progress; reselect resets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = <String>[];
    final subscription = topStore.topStream.listen(events.add);
    addTearDown(subscription.cancel);
    await tester.pumpWidget(_app(const NewPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(events.where((event) => event == '302'), isEmpty);
    await _advance(tester);
    await _advance(tester);
    expect(_visibleArtworkIds(tester), [1004, 1005]);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(events.where((event) => event == '302'), isEmpty);
    expect(_visibleArtworkIds(tester), [1004, 1005]);
    expect(find.text('3 / 12'), findsOneWidget);
    expect(bookmarkRequests, 1);

    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    expect(events.where((event) => event == '302'), ['302']);
    expect(_visibleArtworkIds(tester), [1000, 1001]);
    expect(find.text('1 / 12'), findsOneWidget);
    expect(bookmarkRequests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
