import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/cloud_api.dart';
import '../../sync/cloud_sync_service.dart';
import '../../ui/layout.dart';
import '../../ui/empty_state.dart';
import 'cloud_card.dart';

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

/// 邮箱验证码登录。[restore] 为 true 时登录后选择团队恢复到本机，否则为本团队开启云端备份。
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

  /// 恢复模式：登录后拿到的令牌和团队列表。
  String? _token;
  String? _displayName;
  List<CloudTeam>? _teams;

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
    if (widget.restore) {
      final teams = await api.listTeams(token);
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

  Future<void> _restore(CloudTeam team) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.restoreConfirmTitle(team.name),
      body: l10n.restoreConfirmBody,
      confirmLabel: l10n.restore,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(syncServiceProvider).stop();
      await restoreTeamFromCloud(
        db: ref.read(databaseProvider),
        api: ref.read(cloudApiProvider),
        token: _token!,
        email: _email.text.trim().toLowerCase(),
        team: team,
        displayName: _displayName,
      );
      ref.read(restartAppProvider)();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final teams = _teams;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restore ? l10n.restoreFromCloud : l10n.cloudBackup),
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
    const SizedBox(height: 12),
    if (teams.isEmpty) Text(l10n.noCloudTeams),
    for (final team in teams)
      Card(
        child: ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(team.name.isEmpty ? team.id.substring(0, 8) : team.name),
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
}
