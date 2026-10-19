import 'package:material_ui/material_ui.dart';

/// The image selected inside one artwork, independent of recommendation paging.
class ArtworkImageController extends ChangeNotifier {
  int? _artworkId;
  int _index = 0;
  int _count = 1;

  int get index => _index;
  int get count => _count;

  void configure({required int artworkId, required int imageCount}) {
    final count = imageCount < 1 ? 1 : imageCount;
    final index = _artworkId == artworkId ? _index.clamp(0, count - 1) : 0;
    if (_artworkId == artworkId && _count == count && _index == index) return;
    _artworkId = artworkId;
    _count = count;
    _index = index;
    notifyListeners();
  }

  void previous() {
    if (_index == 0) return;
    _index--;
    notifyListeners();
  }

  void next() {
    if (_index + 1 >= _count) return;
    _index++;
    notifyListeners();
  }
}

class ArtworkImageControls extends StatelessWidget {
  final ArtworkImageController controller;
  final bool compact;

  const ArtworkImageControls({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final extent = compact ? 40.0 : 48.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '上一张图',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: extent, height: 48),
            visualDensity: VisualDensity.standard,
            onPressed: controller.index > 0 ? controller.previous : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('图 ${controller.index + 1}/${controller.count}'),
          IconButton(
            tooltip: '下一张图',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: extent, height: 48),
            visualDensity: VisualDensity.standard,
            onPressed: controller.index + 1 < controller.count
                ? controller.next
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
    },
  );
}
