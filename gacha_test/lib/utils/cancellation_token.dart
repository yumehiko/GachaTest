// lib/utils/cancellation_token.dart

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  void throwIfCancellationRequested() {
    if (_isCancelled) {
      throw CancellationException();
    }
  }
}

class CancellationTokenSource {
  final CancellationToken token = CancellationToken();

  void cancel() {
    token.cancel();
  }

  /// 他の CancellationToken と連動させる簡易実装
  static CancellationTokenSource createLinked(CancellationToken ct) {
    final cts = CancellationTokenSource();
    if (ct.isCancelled) {
      cts.cancel();
    }
    return cts;
  }
}

class CancellationException implements Exception {}
