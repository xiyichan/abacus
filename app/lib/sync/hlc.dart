/// 混合逻辑时钟（HLC）。生成的字符串可直接按字典序比较先后，
/// 用于同步时按行“后写为准”。格式：`毫秒(15位)-计数(4位36进制)-设备id`。
class HlcClock {
  HlcClock(this.nodeId, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final String nodeId;
  final DateTime Function() _now;
  int _lastMillis = 0;
  int _counter = 0;

  String tick() {
    final millis = _now().millisecondsSinceEpoch;
    if (millis > _lastMillis) {
      _lastMillis = millis;
      _counter = 0;
    } else {
      _counter++;
    }
    return _format();
  }

  /// 收到其他设备的时间戳后推进本机时钟，保证本机之后的修改排在它后面
  /// （即使本机系统时间比对方慢）。
  void receive(String remote) {
    final parsed = parseHlc(remote);
    if (parsed == null) return;
    final (millis, counter) = parsed;
    if (millis > _lastMillis) {
      _lastMillis = millis;
      _counter = counter;
    } else if (millis == _lastMillis && counter > _counter) {
      _counter = counter;
    }
  }

  String _format() =>
      '${_lastMillis.toString().padLeft(15, '0')}-'
      '${_counter.toRadixString(36).padLeft(4, '0')}-$nodeId';
}

/// 解析 HLC 字符串为 (毫秒, 计数)，格式不对返回 null。
(int, int)? parseHlc(String value) {
  final parts = value.split('-');
  if (parts.length < 3) return null;
  final millis = int.tryParse(parts[0]);
  final counter = int.tryParse(parts[1], radix: 36);
  if (millis == null || counter == null) return null;
  return (millis, counter);
}
