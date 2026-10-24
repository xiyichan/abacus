import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../data/session.dart';
import '../providers.dart';

/// 从相册选一张图片，复制到 App 自己的目录，返回文件名（取消时为 null）。
Future<String?> pickAndStoreImage(
  WidgetRef ref, {
  double maxSize = 1600,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSize,
    maxHeight: maxSize,
    imageQuality: 90,
  );
  if (picked == null) return null;
  final dir = ref.read(mediaDirProvider);
  await dir.create(recursive: true);
  final name = '${newId()}${p.extension(picked.path).toLowerCase()}';
  await File(picked.path).copy(p.join(dir.path, name));
  return name;
}

/// 显示 App 目录里保存的图片；没有图片时显示 [placeholder]。
class StoredImage extends ConsumerWidget {
  const StoredImage(
    this.fileName, {
    super.key,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? fileName;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = placeholder ?? const SizedBox.shrink();
    final name = fileName;
    if (name == null) return fallback;
    final file = File(p.join(ref.watch(mediaDirProvider).path, name));
    return Image.file(file, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}

/// 没有图片时用名字首字生成的色块。
class NamePlaceholder extends StatelessWidget {
  const NamePlaceholder(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final initial = name.isEmpty ? '?' : name.characters.first;
    return ColoredBox(
      color: colors[name.hashCode.abs() % colors.length],
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
