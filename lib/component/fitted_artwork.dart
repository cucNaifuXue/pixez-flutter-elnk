import 'package:material_ui/material_ui.dart';

/// Keeps the complete artwork visible even when its natural height is larger
/// than the detail page's viewport. The image retains its own aspect ratio.
class FittedArtwork extends StatelessWidget {
  const FittedArtwork({
    super.key,
    required this.maxHeight,
    required this.child,
  });

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FittedBox(fit: BoxFit.contain, child: child),
      ),
    );
  }
}
