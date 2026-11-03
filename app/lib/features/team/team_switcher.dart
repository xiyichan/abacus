import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/session.dart';
import '../../data/team_library.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/cloud_api.dart';
import '../../sync/cloud_sync_service.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/layout.dart';
import 'cloud_login_page.dart' show cloudErrorText;

/// 换团队或新增团队：全屏显示 [message]，停掉当前团队的局域网和云端同步，
/// 再交给 [TeamSwitcher]。没成功（比如下载失败）时恢复同步并把错误抛给调用方显示。
Future<void> changeTeam(
  WidgetRef ref,
  String message,
  Future<void> Function(TeamSwitcher switcher) action,
) async {
  final switcher = ref.read(teamSwitcherProvider);
  if (switcher == null) return;
  final lan = ref.read(syncServiceProvider);
  final cloud = ref.read(cloudSyncProvider);
  await switcher.busy(message, () async {
    // 云端要等重连循环退出，可能要一会儿：两个一起停。
    await Future.wait([lan.stop(), cloud.stop()]);
    try {
      await action(switcher);
    } on Object {
      await lan.start();
      await cloud.start();
      rethrow;
    }
  });
}

String teamLabel(AppLocalizations l10n, String name) =>
    name.trim().isEmpty ? l10n.unnamedTeam : name;

