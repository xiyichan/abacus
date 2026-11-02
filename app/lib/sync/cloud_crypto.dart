import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'op_store.dart';

/// 从团队密钥派生出云端用的两把钥匙：
/// - teamToken：交给服务器验证“这台设备确实属于这个团队”；
/// - dataKey：加密上传的同步记录。服务器只拿到 teamToken，解不开数据。
class CloudKeys {
  CloudKeys._(this.teamToken, this._dataKey);

  static Future<CloudKeys> derive(List<int> teamKey) async {
    final hmac = Hmac.sha256();
    final key = SecretKey(teamKey);
    Future<List<int>> label(String l) async =>
        (await hmac.calculateMac(utf8.encode(l), secretKey: key)).bytes;
    final token = base64Url
        .encode(await label('abacus/cloud-auth/v1'))
        .replaceAll('=', '');
    return CloudKeys._(token, SecretKey(await label('abacus/cloud-data/v1')));
  }

  final String teamToken;
  final SecretKey _dataKey;
  static final _aes = AesGcm.with256bits();

  /// 加密一条记录：来源设备和序号保持明文（服务器靠它们算谁缺什么），
  /// 并作为附加认证数据绑定到密文上，防止被调换。
  Future<Map<String, Object?>> seal(SyncOp op) async {
    final clear = utf8.encode(
      jsonEncode({'h': op.hlc, 't': op.table, 'r': op.rowId, 'p': op.row}),
    );
    final box = await _aes.encrypt(
      clear,
      secretKey: _dataKey,
      aad: _aad(op.originDevice, op.seq),
    );
    return {
      'o': op.originDevice,
      's': op.seq,
      'c': base64Encode(box.concatenation()),
    };
  }

  /// 解密一条记录；被篡改或不是本团队的数据返回 null。
  Future<SyncOp?> open(Map<String, dynamic> sealed) async {
    try {
      final origin = sealed['o'] as String;
      final seq = sealed['s'] as int;
      final box = SecretBox.fromConcatenation(
        base64Decode(sealed['c'] as String),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: _dataKey,
        aad: _aad(origin, seq),
      );
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      return SyncOp(
        originDevice: origin,
        seq: seq,
        hlc: json['h'] as String,
        table: json['t'] as String,
        rowId: json['r'] as String,
        row: (json['p'] as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  /// 加密一张图片。文件名作为附加认证数据，防止把一张图的密文当成另一张。
  Future<Uint8List> sealMedia(String name, List<int> bytes) async {
    final box = await _aes.encrypt(
      bytes,
      secretKey: _dataKey,
      aad: _mediaAad(name),
    );
    return box.concatenation();
  }

  /// 解密一张图片；被篡改、文件名对不上或不是本团队的数据返回 null。
  Future<Uint8List?> openMedia(String name, List<int> sealed) async {
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: _dataKey,
        aad: _mediaAad(name),
      );
      return Uint8List.fromList(clear);
    } on Object {
      return null;
    }
  }

  static Uint8List _aad(String origin, int seq) => utf8.encode('$origin:$seq');

  // 带“media/”前缀，和同步记录的“设备:序号”不会重合。
  static Uint8List _mediaAad(String name) => utf8.encode('media/$name');
}
