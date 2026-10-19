import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/paged_grid_layout.dart';

/// Controls navigation without introducing an animated scroll position.
class SwipePagedGridController {
  _SwipePagedGridState? _state;
  bool _disposed = false;

  void nextPage() => _state?._next();

  void firstPage() => _state?._first();

  void restoreReadingPage() => _state?._restoreReadingPage();

  void _attach(_SwipePagedGridState state) {
    if (!_disposed) _state = state;
  }

  void _detach(_SwipePagedGridState state) {
    if (identical(_state, state)) _state = null;
  }

  void dispose() {
    _disposed = true;
    _state = null;
  }
}

/// A grid that changes whole pages after a vertical swipe, without scrolling
/// the artwork through intermediate frames.
class SwipePagedGrid extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;
  final bool usePageLayout;
  final IndexedWidgetBuilder itemBuilder;
  final bool Function() hasMore;
  final Future<bool> Function() onLoadMore;
  final Future<bool> Function() onRefresh;
  final bool isLoading;
  final int resetToken;
  final String loadingLabel;
  final String emptyLabel;
  final String retryLabel;
  final String refreshLabel;
  final double? rowExtent;
  final double footerTrailingSpace;
  final VoidCallback? onInteractionStart;
  final WidgetBuilder? firstPageBuilder;
  final SwipePagedGridController? controller;
  final String firstPageLabel;
  final String restorePageLabel;
  final Widget? imageNavigation;
  final Widget? footerAction;

  const SwipePagedGrid({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
    this.usePageLayout = false,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRefresh,
    required this.loadingLabel,
    required this.emptyLabel,
    required this.retryLabel,
    required this.refreshLabel,
    this.isLoading = false,
    this.resetToken = 0,
    this.rowExtent,
    this.footerTrailingSpace = 0,
    this.onInteractionStart,
    this.firstPageBuilder,
    this.controller,
    this.firstPageLabel = '回到第1页',
    this.restorePageLabel = '返回刚才的推荐页',
    this.imageNavigation,
    this.footerAction,
  });

  @override
  State<SwipePagedGrid> createState() => _SwipePagedGridState();
}

class _SwipePagedGridState extends State<SwipePagedGrid> {
  int _page = 0;
  int _pageSize = 1;
  double _dragDistance = 0;
  bool _busy = false;
  bool _failed = false;
  int? _lastContentFirstItem;
  int _navigationRevision = 0;

