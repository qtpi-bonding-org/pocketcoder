import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'no provider selected', type: ProviderKeyEditorDialog)
Widget providerEditorEmpty(BuildContext context) =>
    _app(ProviderKeyEditorDialog(
      providerCatalog: const [],
      onSave: (_) {},
    ));

@wb.UseCase(name: 'provider picker with choices', type: ProviderTargetPicker)
Widget providerPickerChoices(BuildContext context) => _app(ProviderTargetPicker(
      targets: const [],
      selectedProvider: null,
      onSelected: (_) {},
    ));
