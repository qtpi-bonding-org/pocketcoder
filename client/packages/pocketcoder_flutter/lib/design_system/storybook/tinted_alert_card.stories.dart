import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/tinted_alert_card.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

@wb.UseCase(name: 'warning tint', type: TintedAlertCard)
Widget warningTint(BuildContext context) => _app(
      TintedAlertCard(
        eyebrowLeft: 'SECURITY',
        eyebrowRight: "COMMANDER'S SIGNOFF",
        tint: context.terminalColors.warning,
        child: const Text('A warning alert body.'),
      ),
    );

@wb.UseCase(name: 'error tint', type: TintedAlertCard)
Widget errorTint(BuildContext context) => _app(
      TintedAlertCard(
        eyebrowLeft: 'ERROR',
        eyebrowRight: 'ACTION REQUIRED',
        tint: context.colorScheme.error,
        child: const Text('An error alert body.'),
      ),
    );
