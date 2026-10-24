import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../domain/creator_split.dart';
import '../../domain/sales_stats.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/money.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStats),
        actions: [if (events.isNotEmpty) ExportOrdersButton(event: event)],
      ),
      body: events.isEmpty
          ? EmptyState(
              icon: Icons.insights_outlined,
              title: l10n.noEvents,
              actionLabel: l10n.newEvent,
              onAction: () => context.go('/pos/events'),
            )
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      for (final (id, label) in [
                        (_all, l10n.allEvents),
                        for (final e in events) (e.id, e.name),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: selected == id,
                            onSelected: (_) => setState(() => _selected = id),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ref
                      .watch(_statsProvider(event?.id))
                      .when(
                        loading: () => asyncLoading,
                        error: asyncError,
                        data: (stats) => _StatsBody(
                          stats: stats,
                          header: event == null
                              ? _Comparison(
                                  onSelect: (id) =>
                                      setState(() => _selected = id),
                                )
                              : null,
                        ),
                      ),
                ),
              ],
            ),
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
              borderRadius: BorderRadius.circular(8),
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
                              r.event.startsOn == null
                                  ? l10n.noEventDate
                                  : _dateFormat.format(r.event.startsOn!),
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
                    Text(
                      money(r.revenue),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
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
  const _StatsBody({required this.stats, this.header});

  final SalesStats stats;

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

    if (stats.orderCount == 0 && stats.refundCount == 0) {
      return EmptyState(icon: Icons.insights_outlined, title: l10n.noOrders);
    }

    final summary = _Summary(stats: stats);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            summary,
            const SizedBox(height: 16),
            if (header != null) ...[header!, const SizedBox(height: 16)],
            if (wide)
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
        );
      },
    );
  }

  static String _percent(int part, int whole) => whole == 0
      ? '0%'
      : '${(part * 100 / whole).toStringAsFixed(part * 100 % whole == 0 ? 0 : 1)}%';
}

/// 顶部：实收大数字 + 几个指标。
class _Summary extends ConsumerWidget {
  const _Summary({required this.stats});

  final SalesStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final tiles = [
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
                LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      width: max <= 0 ? 0 : constraints.maxWidth * value / max,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
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
