# Deploy Flow Entry Point + User-Chosen Admin Credentials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a brand-new user (no server yet) reach the real Linode deploy flow before logging in, and replace today's auto-generated admin password with one the user chooses up front, alongside email — deleting the now-redundant/dead code this displaces along the way.

**Architecture:** `OnboardingScreen` gains a `LOGIN` / `DEPLOY` toggle. Email + Password chosen in `DEPLOY` mode travel forward through the existing deploy route chain (`DeployPickerScreen` → `AuthScreen` → `ConfigScreen`) as a small carry-object (`DeployCredentials`), same pattern already used by `OnboardingPrefill` in the reverse direction. `ConfigScreen` stops collecting its own email and stops offering the dead `linodeToken` field; `DeploymentService` stops auto-generating the admin password and takes the carried one instead.

**Tech Stack:** Flutter/Dart, `go_router` (route `extra` for carrying state), `flutter_bloc`/`cubit_ui_flow`, `mocktail` for tests. Spans two repos: this monorepo (`packages/pocketcoder_flutter`, `packages/pocketcoder_pro`) and the separate git repo `flutter_aeroform` (checked out at `/Users/aicoder/Documents/flutter_aeroform`, remote `qtpi-bonding-org/flutter_aeroform.git`, currently pinned in `client/pubspec.lock` at commit `b7dbd38fc27a07a387aa3e0f0b25f99e19c33833`).

## Global Constraints

