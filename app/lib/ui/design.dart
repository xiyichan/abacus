import 'package:flutter/animation.dart';

/// 全 App 共用的设计常量（颜色、间距、圆角、动效），界面统一从这里取，改一处全局生效。
///
/// 风格按 iOS 26 原生应用（参考 SwiftUI Pro 的设计规则）：大标题、玻璃质感的悬浮标签栏和工具栏按钮、
/// 系统式空状态和「标题—值」行、最小 44pt 点击区域、跟随系统字体大小。
/// 配色：千禧粉 #FFD1DC + 雾玫瑰 #FFE4E1，整体偏暖。
abstract final class Brand {
  /// 千禧粉：选中状态、主要高亮。
  static const blush = Color(0xFFFFD1DC);

  /// 雾玫瑰：次要高亮。
  static const mistyRose = Color(0xFFFFE4E1);

  /// 主色（按钮、链接、选中图标）：偏珊瑚的暖玫红，白字对比度约 5.3:1。
  static const rose = Color(0xFFB4465A);

  /// 浅粉底上的文字（约 12:1）。
  static const wine = Color(0xFF401518);

  /// 分组列表的背景（暖色版 systemGroupedBackground），上面放白色单元格。
  static const grouped = Color(0xFFF9F1EF);
  static const groupedNight = Color(0xFF120B0A);
  static const cellNight = Color(0xFF241917);

  /// 设置页图标方块的颜色（白色图标）。
  static const tiles = [
    Color(0xFFB4465A), // 玫红
    Color(0xFFD9744F), // 珊瑚
    Color(0xFF6E8B5B), // 鼠尾草绿
    Color(0xFF7A4B5C), // 梅子
    Color(0xFF8E8A93), // 灰
  ];
}

/// 间距：xs 4 / sm 8 / md 12 / lg 16 / xl 24。
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// 圆角：分组卡片 20，输入框 12，对话框 20；按钮、标签栏、工具栏按钮都是胶囊。
abstract final class Radii {
  static const sm = 12.0;
  static const field = 12.0;
  static const card = 20.0;
  static const dialog = 20.0;
  static const pill = 999.0;
}

/// 动效：统一缓动，0.15–0.25 秒。
abstract final class Motion {
  static const curve = Cubic(0.4, 0, 0.2, 1);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}

/// iOS 要求的最小点击区域。
const minTapSize = 44.0;
