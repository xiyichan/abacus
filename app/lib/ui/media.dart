import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../data/session.dart';
import '../providers.dart';
import '../sync/media_store.dart';

/// 从相册选一张图片，缩到 [maxSize] 以内后复制到 App 自己的目录，
/// 返回文件名（取消时为 null）。商品图用 1024 就够清楚，同步也快；收款码要扫得出来，用默认值。
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

/// 别的设备传来新图片时加一，显示图片的地方据此刷新。
final _mediaArrivalsProvider = StreamProvider<int>((ref) async* {
  final store = ref.watch(mediaStoreProvider);
  var count = 0;
  yield count;
  await for (final name in store.received) {
    // 文件到之前加载失败过，先清掉缓存里的失败结果再重新加载。
    await FileImage(store.file(name)).evict();
    yield ++count;
  }
});

/// 显示 App 目录里保存的图片；没有图片（或还没从别的设备同步过来）时显示 [placeholder]。
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
    if (name == null || !MediaStore.isValidName(name)) return fallback;
    final arrivals = ref.watch(_mediaArrivalsProvider).value ?? 0;
    final file = ref.watch(mediaStoreProvider).file(name);
    return Image.file(
      file,
      key: ValueKey('$name#$arrivals'),
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// 没有图片时用名字首字生成的色块：千禧粉、雾玫瑰、浅桃三种暖色轮换，深酒红字。
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
    // 稳定的字符串哈希（不同平台、每次启动都一样）。
    final hash = name.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    final initial = name.isEmpty ? '?' : name.characters.first;
    return ColoredBox(
      color: colors[hash % colors.length],
      // 首字随色块大小缩放（约四成边长，最大 32），小缩略图里不会显得笨重。
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontSize: (constraints.biggest.shortestSide * 0.4).clamp(
                12.0,
                32.0,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
