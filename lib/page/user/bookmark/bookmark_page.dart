/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/component/sort_group.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_page.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/user/bookmark/tag/user_bookmark_tag_page.dart';
import 'package:pixez/page/user/works/works_page.dart';

class BookmarkPage extends StatefulWidget {
  final int id;
  final String restrict;
  final bool isNested;

  const BookmarkPage({
    Key? key,
    required this.id,
    this.restrict = "public",
    this.isNested = false,
  }) : super(key: key);

  @override
  _BookmarkPageState createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>
    with AutomaticKeepAliveClientMixin {
  late LightSource futureGet;
  String restrict = 'public';
  late StreamSubscription<String> subscription;
  String? currentTag;
  int _resetToken = 0;

  @override
  void initState() {
    restrict = widget.restrict;
    futureGet = ApiForceSource(
      futureGet: (e) => apiClient.getBookmarksIllust(widget.id, restrict, null),
    );
    super.initState();
    subscription = topStore.topStream.listen((event) {
      if (event == "302") {
        setState(() => _resetToken++);
      }
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (accountStore.now != null) {
      if (int.parse(accountStore.now!.userId) == widget.id) {
        return Stack(
          children: [
            LightingList(
              source: futureGet,
              resetToken: _resetToken,
              footerTrailingSpace: 72,
              isNested: widget.isNested,
              header: Container(height: 45),
            ),
            buildTopChip(context),
          ],
        );
      }
      return LightingList(
        isNested: widget.isNested,
        resetToken: _resetToken,
        footerTrailingSpace: 72,
        source: futureGet,
      );
    } else {
      return Container();
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget buildTopChip(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SortGroup(
            children: [I18n.of(context).public, I18n.of(context).private],
            onChange: (index) {
              if (index == 0)
                setState(() {
                  futureGet = ApiForceSource(
                    futureGet: (bool e) => apiClient.getBookmarksIllust(
                      widget.id,
                      restrict = 'public',
                      currentTag,
                    ),
                  );
                });
              if (index == 1)
                setState(() {
                  futureGet = ApiForceSource(
                    futureGet: (bool e) => apiClient.getBookmarksIllust(
                      widget.id,
                      restrict = 'private',
                      currentTag,
                    ),
                  );
                });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserBookmarkTagPage(currentTag: currentTag),
                  ),
                );
                if (result != null) {
                  String? tag = result['tag'];
                  String selectedRestrict = result['restrict'];
                  setState(() {
                    restrict = selectedRestrict;
                    currentTag = tag;
                    futureGet = ApiForceSource(
                      futureGet: (bool e) => apiClient.getBookmarksIllust(
                        widget.id,
                        restrict,
                        tag,
                      ),
                    );
                  });
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Chip(
                label: Row(
                  children: [
                    Icon(Icons.tag, size: 18),
                    if (currentTag != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          currentTag!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                backgroundColor: Theme.of(context).cardColor,
                elevation: 4.0,
                padding: EdgeInsets.all(0.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookMarkNestedPage extends StatefulWidget {
  final int id;
  final LightingStore store;
  final String portal;

  const BookMarkNestedPage({
    Key? key,
    required this.id,
    required this.store,
    required this.portal,
  }) : super(key: key);

  @override
  State<BookMarkNestedPage> createState() => _BookMarkNestedPageState();
}

class _BookMarkNestedPageState extends State<BookMarkNestedPage>
    with AutomaticKeepAliveClientMixin {
  int _resetToken = 0;
  late LightingStore _store;
  String restrict = 'public';
  String? currentTag;

  @override
  void initState() {
    _store = widget.store;
    super.initState();
    _store.fetch();
  }

  Widget _buildWorks(BuildContext context) {
    _store.iStores.removeWhere(
      (element) => element.illusts!.hateByUser(ai: false),
    );
    final itemCount = _store.iStores.length;
    final isLoading = _store.refreshing;
    final columns = _crossAxisCount();
    final userIsMe =
        accountStore.now != null &&
        accountStore.now!.userId == widget.id.toString();
    return SafeArea(
      top: false,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        key: PageStorageKey<String>(widget.portal),
        slivers: [
          SliverPinnedOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          if (userIsMe)
            SliverPersistentHeader(
              delegate: SliverChipDelegate(
                Center(child: buildTopChip(context)),
              ),
              pinned: true,
            ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              // The nested viewport already excludes the expanded profile.
              // Reserve exactly the visible area after the pinned filters.
              final height = max(0.0, constraints.remainingPaintExtent);
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: height,
                  // A very tall profile header can temporarily leave too
                  // little space for a card. Reveal it by collapsing the header.
                  child: height < 160
                      ? null
                      : SwipePagedGrid(
                          usePageLayout: true,
                          itemCount: itemCount,
                          crossAxisCount: columns,
                          resetToken: _resetToken,
                          isLoading: isLoading,
                          hasMore: () => _store.nextUrl?.isNotEmpty == true,
                          onLoadMore: _loadMore,
                          onRefresh: () => _store.fetch(force: true),
                          loadingLabel: I18n.of(context).footer_loading,
                          emptyLabel: I18n.of(context).no_more_data,
                          retryLabel: I18n.of(
                            context,
                          ).loading_failed_retry_message,
                          refreshLabel: I18n.of(context).refresh,
                          itemBuilder: (context, index) => IllustCard(
                            lightingStore: _store,
                            store: _store.iStores[index],
                            iStores: _store.iStores,
                            fitToCell: true,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _loadMore() async {
    final success = await _store.fetchNext();
    if (mounted) setState(() {});
    return success;
  }

  Widget _buildContent(context) {
    return _store.errorMessage != null && _store.iStores.isEmpty
        ? _buildErrorContent(context)
        : _buildWorks(context);
  }

  Widget _buildErrorContent(context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(height: 50),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              ':(',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          TextButton(
            onPressed: () {
              _store.fetch(force: true);
            },
            child: Text(I18n.of(context).retry),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              (_store.errorMessage?.contains("400") == true
                  ? '${I18n.of(context).error_400_hint}\n ${_store.errorMessage}'
                  : '${_store.errorMessage}'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Observer(
      builder: (_) {
        return _buildContent(context);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  int _crossAxisCount() {
    if (MediaQuery.of(context).orientation == Orientation.portrait
        ? userSetting.crossAdapt
        : userSetting.hCrossAdapt) {
      return _buildSliderValue();
    }
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? userSetting.crossCount
        : userSetting.hCrossCount;
  }

  int _buildSliderValue() {
    final currentValue =
        (MediaQuery.of(context).orientation == Orientation.portrait
                ? userSetting.crossAdapterWidth
                : userSetting.hCrossAdapterWidth)
            .toDouble();
    var nowAdaptWidth = max(currentValue, 50.0);
    nowAdaptWidth = min(nowAdaptWidth, 2160.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final result = max(screenWidth / nowAdaptWidth, 1.0).toInt();
    return result;
  }

  Widget buildTopChip(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SortGroup(
            children: [I18n.of(context).public, I18n.of(context).private],
            onChange: (index) {
              if (index == 0) {
                setState(() => _resetToken++);
                _store.source = ApiForceSource(
                  futureGet: (bool e) => apiClient.getBookmarksIllust(
                    widget.id,
                    restrict = 'public',
                    currentTag,
                  ),
                );
                _store.fetch();
              } else if (index == 1) {
                setState(() => _resetToken++);
                _store.source = ApiForceSource(
                  futureGet: (bool e) => apiClient.getBookmarksIllust(
                    widget.id,
                    restrict = 'private',
                    currentTag,
                  ),
                );
                _store.fetch();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserBookmarkTagPage(currentTag: currentTag),
                  ),
                );
                if (result != null) {
                  String? tag = result['tag'];
                  String selectedRestrict = result['restrict'];
                  setState(() {
                    restrict = selectedRestrict;
                    currentTag = tag;
                    _resetToken++;
                    _store.source = ApiForceSource(
                      futureGet: (bool e) => apiClient.getBookmarksIllust(
                        widget.id,
                        restrict,
                        tag,
                      ),
                    );
                    _store.fetch();
                  });
                }
              },
              child: Chip(
                label: Row(
                  children: [
                    Icon(Icons.sort),
                    Text(currentTag ?? I18n.of(context).all),
                  ],
                ),
                backgroundColor: Theme.of(context).cardColor,
                elevation: 4.0,
                padding: EdgeInsets.all(0.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
