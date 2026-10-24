import 'package:flutter/widgets.dart';

/// 宽度达到该值（逻辑像素）时使用平板布局：侧边导航 + 常驻购物车。
const tabletBreakpoint = 600.0;

bool isTabletWidth(double width) => width >= tabletBreakpoint;

extension LayoutContext on BuildContext {
  bool get isTablet => isTabletWidth(MediaQuery.sizeOf(this).width);
}
