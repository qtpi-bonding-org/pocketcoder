# Post-Deploy Credential Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a real user finishes provisioning a new deployment (via `pocketcoder_pro`'s Aeroform-backed deploy flow), give them a way to actually see their auto-generated admin password and log in — today the app shows the generated admin *email* on the details screen but never the password, and the login screen requires manually typed credentials with no way to know them.

**Architecture:** No auto-login, no cubit calling another cubit. `DetailsScreen` (the screen shown right after a successful deploy) fetches the already-persisted `InstanceCredentials` directly from `ISecureStorage` (a plain repository-style singleton, not a cubit), adds a masked/reveal/copy password row next to the existing admin-email row, and adds a "LOG IN NOW" action that navigates to `OnboardingScreen` passing the URL/email/password as a plain data object through GoRouter's `extra` parameter. `OnboardingScreen` gains an optional constructor field to pre-fill its three text controllers from that object; the user still presses the existing Login button themselves.

**Tech Stack:** Flutter, flutter_bloc (Cubits only), GetIt/injectable DI, GoRouter, mocktail for widget tests.

## Global Constraints

- **No cubit calls another cubit.** Cross-feature coordination happens at the widget layer or via plain data handed through navigation — never one cubit importing/invoking another. (User-stated architectural rule for this session.)
- **No auto-login.** The user always presses the existing Login action themselves; the app only pre-fills the three onboarding fields. Do not call `AuthCubit.login(...)` automatically anywhere in this plan.
- **Never invent a new full-width button widget.** `DetailsScreen`'s `TerminalScaffold` already has an `actions:` list (`REFRESH`, `UPDATE`, `DISMISS`, each a `TerminalAction`) — reuse that pattern for "LOG IN NOW" rather than adding a new inline button widget.
- **Never use the `!` operator** (per `client/CLAUDE.md`). Use `?.`/`??`/early returns instead.
- **Never log or print the password.** No `logDebug`/`print` of `adminPassword` anywhere in this plan's code.
- All cubits extend `AppCubit<T>`; state uses `@freezed` with `UiFlowStatus status` — not touched by this plan (no cubit changes at all).

---

## File Structure

- **New:** `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_prefill.dart` — plain (non-freezed) data class carrying `url`/`email`/`password` across navigation. Deliberately not a freezed model: it's a transient one-shot navigation payload with no persistence, equality, or JSON needs, so codegen would be pure overhead (YAGNI).
- **Modify:** `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart` — accept an optional `OnboardingPrefill? prefill` constructor field; pre-fill the three controllers from it in `initState`.
- **Modify:** `client/packages/pocketcoder_flutter/lib/app_router.dart` — the `onboarding` `GoRoute` reads `state.extra` and passes it through as `OnboardingPrefill?`.
- **Modify:** `client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart` — fetch `InstanceCredentials` for the shown instance via `ISecureStorage`; add a masked/reveal/copy `ADMIN PASSWORD` row; add a `LOG IN NOW` action that navigates to `onboarding` with an `OnboardingPrefill`.
- **Modify:** `client/packages/pocketcoder_pro/pubspec.yaml` — add `flutter_test` (SDK) and `mocktail` as dev dependencies so this package can host widget tests (it currently has none — its one existing test file is a live, non-widget SSH test).
- **New test:** `client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart`
- **New test:** `client/packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart`

## Interfaces

