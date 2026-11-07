import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';
import 'glass.dart';

/// 主页面（商品、订单、统计、设置）：顶上一行导航栏，左边「团队 / 页面标题」，右边按钮，
/// 和收银台的「团队 / 场次」一样。不单独占一行放大标题，省出上面的空白。
/// 导航栏固定在顶上，内容从它下面滚过时是半透明磨砂的。底部会自动留出悬浮标签栏的高度。
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    required this.slivers,
  });

  final String title;

  /// 标题左边，主页面放团队按钮（带面包屑的「/」）。
  final Widget? leading;

  /// 右上角按钮，一般用 [BarButton]。
  final List<Widget> actions;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _BarDelegate(
                topPadding: MediaQuery.paddingOf(context).top,
                background: theme.colorScheme.surface.withValues(alpha: 0.85),
                child: Padding(
                  // 团队按钮自带 8 的内边距，按钮自带 4 的外边距：文字和图标都对齐 16 的页边。
                  padding: EdgeInsetsDirectional.only(
                    start: leading == null ? Gap.lg : Gap.sm,
                    end: Gap.lg - Gap.xs,
                  ),
                  child: Row(
                    children: [
                      ?leading,
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: leading == null ? 0 : Gap.sm,
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
            ),
            ...slivers,
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: Gap.xl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 固定在顶上的导航栏：状态栏高度 + 一行 [height]，磨砂半透明底。
class _BarDelegate extends SliverPersistentHeaderDelegate {
  _BarDelegate({
    required this.topPadding,
    required this.background,
    required this.child,
  });

  static const height = 56.0;

  final double topPadding;
  final Color background;
  final Widget child;

  @override
  double get minExtent => topPadding + height;

  @override
  double get maxExtent => topPadding + height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // 必须撑满整个高度，否则 sliver 的绘制高度和占位高度对不上。
    return SizedBox.expand(child: _bar());
  }

  Widget _bar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BarDelegate old) =>
      old.topPadding != topPadding ||
      old.background != background ||
      old.child != child;
}

/// 导航栏上的按钮（iOS 26 工具栏样式）：玻璃胶囊（只有图标时是圆形），至少 44pt。
/// [tooltip] 同时是读屏标签，只有图标时必须写清楚是做什么的。
class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 图标旁边的文字；为 null 时只显示图标。
  final String? label;

  /// 图标上的角标数字（null 或 0 不显示）。
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = onPressed == null
        ? scheme.onSurface.withValues(alpha: 0.3)
        : theme.appBarTheme.actionsIconTheme?.color ?? scheme.primary;
    Widget iconWidget = Icon(icon, size: 20, color: color);
    if ((badge ?? 0) > 0) {
      iconWidget = Badge(label: Text('$badge'), child: iconWidget);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
      child: Tooltip(
        message: tooltip,
        child: Glass(
          raised: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: minTapSize,
                  minHeight: minTapSize,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: label == null ? 0 : 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      if (label != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          label!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
