import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/database.dart';
import 'data/session.dart';
import 'data/team_library.dart';
import 'features/lock/cashier_lock.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'support/tip_jar.dart';
import 'sync/cloud_sync_service.dart';
import 'ui/design.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final support = SupportPrefs.load(File(p.join(docs.path, 'support.json')));
  final tips = InAppPurchaseTipStore(support)..listen();
  runApp(
    AppRoot(
      library: TeamLibrary.load(docs),
      mediaDir: Directory(p.join(docs.path, 'media')),
      overrides: [
        supportPrefsProvider.overrideWithValue(support),
        tipStoreProvider.overrideWithValue(tips),
      ],
    ),
  );
}

/// 打开当前团队的数据库、加载本机身份后搭起 ProviderScope。
/// 换团队时关掉这个数据库、打开另一个，界面和同步服务整体重建。
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.library,
    required this.mediaDir,
    this.overrides = const [],
  });

  final TeamLibrary library;
  final Directory mediaDir;

  /// 额外的覆盖（测试里关掉局域网同步等）。
  final List<Override> overrides;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> implements TeamSwitcher {
  @override
  TeamLibrary get library => widget.library;

  late AppDatabase _db = library.open(library.currentKey);
  late Future<Session> _session = _load(_db, library.currentKey);
  int _generation = 0;

  /// 正在换团队（期间再点切换不理会）。
  bool _switching = false;

  /// 换团队时全屏显示的提示；null 表示没在换。
  String? _busyMessage;

  /// 打开一个团队：写入共用的云端登录，读本机身份，顺便记下团队名字给切换列表用。
  Future<Session> _load(AppDatabase db, String key) async {
    // 从旧版本升级：沿用原来数据库里的登录，而不是把它清掉。
    if (!library.accountKnown) library.setAccount(await readCloudAccount(db));
    await applyCloudAccount(db, library.account);
    final session = await ensureSession(db);
    await _remember(db, key, session.teamId);
    return session;
  }

  Future<void> _remember(AppDatabase db, String key, String teamId) async {
    final team = await (db.select(
      db.teams,
    )..where((t) => t.id.equals(teamId))).getSingleOrNull();
    library.remember(key, teamId: teamId, name: team?.name ?? '');
  }

  void _restart() => setState(() {
    _generation++;
    _session = _load(_db, library.currentKey);
  });

  /// 换成 [db]：先卸掉旧团队的界面（同步服务随 ProviderScope 销毁），再关旧数据库。
  Future<void> _replace(AppDatabase db, String key) async {
    _switching = true;
    try {
      final old = _db;
      final oldKey = library.currentKey;
      final oldSession = await _session;
      await _remember(old, oldKey, oldSession.teamId); // 期间可能改过团队名
      setState(() {
        _session = Completer<Session>().future;
      });
      await WidgetsBinding.instance.endOfFrame;
      // 关库要等它上面的查询都收尾；最多等一会儿，剩下的在后台关完，不让切换卡住。
      if (!identical(old, db)) {
        await old.close().timeout(const Duration(seconds: 2), onTimeout: () {});
      }
      library.setCurrent(key);
      setState(() {
        _db = db;
        _generation++;
        _session = _load(db, key);
      });
    } finally {
      _switching = false;
    }
  }

  @override
  Future<void> switchTo(String key) async {
    if (_switching || key == library.currentKey) return;
    await _replace(library.open(key), key);
  }

  @override
  Future<void> add(Future<void> Function(AppDatabase db) setup) async {
    if (_switching) return;
    final key = library.newKey();
    final db = library.open(key);
    try {
      await setup(db);
    } on Object {
      await db.close();
      library.deleteFiles(key);
      rethrow;
    }
    library.add(LocalTeam(key: key));
    await _replace(db, key);
  }

  @override
  Future<void> busy(String message, Future<void> Function() task) async {
    setState(() => _busyMessage = message);
    // 先把加载画面画出来，再开始停同步、关库这些耗时的事。
    await WidgetsBinding.instance.endOfFrame;
    try {
      await task();
      await _session; // 新团队打开了再撤掉
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = FutureBuilder(
      future: _session,
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return const ColoredBox(color: Brand.grouped);
        }
        return ProviderScope(
          key: ValueKey(_generation),
          overrides: [
            databaseProvider.overrideWithValue(_db),
            sessionProvider.overrideWithValue(session),
            mediaDirProvider.overrideWithValue(widget.mediaDir),
            restartAppProvider.overrideWithValue(_restart),
            teamSwitcherProvider.overrideWithValue(this),
            ...widget.overrides,
          ],
          child: const AbacusApp(),
        );
      },
    );
    final message = _busyMessage;
    // 加载画面盖在整个 App 上面（下面的界面不卸掉：下载失败时还要回到原来的面板显示错误）。
    // 结构始终不变，免得加上盖层时整个 App 被拆掉重建。
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          app,
          if (message != null) _SwitchingScreen(message: message),
        ],
      ),
    );
  }
}

/// 换团队时的全屏加载画面。在 MaterialApp 外面，所以字体颜色都自己给。
class _SwitchingScreen extends StatelessWidget {
  const _SwitchingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final theme = buildTheme(dark ? Brightness.dark : Brightness.light);
    return AbsorbPointer(
      child: Semantics(
        liveRegion: true,
        label: message,
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
                const SizedBox(height: Gap.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
