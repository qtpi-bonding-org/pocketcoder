import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';

/// The subset of [launchUrl] used by the secure in-app browser launcher.
typedef LaunchUrlDelegate = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
});

abstract interface class InAppBrowserLauncher {
  Future<bool> open(Uri uri);
}

@LazySingleton(as: InAppBrowserLauncher)
class UrlLauncherInAppBrowserLauncher implements InAppBrowserLauncher {
  UrlLauncherInAppBrowserLauncher({LaunchUrlDelegate launch = launchUrl})
      : _launch = launch;

  final LaunchUrlDelegate _launch;

  @override
  Future<bool> open(Uri uri) => _launch(uri, mode: LaunchMode.inAppBrowserView);
}
