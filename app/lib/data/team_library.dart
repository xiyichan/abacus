import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'database.dart';
import 'session.dart';

/// 本机保存的一个团队。
@immutable
class LocalTeam {
  const LocalTeam({required this.key, this.teamId, this.name = ''});

  /// 数据库文件名（不含 .sqlite）。
  final String key;

  /// 团队 id、名字：上次打开时记下的，用来在切换列表里显示、判断是不是同一个团队。
  final String? teamId;
  final String name;

  LocalTeam copyWith({String? teamId, String? name}) => LocalTeam(
    key: key,
    teamId: teamId ?? this.teamId,
    name: name ?? this.name,
  );

  Map<String, Object?> toJson() => {'key': key, 'teamId': teamId, 'name': name};

  static LocalTeam fromJson(Map<String, dynamic> json) => LocalTeam(
    key: json['key'] as String,
    teamId: json['teamId'] as String?,
    name: json['name'] as String? ?? '',
  );
}

/// 整个 App 共用的云端登录。每个团队的数据库里也各存一份（云端同步从那里读），
/// 打开团队时用这里的覆盖过去，所以登录一次、换哪个团队都不用再登录。
@immutable
class CloudAccount {
  const CloudAccount({
    required this.token,
    required this.email,
    this.displayName,
  });

  final String token;
  final String email;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'token': token,
    'email': email,
    'displayName': displayName,
  };

  static CloudAccount fromJson(Map<String, dynamic> json) => CloudAccount(
    token: json['token'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
  );
}

/// 本机的团队：每个团队一个数据库文件（`<文档目录>/<key>.sqlite`），互不影响，
/// 切换团队就是换一个数据库打开，不清空任何数据。索引 teams.json 记着有哪些团队、
/// 当前用哪个，以及共用的云端登录。
///
/// 早期版本只有一个 abacus.sqlite：没有索引时把它当作唯一的团队。
class TeamLibrary {
  TeamLibrary._(
    this.dir,
    this._open,
    this._teams,
    this._current,
    this._account, {
    this._accountKnown = true,
  });

  /// 读取索引。[open] 按文件名打开数据库（测试里换成临时文件）。
  factory TeamLibrary.load(
    Directory dir, {
    AppDatabase Function(String key)? open,
  }) {
    final opener = open ?? AppDatabase.named;
    final file = File(p.join(dir.path, _indexName));
    if (file.existsSync()) {
      try {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final teams = [
          for (final t in json['teams'] as List)
            LocalTeam.fromJson((t as Map).cast()),
        ];
        final current = json['current'] as String?;
        if (teams.isNotEmpty) {
          return TeamLibrary._(
            dir,
            opener,
            teams,
            teams.any((t) => t.key == current) ? current! : teams.first.key,
            switch (json['account']) {
              final Map<String, dynamic> a => CloudAccount.fromJson(a),
              _ => null,
            },
          );
        }
      } on Object catch (e) {
        debugPrint('teams.json unreadable, starting over: $e');
      }
    }
    return TeamLibrary._(
      dir,
      opener,
      [const LocalTeam(key: legacyKey)],
      legacyKey,
      null,
      accountKnown: false,
    );
  }

  static const legacyKey = 'abacus';
  static const _indexName = 'teams.json';

  final Directory dir;
  final AppDatabase Function(String key) _open;
  final List<LocalTeam> _teams;
  String _current;
  CloudAccount? _account;
  bool _accountKnown;

  List<LocalTeam> get teams => List.unmodifiable(_teams);
  String get currentKey => _current;
  LocalTeam get current => _teams.firstWhere((t) => t.key == _current);
  CloudAccount? get account => _account;

  /// 刚从旧版本升级、还没有索引时为 false：共用的登录还不知道，
  /// 要从原来那个数据库里取（不能当成“已退出”把它清掉）。
  bool get accountKnown => _accountKnown;

  AppDatabase open(String key) => _open(key);

  LocalTeam? byTeamId(String teamId) =>
      _teams.where((t) => t.teamId == teamId).firstOrNull;

  /// 新团队的数据库文件名。
  String newKey() => 'abacus-${newId()}';

  void add(LocalTeam team) {
    _teams.add(team);
    _save();
  }

  void setCurrent(String key) {
    if (!_teams.any((t) => t.key == key)) return;
    _current = key;
    _save();
  }

  /// 记下团队的 id 和名字（打开时、改名后）。
  void remember(String key, {required String teamId, required String name}) {
    final i = _teams.indexWhere((t) => t.key == key);
    if (i < 0) return;
    if (_teams[i].teamId == teamId && _teams[i].name == name) return;
    _teams[i] = _teams[i].copyWith(teamId: teamId, name: name);
    _save();
  }

  void setAccount(CloudAccount? account) {
    _account = account;
    _accountKnown = true;
    _save();
  }

  /// 从本机移除一个团队（删掉它的数据库文件）。当前团队不能移除。
  void remove(String key) {
    if (key == _current) return;
    _teams.removeWhere((t) => t.key == key);
    _save();
    deleteFiles(key);
  }

  /// 删掉某个数据库文件（移除团队，或新建团队没成功时清理）。
  void deleteFiles(String key) {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File(p.join(dir.path, '$key.sqlite$suffix'));
      if (file.existsSync()) file.deleteSync();
    }
  }

  // 索引很小，同步读写即可（也让测试里不用等真实异步）。
  void _save() {
    dir.createSync(recursive: true);
    final file = File(p.join(dir.path, '$_indexName.part'));
    file.writeAsStringSync(
      jsonEncode({
        'current': _current,
        'teams': [for (final t in _teams) t.toJson()],
        'account': _account?.toJson(),
      }),
      flush: true,
    );
    file.renameSync(p.join(dir.path, _indexName));
  }
}
