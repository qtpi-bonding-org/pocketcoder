# FOSS App Target + Real Purity Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a genuinely F-Droid-buildable PocketCoder app — a second app target with zero proprietary code/SDKs in its compiled binary — and replace the existing purity check (which only greps one package's own source for three hardcoded proprietary names) with a real check of the *full resolved runtime dependency graph*, including license verification, so a new proprietary dependency can't slip into the FOSS package undetected regardless of what it's named.

**Architecture:** A new Flutter app package, `client/apps/pocketcoder_foss`, depending only on `pocketcoder_flutter` (already proprietary-free — verified) — no `pocketcoder_pro`, no `flutter_aeroform` (which has no LICENSE file at all, i.e. all-rights-reserved by default). Its `main.dart` wires the FOSS service implementations that already exist in `pocketcoder_flutter` (`NtfyPushService`, `FossBillingService`, `FossDeployOptionService`) instead of the proprietary ones — no new abstractions needed, just a new wiring entrypoint. Separately, `purity_check.sh` is rewritten around `dart pub deps --json` (the package's actual resolved dependency closure, not just its own `pubspec.yaml`/imports) plus a Python helper that locates and classifies each dependency's `LICENSE` file, and a new GitHub Actions workflow runs it on every push/PR touching the relevant paths.

**Tech Stack:** Flutter/Dart (workspace resolution via `client/pubspec.yaml`), bash + Python 3 for the purity check, GitHub Actions.

## Global Constraints

- The FOSS app must depend on `pocketcoder_flutter` only — never `pocketcoder_pro` or `flutter_aeroform`, directly or transitively.
- No auto-login, no new abstractions beyond what's needed to wire existing FOSS service implementations into a new entrypoint (`NtfyPushService`/`FossBillingService`/`FossDeployOptionService` already exist and are unmodified by this plan).
- `client/LICENSE` is MPL-2.0 (verified) — the new app's own source is already covered; nothing to add there.
- Never use the `!` operator (per `client/CLAUDE.md`).
- The purity check's dependency-graph walk must cover the package's full resolved closure (via `dart pub deps --json`), not just its own `pubspec.yaml`/`lib/` source — that was the exact gap that let `flutter_aeroform` (no LICENSE file) go unnoticed under the old grep-by-name approach.
- **CI caveat, not solvable in code:** several of `pocketcoder_flutter`'s git dependencies use SSH URLs under the `qtpi-bonding-org` GitHub org (e.g. `git@github.com:qtpi-bonding-org/flutter_cubit_ui_flow.git`). If any of those repos are private, the new GitHub Actions workflow's `flutter pub get` will fail without an SSH deploy key configured as a repo secret — this is the user's own step (adding the secret + an `ssh-agent`/`webfactory/ssh-agent` action step), not something Task 5 can complete unattended. Task 5's workflow is written correctly assuming such a key will be added; flag this explicitly to the user rather than silently expecting CI to go green on first run.

---

## File Structure

- **New app package:** `client/apps/pocketcoder_foss/` — scaffolded via `flutter create`, then `pubspec.yaml` and `lib/main.dart` replaced with FOSS-specific content; native Android/iOS identity changed to `org.pocketcoder.foss`.
- **Modify:** `client/pubspec.yaml` — add `apps/pocketcoder_foss` to the `workspace:` list and a `run_foss`/`build_foss` melos script pair mirroring the existing `run_app`/`build_app`.
- **Rewrite:** `client/scripts/purity_check.sh` — orchestration only; delegates the actual graph-walk/license-classification to a new Python helper.
- **New:** `client/scripts/check_license_purity.py` — parses `dart pub deps --json` + `pubspec.lock`, locates each dependency's `LICENSE` file (pub cache for hosted/git deps, local directory for path deps), classifies against an allow-list of recognized free licenses.
- **New:** `.github/workflows/foss-purity.yml` — runs the purity check against both `packages/pocketcoder_flutter` and `apps/pocketcoder_foss` on every push/PR touching relevant paths.

## Interfaces

- No new Dart interfaces — `PushService`, `BillingService`, `IDeployOptionService` (all in `pocketcoder_flutter/lib/domain/`) and their FOSS implementations (`pocketcoder_flutter/lib/infrastructure/foss/{ntfy_push_service,foss_billing_service,foss_deploy_option_service}.dart`) already exist, unmodified by this plan.
- `client/scripts/purity_check.sh <path-relative-to-client>` (e.g. `packages/pocketcoder_flutter` or `apps/pocketcoder_foss`) — CLI contract changes from a bare package *name* (old) to a *path*, since the check must now also run against an app under `apps/`, not just a package under `packages/`.
- `client/scripts/check_license_purity.py <path-relative-to-client> <deps-json> <workspace-lock-path>` — invoked by `purity_check.sh`, not called directly by anything else.

---

### Task 1: Scaffold `client/apps/pocketcoder_foss` and wire FOSS services

**Files:**
- Create: `client/apps/pocketcoder_foss/` (via `flutter create`, then edited)
- Modify: `client/apps/pocketcoder_foss/pubspec.yaml`
- Modify: `client/apps/pocketcoder_foss/lib/main.dart`
- Create: `client/apps/pocketcoder_foss/.env`
- Modify: `client/pubspec.yaml`

**Interfaces:**
- Consumes: `PushService`/`BillingService`/`IDeployOptionService` + their FOSS implementations, `bootstrap()`/`getIt` from `pocketcoder_flutter/app/bootstrap.dart`, `App` from `pocketcoder_flutter/app/app.dart` — all pre-existing, read-only for this task.

- [ ] **Step 1: Scaffold the app**

From `client/apps/`, run:
```bash
flutter create --org org.pocketcoder --project-name pocketcoder_foss --platforms=android,ios,web pocketcoder_foss
```
This produces a stock `android/`, `ios/`, `web/`, `lib/main.dart`, `pubspec.yaml` etc. under `client/apps/pocketcoder_foss/`. The default `applicationId`/bundle ID this produces (`org.pocketcoder.pocketcoder_foss`) gets corrected to `org.pocketcoder.foss` in Task 2 — don't fix it here.

- [ ] **Step 2: Replace `pubspec.yaml`**

Overwrite `client/apps/pocketcoder_foss/pubspec.yaml` (keep `flutter_launcher_icons`'s config identical to `apps/pocketcoder/pubspec.yaml`'s, since it points at the same shared logo asset three directories up):

```yaml
name: pocketcoder_foss
resolution: workspace
description: "PocketCoder — sovereign AI coding assistant (FOSS build)"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  pocketcoder_flutter:
    path: ../../packages/pocketcoder_flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
    image_path: "../../../assets/logo-1024.png"
    background_color: "#000000"
    theme_color: "#00b82a"
  image_path: "../../../assets/logo-1024.png"
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "../../../assets/logo-1024.png"
  remove_alpha_ios: true

flutter:
  uses-material-design: true
  assets:
    - .env
```

Note there is no `pocketcoder_pro`/`unifiedpush` dependency line: `unifiedpush` is already a direct dependency of `pocketcoder_flutter` itself (`client/packages/pocketcoder_flutter/pubspec.yaml:69`), and Dart path dependencies expose their own dependencies transitively — no need to redeclare it here.

- [ ] **Step 3: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_deploy_option_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FOSS build: no proprietary push/billing/deploy providers, and no
  // Aeroform/Linode provisioning wiring at all (FossDeployOptionService
  // only ever returns an external URL, never an in-app route, so nothing
  // here needs flutter_aeroform).
  getIt.registerSingleton<PushService>(NtfyPushService());
  getIt.registerSingleton<BillingService>(FossBillingService());
  getIt.registerSingleton<IDeployOptionService>(FossDeployOptionService());

  // Bootstrap registers FlutterSecureStorage, http.Client, etc., and
  // initializes the push/billing services just registered above.
  await bootstrap();

  runApp(const App());
}
```

- [ ] **Step 4: Add `.env`**

`client/apps/pocketcoder_foss/.env` (matches `apps/pocketcoder/.env`'s current dev-only content — `bootstrap()` already tolerates a missing/absent `.env` gracefully, this just keeps behavior identical between the two apps):
```
SKIP_AUTH=true
```

- [ ] **Step 5: Register the new app in the workspace**

In `client/pubspec.yaml`, add to the `workspace:` list:
```yaml
workspace:
  - packages/pocketcoder_flutter
  - packages/pocketcoder_pro
  - apps/pocketcoder
  - apps/pocketcoder_foss
