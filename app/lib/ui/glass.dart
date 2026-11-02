import 'dart:ui';

import 'package:flutter/material.dart';

/// iOS 26 风格的玻璃材质：背后内容模糊透出，半透明的亮面，细白描边和很淡的阴影。
/// 用在悬浮标签栏、导航栏按钮和购物车条上。
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.shape = const StadiumBorder(),
    this.padding = EdgeInsets.zero,
    this.raised = true,
  });

  final Widget child;
  final OutlinedBorder shape;
  final EdgeInsetsGeometry padding;

  /// 悬浮的大块（标签栏、购物车条）阴影重一些；导航栏上的小按钮用轻阴影。
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          raised
              ? const BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                )
              : const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: ShapeDecoration(
              color: light
                  ? Colors.white.withValues(alpha: 0.72)
                  : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
              shape: shape.copyWith(
                side: BorderSide(
                  color: light
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
