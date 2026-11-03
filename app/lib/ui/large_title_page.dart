import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';
import 'glass.dart';

/// iOS 大标题页面：标题大字靠左，往上滚动时缩成导航栏中间的小标题，导航栏是半透明磨砂的。
/// 底部会自动留出悬浮标签栏的高度。
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    required this.slivers,
  });

  final String title;

  /// 左上角，主页面放团队按钮。
  final Widget? leading;

  /// 右上角按钮，一般用 [BarButton]。
  final List<Widget> actions;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            leading: leading,
            // 左边的文字按钮自带 8 的内边距，往左挪一点，让文字和大标题左对齐。
            padding: leading == null
                ? null
                : const EdgeInsetsDirectional.only(start: Gap.sm, end: Gap.lg),
            trailing: actions.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
            backgroundColor: scheme.surface.withValues(alpha: 0.85),
            border: null,
            // 各标签页各有一个导航栏，不做跨页面的标题动画（避免 Hero 冲突）。
            transitionBetweenRoutes: false,
          ),
          ...slivers,
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: Gap.xl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
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
