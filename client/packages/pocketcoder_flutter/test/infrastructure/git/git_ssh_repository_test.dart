import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'package:pocketcoder_flutter/infrastructure/git/git_ssh_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/git/git_ssh_repository.dart';

class MockGitSshCredentialDao extends Mock implements GitSshCredentialDao {}

class MockGitRepositoryAccessDao extends Mock
    implements GitRepositoryAccessDao {}

class _FakeCredential extends Fake implements GitSshCredential {}

class _FakeAccess extends Fake implements GitRepositoryAccess {}

void main() {
  late GitSshRepository repo;
  late MockGitSshCredentialDao credentialDao;
  late MockGitRepositoryAccessDao accessDao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    credentialDao = MockGitSshCredentialDao();
    accessDao = MockGitRepositoryAccessDao();
    repo = GitSshRepository(credentialDao, accessDao);
  });

  group('GitSshRepository.createAccountKey', () {
    test('creates a generated account-kind credential', () async {
      when(() => credentialDao.save(any(), any()))
          .thenAnswer((_) async => _FakeCredential());

      await repo.createAccountKey('my laptop key');

      verify(() => credentialDao.save(null, {
            'label': 'my laptop key',
            'kind': 'account',
            'source': 'generated',
            'algorithm': 'ed25519',
          })).called(1);
    });

    test('wraps failures in GitSshException', () async {
      when(() => credentialDao.save(any(), any())).thenThrow(Exception('x'));

      await expectLater(
        () => repo.createAccountKey('label'),
        throwsA(isA<GitSshException>()),
      );
    });
  });

  group('GitSshRepository.addRepositoryAccess', () {
    test('creates a generated_deploy access row for a built-in provider',
        () async {
      when(() => accessDao.save(any(), any()))
          .thenAnswer((_) async => _FakeAccess());

      await repo.addRepositoryAccess(
        provider: GitRepositoryAccessProvider.github,
        repository: 'octo/hello',
        purpose: 'push CI fixes',
        credentialMode: GitRepositoryAccessCredentialMode.generatedDeploy,
        requestedAccess: GitRepositoryAccessRequestedAccess.readWrite,
      );

      verify(() => accessDao.save(null, {
            'provider': 'github',
            'repository': 'octo/hello',
            'purpose': 'push CI fixes',
            'credential_mode': 'generated_deploy',
            'requested_access': 'read_write',
          })).called(1);
    });

    test('includes host/port for a custom provider', () async {
      when(() => accessDao.save(any(), any()))
          .thenAnswer((_) async => _FakeAccess());

      await repo.addRepositoryAccess(
        provider: GitRepositoryAccessProvider.custom,
        repository: 'org/repo',
        purpose: 'clone my self-hosted repo',
        credentialMode: GitRepositoryAccessCredentialMode.generatedDeploy,
        requestedAccess: GitRepositoryAccessRequestedAccess.readOnly,
        host: 'git.example.com',
        port: 2222,
      );

      verify(() => accessDao.save(null, {
            'provider': 'custom',
            'repository': 'org/repo',
            'purpose': 'clone my self-hosted repo',
            'credential_mode': 'generated_deploy',
            'requested_access': 'read_only',
            'host': 'git.example.com',
            'port': 2222,
          })).called(1);
    });

    test('includes credential for existing_account mode', () async {
      when(() => accessDao.save(any(), any()))
          .thenAnswer((_) async => _FakeAccess());

      await repo.addRepositoryAccess(
        provider: GitRepositoryAccessProvider.gitlab,
        repository: 'org/repo',
        purpose: 'read the repo',
        credentialMode: GitRepositoryAccessCredentialMode.existingAccount,
        requestedAccess: GitRepositoryAccessRequestedAccess.readOnly,
        credential: 'cred1',
      );

      verify(() => accessDao.save(null, {
            'provider': 'gitlab',
            'repository': 'org/repo',
            'purpose': 'read the repo',
            'credential_mode': 'existing_account',
            'requested_access': 'read_only',
            'credential': 'cred1',
          })).called(1);
    });

    test('wraps failures in GitSshException', () async {
      when(() => accessDao.save(any(), any())).thenThrow(Exception('x'));

      await expectLater(
        () => repo.addRepositoryAccess(
          provider: GitRepositoryAccessProvider.github,
          repository: 'octo/hello',
          purpose: 'x',
          credentialMode: GitRepositoryAccessCredentialMode.generatedDeploy,
          requestedAccess: GitRepositoryAccessRequestedAccess.readOnly,
        ),
        throwsA(isA<GitSshException>()),
      );
    });
  });

  group('GitSshRepository.markRegistered', () {
    test('saves only the registration_status field', () async {
      when(() => accessDao.save(any(), any()))
          .thenAnswer((_) async => _FakeAccess());

      await repo.markRegistered('access-1');

      verify(() => accessDao
          .save('access-1', {'registration_status': 'registered'})).called(1);
    });
  });

  group('GitSshRepository.deleteAccess', () {
    test('deletes the access row', () async {
      when(() => accessDao.delete(any())).thenAnswer((_) async {});

      await repo.deleteAccess('access-1');

      verify(() => accessDao.delete('access-1')).called(1);
    });
  });
}
