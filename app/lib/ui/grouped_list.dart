import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';

/// iOS 设置风格的分组列表：浅底上的白色圆角卡片，行之间细分隔线，上方可带小标题，下方可带说明。
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
    required this.children,
  });

  final String? header;
  final String? footer;

  /// 分隔线左侧缩进：行带 [GroupedTile] 方块图标时用 [GroupedTile.iconIndent]。
  final double dividerIndent;

  /// 卡片外边距；放在已经有左右内边距的页面里时去掉左右边距。
  final EdgeInsets margin;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, 6),
              child: Text(header!, style: headerStyle),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.card),
            child: Material(
              color:
                  theme.cardTheme.color ??
                  theme.colorScheme.surfaceContainerLowest,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 0.5, indent: dividerIndent),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 6, Gap.lg, 0),
              child: Text(footer!, style: muted),
            ),
        ],
      ),
    );
  }
}

/// 分组里的一行：左边是 iOS 设置那样的彩色圆角方块图标，可点击的行右边带灰色箭头。
class GroupedTile extends StatelessWidget {
  const GroupedTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron,
  });

  /// 方块图标的行，分隔线从文字开始画。
  static const iconIndent = 62.0;

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 默认可点击时显示箭头。
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chevron = showChevron ?? onTap != null;
    return ListTile(
      leading: icon == null
          ? null
          : Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor ?? Brand.tiles.first,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (chevron
              ? Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                )
              : null),
      onTap: onTap,
    );
  }
}

/// 「标题—值」一行（iOS 的 LabeledContent）：左边是浅棕色标题，右边是值。
/// 值放不下时会换行（大字体时也不会被截断）。[emphasis] 用于合计等要突出的行。
class LabeledRow extends StatelessWidget {
  const LabeledRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 12),
      child: LabelValueRow(
        label: Text(
          label,
          style: emphasis
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        value: Text(
          value,
          textAlign: TextAlign.end,
          style: emphasis
              ? theme.textTheme.titleLarge
              : theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
        ),
      ),
    );
  }
}

/// 左标题、右值的一行：值靠右，最多占 60% 宽度（超出就换行），标题占剩下的部分。
/// 大字体时两边都能换行，不会撑出边界。
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final Widget label;
  final Widget value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: Gap.md),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
          child: value,
        ),
        ?trailing,
      ],
    ),
  );
}
