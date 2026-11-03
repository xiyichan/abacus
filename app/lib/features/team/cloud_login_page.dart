import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/team_library.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/cloud_api.dart';
import '../../sync/cloud_sync_service.dart';
import '../../ui/layout.dart';
import '../../ui/empty_state.dart';
import 'cloud_card.dart';
import 'team_switcher.dart';

String cloudErrorText(AppLocalizations l10n, Object error) {
  final code = error is CloudApiException ? error.code : '$error';
  return switch (code) {
    'invalid_email' => l10n.errInvalidEmail,
    'too_soon' => l10n.errTooSoon,
    'too_many_today' => l10n.errTooManyToday,
    'wrong_code' => l10n.errWrongCode,
    'code_expired' => l10n.errCodeExpired,
    'too_many_attempts' => l10n.errTooManyAttempts,
    'network' => l10n.errNetwork,
    'invalid_name' => l10n.errInvalidName,
    _ => l10n.errGeneric(code),
  };
}

final _createdFormat = DateFormat('yyyy-MM-dd HH:mm');

enum _AfterLogin { restore, backup }

/// 邮箱验证码登录。[restore] 为 true 时登录后选择团队恢复到本机，否则为本团队开启云端备份。
/// 备份时如果这个邮箱在云端还有别的团队，先问一下是不是想恢复，避免新装的 App 又建一个空团队。
class CloudLoginPage extends ConsumerStatefulWidget {
  const CloudLoginPage({super.key, this.restore = false});

  final bool restore;

  @override
  ConsumerState<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends ConsumerState<CloudLoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _devCode = false;
  bool _busy = false;
  String? _error;
  late bool _restoreMode = widget.restore;

  /// 恢复模式：登录后拿到的令牌和团队列表。
  String? _token;
  String? _displayName;
  List<CloudTeam>? _teams;

  @override
  void initState() {
    super.initState();
    if (_restoreMode) unawaited(_listWithSavedLogin());
  }

  /// 已经登录过：不用再验证邮箱，直接列出云端的团队。登录失效时照常用邮箱登录。
  Future<void> _listWithSavedLogin() async {
    final library = ref.read(teamSwitcherProvider)?.library;
    // 共用的登录优先：当前团队可能还没登录过，但别的团队登录了。
    final account =
        library?.account ?? await ref.read(cloudSyncProvider).account();
    if (account == null || !mounted) return;
    await _run(() async {
      try {
        final teams = await ref.read(cloudApiProvider).listTeams(account.token);
        if (!mounted) return;
        setState(() {
          _email.text = account.email;
          _displayName = account.displayName;
          _token = account.token;
          _teams = teams;
        });
      } on CloudApiException catch (e) {
        if (!e.isAuthError) rethrow;
        library?.setAccount(null); // 登录失效：下面用邮箱重新登录
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = cloudErrorText(AppLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final devCode = await ref
        .read(cloudApiProvider)
        .startLogin(_email.text.trim());
    setState(() {
      _codeSent = true;
      _devCode = devCode != null;
      if (devCode != null) _code.text = devCode;
    });
  });

  Future<void> _signIn() => _run(() async {
    final email = _email.text.trim().toLowerCase();
    final api = ref.read(cloudApiProvider);
    final login = await api.verifyLogin(email, _code.text.trim());
    final token = login.token;
    _displayName = login.displayName;
    // 第一次登录：顺便起个用户名（可以跳过，之后在云端卡片里改）。
    if (_displayName == null && mounted) {
      final name = await askDisplayName(context, firstLogin: true);
      if (name != null && name.isNotEmpty) {
        _displayName = await api.setDisplayName(token, name);
      }
    }
    final teams = await api.listTeams(token);
    if (!_restoreMode) {
      final teamId = ref.read(sessionProvider).teamId;
      final others = teams.where((t) => t.id != teamId).length;
      // 邮箱下还有别的团队：可能是新装的 App 想找回数据，问一下要不要换过去。
      if (others > 0 && mounted) {
        final choice = await _askRestoreOrBackup(others);
        if (choice == null) return;
        if (choice == _AfterLogin.restore) _restoreMode = true;
      }
    }
    if (_restoreMode) {
      // 记成共用的登录：之后添加、切换团队都不用再收验证码。
      ref
          .read(teamSwitcherProvider)
          ?.library
          .setAccount(
            CloudAccount(token: token, email: email, displayName: _displayName),
          );
      setState(() {
        _token = token;
        _teams = teams;
      });
      return;
    }
    await ref
        .read(cloudSyncProvider)
        .signIn(email: email, token: token, displayName: _displayName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).cloudSignedIn)),
    );
    context.pop();
  });

