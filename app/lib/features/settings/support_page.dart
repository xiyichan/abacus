import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../support/tip_jar.dart';
import '../../ui/design.dart';
import '../../ui/grouped_list.dart';
import '../../ui/layout.dart';

/// 请作者喝杯咖啡：几档应用内打赏，不解锁任何功能。
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  late final TipStore? _store = ref.read(tipStoreProvider);
  late final Future<List<TipOption>> _options =
      _store?.load() ?? Future.value(const []);
  StreamSubscription<TipOutcome>? _sub;

  /// 正在付款的档位。
  String? _buying;
  bool _pending = false;
  bool _thanked = false;

  @override
  void initState() {
    super.initState();
    _sub = _store?.outcomes.listen(_onOutcome);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onOutcome(TipOutcome outcome) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pending = outcome == TipOutcome.pending;
      if (outcome != TipOutcome.pending) _buying = null;
      if (outcome == TipOutcome.thanked) _thanked = true;
    });
    if (outcome == TipOutcome.failed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.supportFailed)));
    }
  }

  Future<void> _buy(TipOption option) async {
    if (_buying != null) return;
    setState(() => _buying = option.id);
    try {
      await _store!.buy(option);
    } on Object {
      _onOutcome(TipOutcome.failed);
    }
  }

  String _label(AppLocalizations l10n, String id) => switch (id) {
    'tip_small' => l10n.tipSmall,
    'tip_medium' => l10n.tipMedium,
    _ => l10n.tipLarge,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportAuthor)),
      body: ListView(
        padding: withBottomBar(
          context,
          const EdgeInsets.symmetric(vertical: Gap.md),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.lg),
            child: Column(
              children: [
                Text(
                  _thanked ? '❤️' : '☕',
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  _thanked ? l10n.supportThanks : l10n.supportAuthor,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  _thanked ? l10n.supportThanksBody : l10n.supportIntro,
                  style: muted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          FutureBuilder(
            future: _options,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(Gap.xl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }
              final options = snapshot.data ?? const <TipOption>[];
              if (options.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                  child: Text(
                    l10n.supportUnavailable,
                    style: muted,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return GroupedSection(
                footer: _pending ? l10n.supportPending : l10n.supportFootnote,
                children: [
                  for (final option in options)
                    GroupedTile(
                      title: _label(l10n, option.id),
                      trailing: _buying == option.id
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : FilledButton.tonal(
                              onPressed: _buying == null
                                  ? () => _buy(option)
                                  : null,
                              child: Text(option.price),
                            ),
                      onTap: _buying == null ? () => _buy(option) : null,
                      showChevron: false,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 收摊后轻轻提一句打赏：这场卖出过东西、没打赏过、离上次提已经收了几场摊，
/// 并且连得上商店（连不上点进去也付不了）。
Future<void> maybeAskForTip(
  BuildContext context,
  WidgetRef ref, {
  required String eventName,
  required int orders,
}) async {
  final prefs = ref.read(supportPrefsProvider);
  final store = ref.read(tipStoreProvider);
  if (orders <= 0 || prefs == null || store == null) return;
  if (!prefs.recordEventEnded()) return;
  if ((await store.load()).isEmpty || !context.mounted) return;
  prefs.snoozePrompt();
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _TipPrompt(eventName: eventName, orders: orders),
  );
  if (go == true && context.mounted) context.go('/settings/support');
}

class _TipPrompt extends StatelessWidget {
  const _TipPrompt({required this.eventName, required this.orders});

  final String eventName;
  final int orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '☕',
              style: TextStyle(fontSize: 44),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              l10n.tipPromptTitle(eventName),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              l10n.tipPromptBody(orders),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.tipPromptGo),
            ),
            const SizedBox(height: Gap.xs),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.tipPromptLater),
            ),
          ],
        ),
      ),
    );
  }
}
