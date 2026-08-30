import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_report.dart';

ErrorEntry _entry() => ErrorEntry(
      source: 'ChatCubit',
      errorType: 'ChatException',
      errorCode: 'CHAT_001',
      stackTrace: '#0 fake stack',
      timestamp: DateTime(2026, 1, 1),
    );

void main() {
  test('includes version lines only for the fields that are present', () {
    final report = DiagnosticReportFormatter.format(
      _entry(),
      environment: const DiagnosticEnvironment(
        appVersion: '1.2.3+45',
        serverVersion: '2.0.0',
        nixosVersion: '26.05',
      ),
    );

    expect(report, contains('App version: 1.2.3+45'));
    expect(report, contains('PocketBase version: 2.0.0'));
    expect(report, contains('NixOS version: 26.05'));
  });

  test('omits version lines entirely when the environment is empty', () {
    final report = DiagnosticReportFormatter.format(_entry());

    expect(report, isNot(contains('App version:')));
    expect(report, isNot(contains('PocketBase version:')));
    expect(report, isNot(contains('NixOS version:')));
    expect(report, contains('CHAT_001'));
  });
}
