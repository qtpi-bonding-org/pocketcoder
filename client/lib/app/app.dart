import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:test_app/l10n/app_localizations.dart';
import 'package:test_app/application/system/status_cubit.dart';
import 'package:test_app/application/system/poco_cubit.dart';

import '../app_router.dart';
import '../design_system/theme/app_theme.dart';
import '../design_system/theme/theme_service.dart';
import '../design_system/primitives/ui_scaler.dart';
import '../infrastructure/feedback/localization_service.dart';
import 'bootstrap.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real app, use ListenableBuilder or BlocBuilder on ThemeService
    // For simplicity in template, retrieving directly or assuming singleton
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => getIt<StatusCubit>(),
            ),
            BlocProvider(
              create: (context) => getIt<PocoCubit>(),
            ),
          ],
          child: MaterialApp.router(
            title: 'Test App',
            routerConfig: AppRouter.router,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            builder: (context, child) {
              // Initialize UI Scaler
              UiScaler.instance.init(context);

              // Update Localization Service
              final l10n = AppLocalizations.of(context);
              if (l10n != null) {
                final service = getIt<cubit_ui_flow.ILocalizationService>();
                if (service is AppLocalizationService) {
                  service.update(l10n);
                }
              }

              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}
