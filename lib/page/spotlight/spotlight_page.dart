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
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/spotlight_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/hello/recom/spotlight_store.dart';

class SpotLightPage extends StatefulWidget {
  @override
  State<SpotLightPage> createState() => _SpotLightPageState();
}

class _SpotLightPageState extends State<SpotLightPage> {
  final SpotlightStore _spotlightStore = SpotlightStore(null);
  bool _loading = true;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<bool> _refresh() async {
    final success = await _spotlightStore.fetch();
    if (mounted) {
      setState(() {
        _loading = false;
        if (success) _resetToken++;
      });
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18n.of(context).spotlight)),
      body: Observer(
        builder: (_) {
          return SwipePagedGrid(
            itemCount: _spotlightStore.articles.length,
            crossAxisCount: _crossAxisCount(context),
            rowExtent: 238,
            isLoading: _loading,
            resetToken: _resetToken,
            hasMore: () => _spotlightStore.nextUrl?.isNotEmpty == true,
            onLoadMore: _spotlightStore.next,
            onRefresh: _refresh,
            loadingLabel: I18n.of(context).footer_loading,
            emptyLabel: I18n.of(context).no_more_data,
            retryLabel: I18n.of(context).loading_failed_retry_message,
            refreshLabel: I18n.of(context).refresh,
            itemBuilder: (context, index) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 180,
                  height: 238,
                  child: SpotlightCard(
                    spotlight: _spotlightStore.articles[index],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _crossAxisCount(BuildContext context) {
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    if (portrait ? userSetting.crossAdapt : userSetting.hCrossAdapt) {
      final width =
          (portrait
                  ? userSetting.crossAdapterWidth
                  : userSetting.hCrossAdapterWidth)
              .toDouble()
              .clamp(50.0, 2160.0);
      return max(1, (MediaQuery.of(context).size.width / width).floor());
    }
    return portrait ? userSetting.crossCount : userSetting.hCrossCount;
  }
}
