import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/application/system/status_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
// import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart'; // Unused here

import '../app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/theme/theme_service.dart';
import 'package:pocketcoder_flutter/design_system/primitives/ui_scaler.dart';
import 'package:pocketcoder_flutter/infrastructure/feedback/localization_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/notification_wrapper.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';
import 'bootstrap.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
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
            // Bare instance only -- watchChats()/checkEmptyAndMaybeAutoCreate()
            // must NOT run here: this MultiBlocProvider's create callbacks
            // fire once at app boot, before login/onboarding ever completes,
            // and checkEmptyAndMaybeAutoCreate() needs an authenticated
            // session to mean anything (a boot-time failure would never get
            // a second chance to run). ChatListScreenAdapter's
            // adapter.keep() triggers them instead, once the chat list is
            // actually reached. Provided here (rather than scoped to that
            // one screen) so onboarding's AgentAuthAdapter can
            // also read it, for createAndOpen() on a freshly-connected
            // harness -- see ChatListAdapter.buildAdapter's comment for
            // the incident this fixes.
            BlocProvider(
              create: (context) => getIt<ChatListCubit>(),
            ),
            BlocProvider(
              create: (context) => getIt<McpCubit>()..watchServers(),
            ),
            BlocProvider(
              create: (context) => getIt<ObservabilityCubit>()..refreshStats(),
            ),
            BlocProvider(
              create: (context) => getIt<ReleaseStatusCubit>()..start(),
            ),
          ],
          child: BlocBuilder<ReleaseStatusCubit, ReleaseStatusState>(
            builder: (context, releaseState) => ReleaseStatusScope(
              state: releaseState,
              onDismiss: context.read<ReleaseStatusCubit>().dismissUpdateNotice,
              child: NotificationWrapper(
                child: MaterialApp.router(
                  title: 'PocketCoder',
                  routerConfig: AppRouter.router,
                  scaffoldMessengerKey: AppRouter.messengerKey,
                  // PocketCoder ships one look, so both slots resolve to the same
                  // terminal theme today and toggling [ThemeService] is a visual
                  // no-op. The wiring is deliberately left intact: authoring a
                  // real light palette later means pointing AppTheme.lightTheme at
                  // it, with no changes here or at any call site.
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeService.isDarkMode
                      ? ThemeMode.dark
                      : ThemeMode.light,
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
                      final service =
                          getIt<cubit_ui_flow.ILocalizationService>();
                      if (service is AppLocalizationService) {
                        service.update(l10n);
                      }
                    }

                    return child ?? const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
