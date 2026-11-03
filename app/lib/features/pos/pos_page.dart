import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/large_title_page.dart';
import '../../ui/design.dart';
import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../data/sales_repository.dart';
import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/layout.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import '../events/end_event.dart';
import '../expenses/expense_editor.dart';
import '../lock/cashier_lock.dart';
import '../team/sync_status_chip.dart';
import '../team/team_switcher.dart';
import 'cart.dart';
import 'cart_panel.dart';
import 'checkout_sheet.dart';
import 'menu.dart';

/// 收银台，和外卖点菜一样：左边分类，右边商品。平板右侧常驻购物车；手机底部是购物车条。
class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(currentEventProvider);
    final current = event.value;
    // 收银锁：不能切换场次、备货，也看不到同步和收摊提醒（里面有营业额）。
    final locked = ref.watch(cashierLockedProvider).value ?? false;
    void chooseEvent() => context.go('/pos/events');
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.sm,
        // 左上角：团队 › 场次。收银锁时不显示团队（不能切走）。
        title: Row(
          children: [
            if (!locked) ...[
              const TeamSwitcherButton(),
              const SizedBox(width: Gap.xs),
            ],
            Flexible(
              child: TextButton.icon(
                onPressed: locked ? null : chooseEvent,
                iconAlignment: IconAlignment.end,
                icon: locked ? null : const Icon(Icons.arrow_drop_down),
                label: Text(
                  current?.name ?? l10n.chooseEvent,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 手机上按钮只显示图标（文字在 tooltip 里，也是读屏标签），避免挤爆导航栏。
          if (locked)
            BarButton(
              icon: CupertinoIcons.lock_fill,
              tooltip: l10n.lockedTooltip,
              onPressed: () => unlockCashier(context, ref),
            )
          else if (current != null && current.endedAt == null) ...[
            BarButton(
              icon: CupertinoIcons.doc_plaintext,
              tooltip: l10n.addExpense,
              label: context.isTablet ? l10n.addExpense : null,
              onPressed: () => showExpenseEditor(context, eventId: current.id),
            ),
            BarButton(
              icon: CupertinoIcons.cube_box,
              tooltip: l10n.stockForEvent,
              label: context.isTablet ? l10n.stockForEvent : null,
              onPressed: () => context.go('/pos/events/${current.id}/stock'),
            ),
          ],
          if (!locked) SyncStatusChip(compact: !context.isTablet),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: event.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (event) => event == null
            ? EmptyState(
                icon: Icons.storefront_outlined,
                title: l10n.noEventTitle,
                body: l10n.noEventBody,
                actionLabel: locked ? null : l10n.chooseEvent,
                onAction: locked ? null : chooseEvent,
              )
            : event.endedAt != null
            ? EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.eventEndedTitle(event.name),
                body: l10n.eventEndedBody,
                actionLabel: locked ? null : l10n.chooseEvent,
                onAction: locked ? null : chooseEvent,
              )
            : Column(
                children: [
                  if (!locked) EndEventReminder(event: event),
                  Expanded(child: _Till(event: event)),
                ],
              ),
      ),
    );
  }
}

const _cartPanelKey = 'cartPanelExpanded';

/// 平板收起购物车时，底部购物车条（含上下边距）大约的高度，列表末尾留出这么多空。
const _cartBarHeight = 80.0;

/// 平板上展开的侧边购物车宽度。
const _cartPanelWidth = 340.0;

/// 平板上侧边购物车是否展开；默认收起，让商品有更多地方。
final _cartPanelExpandedProvider = StreamProvider(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting(_cartPanelKey)
      .map((v) => v == '1'),
);

/// 收银台中可售的一件商品，以及它在本场的剩余数量（已扣除购物车占用）。
class _SellableProduct {
  const _SellableProduct(this.item, this.variants, this.remaining);

  final CatalogProduct item;

  /// 本场带了的规格。
  final List<Variant> variants;
  final int remaining;
}

class _Till extends ConsumerStatefulWidget {
  const _Till({required this.event});

  final Event event;

  @override
  ConsumerState<_Till> createState() => _TillState();
}

class _TillState extends ConsumerState<_Till> {
  /// 左边选中的分类（分类名，“其他”用 [_otherKey]）；null 表示“全部”。
  String? _selected;
  static const _otherKey = '\u0000other';

  Map<String, int> _remaining(Map<String, int> stock, CartState cart) {
    final remaining = Map.of(stock);
    cart.reserved.forEach(
      (id, q) => remaining.update(id, (v) => v - q, ifAbsent: () => -q),
    );
    return remaining;
  }