```

Add two melos scripts mirroring the existing `run_app`/`build_app` pair:
```yaml
    build_foss:
      run: |
        cd apps/pocketcoder_foss && flutter build apk --debug
      description: Build the PocketCoder FOSS app (F-Droid target).

    run_foss:
      run: |
        cd apps/pocketcoder_foss && flutter run
      description: Run the PocketCoder FOSS app.
```

- [ ] **Step 6: Resolve and verify**

Run: `cd client && flutter pub get`
Expected: resolves cleanly (no proprietary package is reachable from `pocketcoder_foss`'s dependency graph at this point, since it only depends on `pocketcoder_flutter`).

Run: `cd client/apps/pocketcoder_foss && flutter pub run flutter_launcher_icons` (generates icon assets from the shared logo).
Expected: completes without error, icon files appear under `android/app/src/main/res/mipmap-*/` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

Run: `cd client/apps/pocketcoder_foss && flutter analyze`
Expected: no issues (or only the same lint baseline `apps/pocketcoder` already has — compare if anything unexpected shows up).

- [ ] **Step 7: Commit**

```bash
git add client/apps/pocketcoder_foss client/pubspec.yaml
git commit -m "feat(client): scaffold pocketcoder_foss, an F-Droid-buildable app target"
```

---

### Task 2: Native app identity + deep link for the FOSS app

**Files:**
- Modify: `client/apps/pocketcoder_foss/android/app/build.gradle.kts`
- Modify: `client/apps/pocketcoder_foss/android/app/src/main/AndroidManifest.xml`
- Modify: `client/apps/pocketcoder_foss/ios/Runner.xcodeproj/project.pbxproj`
- Modify: `client/apps/pocketcoder_foss/ios/Runner/Info.plist`

**Interfaces:**
- Consumes: nothing new — `pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart:38` defines `_callbackScheme = 'pocketcoder'`, used via `flutter_web_auth_2` for the MCP OAuth provider-discovery flow. This is FOSS-core code (not pro-only), so the FOSS app needs the identical `pocketcoder://` deep-link registration `apps/pocketcoder` already has, or that flow silently fails to return from the browser.

