import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/expense_repository.dart';
import '../../domain/creator_split.dart';
import '../../domain/sales_stats.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/large_title_page.dart';
import '../../ui/money.dart';
import '../events/event_dates.dart';
import '../expenses/expense_editor.dart';
import '../orders/export_orders.dart';

/// key 为 null 时汇总所有场次。
final _statsProvider = StreamProvider.family<SalesStats, String?>(
  (ref, eventId) => ref.watch(salesRepositoryProvider).watchEventStats(eventId),
);

final _comparisonProvider = StreamProvider(
  (ref) => ref.watch(salesRepositoryProvider).watchEventComparison(),
);

const _all = '__all__';
final _dateFormat = DateFormat('MM-dd');

/// 统计：顶部一排场次标签切换单场 / 全部场次。单场看该场的实收、热销、分账、支付方式；
/// 全部场次看合计和各场对比。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  /// 选中的场次 id，或 [_all]；null 时跟随当前场次。
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider).value ?? const <Event>[];
    final currentId = ref.watch(currentEventIdProvider).value;
    final fallback = events.any((e) => e.id == currentId) ? currentId! : _all;
    final selected = _selected == _all || events.any((e) => e.id == _selected)
        ? _selected!
        : fallback;
    final event = events.where((e) => e.id == selected).firstOrNull;

    return LargeTitlePage(
      title: l10n.navStats,
      actions: [if (events.isNotEmpty) ExportOrdersButton(event: event)],
      slivers: events.isEmpty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: CupertinoIcons.chart_bar,
                  title: l10n.noEvents,
                  actionLabel: l10n.newEvent,
                  onAction: () => context.go('/pos/events'),
                ),
              ),
            ]
          : [
              // 场次标签不固定高度，大字体时会跟着变高。
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.sm,
                  ),
                  child: Row(
                    children: [
                      for (final (id, label) in [
                        (_all, l10n.allEvents),
                        for (final e in events) (e.id, e.name),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: Gap.sm),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: selected == id,
                            onSelected: (_) => setState(() => _selected = id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ref
                  .watch(_statsProvider(event?.id))
                  .when(
                    loading: () =>
                        const SliverFillRemaining(child: asyncLoading),
                    error: (e, s) =>
                        SliverFillRemaining(child: asyncError(e, s)),
                    data: (stats) => _StatsBody(
                      stats: stats,
                      eventId: event?.id,
                      expenses:
                          ref.watch(expensesProvider(event?.id)).value ??
                          const [],
                      header: event == null
                          ? _Comparison(
                              onSelect: (id) => setState(() => _selected = id),
                            )
                          : null,
                    ),
                  ),
            ],
    );
  }
}

/// 全部场次视图里的各场对比表，点一行切到那一场。
class _Comparison extends ConsumerWidget {
  const _Comparison({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    final rows = ref.watch(_comparisonProvider).value ?? const [];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return _Section(
      title: l10n.eventComparison,
      child: Column(
        children: [
          for (final r in rows)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(r.event.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              r.event.dateLabel(withYear: false) ??
                                  l10n.noEventDate,
                              if (r.event.endedAt != null) l10n.eventEnded,
                              l10n.comparisonOrders(r.orderCount),
                              l10n.itemCount(r.itemCount),
                              if (r.pendingCount > 0)
                                '${l10n.pendingPayment} ${r.pendingCount}',
                            ].join(' · '),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(r.revenue),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (r.expenses > 0)
                          Text(l10n.netShort(money(r.net)), style: muted),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({
    required this.stats,
    required this.eventId,
    required this.expenses,
    this.header,
  });

  final SalesStats stats;

  /// 选中的场次；null 为全部场次。
  final String? eventId;
  final List<Expense> expenses;

  /// 显示在汇总下面的额外内容（全部场次时为各场对比）。
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final creators = {
      for (final c in ref.watch(creatorsProvider).value ?? const <Creator>[])
        c.id: c.name,
    };

    final noSales = stats.orderCount == 0 && stats.refundCount == 0;
    final expenseSection = _ExpensesSection(
      eventId: eventId,
      expenses: expenses,
    );
    if (noSales && expenses.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: CupertinoIcons.chart_bar,
          title: l10n.noOrders,
          actionLabel: l10n.newExpense,
          onAction: () => showExpenseEditor(
            context,
            eventId: eventId ?? ref.read(currentEventIdProvider).value,
          ),
        ),
      );
    }

    final summary = _Summary(stats: stats, expenses: ExpenseSummary(expenses));
    final topSellers = _Section(
      title: l10n.topSellers,
      child: _RankedBars(
        rows: [
          for (final s in stats.topSellers.take(10))
            (
              s.name,
              s.quantity,
              '${l10n.itemCount(s.quantity)} · ${money(s.revenue)}',
            ),
        ],
      ),
    );
    final byCreator = _Section(
      title: l10n.byCreator,
      child: _RankedBars(
        rows: [
          for (final MapEntry(key: id, value: amount) in stats.byCreator)
            (
              id == unassignedCreator
                  ? l10n.noCreator
                  : creators[id] ?? l10n.noCreator,
              amount,
              '${money(amount)} · ${_percent(amount, stats.revenue)}',
            ),
        ],
      ),
    );
    final byPayment = _Section(
      title: l10n.byPayment,
      child: _RankedBars(
        rows: [
          for (final p in stats.byPayment)
            (
              p.name,
              p.amount,
              '${l10n.orderCount(p.orders)} · ${money(p.amount)}',
            ),
        ],
      ),
    );

    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      sliver: SliverList.list(
        children: [
          summary,
          const SizedBox(height: 16),
          if (header != null) ...[header!, const SizedBox(height: 16)],
          expenseSection,
          const SizedBox(height: 16),
          if (noSales)
            const SizedBox.shrink()
          else if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: topSellers),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      byCreator,
                      const SizedBox(height: 16),
                      byPayment,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            topSellers,
            const SizedBox(height: 16),
            byCreator,
            const SizedBox(height: 16),
            byPayment,
          ],
        ],
      ),
    );
  }

  static String _percent(int part, int whole) => whole == 0
      ? '0%'
      : '${(part * 100 / whole).toStringAsFixed(part * 100 % whole == 0 ? 0 : 1)}%';
}

