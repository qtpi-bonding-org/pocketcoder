import 'package:flutter/services.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_report.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

import 'error_inbox_diagnostics_state.dart';

// Query params only, deliberately no `body`: a body long enough to hold a
// real stack trace risks silently exceeding browsers'/GitHub's URL length
// limits. The report is copied to the clipboard instead -- the reviewer
// pastes it once the issue page opens.
final Uri _newIssueBaseUri =
    Uri.parse('https://github.com/qtpi-bonding-org/pocketcoder/issues/new');

class ErrorInboxDiagnosticsCubit extends AppCubit<ErrorInboxDiagnosticsState> {
  ErrorInboxDiagnosticsCubit(this._releaseStatusService, this._launcher)
      : super(const ErrorInboxDiagnosticsState());

  final IServerReleaseStatusService _releaseStatusService;
  final InAppBrowserLauncher _launcher;

  Future<void> copyReport(ErrorEntry entry) {
    return tryOperation(() async {
      final environment = await _environment();
      await Clipboard.setData(ClipboardData(
        text: DiagnosticReportFormatter.format(entry, environment: environment),
      ));
      return createSuccessState();
    });
  }

  Future<void> copyReports(Iterable<ErrorBoxEntry> entries) {
    return tryOperation(() async {
      final environment = await _environment();
      await Clipboard.setData(ClipboardData(
        text: DiagnosticReportFormatter.formatMany(
          entries,
          environment: environment,
        ),
      ));
      return createSuccessState();
    });
  }

  /// Copies the full report (same as [copyReport]) and opens a new GitHub
  /// issue pre-filled with just a title -- the reviewer pastes the report
  /// once the page opens.
  Future<void> reportOnGithub(ErrorEntry entry) {
    return tryOperation(() async {
      final environment = await _environment();
      await Clipboard.setData(ClipboardData(
        text: DiagnosticReportFormatter.format(entry, environment: environment),
      ));
      final uri = _newIssueBaseUri.replace(queryParameters: {
        'title': '${entry.source}: ${entry.errorCode}',
      });
      await _launcher.open(uri);
      return createSuccessState();
    });
  }

  Future<DiagnosticEnvironment> _environment() async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Best effort -- a bug report must never fail to copy just because
      // the platform channel for app version happened to be unavailable.
    }

    String? serverVersion;
    String? nixosVersion;
    try {
      if (_releaseStatusService.isAuthenticated) {
        final snapshot = await _releaseStatusService.inspect();
        serverVersion = snapshot.currentVersion;
        nixosVersion = snapshot.nixosVersion;
      }
    } catch (_) {
      // Same reasoning -- an unreachable/unauthenticated server must not
      // block copying the report, it just omits the server-side versions.
    }

    return DiagnosticEnvironment(
      appVersion: appVersion,
      serverVersion: serverVersion,
      nixosVersion: nixosVersion,
    );
  }
}