- [ ] **Step 1: Fix the Android applicationId**

In `client/apps/pocketcoder_foss/android/app/build.gradle.kts`, `flutter create` will have set `applicationId = "org.pocketcoder.pocketcoder_foss"` and `namespace = "org.pocketcoder.pocketcoder_foss"` — change both to `org.pocketcoder.foss`. Grep first (`grep -rn "pocketcoder_foss" android/`) to confirm there are exactly these two occurrences before editing, since a fresh `flutter create` output's exact structure should match `apps/pocketcoder/android/app/build.gradle.kts`'s shape from this same repo.

- [ ] **Step 2: Fix the iOS bundle identifier**

In `client/apps/pocketcoder_foss/ios/Runner.xcodeproj/project.pbxproj`, `flutter create` sets `PRODUCT_BUNDLE_IDENTIFIER = org.pocketcoder.pocketcoder_foss;` (and a `.RunnerTests` variant) across the Debug/Release/Profile build configs — same pattern verified earlier in `apps/pocketcoder`'s own `project.pbxproj` (3 occurrences for the main target, 3 for RunnerTests). Replace the main target's 3 occurrences with `org.pocketcoder.foss` (leave `.RunnerTests` as `org.pocketcoder.foss.RunnerTests` for consistency, not `org.pocketcoder.pocketcoder_foss.RunnerTests`). Verify with `plutil -lint client/apps/pocketcoder_foss/ios/Runner.xcodeproj/project.pbxproj` afterward — wait, `plutil` doesn't lint `.pbxproj` (it's not a plist despite similar syntax in older Xcode versions; modern pbxproj is a plist-like format `plutil -lint` *can* actually parse). Run it anyway as a sanity check; if it errors as "not a plist", that's expected for this file format and not a sign anything is broken — cross-check instead by opening the file and confirming `PRODUCT_BUNDLE_IDENTIFIER` values via `grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 3: Add the `pocketcoder://` deep link to Android**

