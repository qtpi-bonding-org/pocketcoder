import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/git_ssh/git_ssh_state.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/git_ssh/widgets/git_ssh_view.dart';

void main() {
  Widget subject(GitSshState state) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GitSshView(
          state: state,
          onCreateAccountKey: (_) async {},
          onAddRepositoryAccess: ({
            required provider,
            required repository,
            required purpose,
            required credentialMode,
            required requestedAccess,
            credential,
            host,
            port,
          }) async {},
          onDeleteAccess: (_) async {},
        ),
      );

  testWidgets('shows the empty state when there are no keys or repos',
      (tester) async {
    await tester.pumpWidget(subject(
        const GitSshState(status: UiFlowStatus.success)));
    expect(find.text('no keys or repositories yet'), findsOneWidget);
  });

  testWidgets('lists an account key with its status', (tester) async {
    await tester.pumpWidget(subject(GitSshState(
      status: UiFlowStatus.success,
      credentials: [
        const GitSshCredential(
          id: 'c1',
          user: 'u1',
          label: 'my laptop key',
          kind: GitSshCredentialKind.account,
          source: GitSshCredentialSource.generated,
          algorithm: GitSshCredentialAlgorithm.ed25519,
          status: GitSshCredentialStatus.pending,
        ),
      ],
    )));
    expect(find.text('my laptop key'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
  });

  testWidgets(
      'a ready credential offers to show its public key; a pending one does not',
      (tester) async {
    await tester.pumpWidget(subject(GitSshState(
      status: UiFlowStatus.success,
      credentials: [
        const GitSshCredential(
          id: 'c1',
          user: 'u1',
          label: 'ready key',
          kind: GitSshCredentialKind.account,
          source: GitSshCredentialSource.generated,
          algorithm: GitSshCredentialAlgorithm.ed25519,
          status: GitSshCredentialStatus.ready,
          publicKey: 'ssh-ed25519 AAAA',
        ),
      ],
    )));
    expect(find.text('<show public key>'), findsOneWidget);
  });

  testWidgets('lists a repository access row with its status',
      (tester) async {
    await tester.pumpWidget(subject(GitSshState(
      status: UiFlowStatus.success,
      access: [
        const GitRepositoryAccess(
          id: 'a1',
          user: 'u1',
          provider: GitRepositoryAccessProvider.github,
          repository: 'octo/hello',
          purpose: 'push CI fixes',
          credentialMode: GitRepositoryAccessCredentialMode.generatedDeploy,
          requestedAccess: GitRepositoryAccessRequestedAccess.readWrite,
          registrationStatus:
              GitRepositoryAccessRegistrationStatus.needsRegistration,
          status: GitRepositoryAccessStatus.pending,
        ),
      ],
    )));
    expect(find.textContaining('github/octo/hello'), findsOneWidget);
    expect(find.text('<remove>'), findsOneWidget);
  });
}
