import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 打开系统分享面板（存到“文件”、发给其他 App 等）。[origin] 是 iPad 上分享面板的锚点。
typedef ShareFiles = Future<void> Function(
  List<XFile> files, {
  String? subject,
  Rect? origin,
});

/// 测试里可以替换成记录分享内容的假实现。
final shareFilesProvider = Provider<ShareFiles>(
  (ref) =>
      (files, {subject, origin}) => SharePlus.instance.share(
        ShareParams(
          files: files,
          subject: subject,
          sharePositionOrigin: origin,
        ),
      ),
);

/// 生成待分享文件用的临时目录（测试里换成系统临时目录）。
final shareTempDirProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);
