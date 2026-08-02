# Deploy Flow Entry Point + User-Chosen Admin Credentials — Design

> Sub-project 1+2 of `2026-08-02-apple-review-linode-access-overview.md`
> (merged, since they turned out to be the same screen). Sub-project 3
> (the reviewer-bypass mechanism) is a separate design that builds on
> this one — the Email field this spec adds must remain a plain,
> unrestricted text field so that spec can later detect a sentinel value
> there without this spec needing to change.

**Goal:** Let a brand-new user (no server yet) reach the real Linode
deploy flow before logging in, and replace today's auto-generated admin
password with one the user chooses — collected once, up front, instead of
re-asking for email later and revealing a random password after the fact.

**Architecture:** `OnboardingScreen` gains a `LOGIN` / `DEPLOY` segmented
toggle. Email + Password (chosen in `DEPLOY` mode) travel forward through
the existing deploy route chain as a small carry-object, the same pattern
already used by `OnboardingPrefill` for the reverse direction. The two
downstream screens that today collect/generate these values
(`ConfigScreen`'s own email field, `DeploymentService`'s auto-generated
password) are simplified to use the carried values instead.

**Tech Stack:** Flutter/Dart, `go_router` (route `extra` for carrying
state), existing `cubit_ui_flow` state machine conventions. Touches two
repos: `pocketcoder_flutter`/`pocketcoder_pro` (this monorepo) and
`flutter_aeroform` (separate git repo, `qtpi-bonding-org/flutter_aeroform`).

## Global Constraints

- LOGIN mode's existing behavior (3 fields, saved-URL restore, existing
  validation) must not change.
- The DEPLOY mode Email field must stay a plain, unvalidated-beyond-format
  text field — no client-side allowlist/denylist on its value — since the
  separate reviewer-bypass spec depends on being able to type an arbitrary
  sentinel string there later.
- No multi-deployment support. A user who already has a working
  deployment never reaches this toggle (BootScreen's existing
  already-authenticated auto-login bypasses it entirely) — this spec only
  covers the zero-deployment first-run case.
- `flutter_aeroform` changes needed here must be scoped to the deploy
  flow's credential handling — not a general refactor of that package.

---

## Components

### 1. `OnboardingScreen` (packages/pocketcoder_flutter/lib/presentation/onboarding/onboarding_screen.dart)

Add a stateful `_mode` field (`_OnboardingMode.login` / `.deploy`,
default `.login`), rendered as a two-segment toggle above the existing
form fields.

- **LOGIN mode**: today's 3 fields (URL, Email, Password) and `LOGIN`
  action button — unchanged.
- **DEPLOY mode**: 2 fields (Email, Password) — the URL field and its
  saved-URL restore logic do not apply and are hidden. Action button
  reads `DEPLOY`. On tap, both fields must be non-empty (same
  non-empty-field validation LOGIN already has) — if either is blank,
  show the existing inline validation error styling, don't navigate.
- On successful DEPLOY submission: `context.pushNamed(RouteNames.deploy,
  extra: DeployCredentials(email: ..., password: ...))`.

### 2. New carry object: `DeployCredentials`

New file, `packages/pocketcoder_flutter/lib/presentation/deployment/deploy_credentials.dart`
(sibling to `onboarding_prefill.dart`, same spirit — plain object, never
persisted):