  bool get _blocked => _busy || widget.isLoading;
  int get _firstPageCount => widget.firstPageBuilder == null ? 0 : 1;
  bool get _isFirstPage => _firstPageCount > 0 && _page == 0;
  int get _contentPageCount => max(1, (widget.itemCount / _pageSize).ceil());
  int get _pageCount => _firstPageCount + _contentPageCount;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipePagedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.resetToken != widget.resetToken ||
        (oldWidget.firstPageBuilder == null) !=
            (widget.firstPageBuilder == null)) {
      _page = 0;
      _failed = false;
      _lastContentFirstItem = null;
      _navigationRevision++;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _showPage(int page) {
    // A load can notify its parent before this state's widget receives the new
    // item count. Clamp against the updated count in build, not this frame.
    _page = max(0, page);
    _failed = false;
    _navigationRevision++;
    if (_firstPageCount > 0 && !_isFirstPage) {
      _lastContentFirstItem = (_page - _firstPageCount) * _pageSize;
    }
  }

  void _first() {
    widget.onInteractionStart?.call();
    if (_page > 0 && (_firstPageCount > 0 || !_blocked)) {
      setState(() => _showPage(0));
    }
  }

  void _restoreReadingPage() {
    widget.onInteractionStart?.call();
    final firstItem = _lastContentFirstItem;
    if (!_isFirstPage || firstItem == null) return;
    setState(() {
      // Keep the item anchor when a new row/column layout moves it into a
      // differently numbered recommendation page.
      _page = min(_firstPageCount + firstItem ~/ _pageSize, _pageCount - 1);
      _failed = false;
      _navigationRevision++;
    });
  }

  Future<void> _refresh() async {
    widget.onInteractionStart?.call();
    if (_blocked) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final resetToken = widget.resetToken;
    var success = false;
    try {
      success = await widget.onRefresh();
    } catch (_) {
      success = false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (widget.resetToken == resetToken) {
            _failed = !success;
            if (success) {
              _page = 0;
              _lastContentFirstItem = null;
              _navigationRevision++;
            }
          }
        });
      }
    }
  }

  Future<void> _next() async {
    widget.onInteractionStart?.call();
    if (_blocked) return;
    if (_page + 1 < _pageCount) {
      setState(() => _showPage(_page + 1));
      return;
    }
    if (!widget.hasMore()) return;
    final previousCount = widget.itemCount;
    final previousPage = _page;
    final previousPageSize = _pageSize;
    final resetToken = widget.resetToken;
    final navigationRevision = _navigationRevision;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var success = false;
    try {
      success = await widget.onLoadMore();
    } catch (_) {
      success = false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (widget.resetToken != resetToken) return;
          _failed = !success;
          // Fill a partial last page before advancing, so newly appended
          // artworks in its empty cells are never skipped.
          if (success &&
              previousCount > 0 &&
              previousCount % previousPageSize == 0 &&
              _page == previousPage &&
              _pageSize == previousPageSize &&
              _navigationRevision == navigationRevision &&
              widget.resetToken == resetToken) {
            _showPage(_page + 1);
          }
        });
      }
    }
  }

  void _previous() {
    widget.onInteractionStart?.call();
    if (_page > 0 && (!_blocked || _firstPageCount > 0)) {
      setState(() => _showPage(_page - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.usePageLayout
        ? PagedGridLayout.maybeOf(context)
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        const footerHeight = 48.0;
        final columns = layout?.columns ?? max(1, widget.crossAxisCount);
        final cellWidth = constraints.maxWidth / columns;
        // Reserve room for the existing title, author and series labels.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final rows =
            layout?.rows ??
            max(
              1,
              ((constraints.maxHeight - footerHeight) /
                      max(1.0, widget.rowExtent ?? cellWidth + 80 * textScale))
                  .floor(),
            );
        final pageSize = columns * rows;
        if (pageSize != _pageSize) {
          if (!_isFirstPage) {
            final firstItem = _firstPageCount > 0
                ? (_lastContentFirstItem ??
                      (_page - _firstPageCount) * _pageSize)
                : _page * _pageSize;
            _page = _firstPageCount + firstItem ~/ pageSize;
          }
          _pageSize = pageSize;
        }
        _page = min(_page, _pageCount - 1);
        final start = max(0, _page - _firstPageCount) * _pageSize;
        final grid = widget.itemCount == 0
            ? Center(
                child: TextButton(
                  onPressed: _blocked ? null : _refresh,
                  child: Text(
                    _blocked
                        ? widget.loadingLabel
                        : (_failed ? widget.retryLabel : widget.emptyLabel),
                  ),
                ),
              )
            : Column(
                children: List.generate(rows, (row) {
                  return Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(columns, (column) {
                        final index = start + row * columns + column;
                        return Expanded(
                          child: index < widget.itemCount
                              ? widget.itemBuilder(context, index)
                              : const SizedBox.shrink(),
                        );
                      }),
                    ),
                  );
                }),
              );
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) {
                  widget.onInteractionStart?.call();
                  _dragDistance = 0;
                },
                onVerticalDragUpdate: (details) {
                  _dragDistance += details.primaryDelta ?? 0;
                },
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_dragDistance < -40 || velocity < -400) {
                    _next();
                  } else if (_dragDistance > 40 || velocity > 400) {
                    _previous();
                  }
                  _dragDistance = 0;
                },
                child: widget.firstPageBuilder == null
                    ? grid
                    : IndexedStack(
                        index: _isFirstPage ? 0 : 1,
                        sizing: StackFit.expand,
                        children: [widget.firstPageBuilder!(context), grid],
                      ),
              ),
            ),
            _buildFooter(context, footerHeight),
          ],
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, double height) {
    final localizations = MaterialLocalizations.of(context);
    final imageNavigation = _isFirstPage ? widget.imageNavigation : null;
    final empty = widget.itemCount == 0 && _firstPageCount == 0;
    final pageLabel = _firstPageCount > 0
        ? '页 ${_page + 1}/$_pageCount${widget.hasMore() ? '+' : ''}'
        : '${empty ? 0 : _page + 1} / ${empty ? 0 : _pageCount}'
              '${widget.hasMore() ? '+' : ''}';
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(right: widget.footerTrailingSpace),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final footer = SizedBox(
              width: imageNavigation == null
                  ? constraints.maxWidth
                  : max(560.0, constraints.maxWidth),
              height: height,
              child: Row(
                children: [
                  IconButton(
                    tooltip: widget.refreshLabel,
                    onPressed: _blocked ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  if (_firstPageCount > 0) ...[
                    IconButton(
                      tooltip: widget.firstPageLabel,
                      onPressed: _isFirstPage ? null : _first,
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      tooltip: widget.restorePageLabel,
                      onPressed: _isFirstPage && _lastContentFirstItem != null
                          ? _restoreReadingPage
                          : null,
                      icon: const Icon(Icons.history),
                    ),
                  ],
                  IconButton(
                    tooltip: localizations.previousPageTooltip,
                    onPressed: _page > 0 && (!_blocked || _firstPageCount > 0)
                        ? _previous
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _blocked
                            ? widget.loadingLabel
                            : (_failed ? widget.retryLabel : pageLabel),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: localizations.nextPageTooltip,
                    onPressed:
                        !_blocked &&
                            (_page + 1 < _pageCount || widget.hasMore())
                        ? _next
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  if (imageNavigation != null) imageNavigation,
                  if (widget.footerAction != null) widget.footerAction!,
                ],
              ),
            );
            // Keep both image and page navigation in the same footer on phones.
            return imageNavigation == null
                ? footer
                : FittedBox(fit: BoxFit.scaleDown, child: footer);
          },
        ),
      ),
    );
  }
}
