import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';

class SingingIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const SingingIcon({
    super.key,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: ScalableImageWidget.fromSISource(
        si: ScalableImageSource.fromSvg(
          DefaultAssetBundle.of(context),
          'assets/icons/human_singing.svg',
          currentColor: effectiveColor,
        ),
      ),
    );
  }
}
