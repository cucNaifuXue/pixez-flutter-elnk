import 'package:material_ui/material_ui.dart';

/// Page dimensions shared by the artwork grids inside a feed tab.
class PagedGridLayout extends InheritedWidget {
  final int rows;
  final int columns;

  const PagedGridLayout({
    super.key,
    required this.rows,
    required this.columns,
    required super.child,
  }) : assert(rows >= 1 && rows <= 4),
       assert(columns >= 1 && columns <= 4);

  static PagedGridLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PagedGridLayout>();

  @override
  bool updateShouldNotify(PagedGridLayout oldWidget) =>
      rows != oldWidget.rows || columns != oldWidget.columns;
}
