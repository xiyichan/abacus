import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sales_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/grouped_list.dart';
import '../../ui/design.dart';
import '../../ui/glass.dart';
import '../../ui/money.dart';
import 'cart.dart';
import 'discount_dialog.dart';

Future<void> _editDiscount(BuildContext context, WidgetRef ref) async {
  final d = await showDiscountDialog(context, ref.read(cartProvider).discount);
  if (d != null) ref.read(cartProvider.notifier).setDiscount(d);
}

/// 平板右侧的购物车：已点清单（白色圆角卡片，可加减），下面是小计、优惠、合计和结账。
/// [onCollapse] 有值时标题旁有“收起”按钮，收起后换成底部的购物车条。
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, required this.onCheckout, this.onCollapse});

  final VoidCallback onCheckout;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = ref.watch(moneyProvider);
    final cart = ref.watch(cartProvider);
    final summary = cart.summary;
    final card = BoxDecoration(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.card),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CartHeader(
            title: l10n.cart,
            large: true,
            trailing: onCollapse == null
                ? null
                : IconButton(
                    tooltip: l10n.collapseCartPanel,
                    icon: const Icon(CupertinoIcons.sidebar_right),
                    onPressed: onCollapse,
                  ),
          ),
          const SizedBox(height: Gap.sm),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.cart,
                            size: 48,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: Gap.md),
                          Text(
                            l10n.cartEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: card,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.card),
                      child: _CartLines(lines: cart.lines),
                    ),
                  ),
          ),
          const SizedBox(height: Gap.md),
          DecoratedBox(
            decoration: card,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.sm,
                Gap.sm,
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: l10n.subtotal,
                    value: money(summary.subtotal),
                    trailing: const SizedBox(width: Gap.sm),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    onTap: cart.isEmpty
                        ? null
                        : () => _editDiscount(context, ref),
                    child: _SummaryRow(
                      label: l10n.discount,
                      value: summary.discount == 0
                          ? '—'
                          : '−${money(summary.discount)}',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const Divider(height: Gap.md),
                  _SummaryRow(
                    label: l10n.total,
                    value: money(summary.total),
                    style: theme.textTheme.titleLarge,
                    valueStyle: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                    trailing: const SizedBox(width: Gap.sm),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: cart.isEmpty ? null : onCheckout,
            child: Text(l10n.checkout),
          ),
        ],
      ),
    );
  }
}

/// 购物车标题行：标题、件数、清空。
class _CartHeader extends ConsumerWidget {
  const _CartHeader({required this.title, this.large = false, this.trailing});

  final String title;
  final bool large;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cart = ref.watch(cartProvider);
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: large
                ? theme.textTheme.titleLarge
                : theme.textTheme.titleMedium,
          ),
        ),
        if (large && !cart.isEmpty) ...[
          const SizedBox(width: Gap.sm),
          Text(
            l10n.itemCount(cart.itemCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (!cart.isEmpty)
          TextButton(
            onPressed: ref.read(cartProvider.notifier).clear,
            child: Text(l10n.clearCart),
          ),
        ?trailing,
      ],
    );
  }
}

/// 已点清单，一行一个规格，带分隔线。
class _CartLines extends StatelessWidget {
  const _CartLines({required this.lines, this.shrinkWrap = false});

  final List<SaleLine> lines;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => ListView.separated(
    shrinkWrap: shrinkWrap,
    padding: EdgeInsets.zero,
    itemCount: lines.length,
    separatorBuilder: (_, _) => const Divider(height: 1, indent: Gap.lg),
    itemBuilder: (_, i) => _CartLine(line: lines[i]),
  );
}

/// 一行：名字和单价，加减按钮，小计。
class _CartLine extends ConsumerWidget {
  const _CartLine({required this.line});

