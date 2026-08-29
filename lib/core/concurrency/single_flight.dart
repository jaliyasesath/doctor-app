class SingleFlight {
  final Map<String, Future<dynamic>> _pending = {};

  Future<T> run<T>(String key, Future<T> Function() operation) {
    final running = _pending[key];
    if (running != null) return running as Future<T>;

    final future = operation();
    _pending[key] = future;

    void clear() {
      if (identical(_pending[key], future)) {
        _pending.remove(key);
      }
    }

    future.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace __) => clear(),
    );
    return future;
  }
}
