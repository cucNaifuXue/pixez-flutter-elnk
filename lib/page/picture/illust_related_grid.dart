import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';

/// Keeps related artworks within one viewport while the surrounding artwork
/// and description remain reachable through the detail button.
class IllustRelatedGrid extends StatefulWidget {
  final LightingStore store;
  final ScrollController scrollController;
  final VoidCallback onShowDetails;

  const IllustRelatedGrid({
    super.key,
    required this.store,
    required this.scrollController,
    required this.onShowDetails,
  });

  @override
  State<IllustRelatedGrid> createState() => _IllustRelatedGridState();
}

class _IllustRelatedGridState extends State<IllustRelatedGrid> {
  final _viewportKey = GlobalKey();
  double? _targetOffset() {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (!widget.scrollController.hasClients ||
        renderObject == null ||
        !renderObject.attached)
      return null;
    final viewport = RenderAbstractViewport.of(renderObject);
    final position = widget.scrollController.position;
    return viewport
        .getOffsetToReveal(renderObject, 0)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  void _reveal() {
    final target = _targetOffset();
    if (target != null && (widget.scrollController.offset - target).abs() > 1) {
      widget.scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final strings = I18n.of(context);
    final mediaQuery = MediaQuery.of(context);
    return SizedBox(
      key: _viewportKey,
      height: mediaQuery.size.height,
      child: Padding(
        // Detail pages draw their toolbar over the scroll view.
        padding: EdgeInsets.only(
          top: mediaQuery.padding.top + kToolbarHeight,
          bottom: mediaQuery.padding.bottom,
        ),
        child: Column(
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onShowDetails,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: Text(strings.detail),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _reveal,
                    icon: const Icon(Icons.open_in_full),
                    label: Text(strings.recommend),
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Observer(
                    builder: (_) {
                      store.iStores.removeWhere(
                        (item) => item.illusts!.hateByUser(),
                      );
                      final artworks = store.iStores;
                      return SwipePagedGrid(
                        key: ObjectKey(store),
                        onInteractionStart: _reveal,
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
                        footerTrailingSpace: 72,
                        itemBuilder: (context, index) {
                          return IllustCard(
                            store: artworks[index],
                            lightingStore: store,
                            iStores: artworks,
                            fitToCell: true,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
