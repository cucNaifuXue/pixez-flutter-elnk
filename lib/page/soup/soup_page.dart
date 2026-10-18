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

import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/null_hero.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/amwork.dart';
import 'package:pixez/models/spotlight_response.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/soup/soup_store.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SoupPage extends StatefulWidget {
  final String url;
  final SpotlightArticle? spotlight;
  final String? heroTag;

  SoupPage({Key? key, required this.url, required this.spotlight, this.heroTag})
    : super(key: key);

  @override
  _SoupPageState createState() => _SoupPageState();
}

class _SoupPageState extends State<SoupPage> {
  final SoupStore _soupStore = SoupStore();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  bool _loading = true;
  bool _failed = false;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<bool> _refresh() async {
    final success = await _soupStore.fetch(widget.url);
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !success;
        if (success) _resetToken++;
      });
    }
    return success;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _alignGrid() {
    final target = _gridKey.currentContext?.findRenderObject();
    if (target == null || !_scrollController.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;
    final pinnedHeight = kToolbarHeight + MediaQuery.paddingOf(context).top;
    final offset = viewport.getOffsetToReveal(target, 0).offset - pinnedHeight;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pinnedHeight =
              kToolbarHeight + MediaQuery.paddingOf(context).top;
          final gridHeight = max(48.0, constraints.maxHeight - pinnedHeight);
          return Observer(
            builder: (context) {
              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: widget.spotlight == null ? null : 200,
                    flexibleSpace: widget.spotlight == null
                        ? null
                        : FlexibleSpaceBar(
                            centerTitle: true,
                            title: Text(
                              widget.spotlight!.pureTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            background: NullHero(
                              tag: widget.heroTag,
                              child: PixivImage(
                                widget.spotlight!.thumbnail,
                                fit: BoxFit.cover,
                                height: 200,
                                fade: false,
                              ),
                            ),
                          ),
                    actions: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).firstPageTooltip,
                        icon: const Icon(Icons.vertical_align_top),
                        onPressed: () {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.minScrollExtent,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => launchUrlString(
                          widget.spotlight?.articleUrl ?? widget.url,
                        ),
                      ),
                    ],
                  ),
                  if (_soupStore.description?.isNotEmpty == true)
                    SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_soupStore.description!),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      key: _gridKey,
                      height: gridHeight,
                      child: SafeArea(
                        top: false,
                        child: SwipePagedGrid(
                          itemCount: _soupStore.amWorks.length,
                          crossAxisCount: 1,
                          resetToken: _resetToken,
                          isLoading: _loading,
                          hasMore: () => false,
                          onLoadMore: () async => true,
                          onRefresh: _refresh,
                          onInteractionStart: _alignGrid,
                          loadingLabel: I18n.of(context).footer_loading,
                          emptyLabel: _failed
                              ? I18n.of(context).loading_failed_retry_message
                              : I18n.of(context).no_more_data,
                          retryLabel: I18n.of(
                            context,
                          ).loading_failed_retry_message,
                          refreshLabel: I18n.of(context).refresh,
                          itemBuilder: (context, index) =>
                              _buildWork(_soupStore.amWorks[index]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWork(AmWork amWork) {
    return InkWell(
      onTap: () {
        final id = int.parse(Uri.parse(amWork.arworkLink!).pathSegments.last);
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) =>
                IllustLightingPage(id: id, store: IllustStore(id, null)),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: PainterAvatar(
                url: amWork.userImage!,
                id: int.parse(Uri.parse(amWork.userLink!).pathSegments.last),
              ),
              title: Text(
                amWork.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                amWork.user ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: PixivImage(
                amWork.showImage!,
                fit: BoxFit.contain,
                fade: false,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
