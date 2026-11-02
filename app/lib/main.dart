import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/database.dart';
import 'data/session.dart';
import 'features/lock/cashier_lock.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'ui/design.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final docs = await getApplicationDocumentsDirectory();
  runApp(AppRoot(db: db, mediaDir: Directory(p.join(docs.path, 'media'))));
}

/// 加载本机身份后搭起 ProviderScope。加入新团队后整体重建（换会话、重启同步）。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.db, required this.mediaDir});

  final AppDatabase db;
  final Directory mediaDir;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late Future<Session> _session = ensureSession(widget.db);
  int _generation = 0;

  void _restart() => setState(() {
    _generation++;
    _session = ensureSession(widget.db);
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _session,
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return const ColoredBox(color: Brand.grouped);
        }
        return ProviderScope(
          key: ValueKey(_generation),
          overrides: [
            databaseProvider.overrideWithValue(widget.db),
            sessionProvider.overrideWithValue(session),
            mediaDirProvider.overrideWithValue(widget.mediaDir),
            restartAppProvider.overrideWithValue(_restart),
          ],
          child: const AbacusApp(),
        );
      },
    );
  }
}

class AbacusApp extends ConsumerStatefulWidget {
  const AbacusApp({super.key});

  @override
  ConsumerState<AbacusApp> createState() => _AbacusAppState();
}

class _AbacusAppState extends ConsumerState<AbacusApp> {
  final _locked = ValueNotifier(false);
  late final GoRouter _router = createRouter(locked: _locked);

  @override
  void initState() {
    super.initState();
    // 收银锁状态交给路由：锁着时只能停在收银台。
    ref.listenManual(
      cashierLockedProvider,
      (_, next) => _locked.value = next.value ?? false,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _locked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // 先只开放中文；英文翻译已就绪，海外版时去掉这一行即可跟随系统语言。
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      // 跟随系统的大字体设置，最大放大到 2 倍（再大收银台的网格和购物车就放不下了）。
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child!),
    );
  }
}
