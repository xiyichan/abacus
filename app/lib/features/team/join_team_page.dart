import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/team_invite.dart';
import '../../ui/layout.dart';
import '../../ui/empty_state.dart';
import 'team_switcher.dart';

/// 加入团队：扫邀请二维码，或粘贴邀请码（模拟器没有相机时用）。
class JoinTeamPage extends ConsumerStatefulWidget {
  const JoinTeamPage({super.key});

  @override
  ConsumerState<JoinTeamPage> createState() => _JoinTeamPageState();
}

class _JoinTeamPageState extends ConsumerState<JoinTeamPage> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _tryJoin(String text) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final invite = TeamInvite.tryParse(text);
    if (invite == null) {
      setState(() => _error = l10n.invalidInvite);
      return;
    }
    if (invite.teamId == ref.read(sessionProvider).teamId) {
      Navigator.of(context).maybePop(); // 已经在这个团队里
      return;
    }
    final switcher = ref.read(teamSwitcherProvider);
    // 本机已经有这个团队：直接切过去。
    final local = switcher?.library.byTeamId(invite.teamId);
    if (local != null) {
      await changeTeam(ref, (s) => s.switchTo(local.key));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await confirmDialog(
      context,
      title: l10n.joinConfirmTitle(invite.teamName),
      // 能新增团队时当前团队保留；不能时（测试）沿用清空本机再加入。
      body: switcher != null ? l10n.joinAddConfirmBody : l10n.joinConfirmBody,
      confirmLabel: l10n.join,
      cancelLabel: l10n.cancel,
      destructive: switcher == null,
    );
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    if (switcher != null) {
      await changeTeam(ref, (s) => s.add((db) => joinTeam(db, invite)));
      return;
    }
    // 先停掉旧团队的同步，再清空数据加入新团队。
    await ref.read(syncServiceProvider).stop();
    await joinTeam(ref.read(databaseProvider), invite);
    ref.read(restartAppProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTeam)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: withBottomBar(context, const EdgeInsets.all(16)),
            children: [
              Text(l10n.joinTeamHint),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: MobileScanner(
                    onDetect: (capture) {
                      for (final code in capture.barcodes) {
                        final value = code.rawValue;
                        if (value != null &&
                            TeamInvite.tryParse(value) != null) {
                          _tryJoin(value);
                          return;
                        }
                      }
                    },
                    errorBuilder: (context, _) => ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.cameraUnavailable,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: _tryJoin,
                // 粘贴进来的是有效邀请码就直接进入确认，不用再找“加入”按钮（常被键盘挡住）。
                onChanged: (v) {
                  if (TeamInvite.tryParse(v) != null) {
                    FocusScope.of(context).unfocus();
                    _tryJoin(v);
                  }
                },
                decoration: InputDecoration(
                  labelText: l10n.pasteInvite,
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _tryJoin(_code.text),
                child: _busy ? asyncLoading : Text(l10n.join),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => context.go('/settings/team/cloud?restore=1'),
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(l10n.restoreFromCloud),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
