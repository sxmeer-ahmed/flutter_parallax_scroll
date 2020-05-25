import 'dart:typed_data';
import 'dart:ui';

import 'package:quiver/core.dart' as quiver;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vector_math/vector_math_64.dart';

class ParallaxBackgroundSettings {
  const ParallaxBackgroundSettings({
    this.deepEffectMatrix,
    this.shadowSigma = 0.0,
    this.shadowColor = const Color(0x00000000),
  });

  final Float64List deepEffectMatrix;
  final double shadowSigma;
  final Color shadowColor;

  static ParallaxBackgroundSettings predefined() {
    return ParallaxBackgroundSettings(
      deepEffectMatrix: (Matrix4.identity()
            ..scale(1.02, 1.010)
            ..translate(-9.0, 2))
          .storage,
      shadowColor: Color.fromARGB(110, 0, 0, 0),
      shadowSigma: 12,
    );
  }

  @override
  bool operator ==(Object other) =>
      (other is ParallaxBackgroundSettings) &&
      deepEffectMatrix == other.deepEffectMatrix &&
      shadowSigma == other.shadowSigma &&
      shadowColor == other.shadowColor;

  @override
  int get hashCode => quiver.hash3(deepEffectMatrix?.hashCode ?? 1,
      shadowColor?.hashCode ?? 2, shadowSigma?.hashCode ?? 3);
}

class ParallaxSvgBackground extends StatefulWidget {
  const ParallaxSvgBackground({
    Key key,
    @required this.svgAssetName,
    this.disableDeepEffect = false,
    this.disableShadow = false,
    this.translationOffset = Offset.zero,
    this.settings,
    this.autoXScale = false,
    this.autoYScale = false,
  });

  final bool disableDeepEffect;
  final bool disableShadow;
  final String svgAssetName;
  final Offset translationOffset;
  final ParallaxBackgroundSettings settings;
  final bool autoXScale;
  final bool autoYScale;

  @override
  _ParallaxSvgBackgroundState createState() => _ParallaxSvgBackgroundState();
}

class _ParallaxSvgBackgroundState extends State<ParallaxSvgBackground> {
  ParallaxBackgroundSettings get settings =>
      widget.settings ?? _predefinedSettings;

  bool _needsRepaint = false;
  ParallaxBackgroundSettings _predefinedSettings =
      ParallaxBackgroundSettings.predefined();

  @override
  void didUpdateWidget(ParallaxSvgBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _needsRepaint = widget.disableDeepEffect != oldWidget.disableDeepEffect ||
        widget.disableShadow != oldWidget.disableShadow ||
        widget.svgAssetName != oldWidget.svgAssetName ||
        oldWidget.settings != settings;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadSvg(),
      builder: (BuildContext context, AsyncSnapshot<DrawableRoot> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container();
        }

        Widget result = RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: false,
            painter: _ParallaxBackgroundPainter(
              drawableRoot: snapshot.data,
              translationOffset: widget.translationOffset,
              disableDeepEffect: widget.disableDeepEffect,
              disableShadow: widget.disableShadow,
              settings: widget.settings,
              needsRepaint: _needsRepaint,
              autoXScale: widget.autoXScale,
              autoYScale: widget.autoYScale,
              screenSize: MediaQuery.of(context).size,
            ),
          ),
        );
        if (_needsRepaint == true) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _needsRepaint = false));
        }
        return result;
      },
    );
  }

  Future<DrawableRoot> _loadSvg() {
    return DefaultAssetBundle.of(context)
        .loadString(widget.svgAssetName)
        .then<DrawableRoot>(
            (svgString) => svg.fromSvgString(svgString, svgString));
  }
}

class _ParallaxBackgroundPainter extends CustomPainter {
  const _ParallaxBackgroundPainter({
    this.disableDeepEffect,
    this.disableShadow,
    this.needsRepaint,
    this.drawableRoot,
    this.translationOffset,
    this.settings,
    this.autoXScale,
    this.autoYScale,
    this.screenSize,
  });

  final bool disableDeepEffect;
  final bool disableShadow;
  final bool needsRepaint;
  final DrawableRoot drawableRoot;
  final Offset translationOffset;
  final ParallaxBackgroundSettings settings;
  final bool autoXScale;
  final bool autoYScale;
  final Size screenSize;

  @override
  void paint(Canvas canvas, Size size) async {
    canvas.save();
    if (translationOffset != null) {
      canvas.translate(translationOffset.dx, translationOffset.dy);
    }

    double scaleXFactor = 1;
    double scaleYFactor = 1;

    if (autoXScale == true) {
      scaleXFactor = screenSize.width / drawableRoot.viewport.width;
    }
    if (autoYScale == true) {
      scaleYFactor = screenSize.height / drawableRoot.viewport.height;
    }

    canvas.scale(scaleXFactor, scaleYFactor);

    drawableRoot.clipCanvasToViewBox(canvas);
    _drawPath(canvas, drawableRoot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ParallaxBackgroundPainter oldDelegate) =>
      needsRepaint == true;

  _drawPath(Canvas canvas, DrawableRoot drawable) {
    Float64List deepEffectMatrix =
        settings?.deepEffectMatrix ?? Matrix4.identity().storage;

    // Draw shadow
    if (disableShadow != true) {
      var shadowDrawable = drawable.mergeStyle(
        DrawableStyle(
          fill: DrawablePaint(
            PaintingStyle.fill,
            color: settings.shadowColor,
            maskFilter: MaskFilter.blur(BlurStyle.normal, settings.shadowSigma),
          ),
        ),
      );

      canvas.save();

      canvas.transform(deepEffectMatrix);
      shadowDrawable.draw(canvas, null);

      canvas.restore();
    }

    if (disableDeepEffect != true) {
      var deepDrawable = drawable.mergeStyle(
        DrawableStyle(
          fill: DrawablePaint(
            PaintingStyle.fill,
            color: Color.fromARGB(40, 0, 0, 0),
          ),
        ),
      );

      canvas.save();

      canvas.transform(deepEffectMatrix);
      drawable.draw(canvas, null);
      deepDrawable.draw(canvas, null);

      canvas.restore();
    }

    drawable.draw(canvas, null);

    // canvas.drawPath(
    //   path.transform(scaleMatrix.storage),
    //   Paint()
    //     ..color = color
    //     ..style = PaintingStyle.fill,
    // );

    // if (enable3D == true) {
    //   canvas.drawPath(
    //     path.transform(scaleMatrix.storage),
    //     Paint()
    //       ..color = Color.fromARGB(40, 0, 0, 0)
    //       ..style = PaintingStyle.fill,
    //   );
    // }

    // canvas.drawPath(
    //   path,
    //   Paint()
    //     ..color = color
    //     ..style = PaintingStyle.fill,
    // );
  }
}
