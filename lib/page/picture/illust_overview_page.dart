import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/artwork_image_controls.dart';
import 'package:pixez/component/artwork_overview_layout.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/illust_cacher.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/picture/illust_detail_content.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/page/picture/ugoira_loader.dart';
import 'package:pixez/page/user/user_store.dart';
import 'package:pixez/page/zoom/photo_zoom_page.dart';

/// One stationary page containing the artwork and its identifying information.
class IllustOverviewPage extends StatefulWidget {
  final Illusts illusts;
  final IllustStore illustStore;
  final UserStore? userStore;
  final String? heroString;
  final VoidCallback loadAbout;
  final ValueChanged<int> onLongPressImage;
  final VoidCallback onShowRelated;
  final bool sideBySide;
  final bool embedded;
  final ArtworkImageController? imageController;

  const IllustOverviewPage({
    super.key,
    required this.illusts,
    required this.illustStore,
    this.userStore,
    this.heroString,
    required this.loadAbout,
    required this.onLongPressImage,
    required this.onShowRelated,
    this.sideBySide = false,
    this.embedded = false,
    this.imageController,
  });

  @override
  State<IllustOverviewPage> createState() => _IllustOverviewPageState();
}

class _IllustOverviewPageState extends State<IllustOverviewPage> {
  late ArtworkImageController _imageController;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _imageController = widget.imageController ?? ArtworkImageController();
    if (widget.imageController == null) {
      _imageController.configure(
        artworkId: widget.illusts.id,
        imageCount: _imageCount,
      );
    } else {
      _synchronizeController();
    }
  }

  @override
  void didUpdateWidget(covariant IllustOverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageController != widget.imageController) {
      if (oldWidget.imageController == null) _imageController.dispose();
      _imageController = widget.imageController ?? ArtworkImageController();
    }
    _synchronizeController();
  }

  int get _imageCount => max(1, widget.illusts.metaPages.length);
  int get _imageIndex => min(_imageController.index, _imageCount - 1);

  void _synchronizeController() {
    final controller = _imageController;
    // The shared footer can already be mounted when artwork data changes.
    // Notify it after this build rather than marking a sibling dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _imageController) return;
      controller.configure(
        artworkId: widget.illusts.id,
        imageCount: _imageCount,
      );
    });
  }

  @override
  void dispose() {
    if (widget.imageController == null) _imageController.dispose();
    super.dispose();
  }

  Widget _artwork(BuildContext context) {
    final data = widget.illusts;
    if (data.type == 'ugoira') {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: data.width.toDouble(),
            height: data.height.toDouble(),
            child: UgoiraLoader(id: data.id, illusts: data),
          ),
        ),
      );
    }
    final isManga = data.type == 'manga';
    final quality = isManga
        ? userSetting.mangaQuality
        : userSetting.pictureQuality;
    final hasPages = data.metaPages.isNotEmpty;
    final url = hasPages
        ? (isManga
              ? data.managaDetailImageUrl(_imageIndex)
              : data.illustDetailImageUrl(_imageIndex))
        : (isManga ? data.managaDetailUrl : data.illustDetailUrl);
    final thumbnail = hasPages
        ? data.metaPages[_imageIndex].imageUrls!.medium
        : data.imageUrls.medium;
    final image = KeyedSubtree(
      key: ValueKey('${data.id}_$_imageIndex'),
      child: PixivImage(
        url,
        fit: BoxFit.contain,
        fade: false,
        placeWidget: thumbnail == url
            ? Center(child: Text(I18n.of(context).footer_loading))
            : PixivImage(thumbnail, fit: BoxFit.contain, fade: false),
        cacheHeaderData: PixEzCacheHeaderData(
          key: '${data.id}_$_imageIndex',
          quality: IllustQualityExtension.fromValue(quality),
        ),
      ),
    );
    return InkWell(
      onLongPress: () => widget.onLongPressImage(_imageIndex),
      onTap: () => Leader.push(
        context,
        PhotoZoomPage(
          index: _imageIndex,
          illusts: data,
          illustStore: widget.illustStore,
        ),
      ),
      child: SizedBox.expand(child: image),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _imageController,
    builder: (context, _) => _buildContents(context),
  );

  Widget _buildContents(BuildContext context) {
    final metadata = IllustDetailContent(
      key: ValueKey(widget.illusts.id),
      illusts: widget.illusts,
      userStore: widget.userStore,
      illustStore: widget.illustStore,
      loadAbout: widget.loadAbout,
      overview: true,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: widget.embedded ? null : (_) => _dragDistance = 0,
      onVerticalDragUpdate: widget.embedded
          ? null
          : (details) => _dragDistance += details.primaryDelta ?? 0,
      onVerticalDragEnd: widget.embedded
          ? null
          : (details) {
              if (_dragDistance < -40 ||
                  (details.primaryVelocity ?? 0) < -400) {
                widget.onShowRelated();
              }
            },
      child: Column(
        children: [
          Expanded(
            child: widget.sideBySide
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _artwork(context)),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: max(1, (constraints.maxWidth - 12) * .4),
                                child: metadata,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : ArtworkOverviewLayout(
                    artwork: _artwork(context),
                    metadata: metadata,
                  ),
          ),
          if (!widget.embedded)
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  ArtworkImageControls(controller: _imageController),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onShowRelated,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: Text(I18n.of(context).recommend),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
