import 'dart:async';
import 'dart:io';

/// Walks the path to a server one hop at a time -- DNS, TCP per address,
/// TLS -- and says which hop failed or stalled. A login that times out only
/// says "the server didn't answer"; this says whether the name resolved, to
/// which address families, and whether the connection or the handshake is
/// what never completed.
///
/// Only hop names, address literals of the server the user typed, and
/// timings are reported -- never headers, bodies or credentials.
class NetworkProbe {
  NetworkProbe({
    Future<List<InternetAddress>> Function(String host)? lookup,
    Future<Socket> Function(InternetAddress address, int port)? connect,
    Future<Socket> Function(String host, int port)? tls,
    this.stepTimeout = const Duration(seconds: 5),
  })  : _lookup = lookup ?? InternetAddress.lookup,
        _connect = connect ?? _defaultConnect,
        _tls = tls ?? _defaultTls;

  static const int _maxAddresses = 3;

  final Future<List<InternetAddress>> Function(String host) _lookup;
  final Future<Socket> Function(InternetAddress address, int port) _connect;
  final Future<Socket> Function(String host, int port) _tls;
  final Duration stepTimeout;

  static Future<Socket> _defaultConnect(InternetAddress address, int port) =>
      Socket.connect(address, port);

  static Future<Socket> _defaultTls(String host, int port) =>
      SecureSocket.connect(host, port);

  /// Never throws; a probe that breaks must not hide the failure it
  /// was asked to explain.
  Future<String> run(Uri url) async {
    final lines = <String>[];
    try {
      await _walk(url, lines);
    } catch (error) {
      lines.add('probe failed ${error.runtimeType}');
    }
    return lines.join('\n');
  }

  Future<void> _walk(Uri url, List<String> lines) async {
    final host = url.host;
    final secure = url.scheme != 'http';
    final port = url.hasPort ? url.port : (secure ? 443 : 80);

    final addresses = await _dns(host, lines);
    if (addresses.isEmpty) return;

    var reachable = false;
    for (final address in addresses.take(_maxAddresses)) {
      final label = 'tcp ${address.address}:$port';
      final result = await _timed(
        _connect(address, port),
        onDone: (socket) => socket.destroy(),
      );
      lines.add('$label ${result.describe()}');
      reachable = reachable || result.ok;
    }
    if (!reachable || !secure) return;

    final result = await _timed(
      _tls(host, port),
      onDone: (socket) => socket.destroy(),
    );
    lines.add('tls ${result.describe()}');
  }

  Future<List<InternetAddress>> _dns(String host, List<String> lines) async {
    final watch = Stopwatch()..start();
    try {
      final addresses = await _lookup(host).timeout(stepTimeout);
      final shown = addresses
          .map((a) =>
              '${a.type == InternetAddressType.IPv6 ? 'v6' : 'v4'} ${a.address}')
          .join(', ');
      lines.add('dns ok ${watch.elapsedMilliseconds}ms '
          '${addresses.isEmpty ? 'no addresses' : shown}');
      return addresses;
    } on TimeoutException {
      lines.add('dns timeout ${watch.elapsedMilliseconds}ms');
    } catch (error) {
      lines.add('dns failed ${watch.elapsedMilliseconds}ms '
          '${error.runtimeType}');
    }
    return const [];
  }

  Future<_Hop> _timed<T>(Future<T> step,
      {required void Function(T) onDone}) async {
    final watch = Stopwatch()..start();
    try {
      final value = await step.timeout(stepTimeout);
      onDone(value);
      return _Hop(watch.elapsedMilliseconds);
    } on TimeoutException {
      // A late socket would otherwise leak once the connect finally lands.
      unawaited(step.then(onDone, onError: (_) {}));
      return _Hop(watch.elapsedMilliseconds, 'timeout');
    } catch (error) {
      return _Hop(watch.elapsedMilliseconds, 'failed ${error.runtimeType}');
    }
  }
}

class _Hop {
  _Hop(this.ms, [this.problem]);

  final int ms;
  final String? problem;

  bool get ok => problem == null;

  String describe() => ok ? 'ok ${ms}ms' : '$problem ${ms}ms';
}