  List<_SellableProduct> _sellable(
    List<CatalogProduct> catalog,
    Map<String, int> stock,
    Map<String, int> remaining,
  ) => [
    for (final p in catalog)
      if (p.isBundle)
        if (p.components.values.firstOrNull case final comps?
            when comps.isNotEmpty &&
                comps.every((c) => stock.containsKey(c.variantId)))
          _SellableProduct(p, p.variants, bundleAvailable(comps, remaining))
        else
          ...[]
      else if (p.variants.where((v) => stock.containsKey(v.id)).toList()
          case final vs when vs.isNotEmpty)
        _SellableProduct(
          p,
          vs,
          vs.fold(0, (a, v) => a + (remaining[v.id] ?? 0)),
        ),
  ];

  /// 分类：优先用自定义分类（按分类的排序），没归类的放“其他”；
  /// 还没给商品选分类时按标签分；都没有标签时按作者分；作者也没有就是一组“全部”。
  static List<MenuSection<_SellableProduct>> _sections(
    List<_SellableProduct> sellable,
    List<ProductCategory> categories,
  ) {
    final order = {for (final (i, c) in categories.indexed) c.id: i};
    List<String> categoriesOf(_SellableProduct s) => [
      for (final id in s.item.categoryIds)
        if (order.containsKey(id)) id,
    ];
    if (sellable.any((s) => categoriesOf(s).isNotEmpty)) {
      final byId = groupByTags(sellable, categoriesOf)
        ..sort(
          (a, b) => (order[a.title] ?? categories.length).compareTo(
            order[b.title] ?? categories.length,
          ),
        );
      return [
        for (final s in byId)
          MenuSection(
            s.title == null ? null : categories[order[s.title]!].name,
            s.items,
          ),
      ];
    }
    final byTag = groupByTags(
      sellable,
      (s) => productTags(s.item.product.tags),
    );
    if (byTag.any((s) => s.title != null)) return byTag;
    final byCreator = groupByTags(
      sellable,
      (s) => [if (s.item.creator case final c?) c.name],
    );
    return byCreator.any((s) => s.title != null) ? byCreator : byTag;
  }

  /// 只有一个规格（或是套装）的商品可以在列表里直接加减。
  static bool _single(_SellableProduct s) =>
      s.item.isBundle || s.variants.length == 1;

  void _add(_SellableProduct s, Map<String, int> remaining) {
    final notifier = ref.read(cartProvider.notifier);
    final item = s.item;
    if (item.isBundle) {
      final v = item.variants.single;
      notifier.add(
        SaleLine(
          variantId: v.id,
          name: item.product.name,
          unitPrice: v.price,
          quantity: 1,
          components: item.components[v.id] ?? const [],
        ),
      );
    } else if (s.variants.length == 1) {
      final v = s.variants.single;
      notifier.add(
        SaleLine(
          variantId: v.id,
          name: item.displayName(v),
          unitPrice: v.price,
          quantity: 1,
        ),
      );
    } else {
      _chooseVariant(s, remaining);
    }
  }

  void _removeOne(_SellableProduct s, Map<String, int> inCart) {
    final id = s.variants.single.id;
    ref.read(cartProvider.notifier).setQuantity(id, (inCart[id] ?? 0) - 1);
  }

