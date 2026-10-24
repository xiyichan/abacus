import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 单个输入框的对话框。确定时返回输入内容（可能为空字符串），取消时返回 null。
///
/// 输入框控制器由对话框自己持有，关闭动画结束后才释放。
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String? body,
  String initialValue = '',
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  bool destructive = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _InputDialog(
    title: title,
    label: label,
    body: body,
    initialValue: initialValue,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
  ),
);

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.label,
    required this.body,
    required this.initialValue,
    required this.keyboardType,
    required this.inputFormatters,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String label;
  final String? body;
  final String initialValue;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.body != null) ...[
              Text(widget.body!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: widget.body == null,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              decoration: InputDecoration(labelText: widget.label),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
