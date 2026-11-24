// test/infrastructure/errors/error_code_mapper_test.dart
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';

void main() {
  group('PocketCoderErrorCodeMapper.mapError', () {
    test('maps known domain exceptions to stable codes', () {
      expect(
          PocketCoderErrorCodeMapper.mapError(AuthException('x')), 'AUTH_001');
      expect(
          PocketCoderErrorCodeMapper.mapError(ChatException('x')), 'CHAT_001');
      expect(PocketCoderErrorCodeMapper.mapError(ChatListException('x')),
          'CHATLIST_001');
      expect(PocketCoderErrorCodeMapper.mapError(PermissionException('x')),
          'PERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(AiException('x')), 'AI_001');
      expect(PocketCoderErrorCodeMapper.mapError(ToolPermissionsException('x')),
          'TOOLPERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(RepositoryException('x')),
          'REPO_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpException('x')), 'MCP_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpOAuthException('x')),
          'MCP_002');
      expect(PocketCoderErrorCodeMapper.mapError(ObservabilityException('x')),
          'OBS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SkillsException('x')),
          'SKILLS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SchedulerException('x')),
          'SCHED_001');
      expect(PocketCoderErrorCodeMapper.mapError(FilesException('x')),
          'FILES_001');
    });

    test('falls back to ERR_<Type> for unmapped exception types', () {
      expect(PocketCoderErrorCodeMapper.mapError(FormatException('x')),
          'ERR_FormatException');
      expect(PocketCoderErrorCodeMapper.mapError(StateError('x')),
          'ERR_StateError');
    });
  });

  // The inbox groups entries by errorType:errorCode:source, and the report
  // prints the code. A bare AUTH_001 for every AuthException hid whether a
  // device failed on DNS, TLS, a timeout or a wrong password.
  group('PocketCoderErrorCodeMapper.mapError names the failing step and cause',
      () {
    Object wrapped(Object original) => SafeExceptionCause(
        original.runtimeType, original, StackTrace.current);

    String code(Object error) => PocketCoderErrorCodeMapper.mapError(error);

    test('a bare exception keeps its stable base code', () {
      expect(code(AuthException('x')), 'AUTH_001');
    });

    test('adds the step and a DNS cause for a failed host lookup', () {
      final error = AuthException(
          'login failed: ClientException',
          wrapped(ClientException(
              originalError: const SocketException(
                  "Failed host lookup: 'example.sslip.io'"))));
      expect(code(error), 'AUTH_001.LOGIN.DNS');
    });

    test('tells the compatibility check apart from the login step', () {
      final dio = DioException(
          requestOptions: RequestOptions(path: '/compatibility'),
          type: DioExceptionType.connectionTimeout);
      final error = AuthException(
          'verifyServerCompatibility failed: DioException', wrapped(dio));
      expect(code(error), 'AUTH_001.COMPAT.TIMEOUT');
    });

    test('names a cubit-level login timeout', () {
      final error = AuthException(
          'login timed out',
          ClientException(
              originalError:
                  TimeoutException(null, const Duration(seconds: 15))));
      expect(code(error), 'AUTH_001.LOGIN.TIMEOUT');
    });

    test('names TLS, unreachable and dropped-connection causes', () {
      AuthException with0(Object cause) => AuthException(
          'login failed: ClientException',
          wrapped(ClientException(originalError: cause)));
      expect(code(with0(const HandshakeException('x'))), 'AUTH_001.LOGIN.TLS');
      expect(code(with0(const SocketException('Connection refused'))),
          'AUTH_001.LOGIN.UNREACHABLE');
      expect(code(with0(const HttpException('Connection closed'))),
          'AUTH_001.LOGIN.UNREACHABLE');
    });

    test('carries the HTTP status of an answer the server gave', () {
      AuthException status(int s) => AuthException('login failed: ClientException',
          wrapped(ClientException(statusCode: s)));
      expect(code(status(400)), 'AUTH_001.LOGIN.HTTP_400');
      expect(code(status(401)), 'AUTH_001.LOGIN.HTTP_401');
      expect(code(status(502)), 'AUTH_001.LOGIN.HTTP_502');
    });

    test('carries the HTTP status of a Dio bad response', () {
      final dio = DioException(
        requestOptions: RequestOptions(path: '/compatibility'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/compatibility'),
            statusCode: 404),
      );
      expect(
          code(AuthException(
              'verifyServerCompatibility failed: DioException', wrapped(dio))),
          'AUTH_001.COMPAT.HTTP_404');
    });

    test('flags an unparseable answer and a format mismatch', () {
      expect(
          code(AuthException('verifyServerCompatibility failed: FormatException',
              wrapped(const FormatException('mismatch')))),
          'AUTH_001.COMPAT.FORMAT');
    });

    test('names the type of a cause it does not recognise', () {
      expect(
          code(AuthException('login failed: StateError', wrapped(StateError('x')))),
          'AUTH_001.LOGIN.OTHER_StateError');
    });

    test('applies to every domain exception, not only auth', () {
      final socket = wrapped(ClientException(
          originalError: const SocketException('Connection refused')));
      expect(code(ChatException('send failed: ClientException', socket)),
          'CHAT_001.SEND.UNREACHABLE');
      expect(code(FilesException('fetch failed: ClientException', socket)),
          'FILES_001.FETCH.UNREACHABLE');
      expect(code(BillingException('restore failed: PlatformException',
              wrapped(TimeoutException('x')))),
          'BILLING_001.RESTORE.TIMEOUT');
    });

    test('gives previously unmapped domain exceptions a stable base code', () {
      expect(code(GitSshException('x')), 'GITSSH_001');
      expect(code(BillingException('x')), 'BILLING_001');
      expect(code(UserManagementException('x')), 'USERMGMT_001');
      expect(code(LiveActivityException('x')), 'LIVEACT_001');
    });

    test('keeps ERR_<Type> for unknown types and adds a transport cause', () {
      expect(code(ClientException(statusCode: 404)), 'ERR_ClientException.HTTP_404');
    });

    test('distinct causes produce distinct codes', () {
      final codes = <String>{
        for (final original in <Object>[
          const SocketException("Failed host lookup: 'x'"),
          const SocketException('Connection refused'),
          const HandshakeException('x'),
          TimeoutException('x'),
        ])
          code(AuthException('login failed: ClientException',
              wrapped(ClientException(originalError: original)))),
      };
      expect(codes, hasLength(4));
    });

    test('never copies free text from the message into the code', () {
      final error = AuthException(
          'login failed for https://secret.example/token=abc',
          wrapped(ClientException(statusCode: 401)));
      expect(code(error), 'AUTH_001.LOGIN.HTTP_401');
    });
  });
}
