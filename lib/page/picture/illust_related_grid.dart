import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';

/// Shares one page sequence and footer between the artwork and related works.
class IllustRelatedGrid extends StatelessWidget {
  final LightingStore store;
  final WidgetBuilder firstPageBuilder;
  final SwipePagedGridController? controller;
  final Widget? imageNavigation;
  final Widget? footerAction;

  const IllustRelatedGrid({
    super.key,
    required this.store,
    required this.firstPageBuilder,
    this.controller,
    this.imageNavigation,
    this.footerAction,
  });

  @override
  Widget build(BuildContext context) {
    final strings = I18n.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Observer(
        builder: (_) {
          store.iStores.removeWhere((item) => item.illusts!.hateByUser());
          final artworks = store.iStores;
          return SwipePagedGrid(
            key: ObjectKey(store),
            controller: controller,
            imageNavigation: imageNavigation,
            footerAction: footerAction,
            firstPageBuilder: firstPageBuilder,
            itemCount: artworks.length,
            crossAxisCount: min(
              3,
              max(1, (constraints.maxWidth / 180).floor()),
            ),
            isLoading: store.refreshing,
            resetToken: identityHashCode(store),
            hasMore: () => store.nextUrl?.isNotEmpty ?? false,
            onLoadMore: store.fetchNext,
            onRefresh: () => store.fetch(force: true),
            loadingLabel: strings.footer_loading,
            emptyLabel: store.errorMessage != null
                ? strings.retry
                : strings.no_more,
            retryLabel: strings.retry,
            refreshLabel: strings.refresh,
            itemBuilder: (context, index) => IllustCard(
              store: artworks[index],
              lightingStore: store,
              iStores: artworks,
              fitToCell: true,
            ),
          );
        },
      ),
    );
  }
}
