import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/component/null_hero.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/star_icon.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/series/illust_series_notifier.dart';
import 'package:pixez/page/user/users_page.dart';
import 'package:share_plus/share_plus.dart';

class IllustSeriesPage extends StatefulHookConsumerWidget {
  final int id;

  const IllustSeriesPage({super.key, required this.id});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _IllustSeriesPageState();
}

class _IllustSeriesPageState extends ConsumerState<IllustSeriesPage> {
  int _resetToken = 0;

  Future<bool> _refresh() async {
    final success = await ref
        .read(illustSeriesStoreProvider(widget.id).notifier)
        .fetch();
    if (success && mounted) setState(() => _resetToken++);
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(illustSeriesStoreProvider(widget.id));
    final detail = state.model?.illustSeriesDetail;
    final coverImageUrl = detail?.coverImageUrls?.medium;
    final profileUrl = detail?.user?.profileImageUrls?.medium;
    useEffect(() {
      Future.microtask(_refresh);
      return null;
    }, []);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (detail?.caption.isNotEmpty == true)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(detail!.title),
                  content: SingleChildScrollView(child: Text(detail.caption)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(I18n.of(context).ok),
                    ),
                  ],
                ),
              ),
            ),
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () {
                  final userId = detail?.user?.id;
                  final seriesId = detail?.id;
                  if (userId != null && seriesId != null) {
                    final box = context.findRenderObject() as RenderBox?;
                    final pos = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'https://www.pixiv.net/user/$userId/series/$seriesId',
                        sharePositionOrigin: pos,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.share),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (detail != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  if (coverImageUrl != null) ...[
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: PixivImage(
                        coverImageUrl,
                        fit: BoxFit.contain,
                        fade: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: detail.user == null
                          ? null
                          : () => Leader.push(
                              context,
                              UsersPage(id: detail.user!.id),
                            ),
                      child: Row(
                        children: [
                          if (profileUrl != null) ...[
                            ClipOval(
                              child: PixivImage(
                                profileUrl,
                                width: 24,
                                height: 24,
                                fade: false,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              detail.user?.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: state.watchlistAdded
                        ? I18n.of(context).watchlist_added
                        : I18n.of(context).add_to_watchlist,
                    icon: Icon(
                      state.watchlistAdded
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    onPressed: () {
                      final notifier = ref.read(
                        illustSeriesStoreProvider(widget.id).notifier,
                      );
                      if (state.watchlistAdded) {
                        notifier.removeWatchlist();
                      } else {
                        notifier.addWatchlist();
                      }
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: SwipePagedGrid(
              itemCount: state.illusts.length,
              crossAxisCount: 2,
              resetToken: _resetToken,
              isLoading: state.isLoading,
              hasMore: () =>
                  ref
                      .read(illustSeriesStoreProvider(widget.id))
                      .model
                      ?.nextUrl
                      ?.isNotEmpty ==
                  true,
              onLoadMore: () => ref
                  .read(illustSeriesStoreProvider(widget.id).notifier)
                  .loadMore(),
              onRefresh: _refresh,
              loadingLabel: I18n.of(context).footer_loading,
              emptyLabel: state.errorMessage == null
                  ? I18n.of(context).no_more_data
                  : I18n.of(context).loading_failed_retry_message,
              retryLabel: I18n.of(context).loading_failed_retry_message,
              refreshLabel: I18n.of(context).refresh,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.all(6),
                child: IllustSeriesItem(
                  key: ValueKey(state.illusts[index].id),
                  illust: state.illusts[index],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IllustSeriesItem extends StatefulHookConsumerWidget {
  final IllustStore illust;
  const IllustSeriesItem({super.key, required this.illust});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _State();
}

class _State extends ConsumerState<IllustSeriesItem> {
  late IllustStore illustStore = widget.illust;
  late Illusts illust = illustStore.illusts!;

  @override
  void didUpdateWidget(covariant IllustSeriesItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    illustStore = widget.illust;
    illust = illustStore.illusts!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Leader.push(
          context,
          IllustLightingPage(
            id: illust.id,
            store: IllustStore(illust.id, illust),
            heroString: "illust_series_${illust.id}",
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NullHero(
                    tag: "illust_series_${illust.id}",
                    child: PixivImage(
                      illust.imageUrls.large,
                      fit: BoxFit.contain,
                      fade: false,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  if (illust.metaPages.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.all(
                              Radius.circular(4.0),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2.0,
                              horizontal: 2.0,
                            ),
                            child: Text(
                              illust.metaPages.length.toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2),
          Container(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    illust.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    illustStore.star(
                      restrict: userSetting.defaultPrivateLike
                          ? "private"
                          : "public",
                    );
                  },
                  child: Observer(
                    builder: (context) {
                      return StarIcon(state: illustStore.state);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