- `OnboardingPrefill({required String url, required String email, required String password})` — plain class, three final `String` fields, no methods.
- `OnboardingScreen({Key? key, OnboardingPrefill? prefill})` — new optional named parameter, defaults to `null` (today's behavior unchanged when omitted).
- Existing, unmodified, consumed by this plan:
  - `ISecureStorage.getInstanceCredentials(String instanceId) → Future<InstanceCredentials?>` (`flutter_aeroform`, already a global `GetIt.instance` singleton reachable from `pocketcoder_pro` — confirmed via `initializeAeroformDI()` in `pocketcoder_pro/lib/app.dart`).
  - `InstanceCredentials` — `{ instanceId, adminPassword, rootSshPrivateKey, adminEmail }` (all `String`, `flutter_aeroform`).
  - `Instance.httpsUrl` (`String`, already read elsewhere in `details_screen.dart`).
  - `RouteNames.onboarding` / `AppRoutes.onboarding` (`app_router.dart`).

---

### Task 1: `OnboardingPrefill` + `OnboardingScreen` pre-fill support

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_prefill.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart`

**Interfaces:**
- Produces: `OnboardingPrefill` (see above) and `OnboardingScreen`'s new `prefill` parameter — Task 2 (route wiring) and Task 3 (`DetailsScreen`) both construct and pass this type.

- [ ] **Step 1: Write the failing widget test**

Mirrors the existing `getIt`-registration pattern from `test/presentation/settings/settings_screen_test.dart` (mocktail + `getIt.registerFactory`/`getIt.reset()`), since `OnboardingScreen` builds `getIt<AuthCubit>()` internally and reads `PocoCubit` via `context.read`.

```dart
// client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockStatusRepository extends Mock implements IStatusRepository {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRepository authRepo;
  late MockStatusRepository statusRepo;
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    authRepo = MockAuthRepository();
    statusRepo = MockStatusRepository();
    when(() => statusRepo.checkPocketBaseHealth())
        .thenAnswer((_) async => true);

    getIt.registerFactory<AuthCubit>(() => AuthCubit(authRepo));
    getIt.registerFactory<IStatusRepository>(() => statusRepo);
    // OnboardingScreen's no-prefill path calls _restoreSavedUrl(), which
    // reads getIt<FlutterSecureStorage>() -- must be registered even
    // though this test never asserts on its value.
    secureStorage = MockFlutterSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    getIt.registerFactory<FlutterSecureStorage>(() => secureStorage);
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestable({OnboardingPrefill? prefill}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PocoCubit>(create: (_) => PocoCubit()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(prefill: prefill),
      ),
    );
  }

  testWidgets('pre-fills url/email/password fields when prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable(
      prefill: const OnboardingPrefill(
        url: 'https://1.2.3.4.sslip.io',
        email: 'admin@pocketcoder.local',
        password: 'correct-horse-battery-staple',
      ),
    ));
    await tester.pump();

    expect(find.text('https://1.2.3.4.sslip.io'), findsOneWidget);
    expect(find.text('admin@pocketcoder.local'), findsOneWidget);
    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('falls back to the default local url when no prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    expect(find.text('http://127.0.0.1:8090'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/onboarding/onboarding_screen_test.dart`
Expected: FAIL — `onboarding_prefill.dart` doesn't exist yet (import error), and `OnboardingScreen` has no `prefill` parameter.

- [ ] **Step 3: Create `OnboardingPrefill`**

```dart
// client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_prefill.dart

/// Carries a just-generated deployment's login details across navigation
/// (e.g. from DetailsScreen's "LOG IN NOW" action to OnboardingScreen) so
/// the user can review and submit them instead of typing them from
/// memory. Deliberately a plain object, not persisted anywhere.
class OnboardingPrefill {
  const OnboardingPrefill({
    required this.url,
    required this.email,
    required this.password,
  });

  final String url;
  final String email;
  final String password;
}
```

- [ ] **Step 4: Wire `prefill` into `OnboardingScreen`**

Modify `client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart`:

Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
```

Replace the widget declaration (currently `const OnboardingScreen({super.key});`) with:
```dart
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}
```

Replace the controller field declarations (currently `_urlController` is initialized inline with the default text) with plain, uninitialized controllers — the default/pre-filled text now gets set in `initState`, since `widget` isn't available at field-initializer time:
```dart
class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
```

In `initState`, replace the existing `_restoreSavedUrl(); _checkInitialStatus();` tail with:
```dart
    final prefill = widget.prefill;
    if (prefill != null) {
      _urlController.text = prefill.url;
      _emailController.text = prefill.email;
      _passwordController.text = prefill.password;
    } else {
      _urlController.text = 'http://127.0.0.1:8090';
      _restoreSavedUrl();
    }
    _checkInitialStatus();
```

`_restoreSavedUrl()` itself is unchanged — it only overwrites `_urlController.text` if a saved value exists, and is now only called on the no-prefill path.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/onboarding/onboarding_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_prefill.dart \
        client/packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart \
        client/packages/pocketcoder_flutter/test/presentation/onboarding/onboarding_screen_test.dart
git commit -m "feat(onboarding): support pre-filling login fields via OnboardingPrefill"
```

---

### Task 2: Wire the `onboarding` route to pass `extra` through as `OnboardingPrefill`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`

**Interfaces:**
- Consumes: `OnboardingPrefill` (Task 1), `OnboardingScreen(prefill: ...)` (Task 1).
- Produces: the `onboarding` route now accepts navigation calls of the form `context.pushNamed(RouteNames.onboarding, extra: OnboardingPrefill(...))` — Task 3's `DetailsScreen` relies on this.

- [ ] **Step 1: Update the route**

In `client/packages/pocketcoder_flutter/lib/app_router.dart`, add the import:
```dart
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
```

Replace the `onboarding` `GoRoute` (currently using `const OnboardingScreen()`):
```dart
GoRoute(
  path: AppRoutes.onboarding,
  name: RouteNames.onboarding,
  pageBuilder: (context, state) => TerminalTransition.buildPage(
    context: context,
    state: state,
    child: OnboardingScreen(
      prefill: state.extra is OnboardingPrefill
          ? state.extra as OnboardingPrefill
          : null,
    ),
  ),
),
```