```dart
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

### 3. `DeployPickerScreen` (packages/pocketcoder_flutter/lib/presentation/deployment/deploy_picker_screen.dart)

Accept an optional `DeployCredentials? credentials` constructor param.
`_onTap` (the provider-card tap handler) forwards it when pushing the
Linode option's route:

```dart
context.push(routePath, extra: credentials);
```

Router registration (`packages/pocketcoder_flutter/lib/app_router.dart`,
`AppRoutes.deploy` route) reads `state.extra as DeployCredentials?` and
passes it to the screen constructor, same pattern already used for
`AppRoutes.onboarding`/`OnboardingPrefill`.

**Must resolve during planning:** today `DeployPickerScreen`'s route
(`AppRoutes.deploy`) sits inside the authenticated main shell's route
list. Making it reachable from `OnboardingScreen` (pre-login) means this
route must be reachable without the auth guard the rest of that shell's
routes may rely on — confirm during planning whether `go_router`'s
current redirect logic actually gates this route today, and if so, add
`AppRoutes.deploy` (and only that route) to whatever allowlist an
unauthenticated user is permitted to reach.

### 4. `AuthScreen` (packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart)

Accept the same optional `DeployCredentials?`, forward it unchanged when
navigating to `ConfigScreen` on OAuth success:

```dart
context.pushNamed(RouteNames.config, extra: credentials);
```

No other change — this screen doesn't read email/password itself, purely
a pass-through.

### 5. `ConfigScreen` (packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart)

- **Remove** `_emailController` and its `TerminalTextField` — email now
  arrives via the carried `DeployCredentials`, pre-filled into
  `ConfigCubit`'s state at `initState` instead of typed here.
- **Remove** `_linodeTokenController` and its `TerminalTextField`
  entirely (confirmed dead: written into `DeploymentConfig.linodeToken`
  but never read by anything — the one thing that would have read it,
  `DeploymentConfig.toMetadata()`, was already deleted in a prior
  session; `toUserData()` never references it either).
- `_updateConfig` no longer sets `adminEmail`/`linodeToken` from local
  controllers — `adminEmail` comes from the carried credentials once, at
  screen init; `linodeToken` is gone from `DeploymentConfig` entirely
  (field removal, not just no-longer-set — see Component 7).
- `_deploy` passes the carried `password` through to
  `DeploymentCubit.deploy()` (signature change, see Component 8).

### 6. `ConfigCubit` (packages/pocketcoder_pro/lib/application/config/config_cubit.dart)

Delete 4 confirmed-dead methods, unreferenced anywhere else in the
codebase (verified directly, not from the stale-checkout audit pass):
`loadPlans()`, `loadRegions()`, `clearConfig()`, `validateConfig()` (this
cubit's own method — distinct from `DeploymentService.validateConfig()`,
which `DeploymentCubit` calls and which is unaffected).

### 7. `DeploymentConfig` (flutter_aeroform: lib/domain/models/deployment_config.dart)

Remove the `linodeToken` field entirely (confirmed dead per Component 5).
`toUserData()` never referenced it, so deleting the field from the
freezed `factory DeploymentConfig({...})` constructor is the only change
needed here — then regenerate `.freezed.dart`/`.g.dart`.

### 8. `DeploymentService`/`IDeploymentService` (flutter_aeroform: lib/infrastructure/deployment/deployment_service.dart, lib/domain/deployment/i_deployment_service.dart)

- `deploy(DeploymentConfig config)` becomes `deploy(DeploymentConfig
  config, {required String adminPassword})`. Delete the internal
  `_passwordGenerator.generateAdminPassword()` call and the
  `_passwordGenerator` dependency if `deploy()` was its only caller
  (confirm during planning — check for other call sites first).
- Also remove `cancelMonitoring()` from `IDeploymentService` and its
  implementation (confirmed dead: exists, never called from
  `pocketcoder_pro`).
- `DeploymentCubit.deploy()` (packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart)
  threads the carried password through to this new parameter.

---

## Data Flow

```
OnboardingScreen (DEPLOY tab: email + password typed)
  -> DeployCredentials{email, password}
  -> DeployPickerScreen (forwards, unread)
  -> AuthScreen (OAuth happens; forwards, unread)
  -> ConfigScreen (reads email into ConfigCubit state at init;
                   plan/region selection unchanged; password held
                   for the deploy call)
  -> DeploymentCubit.deploy(config, adminPassword: <carried password>)
  -> DeploymentService.deploy(): no more auto-generation, uses the
     passed-in password directly in toUserData()
  -> ProgressScreen -> DetailsScreen (still shows the now-user-chosen
     password, same reveal/copy UI as today -- unchanged)
```

## Error Handling

- Empty Email or Password on the DEPLOY tab: block submission, existing
  inline validation error style (matches LOGIN's current behavior).
- `DeployCredentials` is a plain in-memory object passed via route
  `extra` — if the app is killed mid-flow (before `DetailsScreen`), it's
  simply lost, same as any other in-flight, non-persisted navigation
  state today. No new persistence needed.
- If `DeploymentService.deploy()` fails downstream (network error,
  Linode API error), the carried credentials aren't consumed until the
  actual API call — a retry (if the UI offers one) can reuse the same
  `DeployCredentials` still held in `ConfigCubit`'s state.

## Testing

- Widget test: `OnboardingScreen` toggle — switching to DEPLOY mode hides
  the URL field, shows exactly 2 fields; tapping DEPLOY with an empty
  field shows a validation error and does not navigate; tapping DEPLOY
  with both fields filled navigates with the correct `DeployCredentials`.
- Widget test: `DeployPickerScreen` forwards a non-null `credentials` to
  the Linode route's `extra` when tapped (reuse the existing
  `details_screen_test.dart`-style route-assertion pattern already in
  this codebase).
- `flutter_aeroform` unit test: `DeploymentService.deploy()` uses the
  passed `adminPassword` verbatim in the generated `toUserData()` output,
  and no longer calls a password generator.
- Regenerate and re-run existing `ConfigCubit`/`DeploymentCubit` tests
  after deleting the 4 dead methods and updating the `deploy()` call
  site — confirm nothing else referenced them (already verified via grep
  during design, but the real test run is the actual gate).
