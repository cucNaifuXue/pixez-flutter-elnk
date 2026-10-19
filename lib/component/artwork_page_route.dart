import 'package:material_ui/material_ui.dart';

/// Artwork opens at its final size immediately, including its image heroes.
class ArtworkPageRoute<T> extends PageRouteBuilder<T> {
  ArtworkPageRoute({required WidgetBuilder builder, RouteSettings? settings})
    : super(
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            HeroMode(enabled: false, child: builder(context)),
      );
}
