/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:math';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/painer_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/hello/recom/recom_user_store.dart';

class RecomUserPage extends StatefulWidget {
  final RecomUserStore? recomUserStore;

  const RecomUserPage({Key? key, this.recomUserStore}) : super(key: key);

  @override
  _RecomUserPageState createState() => _RecomUserPageState();
}

class _RecomUserPageState extends State<RecomUserPage> {
  late EasyRefreshController _refreshController;
  late RecomUserStore _recomUserStore;
  bool _loading = false;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _refreshController = EasyRefreshController(
      controlFinishLoad: true,
      controlFinishRefresh: true,
    );
    _recomUserStore =
        widget.recomUserStore ?? RecomUserStore(_refreshController);
    _recomUserStore.controller = _refreshController;
    if (widget.recomUserStore == null) {
      _loading = true;
      _refresh();
    }
  }

  Future<bool> _refresh() async {
    final success = await _recomUserStore.fetch();
    if (mounted) {
      setState(() {
        _loading = false;
        if (success) _resetToken++;
      });
    }
    return success;
  }

  @override
  void dispose() {
    _recomUserStore.controller = null;
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18n.of(context).recommend_for_you)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = max(1, (constraints.maxWidth / 600).ceil());
          return Observer(
            builder: (_) {
              return SwipePagedGrid(
                itemCount: _recomUserStore.users.length,
                crossAxisCount: columns,
                rowExtent:
                    constraints.maxWidth / columns / 3 +
                    110 * MediaQuery.textScalerOf(context).scale(1),
                resetToken: _resetToken,
                isLoading: _loading,
                hasMore: () => _recomUserStore.nextUrl?.isNotEmpty == true,
                onLoadMore: _recomUserStore.next,
                onRefresh: _refresh,
                loadingLabel: I18n.of(context).footer_loading,
                emptyLabel: I18n.of(context).no_more_data,
                retryLabel: I18n.of(context).loading_failed_retry_message,
                refreshLabel: I18n.of(context).refresh,
                itemBuilder: (context, index) => PainterCard(
                  key: ValueKey(_recomUserStore.users[index].user.id),
                  user: _recomUserStore.users[index],
                  paged: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
