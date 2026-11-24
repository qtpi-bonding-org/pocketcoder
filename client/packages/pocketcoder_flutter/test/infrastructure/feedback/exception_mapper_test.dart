// Regression test for a real class of bug: an exception type reaching
// UiFlowListener's fallback with no AppExceptionKeyMapper entry renders as
// Dart's default Object.toString() (e.g. "Instance of
// 'ProviderReauthenticationRequired'") or, for a DomainException subtype,
// as its raw internal detail (e.g. "ObservabilityException: failed to
// fetch traces") -- both violate this project's "technical detail stays
// in logs, user messages are generic + localized" rule. Already fixed
// once for AgentActionFailure (see agent_actions_api.dart); this covers
// the remaining unmapped types found in the E2E audit.
import 'dart:async';
import 'dart:io';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart';

void main() {
  final mapper = AppExceptionKeyMapper();

  test(
      'maps ProviderReauthenticationRequired to its dedicated, already-'
      'localized key instead of falling through to null', () {
    final key = mapper.map(const ProviderReauthenticationRequired());
    expect(key, isNotNull);
    expect(key!.key, 'provider.reauthentication.required');
  });

  test(
      'maps every previously-unmapped DomainException subtype to a safe '
      'generic key, not null', () {
    final errors = <Object>[
      RepositoryException('boom'),
      McpException('boom'),
      ObservabilityException('boom'),
      SkillsException('boom'),
      SchedulerException('boom'),
      FilesException('boom'),
    ];
    for (final error in errors) {
      final key = mapper.map(error);
      expect(key, isNotNull, reason: '${error.runtimeType} should be mapped');
      expect(key!.key, MessageKey.genericError.key,
          reason: '${error.runtimeType} should fall back to the generic '
              'error key, not leak its raw message');
    }
  });

  group('AuthException unwrapping', () {
    AuthException wrap(Object original) => AuthException(
          'operation failed: ${original.runtimeType}',
          SafeExceptionCause(
              original.runtimeType, original, StackTrace.current),
        );

    test('maps a definite rejection (401/403/400) to auth.login.failed', () {
      for (final status in [400, 401, 403]) {
        final key =
            mapper.map(wrap(ClientException(statusCode: status)));
        expect(key!.key, 'auth.login.failed',
            reason: 'statusCode $status is a definite server rejection');
      }
    });

    test(
        'maps a transport failure with no recognisable cause (statusCode 0) '
        'to the generic network key, not a credentials message', () {
      final key = mapper.map(wrap(ClientException(statusCode: 0)));
      expect(key!.key, 'error.network');
    });

    test('maps a 5xx response to a dedicated server-error key', () {
      for (final status in [500, 502, 503]) {
        final key = mapper.map(wrap(ClientException(statusCode: status)));
        expect(key!.key, 'auth.server.error',
            reason: 'statusCode $status means the server answered badly');
      }
    });

    test('maps a transport timeout to auth.server.timeout', () {
      final key = mapper.map(wrap(ClientException(
          originalError: TimeoutException(null, const Duration(seconds: 15)))));
      expect(key!.key, 'auth.server.timeout');
    });

    test('maps a failed DNS lookup to auth.server.dns', () {
      final key = mapper.map(wrap(ClientException(
          originalError: const SocketException(
              "Failed host lookup: 'example.sslip.io'"))));
      expect(key!.key, 'auth.server.dns');
    });

    test('maps a refused or unreachable connection to auth.server.unreachable',
        () {
      for (final error in [
        const SocketException('Connection refused'),
        const SocketException('Network is unreachable'),
        const SocketException('Connection reset by peer'),
      ]) {
        final key = mapper.map(wrap(ClientException(originalError: error)));
        expect(key!.key, 'auth.server.unreachable', reason: '$error');
      }
    });

    test('maps a TLS/certificate failure to auth.server.tls', () {
      for (final error in [
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        const TlsException('bad cert'),
      ]) {
        final key = mapper.map(wrap(ClientException(originalError: error)));
        expect(key!.key, 'auth.server.tls', reason: '$error');
      }
    });

    test('maps a dropped connection (dart:io HttpException) to unreachable',
        () {
      final key = mapper.map(wrap(ClientException(
          originalError: const HttpException('Connection closed'))));
      expect(key!.key, 'auth.server.unreachable');
    });

    test(
        'names the exception type for an unrecognised cause instead of a '
        'bare network error', () {
      final key = mapper
          .map(wrap(ClientException(originalError: StateError('closed'))));
      expect(key!.key, 'auth.server.unexpected');
      expect(key.args, {'detail': 'StateError'});
    });

    group('Dio transport failures (the compatibility check)', () {
      final options = RequestOptions(path: '/api/pocketcoder/v1/compatibility');

      DioException dio(DioExceptionType type, {Object? error, int? status}) =>
          DioException(
            requestOptions: options,
            type: type,
            error: error,
            response: status == null
                ? null
                : Response<dynamic>(requestOptions: options, statusCode: status),
          );

      test('maps every Dio timeout type to auth.server.timeout', () {
        for (final type in [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        ]) {
          expect(mapper.map(wrap(dio(type)))!.key, 'auth.server.timeout',
              reason: '$type');
        }
      });

      test('classifies a Dio connection error by its socket cause', () {
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.connectionError,
                    error: const SocketException("Failed host lookup: 'x'"))))!
                .key,
            'auth.server.dns');
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.connectionError,
                    error: const SocketException('Connection refused'))))!
                .key,
            'auth.server.unreachable');
      });

      test('maps a Dio bad certificate or handshake error to auth.server.tls',
          () {
        expect(mapper.map(wrap(dio(DioExceptionType.badCertificate)))!.key,
            'auth.server.tls');
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.unknown,
                    error: const HandshakeException('x'))))!
                .key,
            'auth.server.tls');
      });

      test('maps a Dio 5xx response to auth.server.error', () {
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.badResponse, status: 502)))!
                .key,
            'auth.server.error');
      });

      test('maps a Dio 401/403 to auth.login.failed', () {
        for (final status in [401, 403]) {
          expect(
              mapper
                  .map(wrap(dio(DioExceptionType.badResponse, status: status)))!
                  .key,
              'auth.login.failed',
              reason: '$status');
        }
      });

      test('maps any other Dio non-5xx answer to auth.server.incompatible', () {
        for (final status in [302, 405, 418]) {
          expect(
              mapper
                  .map(wrap(dio(DioExceptionType.badResponse, status: status)))!
                  .key,
              'auth.server.incompatible',
              reason: '$status');
        }
      });

      test(
          'maps a 200 answer that cannot be parsed (captive portal, wrong '
          'server) to auth.server.incompatible', () {
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.unknown,
                    error: const FormatException('not json'), status: 200)))!
                .key,
            'auth.server.incompatible');
      });

      test('maps a Dio 404 (server answered, wrong app) to auth.server.incompatible',
          () {
        expect(
            mapper
                .map(wrap(dio(DioExceptionType.badResponse, status: 404)))!
                .key,
            'auth.server.incompatible');
      });
    });

    test(
        'maps a compatibility mismatch (FormatException from '
        'verifyServerCompatibility) to a dedicated incompatible-server key',
        () {
      final key = mapper.map(wrap(const FormatException('mismatch')));
      expect(key!.key, 'auth.server.incompatible');
    });
  });
}
