import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/network_probe.dart';

class _FakeSocket implements Socket {
  @override
  void destroy() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final v4 = InternetAddress('192.155.89.165');
  final v6 = InternetAddress('64:ff9b::c09b:59a5');

  NetworkProbe probe({
    Future<List<InternetAddress>> Function(String host)? lookup,
    Future<Socket> Function(InternetAddress address, int port)? connect,
    Future<Socket> Function(String host, int port)? tls,
  }) =>
      NetworkProbe(
        lookup: lookup ?? (_) async => [v4],
        connect: connect ?? (_, __) async => _FakeSocket(),
        tls: tls ?? (_, __) async => _FakeSocket(),
        stepTimeout: const Duration(milliseconds: 50),
      );

  test('reports dns, tcp and tls when every step works', () async {
    final report = await probe().run(Uri.parse('https://server.example'));

    expect(report, contains('dns ok'));
    expect(report, contains('v4 192.155.89.165'));
    expect(report, contains('tcp 192.155.89.165:443 ok'));
    expect(report, contains('tls ok'));
  });

  test('names the address family so an IPv6-only path is visible', () async {
    final report = await probe(lookup: (_) async => [v6, v4])
        .run(Uri.parse('https://server.example'));

    expect(report, contains('v6 64:ff9b::c09b:59a5'));
    expect(report, contains('v4 192.155.89.165'));
    expect(report, contains('tcp 64:ff9b::c09b:59a5:443 ok'));
    expect(report, contains('tcp 192.155.89.165:443 ok'));
  });

  test('a dns failure stops the probe there and says why', () async {
    final report = await probe(
      lookup: (_) async => throw const SocketException('Failed host lookup'),
    ).run(Uri.parse('https://server.example'));

    expect(report, contains('dns failed'));
    expect(report, isNot(contains('tcp')));
    expect(report, isNot(contains('tls')));
  });

  test('a tcp connect that never answers is reported as a timeout', () async {
    final report = await probe(
      connect: (_, __) => Completer<Socket>().future,
    ).run(Uri.parse('https://server.example'));

    expect(report, contains('tcp 192.155.89.165:443 timeout'));
  });

  test('tcp failing on every address skips tls', () async {
    final report = await probe(
      connect: (_, __) async => throw const SocketException('refused'),
    ).run(Uri.parse('https://server.example'));

    expect(report, contains('tcp 192.155.89.165:443 failed'));
    expect(report, isNot(contains('tls')));
  });

  test('a tls handshake that stalls is reported as a timeout', () async {
    final report = await probe(
      tls: (_, __) => Completer<Socket>().future,
    ).run(Uri.parse('https://server.example'));

    expect(report, contains('tcp 192.155.89.165:443 ok'));
    expect(report, contains('tls timeout'));
  });

  test('plain http has no tls step and defaults to port 80', () async {
    final report = await probe().run(Uri.parse('http://server.example'));

    expect(report, contains(':80 ok'));
    expect(report, isNot(contains('tls')));
  });

  test('never throws, whatever the steps do', () async {
    final report = await probe(
      lookup: (_) async => throw StateError('boom'),
    ).run(Uri.parse('https://server.example'));

    expect(report, contains('dns failed'));
  });
}