  final SaleLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = ref.watch(moneyProvider);
    final notifier = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Gap.lg,
        Gap.xs,
        Gap.md,
        Gap.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  money(line.unitPrice),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.removeOne,
            icon: Icon(CupertinoIcons.minus_circle, color: scheme.primary),
            onPressed: () =>
                notifier.setQuantity(line.variantId, line.quantity - 1),
          ),
          Text('${line.quantity}', style: theme.textTheme.titleMedium),
          IconButton(
            tooltip: l10n.addOne,
            icon: Icon(CupertinoIcons.plus_circle_fill, color: scheme.primary),
            onPressed: () =>
                notifier.setQuantity(line.variantId, line.quantity + 1),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              money(line.unitPrice * line.quantity),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.style,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle? style;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
      child: LabelValueRow(
        label: Text(label, style: style),
        value: Text(
          value,
          style: valueStyle ?? style,
          textAlign: TextAlign.end,
        ),
        trailing: trailing,
      ),
    );
  }
}

/// 手机底部：已点清单常驻在购物车条上面（可以收起），下面是件数、合计和结账。
/// 平板收起侧边购物车时也用它：传 [onExpand]，不显示清单，点一下展开回侧边。
class CartBar extends ConsumerStatefulWidget {
  const CartBar({super.key, required this.onCheckout, this.onExpand});

  final VoidCallback onCheckout;
  final VoidCallback? onExpand;

  @override
  ConsumerState<CartBar> createState() => _CartBarState();
}

class _CartBarState extends ConsumerState<CartBar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = ref.watch(moneyProvider);
    final cart = ref.watch(cartProvider);
    final summary = cart.summary;
    final expand = widget.onExpand;
    final showLines = expand == null && !cart.isEmpty && !_collapsed;
    void toggle() => setState(() => _collapsed = !_collapsed);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Glass(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(showLines ? Radii.card : 999),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.curve,
                alignment: Alignment.bottomCenter,
                child: !showLines
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              Gap.lg,
                              Gap.xs,
                              Gap.xs,
                              0,
                            ),
                            child: _CartHeader(
                              title: l10n.orderedCount(cart.itemCount),
                              trailing: IconButton(
                                tooltip: l10n.collapseCart,
                                icon: const Icon(CupertinoIcons.chevron_down),
                                onPressed: toggle,
                              ),
                            ),
                          ),
                          // 清单最多占屏幕三成，多了在里面滚动。
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * 0.3,
                            ),
                            child: _CartLines(
                              lines: cart.lines,
                              shrinkWrap: true,
                            ),
                          ),
                          InkWell(
                            onTap: () => _editDiscount(context, ref),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                Gap.lg,
                                0,
                                Gap.md,
                                0,
                              ),
                              child: _SummaryRow(
                                label: l10n.discount,
                                value: summary.discount == 0
                                    ? '—'
                                    : '−${money(summary.discount)}',
                                trailing: Icon(
                                  CupertinoIcons.chevron_forward,
                                  size: 18,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
              ),
              InkWell(
                customBorder: showLines ? null : const StadiumBorder(),
                onTap: expand ?? (cart.isEmpty ? null : toggle),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.sm,
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: cart.isEmpty
                            ? null
                            : (_collapsed
                                  ? l10n.expandCart
                                  : l10n.collapseCart),
                        child: Badge(
                          isLabelVisible: !cart.isEmpty,
                          backgroundColor: scheme.primary,
                          label: Text('${cart.itemCount}'),
                          child: const Icon(CupertinoIcons.bag),
                        ),
                      ),
                      const SizedBox(width: Gap.lg),
                      Expanded(
                        child: Text(
                          cart.isEmpty
                              ? l10n.itemCount(0)
                              : expand != null
                              ? '${l10n.itemCount(cart.itemCount)} · ${money(summary.total)}'
                              : money(summary.total),
                          style: cart.isEmpty
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                        ),
                      ),
                      if (expand != null)
                        IconButton(
                          tooltip: l10n.expandCartPanel,
                          icon: const Icon(CupertinoIcons.sidebar_right),
                          onPressed: expand,
                        ),
                      FilledButton(
                        onPressed: cart.isEmpty ? null : widget.onCheckout,
                        child: Text(l10n.checkout),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
