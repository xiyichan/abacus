import 'package:flutter/widgets.dart';

/// 宽度达到该值（逻辑像素）时使用平板布局：收银台右侧常驻购物车。
const tabletBreakpoint = 600.0;

bool isTabletWidth(double width) => width >= tabletBreakpoint;

extension LayoutContext on BuildContext {
  bool get isTablet => isTabletWidth(MediaQuery.sizeOf(this).width);
}

/// 底部的悬浮标签栏盖在内容上：滚动内容在原有内边距之外再留出它的高度（MediaQuery 的底部内边距，
/// 含系统安全区）。显式设置了 padding 的列表不会自动避让，要用这个。
EdgeInsets withBottomBar(BuildContext context, EdgeInsets padding) => padding
    .copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);
