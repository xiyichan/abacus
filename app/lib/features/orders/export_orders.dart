import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import '../../data/order_export.dart';
import '../../domain/csv.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// 导出订单为 CSV，并打开系统分享面板（存到“文件”、发微信、AirDrop 等）。
/// [event] 为 null 时导出所有场次，并多一列场次名。
class ExportOrdersButton extends ConsumerWidget {
  const ExportOrdersButton({super.key, this.event});

  final Event? event;

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // iPad 的分享面板需要一个锚点。
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    final event = this.event;
    final orders = await ref
        .read(salesRepositoryProvider)
        .loadOrderDetails(event?.id);
    if (orders.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noOrders)));
      return;
    }
    final dir = await getTemporaryDirectory();
    final date = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final title = event?.name ?? l10n.allEvents;
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    final file = File(
      p.join(dir.path, '${l10n.navOrders}_${safeName}_$date.csv'),
    );
    final eventNames = event != null
        ? null
        : {for (final e in await ref.read(eventsProvider.future)) e.id: e.name};
    await file.writeAsBytes(
      csvBytes(buildOrdersCsv(orders, eventNames: eventNames)),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '${l10n.navOrders} · $title',
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Builder(
      // 用按钮自己的 context 定位 iPad 分享面板。
      builder: (buttonContext) => IconButton(
        tooltip: l10n.exportCsv,
        icon: const Icon(Icons.ios_share),
        onPressed: () => _export(buttonContext, ref),
      ),
    );
  }
}