  void _chooseVariant(_SellableProduct s, Map<String, int> remaining) {
    final l10n = AppLocalizations.of(context);
    final money = ref.read(moneyProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '${s.item.product.name} · ${l10n.chooseVariant}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final v in s.variants)
              ListTile(
                title: Text(v.label),
                subtitle: _StockText(remaining[v.id] ?? 0),
                trailing: Text(money(v.price)),
                onTap: () {
                  ref
                      .read(cartProvider.notifier)
                      .add(
                        SaleLine(
                          variantId: v.id,
                          name: s.item.displayName(v),
                          unitPrice: v.price,
                          quantity: 1,
                        ),
                      );
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 点菜式菜单：左边分类，右边是选中分类的商品（“全部”时按分类分段列出所有商品）。
  /// 手机上是一行一个（可直接加减），平板上是固定大小的图片卡片。
  Widget _menu(
    BuildContext context,
    List<_SellableProduct> sellable,
    Map<String, int> remaining,
    CartState cart, {
    required bool tablet,
    required bool padBottom,
    double extraBottom = 0,
  }) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sections = _sections(
      sellable,
      ref.watch(categoriesProvider).value ?? const [],
    );
    String keyOf(MenuSection<_SellableProduct> s) => s.title ?? _otherKey;
    String titleOf(MenuSection<_SellableProduct> s) =>
        s.title ?? (sections.length == 1 ? l10n.all : l10n.otherCategory);
    // 选中的分类没了（改了分类、卖完了）就回到“全部”。
    final selected = sections.where((s) => keyOf(s) == _selected).firstOrNull;
    final inCart = {for (final l in cart.lines) l.variantId: l.quantity};
    int countOf(_SellableProduct s) =>
        s.variants.fold(0, (a, v) => a + (inCart[v.id] ?? 0));
    // 手机：浅色分类栏 + 白色列表；平板：分类栏和卡片都在分组底色上。
    final contentColor = tablet ? scheme.surface : scheme.surfaceContainer;
    // 平板上列表一直排到底，要避开悬浮标签栏和购物车条；手机上下面的购物车条会避让。
    EdgeInsets bottomSafe(EdgeInsets padding) => padBottom
        ? withBottomBar(
            context,
            padding.copyWith(bottom: padding.bottom + extraBottom),
          )
        : padding;

    Widget product(_SellableProduct s) {
      final count = countOf(s);
      if (tablet) {
        return _ProductCard(
          sellable: s,
          count: count,
          onTap: () => _add(s, remaining),
        );
      }
      return _MenuRow(
        sellable: s,
        count: count,
        onAdd: () => _add(s, remaining),
        onRemove: _single(s) ? () => _removeOne(s, inCart) : null,
      );
    }

    List<Widget> items(MenuSection<_SellableProduct> section) => [
      if (tablet)
        // 卡片固定大小：展开/收起购物车时只是每行放几张变了，卡片不跟着缩放。
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            for (final s in section.items)
              SizedBox(
                width: _ProductCard.width,
                height: _ProductCard.width / 0.72,
                child: product(s),
              ),
          ],
        )
      else
        for (final (j, s) in section.items.indexed) ...[
          if (j > 0)
            const Divider(
              height: 1,
              indent: Gap.md + _MenuRow.imageSize + Gap.md,
            ),
          product(s),
        ],
    ];

    // 只有一组时左边就是“全部”，不用再列分类。
    final showAll = sections.length > 1;
    // （选中用的 key，名字，已点件数，商品款数）
    final railEntries = <(String?, String, int, int)>[
      if (showAll)
        (
          null,
          l10n.all,
          sellable.fold(0, (a, s) => a + countOf(s)),
          sellable.length,
        ),
      for (final s in sections)
        if (showAll || sections.length == 1)
          (
            showAll ? keyOf(s) : null,
            titleOf(s),
            s.items.fold(0, (a, p) => a + countOf(p)),
            s.items.length,
          ),
    ];
    final selectedKey = selected == null ? null : keyOf(selected);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRail(
          titles: [for (final e in railEntries) e.$2],
          counts: [for (final e in railEntries) e.$3],
          sizes: [for (final e in railEntries) e.$4],
          selected: railEntries.indexWhere((e) => e.$1 == selectedKey),
          onSelect: (i) => setState(() => _selected = railEntries[i].$1),
          // 选中项是独立的色块，分类栏本身用页面底色，不再单独画一块白色长条。
          color: scheme.surface,
          padding: bottomSafe(const EdgeInsets.symmetric(vertical: Gap.sm)),
          width: tablet ? 112 : 84,
        ),
        Expanded(
          child: ColoredBox(
            color: contentColor,
            // 换分类时新的列表淡入、稍微往上浮，旧的淡出。
            child: AnimatedSwitcher(
              duration: Motion.normal,
              switchInCurve: Motion.curve,
              switchOutCurve: Motion.curve,
              // 新旧列表都铺满右边、从顶上排，不要默认的居中。
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                key: ValueKey(selectedKey),
                padding: bottomSafe(
                  tablet
                      ? const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md)
                      : const EdgeInsets.only(bottom: Gap.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selected != null || !showAll) ...[
                      SizedBox(height: tablet ? Gap.md : Gap.sm),
                      ...items(selected ?? sections.single),
                    ] else
                      for (final section in sections) ...[
                        _SectionHeader(
                          title: titleOf(section),
                          inset: tablet ? 0 : Gap.md,
                        ),
                        ...items(section),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    final stock = ref.watch(stockProvider(widget.event.id));
    final cart = ref.watch(cartProvider);
    void checkout() => startCheckout(context, widget.event.id);

    return switch ((catalog, stock)) {
      (AsyncData(value: final catalog), AsyncData(value: final stock)) =>
        LayoutBuilder(
          builder: (context, constraints) {
            final tablet = isTabletWidth(constraints.maxWidth);
            final remaining = _remaining(stock, cart);
            final sellable = _sellable(catalog, stock, remaining);
            // 平板可以展开侧边购物车，也可以收起成底部的购物车条（记住上次的选择）。
            final expanded =
                tablet &&
                (ref.watch(_cartPanelExpandedProvider).value ?? false);
            void setExpanded(bool value) => ref
                .read(databaseProvider)
                .setSetting(_cartPanelKey, value ? '1' : '0');
            final menu = sellable.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_outlined,
                    title: l10n.noStockTitle,
                    body: l10n.noStockBody,
                    actionLabel: l10n.goStock,
                    onAction: () =>
                        context.go('/pos/events/${widget.event.id}/stock'),
                  )
                : _menu(
                    context,
                    sellable,
                    remaining,
                    cart,
                    tablet: tablet,
                    // 平板上分类栏和商品一直排到底，底部的购物车条浮在上面。
                    padBottom: tablet,
                    extraBottom: expanded ? 0 : _cartBarHeight,
                  );
            final bar = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CartBar(
                  onCheckout: checkout,
                  onExpand: tablet ? () => setExpanded(true) : null,
                ),
              ),
            );
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            if (tablet) {
              // 展开/收起：购物车从右边滑进滑出，商品区跟着让出位置，底部购物车条同时淡出/淡入。
              return TweenAnimationBuilder<double>(
                tween: Tween(end: expanded ? 1 : 0),
                duration: Motion.normal,
                curve: Motion.curve,
                builder: (context, t, _) => Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: _cartPanelWidth * t,
                      child: menu,
                    ),
                    if (t > 0)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        width: _cartPanelWidth,
                        right: -_cartPanelWidth * (1 - t),
                        child: SafeArea(
                          top: false,
                          left: false,
                          child: CartPanel(
                            onCheckout: checkout,
                            onCollapse: () => setExpanded(false),
                          ),
                        ),
                      ),
                    if (t < 1)
                      Positioned(
                        left: 0,
                        right: _cartPanelWidth * t,
                        bottom: bottomInset,
                        child: IgnorePointer(
                          ignoring: expanded,
                          child: Opacity(
                            opacity: 1 - t,
                            child: Transform.translate(
                              offset: Offset(0, 24 * t),
                              child: bar,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Expanded(child: menu),
                Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: bar,
                ),
              ],
            );
          },
        ),
      (AsyncError(:final error, :final stackTrace), _) ||
      (
        _,
        AsyncError(:final error, :final stackTrace),
      ) => asyncError(error, stackTrace),
      _ => asyncLoading,
    };
  }
}

/// 左边的分类栏：每类一行（名字 + 几款商品），右上角是这一类已点的件数。
/// 选中的一项是一块千禧粉的圆角色块，换选中项时色块平滑地滑过去。
class _CategoryRail extends StatefulWidget {
  const _CategoryRail({
    required this.titles,
    required this.counts,
    required this.sizes,
    required this.selected,
    required this.onSelect,
    required this.color,
    required this.padding,
    required this.width,
  });

  final List<String> titles;
  final List<int> counts;
  final List<int> sizes;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color color;
  final EdgeInsets padding;
  final double width;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final _stackKey = GlobalKey();
  List<GlobalKey> _itemKeys = const [];

  /// 每一项在分类栏里的位置（布局完才知道，用来摆滑动的色块）。
  List<Rect> _rects = const [];

  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !mounted) return;
    final rects = <Rect>[
      for (final key in _itemKeys)
        if (key.currentContext?.findRenderObject() case final RenderBox box)
          box.localToGlobal(Offset.zero, ancestor: stack) & box.size
        else
          Rect.zero,
    ];
    if (!listEquals(rects, _rects)) setState(() => _rects = rects);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    if (_itemKeys.length != widget.titles.length) {
      _itemKeys = [for (final _ in widget.titles) GlobalKey()];
    }
    // 每次布局后量一下各项的位置（大字体、改名、增减分类都会变）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    // 大字体时稍微加宽，但不挤占商品列表太多。
    final railWidth = MediaQuery.textScalerOf(context)
        .scale(widget.width)
        .clamp(widget.width, widget.width * 1.4);
    final selectedRect = widget.selected >= 0 && widget.selected < _rects.length
        ? _rects[widget.selected]
        : null;
    const inset = Gap.sm;
    final name = theme.textTheme.bodyMedium!;
    final size = theme.textTheme.labelSmall!;

    return Semantics(
      label: l10n.categories,
      container: true,
      child: ColoredBox(
        color: widget.color,
        child: SizedBox(
          width: railWidth,
          child: SingleChildScrollView(
            padding: widget.padding,
            child: Stack(
              key: _stackKey,
              children: [
                if (selectedRect != null && selectedRect != Rect.zero)
                  AnimatedPositioned(
                    duration: Motion.normal,
                    curve: Curves.easeOutCubic,
                    left: inset,
                    right: inset,
                    top: selectedRect.top,
                    height: selectedRect.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Radii.sm + 2),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, title) in widget.titles.indexed)
                      Padding(
                        key: _itemKeys[i],
                        padding: const EdgeInsets.symmetric(
                          horizontal: inset,
                          vertical: 2,
                        ),
                        child: _RailItem(
                          title: title,
                          subtitle: l10n.categorySize(widget.sizes[i]),
                          count: widget.counts[i],
                          selected: i == widget.selected,
                          nameStyle: name,
                          sizeStyle: size,
                          onTap: () => widget.onSelect(i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.selected,
    required this.nameStyle,
    required this.sizeStyle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final bool selected;
  final TextStyle nameStyle;
  final TextStyle sizeStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 60,
              minWidth: double.infinity,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  // 右边留出角标的位置，名字不会被挡住。
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.md,
                    Gap.md,
                    Gap.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: nameStyle.copyWith(
                          color: fg,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: Text(title),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: sizeStyle.copyWith(
                          color:
                              (selected
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant)
                                  .withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        child: Text(subtitle),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: _CountBadge(count),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.inset});

  final String title;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, Gap.lg, inset, Gap.sm),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 手机上的一行商品：图、名字、库存、价格，右边是加减按钮（多规格是“选择规格”）。
/// 点整行也是加一件。
class _MenuRow extends ConsumerWidget {
  const _MenuRow({
    required this.sellable,
    required this.count,
    required this.onAdd,
    this.onRemove,
  });

  static const imageSize = 64.0;

  final _SellableProduct sellable;

  /// 购物车里这件商品（所有规格）的数量。
  final int count;
  final VoidCallback onAdd;

  /// 有值时显示加减按钮，否则显示“选择规格”。
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = sellable.item.product;
    final prices = [for (final v in sellable.variants) v.price]..sort();
    final priceText = prices.first == prices.last
        ? money(prices.first)
        : l10n.priceFrom(money(prices.first));
    final Widget control;
    if (onRemove == null) {
      control = Stack(
        clipBehavior: Clip.none,
        children: [
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            ),
            child: Text(l10n.chooseVariant),
          ),
          if (count > 0)
            PositionedDirectional(
              top: 0,
              end: -Gap.xs,
              child: _CountBadge(count),
            ),
        ],
      );
    } else {
      control = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[
            IconButton(
              onPressed: onRemove,
              tooltip: l10n.removeOne,
              icon: Icon(CupertinoIcons.minus_circle, color: scheme.primary),
              iconSize: 28,
            ),
            Text('$count', style: theme.textTheme.titleMedium),
          ],
          IconButton(
            onPressed: onAdd,
            tooltip: l10n.addOne,
            icon: Icon(CupertinoIcons.plus_circle_fill, color: scheme.primary),
            iconSize: 28,
          ),
        ],
      );
    }
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.xs, Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox.square(
                dimension: imageSize,
                child: StoredImage(
                  p.imagePath,
                  placeholder: NamePlaceholder(p.name),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  _StockText(sellable.remaining),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      control,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已点件数的小圆标。
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: ShapeDecoration(
          color: scheme.primary,
          shape: const StadiumBorder(),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.sellable,
    required this.count,
    required this.onTap,
  });

  /// 平板上卡片的固定宽度。
  static const width = 168.0;

  final _SellableProduct sellable;

  /// 购物车里这件商品（所有规格）的数量。
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final p = sellable.item.product;
    final prices = [for (final v in sellable.variants) v.price]..sort();
    final priceText = prices.first == prices.last
        ? money(prices.first)
        : AppLocalizations.of(context).priceFrom(money(prices.first));
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StoredImage(
                    p.imagePath,
                    placeholder: NamePlaceholder(p.name),
                  ),
                  if (count > 0)
                    PositionedDirectional(
                      top: Gap.sm,
                      end: Gap.sm,
                      child: _CountBadge(count),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StockText(sellable.remaining),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockText extends StatelessWidget {
  const _StockText(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).stockLeft(count),
      style: theme.textTheme.bodySmall?.copyWith(
        color: count <= 0
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: count <= 0 ? FontWeight.bold : null,
      ),
    );
  }
}
