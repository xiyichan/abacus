import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _productionUrl = 'https://abacus.naturoeye.com';
const _devUrl = 'https://abacus.dev.naturoeye.com';

/// 云端服务地址：正式版（release）连生产环境，调试版连开发环境。
/// 可以用 `--dart-define=CLOUD_URL=...` 覆盖，比如连本机的 `http://127.0.0.1:8790`。
const cloudBaseUrl = String.fromEnvironment(
  'CLOUD_URL',
  defaultValue: kReleaseMode ? _productionUrl : _devUrl,
);

class CloudApiException implements Exception {
  const CloudApiException(this.code, [this.status]);

  /// 服务器返回的错误码，如 wrong_code、too_soon；网络问题为 network。
  final String code;
  final int? status;

  bool get isAuthError => status == 401;

  @override
  String toString() => 'CloudApiException($code, $status)';
}

class CloudTeam {
  const CloudTeam({
    required this.id,
    required this.name,
    required this.currency,
  });

  final String id;
  final String name;
  final String currency;
}

/// 云端的 HTTP 接口：邮箱验证码登录、团队登记、取回团队密钥。
class CloudApi {
  CloudApi({String baseUrl = cloudBaseUrl, http.Client? client})
    : _base = Uri.parse(baseUrl),
      _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;

  /// WebSocket 同步地址，如 wss://abacus.naturoeye.com/teams/{团队id}/sync。
  Uri syncUri(String teamId) => _base.replace(
    scheme: _base.scheme == 'https' ? 'wss' : 'ws',
    path: '/teams/$teamId/sync',
  );

  /// 发送验证码。本地开发服务器会直接返回验证码（[devCode]），正式环境为 null。
  Future<String?> startLogin(String email) async {
    final json = await _post('/auth/start', {'email': email});
    return json['devCode'] as String?;
  }

  /// 校验验证码，成功返回登录令牌。
  Future<String> verifyLogin(String email, String code) async {
    final json = await _post('/auth/verify', {'email': email, 'code': code});
    return json['token'] as String;
  }

  Future<void> logout(String token) =>
      _post('/auth/logout', const {}, token: token);

  Future<List<CloudTeam>> listTeams(String token) async {
    final json = await _get('/teams', token);
    return [
      for (final t in json['teams'] as List)
        CloudTeam(
          id: t['id'] as String,
          name: t['name'] as String,
          currency: t['currency'] as String,
        ),
    ];
  }

  Future<void> linkTeam(
    String token, {
    required String teamId,
    required String teamToken,
    required List<int> teamKey,
    required String name,
    required String currency,
  }) => _post('/teams/$teamId/link', {
    'teamToken': teamToken,
    'teamKey': base64Encode(teamKey),
    'name': name,
    'currency': currency,
  }, token: token);

  /// 取回团队密钥（邮箱恢复用）。
  Future<({List<int> teamKey, String name, String currency})> fetchTeamKey(
    String token,
    String teamId,
  ) async {
    final json = await _get('/teams/$teamId/key', token);
    return (
      teamKey: base64Decode(json['teamKey'] as String),
      name: json['name'] as String,
      currency: json['currency'] as String,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) => _send(
    () => _client.post(
      _base.replace(path: path),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ),
  );

  Future<Map<String, dynamic>> _get(String path, String token) => _send(
    () => _client.get(
      _base.replace(path: path),
      headers: {'Authorization': 'Bearer $token'},
    ),
  );

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } on Object {
      throw const CloudApiException('network');
    }
    Map<String, dynamic> json;
    try {
      json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on Object {
      json = const {};
    }
    if (response.statusCode >= 400) {
      throw CloudApiException(
        json['error'] as String? ?? 'http_${response.statusCode}',
        response.statusCode,
      );
    }
    return json;
  }
}
