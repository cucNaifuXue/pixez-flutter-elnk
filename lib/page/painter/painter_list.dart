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

import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/painer_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/page/painter/painter_list_store.dart';

class PainterList extends StatefulWidget {
  final FutureGet futureGet;
  final bool isNovel;
  final Widget? header;
  final double footerTrailingSpace;

  const PainterList({
    Key? key,
    required this.futureGet,
    this.isNovel = false,
    this.header,
    this.footerTrailingSpace = 0,
  }) : super(key: key);

  @override
  _PainterListState createState() => _PainterListState();
}

class _PainterListState extends State<PainterList> {
  late EasyRefreshController _easyRefreshController;
  late PainterListStore _painterListStore;
  bool _loading = true;
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _easyRefreshController = EasyRefreshController(
      controlFinishLoad: true,
      controlFinishRefresh: true,
    );
    _painterListStore = PainterListStore(
      _easyRefreshController,
      widget.futureGet,
    );
    _fetch();
  }

  Future<bool> _fetch() async {
    final success = await _painterListStore.fetch();
    if (mounted) {
      setState(() {
        _loading = false;
        if (success) _resetToken++;
      });
    }
    return success;
  }

  @override
  void didUpdateWidget(PainterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.futureGet != widget.futureGet) {
      _painterListStore.source = widget.futureGet;
      _loading = true;
      _fetch();
    }
  }

  @override
  void dispose() {
    _easyRefreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.header != null) widget.header!,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = max(1, (constraints.maxWidth / 600).ceil());
              return Observer(
                builder: (_) {
                  return SwipePagedGrid(
                    footerTrailingSpace: widget.footerTrailingSpace,
                    itemCount: _painterListStore.users.length,
                    crossAxisCount: columns,
                    rowExtent:
                        constraints.maxWidth / columns / 3 +
                        110 * MediaQuery.textScalerOf(context).scale(1),
                    resetToken: _resetToken,
                    isLoading: _loading,
                    hasMore: () =>
                        _painterListStore.nextUrl?.isNotEmpty == true,
                    onLoadMore: _painterListStore.next,
                    onRefresh: _fetch,
                    loadingLabel: I18n.of(context).footer_loading,
                    emptyLabel: I18n.of(context).no_more_data,
                    retryLabel: I18n.of(context).loading_failed_retry_message,
                    refreshLabel: I18n.of(context).refresh,
                    itemBuilder: (context, index) => PainterCard(
                      key: ValueKey(_painterListStore.users[index].user.id),
                      user: _painterListStore.users[index],
                      isNovel: widget.isNovel,
                      paged: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
