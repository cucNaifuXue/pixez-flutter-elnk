import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/swipe_paged_grid.dart';
import 'package:pixez/i18n.dart';

/// Keeps both tag sections within the space below the fixed search bar.
class SearchTagPanel extends StatefulWidget {
  final int tagCount;
  final int historyCount;
  final IndexedWidgetBuilder tagBuilder;
  final IndexedWidgetBuilder historyBuilder;
  final Future<bool> Function() onRefresh;
  final VoidCallback onClearHistory;
  final bool isLoading;
  final bool hasError;

  const SearchTagPanel({
    super.key,
    required this.tagCount,
    required this.historyCount,
    required this.tagBuilder,
    required this.historyBuilder,
    required this.onRefresh,
    required this.onClearHistory,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  State<SearchTagPanel> createState() => _SearchTagPanelState();
}

class _SearchTagPanelState extends State<SearchTagPanel> {
  bool _showHistory = false;

  @override
  void didUpdateWidget(covariant SearchTagPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyCount == 0) _showHistory = false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = I18n.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _showHistory ? strings.history : strings.recommand_tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
              ),
              if (widget.historyCount > 0)
                TextButton(
                  key: const ValueKey('search-tag-section'),
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  child: Text(
                    _showHistory ? strings.recommand_tag : strings.history,
                  ),
                ),
              if (_showHistory)
                IconButton(
                  tooltip: strings.clear_search_tag_history,
                  onPressed: widget.onClearHistory,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = max(3, (constraints.maxWidth / 200).floor());
              final scale = MediaQuery.textScalerOf(context).scale(1);
              return IndexedStack(
                index: _showHistory ? 1 : 0,
                children: [
                  SwipePagedGrid(
                    key: const ValueKey('recommended-tag-pages'),
                    itemCount: widget.tagCount,
                    crossAxisCount: columns,
                    rowExtent: max(constraints.maxWidth / columns, 100 * scale),
                    itemBuilder: widget.tagBuilder,
                    isLoading: widget.isLoading,
                    hasMore: () => false,
                    onLoadMore: () async => true,
                    onRefresh: widget.onRefresh,
                    loadingLabel: strings.footer_loading,
                    emptyLabel: widget.hasError
                        ? strings.loading_failed_retry_message
                        : strings.no_more_data,
                    retryLabel: strings.loading_failed_retry_message,
                    refreshLabel: strings.refresh,
                    footerTrailingSpace: 72,
                  ),
                  SwipePagedGrid(
                    key: const ValueKey('search-history-pages'),
                    itemCount: widget.historyCount,
                    crossAxisCount: columns,
                    rowExtent: 52 * scale,
                    itemBuilder: widget.historyBuilder,
                    hasMore: () => false,
                    onLoadMore: () async => true,
                    onRefresh: widget.onRefresh,
                    loadingLabel: strings.footer_loading,
                    emptyLabel: strings.no_more_data,
                    retryLabel: strings.loading_failed_retry_message,
                    refreshLabel: strings.refresh,
                    footerTrailingSpace: 72,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
