#!/usr/bin/env python3
"""Checks that every runtime dependency reachable from <target-dir>'s own
`dependencies` (never `devDependencies`) in a `dart pub deps --json` graph
carries a recognized free/open-source license.

Exists because the old purity_check.sh only grepped one package's own
pubspec.yaml/imports for three hardcoded proprietary package-name strings --
which caught nothing pulled in transitively, and nothing whose license was
simply missing (which is all-rights-reserved by default under copyright law).

Note: `dart pub deps --json` in a Dart pub workspace returns the ENTIRE
workspace's graph, not a graph scoped to one member. This script therefore
computes its own reachability closure from <target-dir>'s dependencies rather
than trusting the graph's per-package "kind" field.
"""
import glob
import json
import os
import re
import sys

ALLOWED_LICENSE_RE = re.compile(
    # Named-license headers (Apache/MPL/GPL/LGPL files spell these out).
    r"Apache License|Mozilla Public License|GNU LESSER GENERAL PUBLIC LICENSE"
    r"|GNU GENERAL PUBLIC LICENSE"
    # BSD/MIT/ISC/Zlib/Unlicense LICENSE files in the wild -- and nearly
    # every Dart/Flutter/Google pub package's LICENSE file specifically --
    # are just a copyright line followed by the license BODY text, with no
    # literal "BSD License"/"MIT License" title anywhere (confirmed against
    # real cached packages: async, collection, url_launcher, etc. all read
    # "Copyright 2015, the Dart project authors." + BSD 3-Clause body with
    # the word "BSD" never appearing). Match on the body's canonical
    # opening phrase instead of a title that mostly doesn't exist.
    r"|Redistribution and use in source and binary forms"  # BSD 2/3-Clause
    r"|Permission is hereby granted, free of charge"  # MIT
    r"|Permission to use, copy, modify, and(?:/or| )distribute this software"  # ISC
    r"|This is free and unencumbered software released into the public domain",  # Unlicense
    re.IGNORECASE,
)

# Ship with the Flutter/Dart SDK itself -- not a separate pub dependency
# with its own LICENSE file to check. Belt-and-suspenders alongside the
# pubspec.lock "source: sdk" check in parse_lock_sources/main below.
SDK_PACKAGES = {
    "flutter", "flutter_test", "flutter_localizations", "flutter_web_plugins",
    "sky_engine", "flutter_driver", "integration_test",
}

# Named, deliberate exceptions -- our own qtpi-bonding-org sibling packages
# that pocketcoder_flutter genuinely depends on but haven't had a real
# LICENSE file added yet (tracked as a TODO, not silently ignored -- see
# the NOTE lines main() prints for these). This is a NAMED list, not an
# org-wide bypass. Only add a package here after confirming with a human that it's
# actually meant to be free and just hasn't been licensed yet -- not as a
# way to silence a real finding.
PENDING_LICENSE_ALLOWLIST = {
    "cubit_ui_flow": "https://github.com/qtpi-bonding-org/flutter_cubit_ui_flow",
    "flutter_color_palette": "https://github.com/qtpi-bonding-org/flutter_color_palette",
    "l10n_key_resolver": "https://github.com/qtpi-bonding-org/dart_l10n_key_resolver",
    "ag_ui_widgets_flutter": "https://github.com/qtpi-bonding-org/ag_ui_widgets_flutter",
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
    # e.g. "https://github.com/org/repo.git" -- the pub cache's git checkout
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
    pending = []
    for pname in sorted(closure):
        if pname in SDK_PACKAGES:
            continue
        if pname in PENDING_LICENSE_ALLOWLIST:
            pending.append(pname)
            continue

        pkg = next((p for p in graph["packages"] if p["name"] == pname), None)
        # Other workspace members (e.g. apps/pocketcoder_foss depending on
        # packages/pocketcoder_flutter) never appear in pubspec.lock's
        # source classification at all -- Dart pub workspaces resolve
        # member-to-member deps via the `workspace:` list, not lockfile
        # `path:` entries (confirmed: zero `source: path` entries exist
        # anywhere in this repo's pubspec.lock). Falling through to the
        # hosted-package lookup for one misreports it as an unlicensed
        # third-party dependency. `dart pub deps --json` tags every
        # workspace member's own entry "kind": "root" regardless of which
        # member you started the closure from -- that's the correct signal
        # to recognize first-party code (covered by the repo's own
        # top-level LICENSE, not a dependency to classify individually).
        if pkg and pkg.get("kind") == "root":
            continue

        source, location = lock_sources.get(pname, (None, None))
        if source == "sdk":
            continue

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

    if pending:
        print(f"NOTE: {len(pending)} package(s) skipped via PENDING_LICENSE_ALLOWLIST "
              f"(named exceptions, not a passed check -- real LICENSE files still owed):")
        for pname in pending:
            print(f"  {pname} -> {PENDING_LICENSE_ALLOWLIST[pname]}")

    if failures:
        print(f"FAILURE: {len(failures)} dependency issue(s) found in {root_pkg_name} "
              f"({len(closure)} packages checked, {len(pending)} allowlisted):")
        for item in failures:
            print(f"  {item}")
        sys.exit(1)

    print(f"SUCCESS: {root_pkg_name}'s full resolved runtime dependency closure "
          f"({len(closure)} packages, {len(pending)} allowlisted) is FOSS-pure.")


if __name__ == "__main__":
    main()
