import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// 收银锁：锁上后本机只显示收银台，看不到订单、商品、统计和设置，解锁要输入 PIN。
/// 只存在本机，不同步（每台设备各自锁）。
const _lockedKey = 'cashierLocked';
const _pinKey = 'cashierLockPin';
const pinLength = 4;

final cashierLockedProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(databaseProvider).watchSetting(_lockedKey).map((v) => v == '1'),
);

final hasLockPinProvider = StreamProvider<bool>(
  (ref) =>
      ref.watch(databaseProvider).watchSetting(_pinKey).map((v) => v != null),
);

/// PIN 只存加盐哈希。
Future<String> _hashPin(String salt, String pin) async {
  final hash = await Sha256().hash(utf8.encode('$salt:$pin'));
  return base64Encode(hash.bytes);
}

Future<void> setLockPin(AppDatabase db, String pin) async {
  final random = Random.secure();
  final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
  await db.setSetting(_pinKey, '$salt:${await _hashPin(salt, pin)}');
}

Future<bool> checkLockPin(AppDatabase db, String pin) async {
  final stored = await db.getSetting(_pinKey);
  if (stored == null) return false;
  final i = stored.indexOf(':');
  return await _hashPin(stored.substring(0, i), pin) == stored.substring(i + 1);
}

Future<void> setCashierLocked(AppDatabase db, bool locked) async {
  if (locked) {
    await db.setSetting(_lockedKey, '1');
  } else {
    await (db.delete(
      db.localSettings,
    )..where((t) => t.key.equals(_lockedKey))).go();
  }
}

/// 上锁：还没有 PIN 时先设置（输两遍），然后锁上并回到收银台。
Future<void> lockCashier(BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  if (await db.getSetting(_pinKey) == null) {
    if (!context.mounted) return;
    if (!await changeLockPin(context, ref)) return;
  }
  await setCashierLocked(db, true);
  if (context.mounted) context.go('/pos');
}

/// 设置或修改 PIN（输两遍确认）。返回是否设置成功。
Future<bool> changeLockPin(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final first = await showPinDialog(context, title: l10n.setLockPin);
  if (first == null || !context.mounted) return false;
  final second = await showPinDialog(
    context,
    title: l10n.confirmLockPin,
    validate: (pin) async => pin == first ? null : l10n.pinMismatch,
  );
  if (second == null) return false;
  await setLockPin(ref.read(databaseProvider), first);
  return true;
}

/// 解锁：输入正确的 PIN 后解除。
Future<void> unlockCashier(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(databaseProvider);
  final pin = await showPinDialog(
    context,
    title: l10n.unlockTitle,
    validate: (pin) async => await checkLockPin(db, pin) ? null : l10n.wrongPin,
  );
  if (pin != null) await setCashierLocked(db, false);
}

/// 输入 [pinLength] 位数字 PIN 的对话框。[validate] 返回错误文案时留在对话框里。
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  Future<String?> Function(String pin)? validate,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PinDialog(title: title, validate: validate),
);

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.validate});

  final String title;
  final Future<String?> Function(String pin)? validate;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text;
    if (pin.length != pinLength) return;
    final error = await widget.validate?.call(pin);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      _controller.clear();
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: pinLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(letterSpacing: 16),
        decoration: InputDecoration(
          hintText: l10n.pinHint(pinLength),
          errorText: _error,
          counterText: '',
        ),
        onChanged: (v) {
          if (_error != null) setState(() => _error = null);
          if (v.length == pinLength) _submit();
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