/// 顶部：实收大数字 + 几个指标。
class _Summary extends ConsumerWidget {
  const _Summary({required this.stats, required this.expenses});

  final SalesStats stats;
  final ExpenseSummary expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final tiles = [
      if (expenses.total > 0) ...[
        (l10n.expenses, money(expenses.total)),
        (l10n.netIncome, money(stats.revenue - expenses.total)),
      ],
      (l10n.orders, '${stats.orderCount}'),
      (l10n.itemsSold, '${stats.itemCount}'),
      (l10n.averageOrder, money(stats.averageOrder)),
      (l10n.discountTotal, money(stats.discountTotal)),
      (l10n.refunds, '${stats.refundCount} · ${money(stats.refundAmount)}'),
      if (stats.pendingCount > 0)
        (
          l10n.pendingPayment,
          '${stats.pendingCount} · ${money(stats.pendingAmount)}',
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.revenue, style: theme.textTheme.titleSmall),
            Text(
              money(stats.revenue),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                for (final (label, value) in tiles)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 支出明细：按日期列出，点一条可修改；底部记新的一笔。
class _ExpensesSection extends ConsumerWidget {
  const _ExpensesSection({required this.eventId, required this.expenses});

  final String? eventId;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    final eventNames = {
      for (final e in ref.watch(eventsProvider).value ?? const <Event>[])
        e.id: e.name,
    };
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return _Section(
      title: l10n.expenses,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expenses.isEmpty)
            Text(l10n.noExpenses, style: muted)
          else
            for (final x in expenses)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showExpenseEditor(context, existing: x),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        expenseCategoryIcon(x.category),
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(expenseCategoryName(l10n, x.category)),
                            Text(
                              [
                                _dateFormat.format(x.spentOn),
                                // 全部场次里注明是哪一场的。
                                if (eventId == null)
                                  x.eventId == null
                                      ? l10n.expenseNoEvent
                                      : eventNames[x.eventId] ?? '',
                                if (x.note.isNotEmpty) x.note,
                              ].join(' · '),
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        money(x.amount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showExpenseEditor(
                context,
                eventId: eventId ?? ref.read(currentEventIdProvider).value,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newExpense),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 排行条形图：一行一个条目，条的长度表示数值，文字用正文颜色写在条上方。
class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.rows});

  /// (名称, 用于比较长度的数值, 右侧显示的文字)
  final List<(String, int, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rows.fold<int>(0, (a, r) => r.$2 > a ? r.$2 : a);
    return Column(
      children: [
        for (final (name, value, label) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // iOS 风格的进度条：浅色胶囊轨道，主色胶囊填充。
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 8,
                    alignment: Alignment.centerLeft,
                    decoration: ShapeDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.07,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Container(
                      width: max <= 0 ? 0 : constraints.maxWidth * value / max,
                      decoration: ShapeDecoration(
                        color: theme.colorScheme.primary,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