This is a pure additive change — any existing navigation to `RouteNames.onboarding` without `extra` still gets `state.extra == null`, so `prefill` is `null` and behavior is unchanged (falls back to Task 1's no-prefill path).

- [ ] **Step 2: Verify statically**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/app_router.dart`
Expected: no errors.

There's no dedicated route test for this file today (`grep -rl "app_router_test" client/packages/pocketcoder_flutter/test` returns nothing) — Task 1's widget test already exercises `OnboardingScreen(prefill: ...)` directly, and Task 3's widget test exercises the actual `pushNamed(..., extra: ...)` call site, so this step is a two-line glue change covered end-to-end by those two, not a place to newly invent route-level test scaffolding.

- [ ] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/app_router.dart
git commit -m "feat(router): pass OnboardingPrefill through the onboarding route's extra"
```

---

### Task 3: `DetailsScreen` — reveal/copy admin password + "LOG IN NOW"

**Files:**
- Modify: `client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart`
- Modify: `client/packages/pocketcoder_pro/pubspec.yaml`
- Test: `client/packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart`

**Interfaces:**
- Consumes: `ISecureStorage.getInstanceCredentials` (`flutter_aeroform`), `OnboardingPrefill` + `RouteNames.onboarding` (Tasks 1–2).

- [ ] **Step 1: Add test dependencies**

`pocketcoder_pro`'s `pubspec.yaml` currently has no `flutter_test`/`mocktail` dev dependency (its one existing test file, `ssh_server_update_service_live_test.dart`, is a manually-run live test gated behind an env var, not part of normal `flutter test` sweeps). `mocktail` is already pinned transitively at `1.0.4` in the workspace lockfile — declare it directly at that version so this package's resolution doesn't change anything else in the workspace.

In `client/packages/pocketcoder_pro/pubspec.yaml`, add to `dev_dependencies:`:
```yaml
dev_dependencies:
  build_runner: ^2.4.7
  freezed: ^3.0.0
  json_serializable: ^6.7.1
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

Run: `cd client/packages/pocketcoder_pro && flutter pub get`
Expected: resolves cleanly, no version conflicts (matches the already-locked transitive version).

- [ ] **Step 2: Write the failing widget test**

`DeploymentCubit` and `ISecureStorage` are mocked directly with mocktail (same technique `settings_screen_test.dart` uses for `MockMcpCubit`) rather than mocking their own dependencies — `DetailsScreen` only ever calls methods on these two, never constructs them.

```dart
// client/packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/presentation/deployment/details_screen.dart';

class MockDeploymentCubit extends Mock implements DeploymentCubit {}

class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockDeploymentCubit cubit;
  late MockSecureStorage secureStorage;
  late Instance instance;
  late InstanceCredentials credentials;

  setUp(() {
    instance = Instance(
      id: 'inst-1',
      label: 'pocketcoder-inst-1',
      ipAddress: '1.2.3.4',
      adminEmail: 'admin@pocketcoder.local',
      status: InstanceStatus.running,
      region: 'us-east',
      planType: 'nanode',
      provider: 'linode',
      created: DateTime(2026, 1, 1),
    );
    // Instance.httpsUrl is a derived getter -- for ipAddress '1.2.3.4' it
    // evaluates to 'https://1-2-3-4.sslip.io' (dots become hyphens), not a
    // constructor field, so nothing to pass in above.
    credentials = const InstanceCredentials(
      instanceId: 'inst-1',
      adminPassword: 'correct-horse-battery-staple',
      rootSshPrivateKey: 'not-used-here',
      adminEmail: 'admin@pocketcoder.local',
    );

    cubit = MockDeploymentCubit();
    when(() => cubit.state).thenReturn(
      DeploymentState.initial().copyWith(instance: instance),
    );
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.refreshInstanceStatus(any())).thenAnswer((_) async {});
    when(() => cubit.cancelDeployment()).thenReturn(null);

    secureStorage = MockSecureStorage();
    when(() => secureStorage.getInstanceCredentials('inst-1'))
        .thenAnswer((_) async => credentials);

    GetIt.I.registerFactory<ISecureStorage>(() => secureStorage);
    GetIt.I.registerFactory<DeploymentMessageMapper>(
        () => DeploymentMessageMapper());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/deployment/details',
      routes: [
        GoRoute(
          path: '/deployment/details',
          name: 'deploymentDetails',
          builder: (context, state) => BlocProvider<DeploymentCubit>.value(
            value: cubit,
            child: const DetailsScreen(instanceId: 'inst-1'),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) =>
              Text('onboarding:${(state.extra as OnboardingPrefill?)?.email}'),
        ),
      ],
    );

    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  testWidgets('password is masked by default, reveals on tap', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('correct-horse-battery-staple'), findsNothing);
    expect(find.text('•' * credentials.adminPassword.length), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('copy icon puts the password on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.content_copy).last);
    await tester.pump();

    expect(copied, contains('correct-horse-battery-staple'));
  });

  testWidgets('LOG IN NOW navigates to onboarding with prefill', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOG IN NOW'));
    await tester.pumpAndSettle();

    expect(find.text('onboarding:admin@pocketcoder.local'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_pro && flutter test test/presentation/deployment/details_screen_test.dart`
Expected: FAIL — no password row, no `LOG IN NOW` action, credentials never fetched.

- [ ] **Step 4: Implement in `DetailsScreen`**

In `client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart`, add imports:
```dart
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
```
(`app_router.dart` is already imported for `RouteNames`/`AppRoutes` at the top of the file — don't duplicate the import if so; grep before adding.)

Add state to `_DetailsViewState`:
```dart
class _DetailsViewState extends State<_DetailsView> {
  InstanceCredentials? _credentials;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    // Start periodic status refresh
    final cubit = context.read<DeploymentCubit>();
    cubit.refreshInstanceStatus(widget.instanceId);
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final credentials =
        await GetIt.I<ISecureStorage>().getInstanceCredentials(widget.instanceId);
    if (mounted) {
      setState(() => _credentials = credentials);
    }
  }
```

Add the `LOG IN NOW` action to the existing `actions:` list in `build`, ahead of `REFRESH` (only shown once credentials have loaded):
```dart
          actions: [
            if (_credentials != null)
              TerminalAction(
                label: 'LOG IN NOW',
                onTap: () => _handleLoginNow(instance),
              ),
            TerminalAction(
              label: 'REFRESH',
              onTap: () => cubit.refreshInstanceStatus(widget.instanceId),
            ),
            ...
```

Add the handler method:
```dart
  void _handleLoginNow(Instance? instance) {
    final credentials = _credentials;
    if (instance == null || credentials == null) return;
    context.pushNamed(
      RouteNames.onboarding,
      extra: OnboardingPrefill(
        url: instance.httpsUrl,
        email: credentials.adminEmail,
        password: credentials.adminPassword,
      ),
    );
  }
```

Add the password row inside the `METADATA REGISTRY` `BiosFrame`, right after the `ADMIN IDENTITY` row:
```dart
                        _buildInfoRow('ADMIN IDENTITY',
                            instance.adminEmail ?? 'N/A', colors),
                        if (_credentials != null) ...[
                          VSpace.x1,
                          _buildPasswordRow(
                              'ADMIN PASSWORD', _credentials!.adminPassword, colors),
                        ],
```

Add the row-builder method, alongside the existing `_buildInfoRow`/`_buildCopyableField`:
```dart
  Widget _buildPasswordRow(String label, String value, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
          ),
        ),
        Row(
          children: [
            Text(
              _passwordVisible ? value : '•' * value.length,
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface,
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
              ),
            ),
            HSpace.x1,
            InkWell(
              onTap: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              child: Icon(
                _passwordVisible ? Icons.visibility_off : Icons.visibility,
                color: colors.primary,
                size: 14,
              ),
            ),
            HSpace.x1,
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label COPIED TO BUFFER'),
                    backgroundColor: colors.primary,
                  ),
                );
              },
              child: Icon(Icons.content_copy, color: colors.primary, size: 14),
            ),
          ],
        ),
      ],
    );
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_pro && flutter test test/presentation/deployment/details_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_pro/pubspec.yaml \
        client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart \
        client/packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart
git commit -m "feat(deployment): reveal/copy admin password and LOG IN NOW on DetailsScreen"
```

---

## Verification

- `cd client/packages/pocketcoder_flutter && flutter analyze && flutter test` — clean, including the two new `onboarding_screen_test.dart` cases.
- `cd client/packages/pocketcoder_pro && flutter analyze && flutter test` — clean, including the three new `details_screen_test.dart` cases.
- Manual sanity check once merged: run the app, deploy (or navigate straight to `DetailsScreen` with a known `instanceId` if a full deploy isn't practical to re-run), confirm the password row is masked by default, reveals correctly, copies correctly, and `LOG IN NOW` lands on `OnboardingScreen` with all three fields filled and the existing Login button still requires a manual tap.
- Grep check: `grep -rn "adminPassword" client/packages/pocketcoder_pro/lib client/packages/pocketcoder_flutter/lib | grep -i "log\|print"` returns nothing — confirms the password is never logged.
