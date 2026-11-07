import 'package:flutter/material.dart';

import 'design.dart';

/// iOS 风格的分段控件：浅色胶囊轨道，选中项是一块会滑动的白色胶囊。
/// Material 的 SegmentedButton 选中块和相邻分段之间是直角，所以自己画。
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// 各分段的值和文字。
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = segments.indexWhere((s) => s.$1 == selected);
    final count = segments.length;
    return Container(
      constraints: const BoxConstraints(minHeight: minTapSize),
      padding: const EdgeInsets.all(_inset),
      decoration: ShapeDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: Motion.normal,
                curve: Motion.curve,
                alignment: AlignmentDirectional(
                  count == 1 ? 0 : -1 + 2 * index / (count - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.surfaceContainer,
                      shape: const StadiumBorder(),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (value, label) in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == selected,
                    inMutuallyExclusiveGroup: true,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onChanged(value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.sm,
                          vertical: 10,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: value == selected
                                ? scheme.onSurface
                                : scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
