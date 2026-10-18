import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/watchlist_manga_model.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/series/illust_series_page.dart';
import 'package:pixez/page/watchlist/watchlist_notifier.dart';

class WatchlistPage extends StatefulHookConsumerWidget {
  const WatchlistPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _State();
}

class _State extends ConsumerState<WatchlistPage> {
  int _resetToken = 0;

  Future<bool> _refresh() async {
    final success = await ref.read(watchlistStoreProvider.notifier).fetch();
    if (success && mounted) setState(() => _resetToken++);
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistStoreProvider);
    useEffect(() {
      Future.microtask(_refresh);
      return null;
    }, []);
    return SwipePagedGrid(
      footerTrailingSpace: 72,
      itemCount: state.mangaSeries.length,
      crossAxisCount: 1,
      rowExtent: 176 * MediaQuery.textScalerOf(context).scale(1),
      resetToken: _resetToken,
      isLoading: state.isLoading,
      hasMore: () =>
          ref.read(watchlistStoreProvider).model?.nextUrl?.isNotEmpty == true,
      onRefresh: _refresh,
      onLoadMore: () => ref.read(watchlistStoreProvider.notifier).loadMore(),
      loadingLabel: I18n.of(context).footer_loading,
      emptyLabel: state.errorMessage == null
          ? I18n.of(context).no_more_data
          : I18n.of(context).loading_failed_retry_message,
      retryLabel: I18n.of(context).loading_failed_retry_message,
      refreshLabel: I18n.of(context).refresh,
      itemBuilder: (context, index) =>
          MangaSeriesItem(data: state.mangaSeries[index]),
    );
  }
}

class MangaSeriesItem extends StatelessWidget {
  final MangaSeriesModel data;
  const MangaSeriesItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Leader.push(context, IllustSeriesPage(id: data.id));
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 16),
              SizedBox(
                width: 120,
                height: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 120),
                    child: Stack(
                      children: [
                        PixivImage(
                          data.url ?? '',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          fade: false,
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            margin: EdgeInsets.only(top: 4, right: 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              '${data.publishedContentCount}',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.user?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      data.lastPublishedContentDatetime?.toShortTime() ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: () {
                          Leader.push(
                            context,
                            IllustLightingPage(id: data.latestContentId),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: Text(
                            I18n.of(context).view_latest,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
            ],
          ),
          Divider(),
        ],
      ),
    );
  }
}
