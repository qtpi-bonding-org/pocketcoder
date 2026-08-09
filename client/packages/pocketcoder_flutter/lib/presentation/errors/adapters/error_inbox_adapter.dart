import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_diagnostics_cubit.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_diagnostics_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_screen.dart';

class ErrorInboxAdapter
    extends CubitAdapter<ErrorInboxCubit, ErrorInboxState> {
  const ErrorInboxAdapter({super.key});

  static List<ErrorBoxEntry> _selectErrors(ErrorInboxState state) =>
      state.errors;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ErrorInboxCubit, ErrorInboxState> adapter,
  ) {
    final errors = adapter.cubitField(_selectErrors);
    return BlocProvider(
      create: (_) => ErrorInboxDiagnosticsCubit(),
      child: UiFlowListener<ErrorInboxDiagnosticsCubit,
          ErrorInboxDiagnosticsState>(
        showSuccessToasts: true,
        successMessage: context.l10n.errorsCopied,
        child: ValueListenableBuilder<List<ErrorBoxEntry>>(
          valueListenable: errors,
          builder: (context, value, _) => ErrorInboxScreen(
            errors: value,
            onCopyAll: () => context.read<ErrorInboxDiagnosticsCubit>().copyReports(value),
            onClearAll: () async {
              final cubit = context.read<ErrorInboxCubit>();
              for (final entry in List.of(value)) {
                await cubit.deleteError(entry.id);
              }
            },
            onCopy: (entry) => context
                .read<ErrorInboxDiagnosticsCubit>()
                .copyReport(entry),
            onDelete: context.read<ErrorInboxCubit>().deleteError,
          ),
        ),
      ),
    );
  }
}