/// 各主页面左上角常驻的团队名：一眼看出现在记在哪个团队，点开切换。
/// 和 iOS 导航栏左边的文字按钮一样：小一号的灰字加 ⌄，不抢页面标题（收银台是场次名）。
class TeamSwitcherButton extends ConsumerWidget {
  const TeamSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switcher = ref.watch(teamSwitcherProvider);
    if (switcher == null) return const SizedBox.shrink();
    // 当前团队改名后，切换列表里记的名字也跟着改。
    ref.listen(teamProvider, (_, next) {
      final team = next.value;
      if (team == null) return;
      switcher.library.remember(
        switcher.library.currentKey,
        teamId: team.id,
        name: team.name,
      );
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    // 还在读库时先用切换列表里记的名字，免得闪一下“未命名团队”。
    final name = teamLabel(
      l10n,
      ref.watch(teamProvider).value?.name ?? switcher.library.current.name,
    );
    return Semantics(
      button: true,
      label: '${l10n.switchTeam} · $name',
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.switchTeam,
        child: InkWell(
          borderRadius: BorderRadius.circular(Gap.sm),
          onTap: () => showTeamSwitcher(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minTapSize,
              minHeight: minTapSize,
              // 名字很长时省略，给场次名和右边的按钮留地方。
              maxWidth: context.isTablet ? 240 : 120,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_down, size: 13, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showTeamSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      // 盖在底部标签栏上面（和其他弹出面板一样）。
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _TeamSheet(),
    );

enum _TeamAction { remove }

final _createdFormat = DateFormat('yyyy-MM-dd HH:mm');

/// 团队列表：本机的团队点一下就切换；登录了邮箱时，这个邮箱在云端的其他团队也列在下面，
/// 点一下就下载到本机并切过去，不用再收验证码。
class _TeamSheet extends ConsumerStatefulWidget {
  const _TeamSheet();

  @override
  ConsumerState<_TeamSheet> createState() => _TeamSheetState();
}

class _TeamSheetState extends ConsumerState<_TeamSheet> {
  late final TeamSwitcher _switcher = ref.read(teamSwitcherProvider)!;
  TeamLibrary get _library => _switcher.library;

  /// 这个邮箱在云端的团队；null 表示没登录或还在加载。
  List<CloudTeam>? _cloudTeams;
  bool _loadingCloud = false;

  /// 正在下载的云端团队 id。
  String? _downloading;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCloudTeams());
  }

  Future<void> _loadCloudTeams() async {
    final account = _library.account;
    if (account == null) return;
    setState(() => _loadingCloud = true);
    try {
      final teams = await ref.read(cloudApiProvider).listTeams(account.token);
      // 云端的名字是改名后自动登记上去的，比本机记的新：顺手更新切换列表里的名字。
      for (final team in teams) {
        final local = _library.byTeamId(team.id);
        if (local != null && team.name.trim().isNotEmpty) {
          _library.remember(local.key, teamId: team.id, name: team.name);
        }
      }
      if (mounted) setState(() => _cloudTeams = teams);
    } on CloudApiException catch (e) {
      if (e.isAuthError) _library.setAccount(null); // 登录失效：显示登录入口
      if (mounted && !e.isAuthError) {
        setState(
          () => _error = cloudErrorText(AppLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCloud = false);
    }
  }

  Future<void> _switch(LocalTeam team) async {
    final l10n = AppLocalizations.of(context);
    Navigator.pop(context);
    await changeTeam(
      ref,
      l10n.switchingToTeam(teamLabel(l10n, team.name)),
      (s) => s.switchTo(team.key),
    );
  }

  /// 下载云端的团队并切过去。成功后整个界面重建，这个面板随之关闭。
  Future<void> _download(CloudTeam team) async {
    final account = _library.account;
    if (account == null || _downloading != null) return;
    final api = ref.read(cloudApiProvider);
    setState(() {
      _downloading = team.id;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      await changeTeam(
        ref,
        l10n.downloadingTeamNamed(teamLabel(l10n, team.name)),
        (s) => s.add(
          (db) => restoreTeamFromCloud(
            db: db,
            api: api,
            token: account.token,
            email: account.email,
            team: team,
            displayName: account.displayName,
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = null;
        _error = cloudErrorText(AppLocalizations.of(context), e);
      });
    }
  }

  Future<void> _newTeam() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.newTeamConfirmTitle,
      body: l10n.newTeamConfirmBody,
      confirmLabel: l10n.newTeam,
      cancelLabel: l10n.cancel,
    );
    if (!ok || !mounted) return;
    Navigator.pop(context);
    await changeTeam(ref, l10n.creatingTeam, (s) => s.add(ensureSession));
  }

  Future<void> _remove(LocalTeam team) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.removeTeamTitle(teamLabel(l10n, team.name)),
      body: l10n.removeTeamBody,
      confirmLabel: l10n.removeFromDevice,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _library.remove(team.key));
  }

  void _goTo(String location) {
    Navigator.pop(context);
    context.go(location);
  }

  String _cloudDetails(AppLocalizations l10n, CloudTeam team) => [
    if (team.createdAt != null)
      l10n.teamCreatedOn(_createdFormat.format(team.createdAt!)),
    if (team.records != null) l10n.teamRecordCount(team.records!),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentName = ref.watch(teamProvider).value?.name;
    final busy = _downloading != null;
    final cloudTeams = _cloudTeams;
    final others = [
      for (final t in cloudTeams ?? const <CloudTeam>[])
        if (_library.byTeamId(t.id) == null) t,
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _header(theme, l10n.teamsOnDevice),
            for (final team in _library.teams)
              if (team.key == _library.currentKey)
                ListTile(
                  leading: Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(teamLabel(l10n, currentName ?? team.name)),
                  subtitle: Text(l10n.teamInUse),
                  onTap: busy ? null : () => Navigator.pop(context),
                )
              else
                ListTile(
                  leading: const Icon(CupertinoIcons.person_2),
                  title: Text(teamLabel(l10n, team.name)),
                  enabled: !busy,
                  onTap: () => _switch(team),
                  trailing: PopupMenuButton<_TeamAction>(
                    enabled: !busy,
                    onSelected: (_) => _remove(team),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _TeamAction.remove,
                        child: Text(l10n.removeFromDevice),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            if (_library.account == null)
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(l10n.signInWithEmail),
                subtitle: Text(l10n.signInToSwitchTeamsHint),
                onTap: () => _goTo('/settings/team/cloud?restore=1'),
              )
            else ...[
              _header(theme, l10n.cloudOtherTeams),
              if (_loadingCloud)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (cloudTeams != null && others.isEmpty)
                ListTile(enabled: false, title: Text(l10n.noOtherCloudTeams)),
              for (final team in others)
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: Text(teamLabel(l10n, team.name)),
                  subtitle: Text(
                    _downloading == team.id
                        ? l10n.downloadingTeam
                        : _cloudDetails(l10n, team),
                  ),
                  trailing: _downloading == team.id
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  enabled: !busy,
                  onTap: () => _download(team),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(CupertinoIcons.qrcode_viewfinder),
              title: Text(l10n.joinTeam),
              enabled: !busy,
              onTap: () => _goTo('/settings/team/join'),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.add),
              title: Text(l10n.newTeam),
              enabled: !busy,
              onTap: _newTeam,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(text, style: theme.textTheme.titleMedium),
  );
}
