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
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';

class LightingList extends StatefulWidget {
  final LightSource source;
  final Widget? header;
  final bool? isNested;
  final ScrollController? scrollController;
  final String? portal;
  final bool? ai;
  final bool Function(Illusts)? filter;
  final int resetToken;
  final double footerTrailingSpace;

  const LightingList({
    super.key,
    required this.source,
    this.header,
    this.isNested,
    this.scrollController,
    this.portal,
    this.ai,
    this.filter,
    this.resetToken = 0,
    this.footerTrailingSpace = 0,
  });

  @override
  State<LightingList> createState() => _LightingListState();
}

class _LightingListState extends State<LightingList> {
  late LightingStore _store;

  void _createStore() {
    _store = LightingStore(widget.source)..portal = widget.portal;
    unawaited(_store.fetch());
  }

  @override
  void initState() {
    super.initState();
    _createStore();
  }

  @override
  void didUpdateWidget(covariant LightingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      // A new query has its own store, so a pending old response cannot replace
      // the results of a changed search, ranking date or bookmark tag.
      _store.dispose();
      _createStore();
    }
    _store.portal = widget.portal;
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<bool> _loadMore() async {
    final store = _store;
    final success = await store.fetchNext();
    // A response containing only muted works can still change nextUrl.
    if (mounted && identical(store, _store)) setState(() {});
    return success;
  }

  int _columns(BuildContext context, double width) {
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final adaptive = portrait
        ? userSetting.crossAdapt
        : userSetting.hCrossAdapt;
    if (!adaptive) {
      return max(
        1,
        portrait ? userSetting.crossCount : userSetting.hCrossCount,
      );
    }
    final targetWidth =
        (portrait
                ? userSetting.crossAdapterWidth
                : userSetting.hCrossAdapterWidth)
            .toDouble()
            .clamp(50.0, 2160.0);
    return max(1, (width / targetWidth).floor());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: widget.isNested != true,
      child: Column(
        children: [
          if (widget.header != null) widget.header!,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Observer(
                  builder: (_) {
                    _store.iStores.removeWhere((element) {
                      final illust = element.illusts!;
                      return illust.hateByUser(ai: widget.ai ?? false) ||
                          (widget.filter != null && !widget.filter!(illust));
                    });
                    return SwipePagedGrid(
                      key: ObjectKey(_store),
                      itemCount: _store.iStores.length,
                      crossAxisCount: _columns(context, constraints.maxWidth),
                      resetToken: widget.resetToken,
                      footerTrailingSpace: widget.footerTrailingSpace,
                      isLoading: _store.refreshing,
                      hasMore: () => _store.nextUrl?.isNotEmpty == true,
                      onLoadMore: _loadMore,
                      onRefresh: () => _store.fetch(force: true),
                      loadingLabel: I18n.of(context).footer_loading,
                      emptyLabel: _store.errorMessage != null
                          ? I18n.of(context).loading_failed_retry_message
                          : I18n.of(context).no_more_data,
                      retryLabel: I18n.of(context).loading_failed_retry_message,
                      refreshLabel: I18n.of(context).refresh,
                      itemBuilder: (context, index) => IllustCard(
                        store: _store.iStores[index],
                        lightingStore: _store,
                        iStores: _store.iStores,
                        fitToCell: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