- LOGIN mode's existing behavior (3 fields, saved-URL restore, existing validation) must not change.
- The DEPLOY mode Email field must stay a plain, unvalidated-beyond-non-empty text field — no allowlist/denylist on its value — a separate future spec depends on typing an arbitrary sentinel value there.
- No multi-deployment support — this only covers the zero-deployment first-run case (an already-authenticated user never reaches this toggle at all, per `BootScreen`'s existing auto-login).
- `/deploy` is already reachable unauthenticated today with zero routing changes (`app_router.dart`'s `redirect` has no auth guard, confirmed during design review) — do not add one.
- `flutter_aeroform` changes must land as real commits in that repo (`/Users/aicoder/Documents/flutter_aeroform`, already a clean checkout on `main` tracking `origin`) and be pushed before `client/pubspec.lock` can pick up the new ref.

---

### Task 1: `flutter_aeroform` — remove dead `linodeToken` field from `DeploymentConfig`

**Files:**
- Modify: `/Users/aicoder/Documents/flutter_aeroform/lib/domain/models/deployment_config.dart`
- Test: `/Users/aicoder/Documents/flutter_aeroform/test/domain/models/deployment_config_test.dart` (create if it doesn't exist)

**Interfaces:**
- Produces: `DeploymentConfig` constructor with no `linodeToken` parameter (was `String? linodeToken`).

- [ ] **Step 1: Confirm no other repo reads `linodeToken` before touching it**

Run from `/Users/aicoder/Documents/flutter_aeroform`:
```bash
grep -rn "linodeToken" lib/ test/
```
Expected: only hits inside `deployment_config.dart` itself and its generated `.freezed.dart`/`.g.dart` files. If you find a hit anywhere else, stop and report — this task assumes it's confirmed dead (verified during design: `toUserData()` never reads it, and the only method that once did, `toMetadata()`, was already deleted in a prior session).

- [ ] **Step 2: Write the failing test**

Create `/Users/aicoder/Documents/flutter_aeroform/test/domain/models/deployment_config_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';

void main() {
  test('DeploymentConfig has no linodeToken field', () {
    final config = DeploymentConfig(
      planType: 'g6-standard-2',
      region: 'us-east',
      adminEmail: 'admin@example.com',
      ntfyEnabled: true,
      imageRelayUrl: 'https://pocketcoder-image-relay.workers.dev',
      nixosImageLabel: 'pocketcoder-nixos-v1',
    );

    // toUserData must still work with exactly this constructor shape --
    // this is really a compile-time check (the test file wouldn't
    // compile if DeploymentConfig still required linodeToken), but the
    // runtime assertion below documents the actual behavior.
    final userData = config.toUserData(
      adminPassword: 'test-pass',
      rootSshKey: 'ssh-ed25519 AAAATEST',
    );
    expect(userData, isNotEmpty);
  });
}
```

- [ ] **Step 3: Run test to verify it currently passes (field still present, just optional)**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/domain/models/deployment_config_test.dart`
Expected: PASS (this test doesn't fail before the change since `linodeToken` is optional — its purpose is to lock in the constructor shape going forward, confirmed by Step 1's grep that nothing else depends on it existing).

- [ ] **Step 4: Remove the field**

In `lib/domain/models/deployment_config.dart`, remove the `String? linodeToken,` line from the `const factory DeploymentConfig({...})` constructor.

- [ ] **Step 5: Regenerate freezed/json code**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && dart run build_runner build --delete-conflicting-outputs`
Expected: `deployment_config.freezed.dart` and `deployment_config.g.dart` regenerate with no `linodeToken` references.

- [ ] **Step 6: Run test to verify it still passes**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/domain/models/deployment_config_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full flutter_aeroform test suite**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test`
Expected: PASS (this monorepo's `pocketcoder_pro`/`pocketcoder_flutter` code that references `DeploymentConfig` is NOT part of this suite and NOT expected to compile yet — that's fixed in Task 6/7 below. Do not attempt to fix pocketcoder-side compile errors from this task.)

- [ ] **Step 8: Commit**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
git add lib/domain/models/deployment_config.dart lib/domain/models/deployment_config.freezed.dart lib/domain/models/deployment_config.g.dart test/domain/models/deployment_config_test.dart
git commit -m "fix: remove dead linodeToken field from DeploymentConfig

Never read by anything -- the one method that once did, toMetadata(),
was already deleted. Confirmed via full grep of lib/ and test/ before
removal."
```

---

### Task 2: `flutter_aeroform` — `DeploymentService.deploy()` takes a caller-supplied admin password; delete dead `cancelMonitoring()` and the now-unused password generator

**Files:**
- Modify: `/Users/aicoder/Documents/flutter_aeroform/lib/domain/deployment/i_deployment_service.dart`
- Modify: `/Users/aicoder/Documents/flutter_aeroform/lib/infrastructure/deployment/deployment_service.dart`
- Delete: `/Users/aicoder/Documents/flutter_aeroform/lib/domain/security/i_password_generator.dart`
- Delete: `/Users/aicoder/Documents/flutter_aeroform/lib/infrastructure/security/password_generator.dart`
- Modify: `/Users/aicoder/Documents/flutter_aeroform/test/infrastructure/deployment/deployment_service_test.dart`

**Interfaces:**
- Consumes: `DeploymentConfig` from Task 1 (no `linodeToken`).
- Produces: `IDeploymentService.deploy(DeploymentConfig config, {required String adminPassword})` — no more `cancelMonitoring()` method on the interface or implementation.

- [ ] **Step 1: Confirm `cancelMonitoring()` and the password generator have no other callers**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
grep -rn "cancelMonitoring" lib/ test/
grep -rn "IPasswordGenerator\|PasswordGenerator(" lib/ test/
```
Expected: hits across `i_deployment_service.dart`, `deployment_service.dart`, `deployment_service_test.dart`, `deployment_service_property_test.dart`, `golden_path_provision_test.dart`, and `password_generator_test.dart` — every one of these is handled explicitly in Steps 2-6 below, so this list is the expected/complete blast radius, not a surprise. If the grep turns up a hit in some OTHER file not in this list, stop and report before proceeding — that would be a real gap this plan didn't account for.

- [ ] **Step 2: Write the failing test for the new `deploy()` signature**

In `/Users/aicoder/Documents/flutter_aeroform/test/infrastructure/deployment/deployment_service_test.dart`, replace the existing `'creates instance with correct parameters'` test in the `group('deploy', ...)` block:

```dart
      test('uses the caller-supplied admin password, not a generated one',
          () async {
        final config = createTestDeploymentConfig();
        final cloudInstance = CloudInstance(
          id: '12345',
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.creating,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.valid());
        when(() => sshKeyGenerator.generate()).thenAnswer((_) async =>
            (publicKey: 'ssh-ed25519 AAAATEST', privateKey: 'PRIVATE_KEY_PEM'));
        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => provisioningStrategy.provisionInstance(
              accessToken: 'test-access-token',
              config: config,
              userData: any(named: 'userData'),
            )).thenAnswer((_) async => cloudInstance);
        when(() => secureStorage.storeInstanceCredentials(any()))
            .thenAnswer((_) async {});

        final result = await deploymentService.deploy(
          config,
          adminPassword: 'user-chosen-Pass123!',
        );

        expect(result.instanceId, '12345');
        final storedCredentials = verify(() =>
                secureStorage.storeInstanceCredentials(captureAny()))
            .captured
            .single as InstanceCredentials;
        expect(storedCredentials.adminPassword, 'user-chosen-Pass123!');
      });
```

Also delete the `passwordGenerator` mock setup lines (`when(() => passwordGenerator.generateAdminPassword())...`) from the two other `group('deploy', ...)` tests (`'fails when validation fails'` doesn't have one; `'fails when not authenticated'` and `'stores instance credentials after successful deployment'` do — remove those lines and add `adminPassword: 'test-pass'` to each `deploymentService.deploy(config, ...)` call in those tests).

Delete the whole `group('cancelMonitoring', ...)` block, and delete the `deploymentService.cancelMonitoring();` calls inside `group('monitorDeployment', ...)`'s three tests (replace with nothing — those tests still exercise polling via `monitorDeployment`, they just no longer call the deleted cancel method; if a test's only purpose was asserting `cancelMonitoring` behavior, e.g. the last assertion checking `isMonitoring` becomes false after cancelling, remove that trailing assertion too since there's no longer a way to trigger it from the public API).

Delete the `MockPasswordGenerator` class declaration and the `passwordGenerator = MockPasswordGenerator();` / `passwordGenerator: passwordGenerator,` lines from `setUp()` and the `DeploymentService(...)` constructor call in the test file's top-level `setUp()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/deployment/deployment_service_test.dart`
Expected: FAIL — `deploy()` doesn't accept `adminPassword` yet, compile error.

- [ ] **Step 3: Update the interface**

In `lib/domain/deployment/i_deployment_service.dart`:
- Change `Future<DeploymentResult> deploy(DeploymentConfig config);` to `Future<DeploymentResult> deploy(DeploymentConfig config, {required String adminPassword});`
- Delete the `/// Cancels ongoing deployment monitoring` doc comment and `void cancelMonitoring();` line.

- [ ] **Step 4: Update the implementation**

In `lib/infrastructure/deployment/deployment_service.dart`:
- Remove `final IPasswordGenerator _passwordGenerator;` field.
- Remove `required IPasswordGenerator passwordGenerator,` constructor parameter and its `_passwordGenerator = passwordGenerator,` initializer.
- Remove the now-unused `import 'package:flutter_aeroform/domain/security/i_password_generator.dart';`.
- Change `Future<DeploymentResult> deploy(DeploymentConfig config) async {` to `Future<DeploymentResult> deploy(DeploymentConfig config, {required String adminPassword}) async {`.
- Delete the line `final adminPassword = await _passwordGenerator.generateAdminPassword();` and its preceding doc comment (`// Generate the admin password and a fresh root SSH keypair...` — keep the part of that comment about the SSH keypair if it moves to just above `_sshKeyGenerator.generate()`, drop the password-specific half).
- Find and delete the `cancelMonitoring()` method body (grep `void cancelMonitoring()` in this file to locate it) and remove its `@override` annotation line too.

- [ ] **Step 5: Delete the now-fully-unused password generator files**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
rm lib/domain/security/i_password_generator.dart
rm lib/infrastructure/security/password_generator.dart
rm test/infrastructure/security/password_generator_test.dart
```

- [ ] **Step 6: Fix collateral damage in two other test files**

Step 1's grep undercounted — these two also reference what this task
deletes and must be updated, not just `deployment_service_test.dart`:

**`test/infrastructure/deployment/deployment_service_property_test.dart`**:
- Delete the `class MockPasswordGenerator extends Mock implements IPasswordGenerator {}` declaration.
- Delete the `late IPasswordGenerator passwordGenerator;` field, its `passwordGenerator = MockPasswordGenerator();` line in `setUp()`, and the `passwordGenerator: passwordGenerator,` argument in the `DeploymentService(...)` constructor call.
- Delete the `deploymentService.cancelMonitoring();` call (around line 219) — if it was the only line establishing test teardown for that specific test, leave the test's remaining assertions intact and just drop that one line.
- Delete the `when(() => passwordGenerator.generateAdminPassword())...` stub (around line 294).
- Update both `deploymentService.deploy(config)` call sites (around lines 325, 328) to `deploymentService.deploy(config, adminPassword: 'test-pass')`.

**`test/integration/golden_path_provision_test.dart`** (a real/live test gated behind `AEROFORM_LIVE_TEST` — do not run it live as part of this task's gate, just fix it so it compiles and reads correctly):
- Delete the `final passwordGenerator = PasswordGenerator();` line (around line 107) and its `passwordGenerator: passwordGenerator,` constructor argument (around line 118).
- Update the `await deploymentService.deploy(config)` call (around line 150) to `await deploymentService.deploy(config, adminPassword: 'test-pass')` (or an equivalent realistic literal — this is a live-infra test, not one that needs a specific value, any non-empty string is fine).

- [ ] **Step 7: Regenerate the injectable DI module**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/flutter_aeroform.module.dart` regenerates with no `IPasswordGenerator`/`PasswordGenerator` registration and no `passwordGenerator:` argument in `DeploymentService`'s constructor call.

- [ ] **Step 8: Run test to verify it passes**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/deployment/deployment_service_test.dart test/infrastructure/deployment/deployment_service_property_test.dart`
Expected: PASS

- [ ] **Step 9: Run the full flutter_aeroform test suite**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test`
Expected: PASS (the live integration test skips itself without `AEROFORM_LIVE_TEST=1` set, matching its existing gating)

- [ ] **Step 10: Commit**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
git add lib/domain/deployment/i_deployment_service.dart lib/infrastructure/deployment/deployment_service.dart lib/flutter_aeroform.module.dart test/infrastructure/deployment/deployment_service_test.dart test/infrastructure/deployment/deployment_service_property_test.dart test/integration/golden_path_provision_test.dart
git rm lib/domain/security/i_password_generator.dart lib/infrastructure/security/password_generator.dart test/infrastructure/security/password_generator_test.dart
git commit -m "feat: DeploymentService.deploy() takes a caller-supplied admin password

Replaces internal auto-generation -- the caller (PocketCoder's deploy
flow) now collects the admin password from the user up front instead
of generating one and revealing it after the fact. Deletes the
password generator entirely (its only call site) and cancelMonitoring()
(confirmed dead: DeploymentCubit manages its own polling independently
and never called it)."
```

---

### Task 3: Bridge — push `flutter_aeroform`, bump PocketCoder's pinned commit

**Files:**
- Modify: `/Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_pro/pubspec.yaml` (the `ref:` under the `flutter_aeroform` git dependency)
- Modify: `/Users/aicoder/Documents/pocketcoder/client/pubspec.lock` (regenerated, not hand-edited)

**Interfaces:**
- Consumes: Tasks 1+2's commits in `flutter_aeroform`.
- Produces: `client/pubspec.lock`'s `flutter_aeroform` entry resolves to the new commit — everything downstream (Tasks 6, 7) compiles against the updated `DeploymentConfig`/`IDeploymentService`.

- [ ] **Step 1: Push flutter_aeroform**

```bash
cd /Users/aicoder/Documents/flutter_aeroform
git push origin main
git rev-parse HEAD
```
Note the printed commit hash — this is the new `resolved-ref`.

- [ ] **Step 2: Update the git ref pin**

In `/Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_pro/pubspec.yaml`, find the `flutter_aeroform:` git dependency block and update its `ref:` value to the commit hash from Step 1 (short form is fine, e.g. first 7-10 characters, matching the existing style already used there for other git deps in this file).

- [ ] **Step 3: Regenerate pubspec.lock**

```bash
cd /Users/aicoder/Documents/pocketcoder/client
flutter pub get
```
Expected: `pubspec.lock`'s `flutter_aeroform` entry now shows `ref:` and `resolved-ref:` matching Step 1's commit hash.

- [ ] **Step 4: Verify the pin actually took**

```bash
grep -A5 "flutter_aeroform:" /Users/aicoder/Documents/pocketcoder/client/pubspec.lock | head -8
```
Expected: `resolved-ref:` matches the hash from Step 1.

- [ ] **Step 5: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_pro/pubspec.yaml client/pubspec.lock
git commit -m "chore(client): bump flutter_aeroform to pick up deploy-credential changes"
```

(Expect `pocketcoder_pro`/`pocketcoder_flutter` to NOT compile cleanly yet after this — `ConfigScreen`/`ConfigCubit`/`DeploymentCubit` still reference the old `DeploymentConfig.linodeToken` field and the old `deploy(config)` signature. That's fixed in Tasks 6 and 7. Do not attempt to fix those compile errors in this task.)

---

### Task 4: `pocketcoder_flutter` — `DeployCredentials` carry object + `OnboardingScreen` LOGIN/DEPLOY toggle

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_credentials.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart`

**Interfaces:**
- Produces: `DeployCredentials(email: String, password: String)`, a plain class. `OnboardingScreen`'s DEPLOY-mode submit navigates via `context.pushNamed(RouteNames.deploy, extra: DeployCredentials(...))`.

- [ ] **Step 1: Write the failing test**

Add to `client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart` (inside the existing `main()`, after the two existing `testWidgets`):

```dart
  testWidgets('DEPLOY mode shows only email/password, hides the URL field',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    expect(find.text('http://127.0.0.1:8090'), findsNothing);
  });

  testWidgets('DEPLOY mode blocks submission when password is empty',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('deployEmailField')), 'reviewer@example.com');
    await tester.pump();

    await tester.tap(find.text('DEPLOY').last);
    await tester.pump();

    // Still on OnboardingScreen -- no navigation happened.
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets(
      'DEPLOY mode navigates with the entered email/password when both are filled',
      (tester) async {
    // The existing buildTestable() wraps OnboardingScreen in a plain
    // MaterialApp with no GoRouter ancestor -- fine for the two tests
    // above (neither one navigates), but this test needs a real router
    // to observe what OnboardingScreen actually pushes.
    DeployCredentials? capturedExtra;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          name: RouteNames.deploy,
          path: '/deploy',
          builder: (context, state) {
            capturedExtra = state.extra as DeployCredentials?;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PocoCubit>(create: (_) => PocoCubit()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('DEPLOY'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('deployEmailField')), 'reviewer@example.com');
    await tester.enterText(find.byType(TextField).last, 'chosen-password');
    await tester.pump();

    await tester.tap(find.text('DEPLOY').last);
    await tester.pumpAndSettle();

    expect(capturedExtra, isNotNull);
    expect(capturedExtra!.email, 'reviewer@example.com');
    expect(capturedExtra!.password, 'chosen-password');
  });
```

Add these two imports to the test file alongside its existing ones:
```dart
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

Note: this test file's `buildTestable()` helper and `setUp()`/`tearDown()` already exist — do not duplicate them, just add these three `testWidgets` blocks alongside the existing ones. The third test builds its own `MaterialApp.router` inline rather than using `buildTestable()`, for the reason explained in its leading comment.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/onboarding/onboarding_screen_test.dart`
Expected: FAIL — no `'DEPLOY'` text/button exists yet, and `Key('deployEmailField')` doesn't exist.

- [ ] **Step 3: Create `DeployCredentials`**

```dart
// client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_credentials.dart

/// Carries the admin email/password chosen on OnboardingScreen's DEPLOY
/// tab forward through the deploy route chain, so DeployPickerScreen ->
/// AuthScreen -> ConfigScreen don't each need to re-collect or
/// auto-generate them. Deliberately a plain object, not persisted
/// anywhere -- same spirit as OnboardingPrefill's opposite direction.
class DeployCredentials {
  const DeployCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}
```

- [ ] **Step 4: Add the LOGIN/DEPLOY toggle to `OnboardingScreen`**

In `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart`:

Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

Add a mode enum above the `OnboardingScreen` class:
```dart
enum _OnboardingMode { login, deploy }
```

In `_OnboardingScreenState`, add the mode field:
```dart
  _OnboardingMode _mode = _OnboardingMode.login;
```

Add a `_handleDeploy` method alongside the existing `_handleLogin`:
```dart
  void _handleDeploy() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      return;
    }
    context.pushNamed(
      RouteNames.deploy,
      extra: DeployCredentials(email: email, password: password),
    );
  }
```

In `build()`, replace the single `actions: [...]` `TerminalAction` with a toggle plus a mode-dependent action. Add the toggle as a new widget just above the existing `AsciiLogo`:

```dart
                        SegmentedButton<_OnboardingMode>(
                          segments: const [
                            ButtonSegment(
                              value: _OnboardingMode.login,
                              label: Text('LOGIN'),
                            ),
                            ButtonSegment(
                              value: _OnboardingMode.deploy,
                              label: Text('DEPLOY'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (selected) {
                            setState(() => _mode = selected.first);
                          },
                        ),
                        VSpace.x4,
```

Change the `TerminalTextField` for URL to only render in LOGIN mode:
```dart
                        if (_mode == _OnboardingMode.login) ...[
                          TerminalTextField(
                            controller: _urlController,
                            label: context.l10n.onboardingHomeServer,
                            hint: 'http://127.0.0.1:8090',
                          ),
                          VSpace.x2,
                        ],
```

Add a `key` to the existing email `TerminalTextField` so both modes' tests can target it precisely:
```dart
                        TerminalTextField(
                          key: const Key('deployEmailField'),
                          controller: _emailController,
                          label: context.l10n.onboardingIdentityLabel,
                          hint: context.l10n.onboardingEmailHint,
                        ),
```

Change the `actions:` list to switch label and handler by mode:
```dart
              actions: [
                TerminalAction(
                  label: isLoading
                      ? context.l10n.onboardingProcessing
                      : (_mode == _OnboardingMode.login ? 'LOGIN' : 'DEPLOY'),
                  onTap: isLoading
                      ? () {}
                      : (_mode == _OnboardingMode.login
                          ? () => _handleLogin(context.read<AuthCubit>())
                          : _handleDeploy),
                ),
              ],
```

- [ ] **Step 5: Verify `RouteNames.deploy` exists**

```bash
grep -n "deploy" client/packages/pocketcoder_flutter/lib/app_router.dart | grep RouteNames
```
Expected: `RouteNames.deploy` already exists (registered for `DeployPickerScreen` per the existing `AppRoutes.deploy` route) — no new route name needed here, Task 5 updates that existing route's `pageBuilder` to read the new `extra`.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/onboarding/onboarding_screen_test.dart`
Expected: PASS (all 5 tests — the 2 pre-existing plus the 3 new ones)

- [ ] **Step 7: Run `flutter analyze`**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/`
Expected: clean (only pre-existing, unrelated lint infos, if any)

- [ ] **Step 8: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_credentials.dart client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart
git commit -m "feat(client): LOGIN/DEPLOY toggle on OnboardingScreen

Lets a brand-new user (no server yet) reach the real deploy flow
before logging in. DEPLOY mode collects email+password (no URL --
that's determined by whichever server gets provisioned) and carries
them forward via the new DeployCredentials object."
```

---

### Task 5: `pocketcoder_flutter` — thread `DeployCredentials` through `DeployPickerScreen` and the deploy route

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_picker_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/deployment/deploy_picker_screen_test.dart` (create)

**Interfaces:**
- Consumes: `DeployCredentials` from Task 4.
- Produces: `DeployPickerScreen({DeployCredentials? credentials})`; tapping the Linode card's `context.push(routePath, extra: credentials)` carries it onward to `AuthScreen` (consumed in Task 6).

- [ ] **Step 1: Write the failing test**

Create `client/packages/pocketcoder_flutter/test/presentation/deployment/deploy_picker_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';

class FakeDeployOptionService implements IDeployOptionService {
  @override
  List<DeployOption> getAvailableProviders() => const [
        DeployOption(
          id: 'linode',
          name: 'Linode (Akamai)',
          description: 'One-tap deploy via OAuth. 24h access included.',
          routePath: '/auth',
          // false, not the real option's true: this test verifies
          // credential forwarding, not the billing gate, and
          // requiresPurchase: true would call GetIt.I<BillingService>()
          // inside _onTap, which nothing in this test registers.
          requiresPurchase: false,
        ),
      ];
}

void main() {
  setUp(() {
    GetIt.I.registerFactory<IDeployOptionService>(() => FakeDeployOptionService());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('forwards credentials as extra when a provider card is tapped',
      (tester) async {
    String? capturedRoute;
    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/deploy',
      routes: [
        GoRoute(
          path: '/deploy',
          builder: (context, state) => const DeployPickerScreen(
            credentials: DeployCredentials(
              email: 'reviewer@example.com',
              password: 'test-pass',
            ),
          ),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) {
            capturedRoute = state.uri.toString();
            capturedExtra = state.extra;
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pump();

    await tester.tap(find.textContaining('LINODE'));
    await tester.pumpAndSettle();

    expect(capturedRoute, '/auth');
    expect(capturedExtra, isA<DeployCredentials>());
    expect((capturedExtra as DeployCredentials).email, 'reviewer@example.com');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/deployment/deploy_picker_screen_test.dart`
Expected: FAIL — `DeployPickerScreen` doesn't accept a `credentials` constructor parameter yet.

- [ ] **Step 3: Thread `credentials` through `DeployPickerScreen` and `_ProviderCard`**

In `client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_picker_screen.dart`:

Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

Change the class:
```dart
class DeployPickerScreen extends StatelessWidget {
  const DeployPickerScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    final options = GetIt.I<IDeployOptionService>().getAvailableProviders();

    return PocketCoderShell(
      title: context.l10n.deployTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Column(
              children: [
                BiosFrame(
                  title: context.l10n.deploySelectProvider,
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TerminalText(
                          context.l10n.deployChooseProvider,
                          alpha: 0.7,
                        ),
                        VSpace.x3,
                        ...options.map(
                          (option) => Padding(
                            padding:
                                EdgeInsets.only(bottom: AppSizes.space),
                            child: _ProviderCard(
                              option: option,
                              credentials: credentials,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Change `_ProviderCard`:
```dart
class _ProviderCard extends StatelessWidget {
  final DeployOption option;
  final DeployCredentials? credentials;

  const _ProviderCard({required this.option, this.credentials});
```

`_onTap` keeps its existing `requiresPurchase`/billing-check block and the `url_launcher` branch completely unchanged — the ONLY change is adding `extra: credentials` to the existing `context.push(routePath)` call, inside its existing `if (context.mounted)` guard. The full method after this one-line change:

```dart
  Future<void> _onTap(BuildContext context) async {
    if (option.requiresPurchase) {
      final billing = GetIt.I<BillingService>();
      final hasAccess = await billing.hasDeployAccess();
      if (!hasAccess) {
        final purchased = await billing.purchase('pocketcoder_deploy_24h');
        if (!purchased) return;
      }
    }

    final url = option.url;
    final routePath = option.routePath;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else if (routePath != null) {
      if (context.mounted) {
        context.push(routePath, extra: credentials);
      }
    }
  }
```

- [ ] **Step 4: Update the deploy route to read `state.extra`**

In `client/packages/pocketcoder_flutter/lib/app_router.dart`, find the `AppRoutes.deploy` `GoRoute` (registered for `DeployPickerScreen`) and change its `pageBuilder`:

```dart
      GoRoute(
        path: AppRoutes.deploy,
        name: RouteNames.deploy,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: DeployPickerScreen(
            credentials: state.extra is DeployCredentials
                ? state.extra as DeployCredentials
                : null,
          ),
        ),
      ),
```

Add the import at the top of `app_router.dart`:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/deployment/deploy_picker_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Run `flutter analyze`**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/`
Expected: clean

- [ ] **Step 7: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/presentation/deployment/deploy_picker_screen.dart client/packages/pocketcoder_flutter/lib/app_router.dart client/packages/pocketcoder_flutter/test/presentation/deployment/deploy_picker_screen_test.dart
git commit -m "feat(client): DeployPickerScreen forwards DeployCredentials to provider routes"
```

---

### Task 6: `pocketcoder_pro` — thread `DeployCredentials` through `AuthScreen`/`ConfigScreen`'s route registrations

**Files:**
- Modify: `client/packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart`
- Modify: `client/packages/pocketcoder_pro/lib/app.dart` (the `linodeRoutes` getter)

**Interfaces:**
- Consumes: `DeployCredentials` arriving via `state.extra` at the `AppRoutes.auth` route (forwarded from Task 5).
- Produces: `AuthScreen({DeployCredentials? credentials})`, forwards unchanged to `RouteNames.config`'s `extra` on OAuth success. `ConfigScreen` (Task 7) receives it via its own route's `extra`.

- [ ] **Step 1: Update `AuthScreen`**

In `client/packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart`:

Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

Change the public widget to accept and pass through credentials:
```dart
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<AuthCubit, AuthState>(
      mapper: GetIt.I<AuthMessageMapper>(),
      child: _AuthView(credentials: credentials),
    );
  }
}

class _AuthView extends StatelessWidget {
  const _AuthView({this.credentials});

  final DeployCredentials? credentials;
```

Change the OAuth-success navigation line:
```dart
        if (state.isSuccess && state.isAuthenticated == true) {
          context.pushNamed(RouteNames.config, extra: credentials);
        }
```

- [ ] **Step 2: Update `linodeRoutes` in `app.dart`**

In `client/packages/pocketcoder_pro/lib/app.dart`, find the `linodeRoutes` getter (around the `AppRoutes.auth` and `AppRoutes.config` entries) and update both `pageBuilder`s to read `state.extra`:

```dart
      GoRoute(
        path: AppRoutes.auth,
        name: RouteNames.auth,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: deploy_auth.AuthScreen(
            credentials: state.extra is DeployCredentials
                ? state.extra as DeployCredentials
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.config,
        name: RouteNames.config,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: deploy_config.ConfigScreen(
            credentials: state.extra is DeployCredentials
                ? state.extra as DeployCredentials
                : null,
          ),
        ),
      ),
```

Add the import at the top of `app.dart`:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

(`ConfigScreen`'s `credentials` constructor parameter is added in Task 7 — this task's edit to `app.dart` will not compile in isolation until Task 7 lands; that's expected and fine since both are part of the same feature and Task 7 is the very next task in this plan. Do not attempt to run `pocketcoder_pro`'s full analyzer/test suite as a gate for this task alone — Task 7's steps are the first point where this monorepo compiles again.)

- [ ] **Step 3: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart client/packages/pocketcoder_pro/lib/app.dart
git commit -m "feat(client): thread DeployCredentials through AuthScreen and its route

ConfigScreen's own credentials param lands in the next task -- this
commit alone does not compile in isolation, expected given both are
one feature split across two commits for reviewability."
```

---

### Task 7: `pocketcoder_pro` — simplify `ConfigScreen`, delete dead `ConfigCubit` methods, thread the password into `DeploymentCubit.deploy()`

**Files:**
- Modify: `client/packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart`
- Modify: `client/packages/pocketcoder_pro/lib/application/config/config_cubit.dart`
- Modify: `client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart`
- Test: `client/packages/pocketcoder_pro/test/application/config/config_cubit_test.dart` (create)

**Interfaces:**
- Consumes: `IDeploymentService.deploy(config, {required adminPassword})` from Task 2; `DeployCredentials` arriving via `ConfigScreen`'s route `extra` (wired in Task 6).
- Produces: `ConfigScreen({DeployCredentials? credentials})`, no local email/linodeToken fields; `DeploymentCubit.deploy(DeploymentConfig config, {required String adminPassword})`.

- [ ] **Step 1: Delete the 4 dead `ConfigCubit` methods and write a test locking in what remains**

In `client/packages/pocketcoder_pro/lib/application/config/config_cubit.dart`, delete these four methods entirely: `validateConfig()`, `loadPlans()`, `loadRegions()`, `clearConfig()`. Keep `updateConfig()` and `loadPlansAndRegions()` (both are used elsewhere, per grep confirmation during design).

Create `client/packages/pocketcoder_pro/test/application/config/config_cubit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/validation_result.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';

class MockValidationService extends Mock implements IValidationService {}

class MockCloudProviderAPIClient extends Mock
    implements ICloudProviderAPIClient {}

class MockSecureStorage extends Mock implements ISecureStorage {}

DeploymentConfig _testConfig() => DeploymentConfig(
      planType: 'g6-standard-2',
      region: 'us-east',
      adminEmail: 'admin@example.com',
      ntfyEnabled: false,
      imageRelayUrl: 'https://pocketcoder-image-relay.workers.dev',
      nixosImageLabel: 'pocketcoder-nixos-v1',
    );

void main() {
  late MockValidationService validationService;
  late MockCloudProviderAPIClient apiClient;
  late MockSecureStorage secureStorage;
  late ConfigCubit cubit;

  setUp(() {
    validationService = MockValidationService();
    apiClient = MockCloudProviderAPIClient();
    secureStorage = MockSecureStorage();
    cubit = ConfigCubit(validationService, apiClient, secureStorage);
  });

  test('updateConfig emits the new config and its validation result', () {
    final config = _testConfig();
    when(() => validationService.validateDeploymentConfig(config))
        .thenReturn(ValidationResult.valid());

    cubit.updateConfig(config);

    expect(cubit.state.config, config);
    expect(cubit.state.isValid, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_pro && flutter test test/application/config/config_cubit_test.dart`
Expected: PASS (this locks in `updateConfig`'s existing, unchanged behavior — the deletions don't affect it)

- [ ] **Step 3: Thread the admin password through `DeploymentCubit.deploy()`**

In `client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart`, change:
```dart
  Future<void> deploy(DeploymentConfig config) async {
```
to:
```dart
  Future<void> deploy(DeploymentConfig config, {required String adminPassword}) async {
```
and change the internal call:
```dart
      final result = await _deploymentService.deploy(config);
```
to:
```dart
      final result = await _deploymentService.deploy(
        config,
        adminPassword: adminPassword,
      );
```

- [ ] **Step 4: Simplify `ConfigScreen`**

In `client/packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart`:

Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
```

Change the public widget:
```dart
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.I<ConfigCubit>()),
        BlocProvider(create: (_) => GetIt.I<DeploymentCubit>()),
      ],
      child: UiFlowListener<ConfigCubit, ConfigState>(
        child: _ConfigView(credentials: credentials),
      ),
    );
  }
}

class _ConfigView extends StatefulWidget {
  const _ConfigView({this.credentials});

  final DeployCredentials? credentials;

  @override
  State<_ConfigView> createState() => _ConfigViewState();
}
```

Remove `_emailController` and `_linodeTokenController` entirely (fields, `dispose()` calls) and replace with plain fields seeded from the carried credentials:
```dart
class _ConfigViewState extends State<_ConfigView> {
  late final String _adminEmail = widget.credentials?.email ?? '';
  late final String _adminPassword = widget.credentials?.password ?? '';

  @override
  void initState() {
    super.initState();
    context.read<ConfigCubit>().loadPlansAndRegions();
  }
```

(No `dispose()` override needed anymore — there are no controllers left to dispose.)

Remove the `BlocConsumer`'s `listener` body entirely (it only existed to sync the two now-deleted controllers) — change:
```dart
    return BlocConsumer<ConfigCubit, ConfigState>(
      listener: (context, state) {
        // Update controllers when config changes
        if (state.config != null) {
          final config = state.config!;
          if (_emailController.text != config.adminEmail) {
            _emailController.text = config.adminEmail;
          }
          if (_linodeTokenController.text != (config.linodeToken ?? '')) {
            _linodeTokenController.text = config.linodeToken ?? '';
          }
        }
      },
      builder: (context, configState) {
```
to:
```dart
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, configState) {
```

Delete the entire `BiosSection(title: 'ADMIN CREDENTIALS', ...)` block (the email `TerminalTextField`) and the `TerminalTextField` for `_linodeTokenController` inside the `BiosSection(title: 'NOTIFICATIONS (OPTIONAL)', ...)` block — keep that section's `Switch`/`ntfyEnabled` row, just remove the token field and the `VSpace.x1` immediately above it that separated the two.

Update `_updateConfig` to use `_adminEmail` instead of the deleted controller, and drop `linodeToken` entirely (the field no longer exists on `DeploymentConfig` per Task 1):
```dart
  void _updateConfig(
    ConfigCubit cubit, {
    String? planType,
    String? region,
  }) {
    final current = cubit.state.config;
    if (current != null) {
      cubit.updateConfig(
        current.copyWith(
          planType: planType ?? current.planType,
          region: region ?? current.region,
        ),
      );
    } else {
      cubit.updateConfig(
        DeploymentConfig(
          planType: planType ?? '',
          region: region ?? '',
          adminEmail: _adminEmail,
          ntfyEnabled: cubit.state.config?.ntfyEnabled ?? false,
          imageRelayUrl: AppConfig.kImageRelayUrl,
          nixosImageLabel: AppConfig.kNixosImageLabel,
        ),
      );
    }
  }
```

(`adminEmail` is now only ever set once, from the carried `_adminEmail`, in the `else` branch that fires on first plan/region selection — it's never re-set afterward since there's no longer a UI control that could change it, matching the spec's "collected once, up front" intent.)

Update `_deploy` to pass the carried password:
```dart
  void _deploy(ConfigCubit configCubit, DeploymentCubit deploymentCubit) {
    final config = configCubit.state.config;
    if (config != null) {
      deploymentCubit.deploy(config, adminPassword: _adminPassword);
    }
  }
```

- [ ] **Step 5: Run `flutter analyze` on the whole package**

Run: `cd client/packages/pocketcoder_pro && flutter analyze lib/`
Expected: clean — this is the point where the whole monorepo compiles again after Tasks 1-6's cross-repo changes.

- [ ] **Step 6: Run the full `pocketcoder_pro` test suite**

Run: `cd client/packages/pocketcoder_pro && flutter test`
Expected: PASS (including the existing `details_screen_test.dart` and the new `config_cubit_test.dart`)

- [ ] **Step 7: Run the full `pocketcoder_flutter` test suite**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart client/packages/pocketcoder_pro/lib/application/config/config_cubit.dart client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart client/packages/pocketcoder_pro/test/application/config/config_cubit_test.dart
git commit -m "feat(client): ConfigScreen uses carried admin credentials, drops dead code

- ConfigScreen no longer collects email (arrives via DeployCredentials)
  or the dead linodeToken field.
- Deletes ConfigCubit's 4 confirmed-unreferenced methods: validateConfig,
  loadPlans, loadRegions, clearConfig.
- DeploymentCubit.deploy() threads the carried password through to
  DeploymentService instead of relying on its now-removed
  auto-generation."
```

---

## Post-implementation note

This plan does not address the separate, out-of-scope gap the design doc flagged: `PocketCoderShell`'s nav bar (`chats`/`monitor`/`configure`) always renders regardless of auth state, so an unauthenticated user on `/deploy` can still tap into screens assuming a logged-in session. Left for a follow-up, per the design doc's explicit call-out.
