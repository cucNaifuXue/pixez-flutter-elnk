import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps an artwork and its information together in one bounded page.
///
/// [metadata] is measured at its natural height first; [artwork] receives the
/// remaining space and should contain its image within those bounds. Only when
/// the information cannot fit is it scaled down, leaving a small image area.
class ArtworkOverviewLayout extends MultiChildRenderObjectWidget {
  ArtworkOverviewLayout({
    super.key,
    required Widget artwork,
    required Widget metadata,
  }) : super(children: [artwork, metadata]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderArtworkOverviewLayout();
}

class _ArtworkOverviewParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderArtworkOverviewLayout extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  double _metadataScale = 1;

  RenderBox get _artwork => firstChild!;
  RenderBox get _metadata => lastChild!;

  Matrix4 get _metadataTransform {
    final offset =
        (_metadata.parentData! as ContainerBoxParentData<RenderBox>).offset;
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(_metadataScale, _metadataScale, 1, 1);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _ArtworkOverviewParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    return constraints.biggest;
  }

  @override
  void performLayout() {
    assert(childCount == 2);
    size = computeDryLayout(constraints);
    _metadata.layout(
      BoxConstraints.tightFor(width: size.width),
      parentUsesSize: true,
    );

    final minimumArtworkHeight = math.min(96.0, size.height * .2);
    final metadataHeight = _metadata.size.height;
    _metadataScale = metadataHeight == 0
        ? 1
        : math.min(1, (size.height - minimumArtworkHeight) / metadataHeight);
    final artworkHeight = size.height - metadataHeight * _metadataScale;
    _artwork.layout(
      BoxConstraints.tight(Size(size.width, artworkHeight)),
      parentUsesSize: true,
    );

    (_artwork.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset.zero;
    (_metadata.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset(
          (size.width - _metadata.size.width * _metadataScale) / 2,
          artworkHeight,
        );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(_artwork, offset);
    context.pushTransform(needsCompositing, offset, _metadataTransform, (
      context,
      offset,
    ) {
      context.paintChild(_metadata, offset);
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
          transform: _metadataTransform,
          position: position,
          hitTest: (result, position) =>
              _metadata.hitTest(result, position: position),
        ) ||
        result.addWithPaintOffset(
          offset: Offset.zero,
          position: position,
          hitTest: (result, position) =>
              _artwork.hitTest(result, position: position),
        );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (child == _metadata) {
      transform.multiply(_metadataTransform);
    }
  }
}
