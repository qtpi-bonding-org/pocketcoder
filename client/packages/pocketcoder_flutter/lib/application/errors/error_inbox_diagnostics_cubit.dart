import 'package:flutter/services.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_report.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

import 'error_inbox_diagnostics_state.dart';

class ErrorInboxDiagnosticsCubit extends AppCubit<ErrorInboxDiagnosticsState> {
  ErrorInboxDiagnosticsCubit() : super(const ErrorInboxDiagnosticsState());

  Future<void> copyReport(ErrorEntry entry) {
    return tryOperation(() async {
      await Clipboard.setData(
        ClipboardData(text: DiagnosticReportFormatter.format(entry)),
      );
      return createSuccessState();
    });
  }

  Future<void> copyReports(Iterable<ErrorBoxEntry> entries) {
    return tryOperation(() async {
      await Clipboard.setData(
        ClipboardData(text: DiagnosticReportFormatter.formatMany(entries)),
      );
      return createSuccessState();
    });
  }
}
