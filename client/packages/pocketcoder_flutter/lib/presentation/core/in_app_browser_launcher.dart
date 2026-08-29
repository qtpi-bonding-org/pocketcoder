import 'package:url_launcher/url_launcher.dart';

/// The subset of [launchUrl] used by the secure in-app browser launcher.
typedef LaunchUrlDelegate = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
});

abstract interface class InAppBrowserLauncher {
  Future<bool> open(Uri uri);
}

// Registered via ExternalModule.inAppBrowserLauncher (a plain constructor
// call, not @LazySingleton-generated), not annotated here directly:
// injectable's generator cannot register a bare function type like
// LaunchUrlDelegate ("is not a class element"), so it can't safely resolve
// this constructor's parameter on its own -- the module getter sidesteps
// that by calling the constructor directly, letting the real Dart default
// value (launchUrl) apply exactly as written below.
class UrlLauncherInAppBrowserLauncher implements InAppBrowserLauncher {
  UrlLauncherInAppBrowserLauncher({LaunchUrlDelegate launch = launchUrl})
      : _launch = launch;

  final LaunchUrlDelegate _launch;

  @override
  Future<bool> open(Uri uri) => _launch(uri, mode: LaunchMode.inAppBrowserView);
}