In `client/apps/pocketcoder_foss/android/app/src/main/AndroidManifest.xml`, inside the `<activity android:name=".MainActivity" ...>` block (after its existing `<intent-filter>` for `android.intent.action.MAIN`), add:
```xml
            <!-- Deep linking (MCP OAuth callback) -->
            <intent-filter android:label="pocketcoder_deep_link">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="pocketcoder" />
            </intent-filter>
```
Also add, as a sibling `<activity>` inside `<application>`, the `flutter_web_auth_2` callback activity (identical to `apps/pocketcoder`'s):
```xml
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true"
            android:taskAffinity="">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="pocketcoder" />
            </intent-filter>
        </activity>
```
Verify with: `python3 -c "import xml.dom.minidom as m; m.parse('client/apps/pocketcoder_foss/android/app/src/main/AndroidManifest.xml'); print('OK')"`

- [ ] **Step 4: Add the `pocketcoder://` URL scheme to iOS**

In `client/apps/pocketcoder_foss/ios/Runner/Info.plist`, add (mirroring `apps/pocketcoder/ios/Runner/Info.plist`'s existing block):
```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>pocketcoder.io</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>pocketcoder</string>
			</array>
		</dict>
	</array>
```
Verify with: `plutil -lint client/apps/pocketcoder_foss/ios/Runner/Info.plist`

- [ ] **Step 5: Commit**

```bash
git add client/apps/pocketcoder_foss/android client/apps/pocketcoder_foss/ios
git commit -m "feat(client): FOSS app identity (org.pocketcoder.foss) + MCP OAuth deep link"
```

---

### Task 3: Rewrite `purity_check.sh` around the real resolved dependency graph

**Files:**
- Rewrite: `client/scripts/purity_check.sh`
- Create: `client/scripts/check_license_purity.py`
- Modify: `client/pubspec.yaml` (the `check:purity` melos script)

**Interfaces:**
- Produces: `purity_check.sh <path-relative-to-client>` — the new CLI contract Task 5's CI workflow calls twice (once per target).

- [ ] **Step 1: Write `check_license_purity.py`**

Two things about `dart pub deps --json` in a **Dart pub workspace** (verified against this repo, not assumed): (1) it always returns the *entire workspace's* graph — every member's own dependencies included — regardless of which directory you run it from; there is no per-member scoping flag. (2) each package entry's `"kind"` field ("root"/"direct"/"transitive"/"dev") describes its relationship across the *whole* multi-root workspace graph and in practice only tags a tiny minority of packages as `"dev"` (just `melos` itself here) — it cannot be used as a "did this ship in the compiled binary" filter. So this script does its own closure computation: it reads the target's own `pubspec.yaml` name, finds that package's entry in the graph, and BFS-walks only the `"dependencies"` edges (never `"devDependencies"`) from there — that's the actual definition of "what ships in the compiled binary," and it's naturally scoped to one target regardless of the graph being workspace-wide.

```python
#!/usr/bin/env python3
"""Checks that every runtime dependency reachable from <target-dir>'s own
`dependencies` (never `devDependencies`) in a `dart pub deps --json` graph
carries a recognized free/open-source license.

Exists because the old purity_check.sh only grepped one package's own
pubspec.yaml/imports for three hardcoded proprietary package-name strings --
which caught nothing pulled in transitively, and nothing whose license was
simply missing (e.g. flutter_aeroform, a private git dependency with no
LICENSE file at all, i.e. all-rights-reserved by default under copyright
law).

Note: `dart pub deps --json` in a Dart pub workspace returns the ENTIRE
workspace's graph, not a graph scoped to one member -- confirmed by running
it from both packages/pocketcoder_flutter and apps/pocketcoder and getting
byte-identical output including packages only pocketcoder_pro depends on.
So this script computes its own reachability closure from <target-dir>'s
own `dependencies` edges rather than trusting the graph's per-package
"kind" field, which cannot distinguish one workspace member's closure from
another's.
"""
import glob
import json
import os
import re
import sys

ALLOWED_LICENSE_RE = re.compile(
    r"MIT License|BSD 2-Clause|BSD 3-Clause|BSD License|Apache License"
    r"|Mozilla Public License|GNU LESSER GENERAL PUBLIC LICENSE"
    r"|GNU GENERAL PUBLIC LICENSE|ISC License|The Unlicense|Zlib License",
    re.IGNORECASE,
)

# Ship with the Flutter/Dart SDK itself -- not a separate pub dependency
# with its own LICENSE file to check. Belt-and-suspenders alongside the
# pubspec.lock "source: sdk" check in parse_lock_sources/main below.
SDK_PACKAGES = {
    "flutter", "flutter_test", "flutter_localizations", "flutter_web_plugins",
    "sky_engine", "flutter_driver", "integration_test",
}

PUB_CACHE = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))


def _find_license_in(directory):
    if not directory or not os.path.isdir(directory):
        return None
    for entry in sorted(os.listdir(directory)):
        if entry.upper().startswith("LICENSE"):
            return os.path.join(directory, entry)
    return None


def _repo_basename_from_git_url(url):
    # e.g. "git@github.com:qtpi-bonding-org/flutter_cubit_ui_flow.git" or
    # "https://github.com/org/repo.git" -- the pub cache's git checkout
    # directory is named after the REPO, not the pub package name (e.g.
    # package "cubit_ui_flow" is cached under "flutter_cubit_ui_flow-<sha>/",
    # confirmed against this machine's real ~/.pub-cache/git/).
    basename = url.rstrip("/").split("/")[-1]
    if basename.endswith(".git"):
        basename = basename[:-4]
    return basename


def find_hosted_license(name, version):
    pkg_dir = os.path.join(PUB_CACHE, "hosted", "pub.dev", f"{name}-{version}")
    return _find_license_in(pkg_dir)


def find_git_license(git_url):
    repo_basename = _repo_basename_from_git_url(git_url)
    for candidate in glob.glob(os.path.join(PUB_CACHE, "git", f"{repo_basename}-*")):
        found = _find_license_in(candidate)
        if found:
            return found
    return None


def find_path_license(path):
    return _find_license_in(path)


def parse_lock_sources(lock_path):
    """Maps package name -> (source, location) from pubspec.lock, where
    location is description.url for git sources (used to find the pub-cache
    checkout dir -- see find_git_license) or description.path for path
    sources. In this repo's real pubspec.lock, a git entry's `description:`
    block (containing `path`/`url`) is written BEFORE its `source: git`
    line, so fields are buffered per-package and only interpreted once the
    package's full block has been read (on flush), not as each line is seen.
    """
    sources = {}
    name = source = desc_path = desc_url = None

    def flush():
        if not name:
            return
        if source == "git":
            sources[name] = ("git", desc_url)
        elif source == "path":
            sources[name] = ("path", desc_path)
        else:
            sources[name] = (source, None)

    with open(lock_path) as f:
        for line in f:
            m = re.match(r"^  (\S+):$", line)
            if m:
                flush()
                name, source, desc_path, desc_url = m.group(1), None, None, None
                continue
            m = re.match(r"^    source: (\S+)", line)
            if m:
                source = m.group(1)
                continue
            m = re.match(r'^      path: "?(.+?)"?$', line)
            if m:
                desc_path = m.group(1)
                continue
            m = re.match(r'^      url: "?(.+?)"?$', line)
            if m:
                desc_url = m.group(1)
                continue
    flush()
    return sources


def read_pubspec_name(target_dir):
    with open(os.path.join(target_dir, "pubspec.yaml")) as f:
        for line in f:
            m = re.match(r"^name:\s*(\S+)", line)
            if m:
                return m.group(1)
    raise SystemExit(f"ERROR: no 'name:' field found in {target_dir}/pubspec.yaml")


def compute_closure(graph, root_pkg_name):
    """BFS over each package's own 'dependencies' (never 'devDependencies')
    edges, starting from root_pkg_name's own 'dependencies' list. This is
    what actually ships in a compiled binary, and -- unlike the graph's own
    "kind" field -- is correctly scoped to one workspace member even though
    the graph itself covers the whole workspace.
    """
    by_name = {p["name"]: p for p in graph.get("packages", [])}
    root = by_name.get(root_pkg_name)
    if root is None:
        raise SystemExit(
            f"ERROR: {root_pkg_name!r} not found in 'dart pub deps --json' output -- "
            f"is it resolved? Run 'flutter pub get' from the workspace root first."
        )

    visited = set()
    queue = list(root.get("dependencies", []))
    while queue:
        pkg_name = queue.pop()
        if pkg_name in visited or pkg_name == root_pkg_name:
            continue
        visited.add(pkg_name)
        pkg = by_name.get(pkg_name)
        if pkg is None:
            continue
        queue.extend(pkg.get("dependencies", []))
    return visited


def main():
    if len(sys.argv) != 4:
        print("Usage: check_license_purity.py <target-dir> <deps-json-path> <workspace-lock-path>",
              file=sys.stderr)
        sys.exit(2)

    target_dir, deps_json_path, lock_path = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(deps_json_path) as f:
        graph = json.load(f)
    lock_sources = parse_lock_sources(lock_path)

    root_pkg_name = read_pubspec_name(target_dir)
    closure = compute_closure(graph, root_pkg_name)

    failures = []
    for pname in sorted(closure):
        if pname in SDK_PACKAGES:
            continue
        source, location = lock_sources.get(pname, (None, None))
        if source == "sdk":
            continue

        pkg = next((p for p in graph["packages"] if p["name"] == pname), None)
        version = pkg.get("version", "") if pkg else ""

        if source == "git" and location:
            license_file = find_git_license(location)
        elif source == "path" and location:
            license_file = find_path_license(location)
        else:
            license_file = find_hosted_license(pname, version)

        if not license_file:
            failures.append(
                f"NO LICENSE: {pname} (source={source or 'hosted'}) -- "
                f"treated as all-rights-reserved, non-free"
            )
            continue

        with open(license_file, errors="replace") as f:
            text = f.read()
        if not ALLOWED_LICENSE_RE.search(text):
            first_line = text.strip().splitlines()[0] if text.strip() else "(empty)"
            failures.append(
                f"UNRECOGNIZED LICENSE: {pname} -> {license_file} "
                f"(first line: {first_line!r})"
            )

    if failures:
        print(f"FAILURE: {len(failures)} dependency issue(s) found in {root_pkg_name} "
              f"({len(closure)} packages checked):")
        for item in failures:
            print(f"  {item}")
        sys.exit(1)

    print(f"SUCCESS: {root_pkg_name}'s full resolved runtime dependency closure "
          f"({len(closure)} packages) is FOSS-pure.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Rewrite `purity_check.sh`**

```bash
#!/usr/bin/env bash
# purity_check.sh <path-relative-to-client>
#
# Verifies that the package/app at <path> (e.g. "packages/pocketcoder_flutter"
# or "apps/pocketcoder_foss") has a FULLY RESOLVED runtime dependency closure
# built entirely from packages carrying a recognized free/open-source
# license -- not just a grep of the target's own pubspec.yaml/imports for
# hardcoded proprietary package names. `dart pub deps --json` returns the
# WHOLE workspace's graph regardless of cwd (verified -- there is no
# per-member scoping flag), so it's fetched once here from the workspace
# root and check_license_purity.py computes the target-scoped closure
# itself from that graph's dependency edges. See that script for the
# classification logic and why this replaced the older, shallower check.
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <path-relative-to-client, e.g. packages/pocketcoder_flutter>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$CLIENT_DIR/$TARGET"
WORKSPACE_LOCK="$CLIENT_DIR/pubspec.lock"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: $TARGET_DIR does not exist."
  exit 1
fi
if [ ! -f "$WORKSPACE_LOCK" ]; then
  echo "ERROR: $WORKSPACE_LOCK not found -- run 'flutter pub get' from $CLIENT_DIR first."
  exit 1
fi

echo "Checking purity for $TARGET (full resolved dependency closure)..."

DEPS_JSON_FILE="$(mktemp)"
trap 'rm -f "$DEPS_JSON_FILE"' EXIT
(cd "$CLIENT_DIR" && dart pub deps --json) > "$DEPS_JSON_FILE"

if [ ! -s "$DEPS_JSON_FILE" ]; then
  echo "ERROR: 'dart pub deps --json' produced no output."
  exit 1
fi

python3 "$SCRIPT_DIR/check_license_purity.py" "$TARGET_DIR" "$DEPS_JSON_FILE" "$WORKSPACE_LOCK"
```

Run: `chmod +x client/scripts/purity_check.sh`

- [ ] **Step 3: Update the melos `check:purity` script**

In `client/pubspec.yaml`, replace:
```yaml
    check:purity:
      run: ./scripts/purity_check.sh pocketcoder_flutter
      description: Verify that the core package has no proprietary dependencies.
```
with:
```yaml
    check:purity:
      run: ./scripts/purity_check.sh packages/pocketcoder_flutter && ./scripts/purity_check.sh apps/pocketcoder_foss
      description: Verify the FOSS core package and the FOSS app target have no proprietary/unlicensed dependencies.
```

- [ ] **Step 4: Run it for real and verify it actually catches something**

First, confirm it passes on the real, clean targets:
```bash
cd client && flutter pub get
melos run check:purity
```
Expected: both `packages/pocketcoder_flutter` and `apps/pocketcoder_foss` report `SUCCESS`.

**Post-implementation update (as actually shipped):** running the check for real against this repo surfaced three more real issues beyond what this plan anticipated, all fixed in the delivered `check_license_purity.py`:

1. `ALLOWED_LICENSE_RE` originally matched only title-style phrases ("MIT License", "BSD License"). The actual convention across the Dart/Flutter ecosystem's own `LICENSE` files is a bare copyright line followed by the license *body* text with no such title at all (e.g. `async`'s `LICENSE` reads "Copyright 2015, the Dart project authors." + BSD-3-Clause body — the word "BSD" never appears). Fixed to match canonical body-text openings ("Redistribution and use in source and binary forms", "Permission is hereby granted, free of charge", etc.) instead.
2. Workspace members never appear in `pubspec.lock`'s source classification at all (Dart pub workspaces resolve member-to-member deps via the `workspace:` list, not lockfile `path:` entries — confirmed zero `source: path` entries exist anywhere in this repo's lockfile). `apps/pocketcoder_foss` depending on `packages/pocketcoder_flutter` was misreported as `NO LICENSE: pocketcoder_flutter (source=hosted)`. Fixed by skipping any package whose graph entry has `"kind": "root"` (dart pub deps --json tags every workspace member's own entry this way) — first-party code covered by the repo's own top-level `LICENSE`, not a dependency to classify individually.
3. With both of the above fixed, the check correctly found 4 real, previously-undetected problems in `pocketcoder_flutter`'s own dependency closure: `ag_ui_widgets_flutter`'s `LICENSE` file literally reads `"TODO: Add your license here."`, and `cubit_ui_flow`/`flutter_color_palette`/`l10n_key_resolver` (three more `qtpi-bonding-org` sibling git packages, same situation as `flutter_aeroform`) have no `LICENSE` file at all. Per explicit user decision, these are tracked as a **named allowlist** (`PENDING_LICENSE_ALLOWLIST` in `check_license_purity.py`) rather than blocking on fixing four separate external repos before this plan could land — deliberately a named list of these four specific packages, not an org-wide bypass, since `flutter_aeroform` lives in the exact same GitHub org and must still be caught (verified: it's real, present in the workspace right now via `pocketcoder_pro`, and correctly does *not* appear in either FOSS target's output). Both `main()`'s success and failure paths print a `NOTE:` line listing anything skipped via the allowlist, so a passing check never silently looks like "fully verified clean."

This also replaces the plan's originally-written "prove it has teeth" methodology (temporarily adding `flutter_aeroform` to `packages/pocketcoder_flutter/pubspec.yaml`), which turned out to be flawed on inspection: since `apps/pocketcoder_foss` depends on `pocketcoder_flutter`, that edit would make `flutter_aeroform` a real transitive dependency of *both* targets, so `apps/pocketcoder_foss` would **not** stay green as originally claimed — it doesn't prove differential scoping at all. The real, already-verified proof needs no temporary edit: `flutter_aeroform` genuinely exists in the workspace right now (via `pocketcoder_pro`, a sibling neither FOSS target depends on) and correctly does not appear in either target's failures, while running `./scripts/purity_check.sh packages/pocketcoder_pro` directly correctly reports `FAILURE: ... NO LICENSE: flutter_aeroform` — proving the check fails exactly the target that actually depends on it and passes the two that don't.

- [ ] **Step 5: Commit**

```bash
git add client/scripts/purity_check.sh client/scripts/check_license_purity.py client/pubspec.yaml
git commit -m "feat(client): rewrite purity check around the real resolved dependency graph + license scan"
```

---

### Task 4: Wire the purity check into CI

**Files:**
- Create: `.github/workflows/foss-purity.yml`

**Interfaces:**
- Consumes: `client/scripts/purity_check.sh` (Task 3).

- [ ] **Step 1: Write the workflow**

```yaml
name: FOSS Purity Check

on:
  push:
    branches: [main]
    paths:
      - 'client/packages/pocketcoder_flutter/**'
      - 'client/apps/pocketcoder_foss/**'
      - 'client/pubspec.lock'
      - 'client/pubspec.yaml'
      - 'client/scripts/purity_check.sh'
      - 'client/scripts/check_license_purity.py'
  pull_request:
    paths:
      - 'client/packages/pocketcoder_flutter/**'
      - 'client/apps/pocketcoder_foss/**'
      - 'client/pubspec.lock'
      - 'client/pubspec.yaml'
      - 'client/scripts/purity_check.sh'
      - 'client/scripts/check_license_purity.py'

permissions:
  contents: read

concurrency:
  group: foss-purity-${{ github.ref }}
  cancel-in-progress: true

jobs:
  purity:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # client/packages/pocketcoder_flutter depends on several private git
      # repos under the qtpi-bonding-org org via SSH URLs -- `flutter pub
      # get` below needs an SSH key with read access to those repos loaded
      # into the runner's ssh-agent. Add one as a repo secret (e.g.
      # FLUTTER_DEPS_DEPLOY_KEY) and uncomment this step; until then this
      # workflow will fail at the "Resolve workspace dependencies" step
      # with a git auth error, not a purity failure.
      # - uses: webfactory/ssh-agent@v0.9.0
      #   with:
      #     ssh-private-key: ${{ secrets.FLUTTER_DEPS_DEPLOY_KEY }}

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Resolve workspace dependencies
        working-directory: client
        run: flutter pub get

      - name: Run purity check
        working-directory: client
        run: |
          ./scripts/purity_check.sh packages/pocketcoder_flutter
          ./scripts/purity_check.sh apps/pocketcoder_foss
```

- [ ] **Step 2: Verify the YAML is well-formed**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/foss-purity.yml')); print('OK')"`
(If `PyYAML` isn't installed, `pip install --user pyyaml` first, or just visually diff against `.github/workflows/docs.yml`'s structure for a sanity check instead — the point is confirming no YAML syntax error, not that CI can actually run in this sandbox.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/foss-purity.yml
git commit -m "ci: run the FOSS purity check on every push/PR touching the FOSS surface"
```

---

## Verification

- `cd client && flutter pub get && melos run check:purity` — both targets report `SUCCESS`.
- Task 3 Step 4's "prove it catches something" exercise passed (confirmed `flutter_aeroform`'s missing LICENSE is actually detected, then reverted).
- `cd client/apps/pocketcoder_foss && flutter analyze` — clean.
- `cd client/apps/pocketcoder_foss && flutter build apk --debug` — succeeds, producing a real APK with no Firebase/RevenueCat code (this can be double-checked by unzipping the APK and confirming no `com/google/firebase` or `com/revenuecat` class files are present, if you want the strongest possible proof beyond the source-level purity check).
- `git log --oneline -4` shows the four commits from Tasks 1–4.
- Manual, outside this plan: register the FOSS app's `org.pocketcoder.foss` applicationId if/when actually submitting to F-Droid (fdroiddata recipe, or self-hosted repo) — explicitly out of scope here, same as the App Store Connect dashboard steps from the earlier native-push-config work.
