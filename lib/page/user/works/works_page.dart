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

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/component/sort_group.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/network/api_client.dart';

class WorksPage extends StatefulWidget {
  final int id;
  final String portal;
  final LightingStore store;
  final String workType;
  final ValueChanged<String> onWorkTypeChange;

  const WorksPage({
    Key? key,
    required this.id,
    required this.store,
    required this.portal,
    required this.workType,
    required this.onWorkTypeChange,
  }) : super(key: key);

  @override
  _WorksPageState createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  late LightingStore _store;
  int _resetToken = 0;
  late String _workType;

  @override
  void initState() {
    _store = widget.store;
    super.initState();
    _store.fetch();
    _workType = widget.workType;
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        return _buildContent(context);
      },
    );
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

  Widget _buildWorks(BuildContext context) {
    _store.iStores.removeWhere(
      (element) => element.illusts!.hateByUser(ai: false),
    );
    final itemCount = _store.iStores.length;
    final isLoading = _store.refreshing;
    final columns = _crossAxisCount();
    return SafeArea(
      top: false,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        key: PageStorageKey<String>(widget.portal),
        slivers: [
          SliverPinnedOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPersistentHeader(
            delegate: SliverChipDelegate(
              Center(child: _buildSortChip()),
              height: 52,
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

  Widget _buildSortChip() {
    return SortGroup(
      onChange: (index) {
        final type = index == 0 ? 'illust' : 'manga';
        setState(() {
          _workType = type;
          _resetToken++;
        });
        widget.onWorkTypeChange(_workType);
        _store.source = ApiForceSource(
          futureGet: (bool e) => apiClient.getUserIllusts(widget.id, type),
        );
        _store.fetch();
      },
      children: [I18n.of(context).illust, I18n.of(context).manga],
      initIndex: _workType == 'illust' ? 0 : 1,
    );
  }
}

class SliverPinnedOverlapInjector extends SingleChildRenderObjectWidget {
  const SliverPinnedOverlapInjector({required this.handle, Key? key})
    : super(key: key);

  final SliverOverlapAbsorberHandle handle;

  @override
  RenderSliverPinnedOverlapInjector createRenderObject(BuildContext context) {
    return RenderSliverPinnedOverlapInjector(handle: handle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverPinnedOverlapInjector renderObject,
  ) {
    renderObject.handle = handle;
  }
}

class RenderSliverPinnedOverlapInjector extends RenderSliver {
  RenderSliverPinnedOverlapInjector({
    required SliverOverlapAbsorberHandle handle,
  }) : _handle = handle;

  double? _currentLayoutExtent;
  double? _currentMaxExtent;

  SliverOverlapAbsorberHandle get handle => _handle;
  SliverOverlapAbsorberHandle _handle;

  set handle(SliverOverlapAbsorberHandle value) {
    if (handle == value) return;
    if (attached) {
      handle.removeListener(markNeedsLayout);
    }
    _handle = value;
    if (attached) {
      handle.addListener(markNeedsLayout);
      if (handle.layoutExtent != _currentLayoutExtent ||
          handle.scrollExtent != _currentMaxExtent)
        markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    handle.addListener(markNeedsLayout);
    if (handle.layoutExtent != _currentLayoutExtent ||
        handle.scrollExtent != _currentMaxExtent)
      markNeedsLayout();
  }

  @override
  void detach() {
    handle.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    _currentLayoutExtent = handle.layoutExtent;

    final paintedExtent = min(
      _currentLayoutExtent!,
      constraints.remainingPaintExtent - constraints.overlap,
    );

    geometry = SliverGeometry(
      paintExtent: paintedExtent,
      maxPaintExtent: _currentLayoutExtent!,
      maxScrollObstructionExtent: _currentLayoutExtent!,
      paintOrigin: constraints.overlap,
      scrollExtent: _currentLayoutExtent!,
      layoutExtent: max(0, paintedExtent - constraints.scrollOffset),
      hasVisualOverflow: paintedExtent < _currentLayoutExtent!,
    );
  }
}

class SliverChipDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  double height = 45;

  SliverChipDelegate(this.child, {this.height = 45});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(SliverChipDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
