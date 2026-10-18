import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// A grid that changes whole pages after a vertical swipe, without scrolling
/// the artwork through intermediate frames.
class SwipePagedGrid extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;
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

  const SwipePagedGrid({
    super.key,
    required this.itemCount,
    required this.crossAxisCount,
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

  bool get _blocked => _busy || widget.isLoading;
  int get _pageCount => max(1, (widget.itemCount / _pageSize).ceil());

  @override
  void didUpdateWidget(covariant SwipePagedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      _page = 0;
      _failed = false;
    }
  }

  Future<void> _refresh() async {
    widget.onInteractionStart?.call();
    if (_blocked) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var success = false;
    try {
      success = await widget.onRefresh();
    } catch (_) {
      success = false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = !success;
          if (success) _page = 0;
        });
      }
    }
  }

  Future<void> _next() async {
    widget.onInteractionStart?.call();
    if (_blocked) return;
    if (_page + 1 < _pageCount) {
      setState(() {
        _page++;
        _failed = false;
      });
      return;
    }
    if (!widget.hasMore()) return;
    final previousCount = widget.itemCount;
    final previousPage = _page;
    final previousPageSize = _pageSize;
    final resetToken = widget.resetToken;
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
          _failed = !success;
          // Fill a partial last page before advancing, so newly appended
          // artworks in its empty cells are never skipped.
          if (success &&
              previousCount > 0 &&
              previousCount % previousPageSize == 0 &&
              _page == previousPage &&
              _pageSize == previousPageSize &&
              widget.resetToken == resetToken) {
            _page++;
          }
        });
      }
    }
  }

  void _previous() {
    widget.onInteractionStart?.call();
    if (!_blocked && _page > 0) {
      setState(() {
        _page--;
        _failed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const footerHeight = 48.0;
        final columns = max(1, widget.crossAxisCount);
        final cellWidth = constraints.maxWidth / columns;
        // Reserve room for the existing title, author and series labels.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final rows = max(
          1,
          ((constraints.maxHeight - footerHeight) /
                  max(1.0, widget.rowExtent ?? cellWidth + 80 * textScale))
              .floor(),
        );
        final pageSize = columns * rows;
        if (pageSize != _pageSize) {
          final firstItem = _page * _pageSize;
          _pageSize = pageSize;
          _page = firstItem ~/ pageSize;
        }
        _page = min(_page, _pageCount - 1);
        final start = _page * _pageSize;
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
                child: widget.itemCount == 0
                    ? Center(
                        child: TextButton(
                          onPressed: _blocked ? null : _refresh,
                          child: Text(
                            _blocked
                                ? widget.loadingLabel
                                : (_failed
                                      ? widget.retryLabel
                                      : widget.emptyLabel),
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
                      ),
              ),
            ),
            SizedBox(
              height: footerHeight,
              child: Padding(
                padding: EdgeInsets.only(right: widget.footerTrailingSpace),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: widget.refreshLabel,
                      onPressed: _blocked ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: localizations.previousPageTooltip,
                      onPressed: !_blocked && _page > 0 ? _previous : null,
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    Expanded(
                      child: Text(
                        _blocked
                            ? widget.loadingLabel
                            : (_failed
                                  ? widget.retryLabel
                                  : '${widget.itemCount == 0 ? 0 : _page + 1} / '
                                        '${widget.itemCount == 0 ? 0 : _pageCount}'
                                        '${widget.hasMore() ? '+' : ''}'),
                        textAlign: TextAlign.center,
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
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
