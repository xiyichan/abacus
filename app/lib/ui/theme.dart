import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';

/// 主题：千禧粉 + 雾玫瑰的暖色配色，按 iOS 26 原生应用的样子来。
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(
    seedColor: Brand.rose,
    brightness: brightness,
  );
  final scheme = light
      ? base.copyWith(
          primary: Brand.rose,
          onPrimary: Colors.white,
          primaryContainer: Brand.blush,
          onPrimaryContainer: Brand.wine,
          secondary: const Color(0xFF8F4E4A),
          onSecondary: Colors.white,
          secondaryContainer: Brand.mistyRose,
          onSecondaryContainer: Brand.wine,
          tertiary: const Color(0xFF9A5A44),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFFD9CE),
          onTertiaryContainer: Brand.wine,
          surface: Brand.grouped,
          onSurface: const Color(0xFF2E1A18),
          onSurfaceVariant: const Color(0xFF6B5451),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerHigh: const Color(0xFFFFEBE8),
          surfaceContainerHighest: const Color(0xFFF8DCD8),
          outlineVariant: const Color(0xFFEBD9D6),
        )
      : base.copyWith(
          primary: const Color(0xFFFFB4AB),
          onPrimary: Brand.wine,
          primaryContainer: const Color(0xFF5C2A2C),
          onPrimaryContainer: Brand.mistyRose,
          secondary: const Color(0xFFE7BDB7),
          onSecondary: Brand.wine,
          secondaryContainer: const Color(0xFF4A2B29),
          onSecondaryContainer: Brand.mistyRose,
          tertiary: Brand.blush,
          onTertiary: Brand.wine,
          tertiaryContainer: const Color(0xFF6A3530),
          onTertiaryContainer: Brand.mistyRose,
          surface: Brand.groupedNight,
          onSurface: const Color(0xFFF2DEDB),
          onSurfaceVariant: const Color(0xFFD8C0BC),
          surfaceContainerLowest: Brand.cellNight,
          surfaceContainerLow: Brand.cellNight,
          surfaceContainer: Brand.cellNight,
          surfaceContainerHigh: const Color(0xFF362826),
          surfaceContainerHighest: const Color(0xFF413230),
          outlineVariant: const Color(0xFF3E2E2B),
        );
  return _iosStyle(scheme);
}

/// iOS 26 风格：所有平台都用 iOS 转场（可右滑返回）、回弹滚动和系统字体，没有水波纹；
/// 分组背景上放白色圆角单元格；按钮是胶囊；.adaptive 控件显示成 iOS 原生样式。
ThemeData _iosStyle(ColorScheme scheme) {
  final cell = scheme.surfaceContainer;
  final hairline = scheme.outlineVariant;
  final fill = scheme.onSurface.withValues(alpha: 0.06);
  const pill = StadiumBorder();

  final theme = ThemeData(colorScheme: scheme, platform: TargetPlatform.iOS);
  final t = theme.textTheme;
  // 标题用粗体（iOS 的大标题和导航标题都是粗体），正文常规。
  final text = t.copyWith(
    displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
  final buttonText = text.titleMedium?.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.field)),
        borderSide: BorderSide(color: color, width: width),
      );

  return theme.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: fill,
    hoverColor: Colors.transparent,
    dividerColor: hairline,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const CupertinoPageTransitionsBuilder(),
      },
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: scheme.primary,
      brightness: scheme.brightness,
      barBackgroundColor: scheme.surface.withValues(alpha: 0.8),
      scaffoldBackgroundColor: scheme.surface,
      textTheme: CupertinoTextThemeData(
        primaryColor: scheme.primary,
        navLargeTitleTextStyle: TextStyle(
          inherit: false,
          fontFamily: 'CupertinoSystemDisplay',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: scheme.onSurface,
        ),
        navTitleTextStyle: TextStyle(
          inherit: false,
          fontFamily: 'CupertinoSystemText',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      iconTheme: IconThemeData(color: scheme.primary),
      actionsIconTheme: IconThemeData(color: scheme.primary),
      titleTextStyle: text.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: cell,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      minTileHeight: minTapSize + 4,
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 0.5),
    // iOS 26 的突出按钮：主色胶囊。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, minTapSize + 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    // 次要按钮：浅主色底的胶囊（iOS 的 bordered 样式），不描边。
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, minTapSize + 6),
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        foregroundColor: scheme.primary,
        side: BorderSide.none,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        minimumSize: const Size(minTapSize, minTapSize),
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTapSize, minTapSize),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: fill,
        selectedBackgroundColor: cell,
        selectedForegroundColor: scheme.onSurface,
        side: BorderSide.none,
        shape: pill,
        minimumSize: const Size(minTapSize, minTapSize),
      ),
    ),
    // 文字颜色不随选中变化（按状态变的文字样式会被 Chip 合并丢掉），选中靠千禧粉底色和描边区分。
    chipTheme: ChipThemeData(
      shape: pill,
      showCheckmark: false,
      color: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? scheme.primaryContainer : cell,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected) ? scheme.primary : hairline,
        ),
      ),
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cell,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: fieldBorder(hairline),
      enabledBorder: fieldBorder(hairline),
      focusedBorder: fieldBorder(scheme.primary, 1.5),
      errorBorder: fieldBorder(scheme.error),
      focusedErrorBorder: fieldBorder(scheme.error, 1.5),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        scheme.onSurface.withValues(alpha: 0.07),
      ),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      constraints: const BoxConstraints(minHeight: minTapSize),
      shape: const WidgetStatePropertyAll(pill),
      hintStyle: WidgetStatePropertyAll(
        text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cell,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.dialog)),
      ),
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.dialog)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cell,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.sm)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
  );
}
