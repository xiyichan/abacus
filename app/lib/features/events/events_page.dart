import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/large_title_page.dart';
import '../../ui/layout.dart';
import '../../ui/grouped_list.dart';
import '../../ui/empty_state.dart';
import 'end_event.dart';
import 'event_dates.dart';

enum _EventAction { edit, end, reopen }

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.isCurrent});

  final Event event;
  final bool isCurrent;

  Future<void> _select(BuildContext context, WidgetRef ref) async {
    if (event.endedAt != null) {
      // 已结束的场次要先重新开启才能收银。
      if (!await confirmReopenEvent(context, ref, event)) return;
    } else if (!isCurrent) {
      await promptEndPrevious(context, ref, nextEventId: event.id);
    }
    await ref.read(inventoryRepositoryProvider).setCurrentEvent(event.id);
    // 选好就回收银台，不用再点返回。
    if (context.mounted) context.go('/pos');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ended = event.endedAt != null;
    return ListTile(
      leading: Icon(
        ended
            ? Icons.check_circle_outline
            : isCurrent
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        color: isCurrent
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(
        event.name,
        style: ended
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(
        [
          ?event.dateLabel(),
          ?event.booth,
          if (ended) l10n.eventEnded else if (isCurrent) l10n.currentEvent,
        ].join(' · '),
      ),
      onTap: () => _select(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!ended)
            FilledButton.tonal(
              onPressed: () => context.go('/pos/events/${event.id}/stock'),
              child: Text(l10n.stockForEvent),
            ),
          PopupMenuButton<_EventAction>(
            onSelected: (action) => switch (action) {
              _EventAction.edit => _editEvent(context, ref, event: event),
              _EventAction.end => confirmEndEvent(context, ref, event),
              _EventAction.reopen => confirmReopenEvent(context, ref, event),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _EventAction.edit,
                child: Text(l10n.editEvent),
              ),
              if (ended)
                PopupMenuItem(
                  value: _EventAction.reopen,
                  child: Text(l10n.reopenEvent),
                )
              else
                PopupMenuItem(
                  value: _EventAction.end,
                  child: Text(l10n.endEvent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 场次列表：点一下切换为当前场次并回到收银台，“备货”进入调拨页面。
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final currentId = ref.watch(currentEventIdProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.events),
        actions: [
          BarButton(
            tooltip: l10n.newEvent,
            icon: CupertinoIcons.add,
            onPressed: () => _editEvent(context, ref),
          ),
        ],
      ),
      body: events.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (events) => events.isEmpty
            ? EmptyState(icon: Icons.event_outlined, title: l10n.noEvents)
            : ListView(
                padding: withBottomBar(
                  context,
                  const EdgeInsets.symmetric(vertical: 12),
                ),
                children: [
                  GroupedSection(
                    dividerIndent: 56,
                    children: [
                      for (final e in events)
                        _EventTile(event: e, isCurrent: e.id == currentId),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// 新建或编辑场次。新建后自动设为当前场次。
Future<void> _editEvent(
  BuildContext context,
  WidgetRef ref, {
  Event? event,
}) async {
  final result = await showDialog<_EventForm>(
    context: context,
    builder: (_) => _EventDialog(event: event),
  );
  if (result == null) return;
  final repo = ref.read(inventoryRepositoryProvider);
  if (event == null) {
    if (context.mounted) await promptEndPrevious(context, ref);
    final id = await repo.createEvent(
      name: result.name,
      startsOn: result.start,
      endsOn: result.end,
      booth: result.booth,
    );
    await repo.setCurrentEvent(id);
  } else {
    await repo.updateEvent(
      event.id,
      name: result.name,
      startsOn: result.start,
      endsOn: result.end,
      booth: result.booth,
    );
  }
}

typedef _EventForm = ({
  String name,
  DateTime? start,
  DateTime? end,
  String booth,
});

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.event});

  final Event? event;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final _name = TextEditingController(text: widget.event?.name);
  late final _booth = TextEditingController(text: widget.event?.booth);
  late DateTime? _start =
      widget.event?.startsOn ??
      (widget.event == null ? DateUtils.dateOnly(DateTime.now()) : null);
  late DateTime? _end = widget.event?.endsOn;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _booth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.event == null ? l10n.newEvent : l10n.editEvent),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.event == null,
              decoration: InputDecoration(
                labelText: l10n.eventName,
                hintText: l10n.eventNameHint,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _booth,
              decoration: InputDecoration(labelText: l10n.eventBooth),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.eventDate),
              subtitle: Text(l10n.eventDateHint),
              trailing: Text(
                _start == null ? '—' : formatDateRange(_start!, _end),
              ),
              onTap: () async {
                // 两天的展先点第一天再点第二天；一天的展点同一天两次。
                final start = DateUtils.dateOnly(_start ?? DateTime.now());
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: DateTimeRange(
                    start: start,
                    end: _end == null || _end!.isBefore(start) ? start : _end!,
                  ),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _start = picked.start;
                    _end = picked.end;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = l10n.required);
              return;
            }
            Navigator.pop<_EventForm>(context, (
              name: _name.text,
              start: _start,
              end: _end,
              booth: _booth.text,
            ));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
