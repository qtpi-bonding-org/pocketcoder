import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

@wb.UseCase(name: 'confirm only', type: TerminalDialogActions)
Widget confirmOnly(BuildContext context) => _app(
      TerminalDialogActions(confirmLabel: 'SAVE', onConfirm: () {}),
    );

@wb.UseCase(name: 'confirm and cancel', type: TerminalDialogActions)
Widget confirmAndCancel(BuildContext context) => _app(
      TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: () {},
        cancelLabel: 'CANCEL',
        onCancel: () {},
      ),
    );

@wb.UseCase(name: 'disabled confirm', type: TerminalDialogActions)
Widget disabledConfirm(BuildContext context) => _app(
      TerminalDialogActions(
        confirmLabel: 'SAVE',
        onConfirm: () {},
        confirmEnabled: false,
      ),
    );

@wb.UseCase(name: 'destructive', type: TerminalDialogActions)
Widget destructive(BuildContext context) => _app(
      TerminalDialogActions(
        confirmLabel: 'DELETE',
        onConfirm: () {},
        cancelLabel: 'CANCEL',
        onCancel: () {},
        destructive: true,
      ),
    );
