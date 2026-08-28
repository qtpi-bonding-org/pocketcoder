import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('opens a URI in the in-app browser view', () async {
    final calls = <({Uri uri, LaunchMode mode})>[];
    final launcher = UrlLauncherInAppBrowserLauncher(
      launch: (uri, {required mode}) async {
        calls.add((uri: uri, mode: mode));
        return true;
      },
    );

    final opened = await launcher.open(Uri.parse('https://example.test'));

    expect(opened, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.uri, Uri.parse('https://example.test'));
    expect(calls.single.mode, LaunchMode.inAppBrowserView);
  });

  test('returns false when the URL cannot be opened', () async {
    final launcher = UrlLauncherInAppBrowserLauncher(
      launch: (uri, {required mode}) async => false,
    );

    expect(
      await launcher.open(Uri.parse('https://example.test')),
      isFalse,
    );
  });
}