  Future<_AfterLogin?> _askRestoreOrBackup(int count) {
    final l10n = AppLocalizations.of(context);
    return showCupertinoDialog<_AfterLogin>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.cloudHasTeamsTitle(count)),
        content: Text(l10n.cloudHasTeamsBody),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, _AfterLogin.restore),
            child: Text(l10n.restoreExistingTeam),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, _AfterLogin.backup),
            child: Text(l10n.backupThisDevice),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(CloudTeam team) async {
    final l10n = AppLocalizations.of(context);
    if (team.id == ref.read(sessionProvider).teamId) {
      context.pop(); // 就是现在用的团队
      return;
    }
    final switcher = ref.read(teamSwitcherProvider);
    // 本机已经有这个团队：直接切过去，不用下载。
    final local = switcher?.library.byTeamId(team.id);
    if (local != null) {
      await _run(() => changeTeam(ref, (s) => s.switchTo(local.key)));
      return;
    }
    final ok = await confirmDialog(
      context,
      title: l10n.restoreConfirmTitle(team.name),
      // 能新增团队时当前团队保留；不能时（测试）沿用清空本机再恢复。
      body: switcher != null
          ? l10n.addTeamConfirmBody
          : l10n.restoreConfirmBody,
      confirmLabel: l10n.restore,
      cancelLabel: l10n.cancel,
      destructive: switcher == null,
    );
    if (!ok) return;
    if (switcher != null) {
      final api = ref.read(cloudApiProvider);
      final token = _token!;
      final email = _email.text.trim().toLowerCase();
      await _run(() async {
        switcher.library.setAccount(
          CloudAccount(token: token, email: email, displayName: _displayName),
        );
        await changeTeam(
          ref,
          (s) => s.add(
            (db) => restoreTeamFromCloud(
              db: db,
              api: api,
              token: token,
              email: email,
              team: team,
              displayName: _displayName,
            ),
          ),
        );
      });
      return;
    }
    await _run(() async {
      // 先停掉局域网和云端同步（已登录时云端还连着原来的团队），
      // 不然旧团队的记录会混进正在恢复的数据里。
      final lan = ref.read(syncServiceProvider);
      final cloud = ref.read(cloudSyncProvider);
      await lan.stop();
      await cloud.stop();
      try {
        await restoreTeamFromCloud(
          db: ref.read(databaseProvider),
          api: ref.read(cloudApiProvider),
          token: _token!,
          email: _email.text.trim().toLowerCase(),
          team: team,
          displayName: _displayName,
        );
      } on Object {
        // 没恢复成：恢复同步，错误显示在页面上。
        await lan.start();
        await cloud.start();
        rethrow;
      }
      ref.read(restartAppProvider)();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final teams = _teams;
    return Scaffold(
      appBar: AppBar(
        title: Text(_restoreMode ? l10n.restoreFromCloud : l10n.cloudBackup),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: withBottomBar(context, const EdgeInsets.all(24)),
            children: teams != null
                ? _teamPicker(l10n, teams)
                : _loginForm(l10n),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginForm(AppLocalizations l10n) => [
    Text(widget.restore ? l10n.restoreHint : l10n.cloudSignedOutHint),
    const SizedBox(height: 24),
    TextField(
      controller: _email,
      enabled: !_codeSent,
      autofocus: true,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendCode(),
      decoration: InputDecoration(
        labelText: l10n.email,
        border: const OutlineInputBorder(),
      ),
    ),
    if (_codeSent) ...[
      const SizedBox(height: 8),
      Text(_devCode ? l10n.devCodeHint : l10n.codeSentTo(_email.text.trim())),
      const SizedBox(height: 16),
      TextField(
        controller: _code,
        autofocus: !_devCode,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _signIn(),
        decoration: InputDecoration(
          labelText: l10n.verificationCode,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
    if (_error != null) ...[
      const SizedBox(height: 12),
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
    const SizedBox(height: 24),
    FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: _busy ? null : (_codeSent ? _signIn : _sendCode),
      child: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Text(_codeSent ? l10n.signIn : l10n.sendCode),
    ),
    if (_codeSent)
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _codeSent = false;
                _code.clear();
                _error = null;
              }),
        child: Text(l10n.resendCode),
      ),
  ];

  List<Widget> _teamPicker(AppLocalizations l10n, List<CloudTeam> teams) => [
    Text(
      l10n.chooseTeamToRestore,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    if (teams.length > 1) ...[
      const SizedBox(height: 4),
      Text(l10n.chooseTeamHint),
    ],
    const SizedBox(height: 12),
    if (teams.isEmpty) Text(l10n.noCloudTeams),
    for (final team in teams)
      Card(
        child: ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(team.name.isEmpty ? team.id.substring(0, 8) : team.name),
          subtitle: switch (_teamDetails(l10n, team)) {
            '' => null,
            final details => Text(details),
          },
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.3),
          ),
          enabled: !_busy,
          onTap: () => _restore(team),
        ),
      ),
    if (_busy) ...[
      const SizedBox(height: 24),
      const Center(child: CircularProgressIndicator.adaptive()),
      const SizedBox(height: 12),
      Center(child: Text(l10n.restoring)),
    ],
    if (_error != null) ...[
      const SizedBox(height: 12),
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];

  /// 创建于 2026-11-03 01:05 · 2 台设备 · 120 条记录 · 本机当前团队
  String _teamDetails(AppLocalizations l10n, CloudTeam team) => [
    if (team.createdAt != null)
      l10n.teamCreatedOn(_createdFormat.format(team.createdAt!)),
    if (team.devices != null) l10n.teamDeviceCount(team.devices!),
    if (team.records != null) l10n.teamRecordCount(team.records!),
    if (team.id == ref.read(sessionProvider).teamId)
      l10n.currentTeamTag
    else if (ref.read(teamSwitcherProvider)?.library.byTeamId(team.id) != null)
      l10n.teamOnDeviceTag,
  ].join(' · ');
}
