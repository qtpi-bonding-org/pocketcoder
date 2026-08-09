import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_widgetsystem/flutter_widgetsystem.dart' as ws;
import 'package:pocketcoder_flutter/design_system/storybook/pc_palette_adapter.dart';
import 'package:pocketcoder_flutter/design_system/storybook/widgetsystem_main.directories.g.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_deploy_credentials_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'package:pocketcoder_pro/presentation/auth/widgets/auth_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/config_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/details_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/progress_view.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const PocketCoderProWidgetbookApp());

class PocketCoderProWidgetbookApp extends StatelessWidget {
  const PocketCoderProWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) => ws.WidgetSystem(
        lightPalette: const PocketCoderPaletteAdapter(),
        themeBuilder: (_) => AppTheme.lightTheme,
        directories: [
          WidgetbookFolder(
            name: 'Screens',
            children: [
              ..._screenDirectories,
              ..._proDirectories,
              ...directories,
            ],
          ),
        ],
      );
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Widget _onboardingApp(Widget child) => BlocProvider(
      create: (_) => PocoCubit(),
      child: _app(child),
    );

final _screenDirectories = <WidgetbookNode>[
  WidgetbookFolder(
    name: 'Onboarding',
    children: [
      WidgetbookComponent(
        name: 'OnboardingScreen',
        useCases: [
          WidgetbookUseCase(
            name: 'entry screen',
            builder: (_) => _onboardingApp(const OnboardingScreen()),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Deploy credentials screen',
        useCases: [
          WidgetbookUseCase(
            name: 'empty form',
            builder: (_) => _app(const OnboardingDeployCredentialsScreen()),
          ),
        ],
      ),
    ],
  ),
];

final _proDirectories = <WidgetbookNode>[
  WidgetbookFolder(
    name: 'Authentication',
    children: [
      WidgetbookComponent(
        name: 'AuthView',
        useCases: [
          WidgetbookUseCase(
            name: 'ready',
            builder: (_) => _app(AuthView(
              isLoading: false,
              errorMessage: null,
              onAuthenticate: () {},
              onBack: () {},
            )),
          ),
          WidgetbookUseCase(
            name: 'error',
            builder: (_) => _app(AuthView(
              isLoading: false,
              errorMessage: 'OAuth gateway unavailable',
              onAuthenticate: () {},
              onBack: () {},
            )),
          ),
        ],
      ),
    ],
  ),
  WidgetbookFolder(
    name: 'Deployment',
    children: [
      WidgetbookComponent(
        name: 'ConfigView',
        useCases: [
          WidgetbookUseCase(
            name: 'populated and valid',
            builder: (_) => _app(ConfigView(
              plans: const [
                InstancePlan(
                  id: 'shared-2',
                  name: 'Shared 2GB',
                  memoryMB: 2048,
                  vcpus: 1,
                  diskGB: 50,
                  monthlyPriceUSD: 12,
                  recommended: true,
                ),
                InstancePlan(
                  id: 'dedicated-4',
                  name: 'Dedicated 4GB',
                  memoryMB: 4096,
                  vcpus: 2,
                  diskGB: 80,
                  monthlyPriceUSD: 24,
                  recommended: false,
                ),
              ],
              regions: const [
                Region(id: 'us-west', name: 'us-west', country: 'US', city: 'Fremont'),
                Region(id: 'eu-central', name: 'eu-central', country: 'DE', city: 'Frankfurt'),
              ],
              selectedPlan: 'shared-2',
              selectedRegion: 'us-west',
              isValid: true,
              backend: ProvisionBackendKind.standardLinux,
              distribution: StandardLinuxDistribution.ubuntu,
              onPlanSelected: (_) {},
              onRegionSelected: (_) {},
              onBackendSelected: (_) {},
              onDistributionSelected: (_) {},
              onDeploy: () {},
            )),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'ProgressView',
        useCases: [
          WidgetbookUseCase(
            name: 'provisioning',
            builder: (_) => _app(ProgressView(
              status: UiFlowStatus.loading,
              deploymentStatus: OnboardingStage.installingHost,
              pollingAttempts: 8,
              instance: null,
              error: null,
              onAbort: () {},
              onRetry: null,
            )),
          ),
          WidgetbookUseCase(
            name: 'failed',
            builder: (_) => _app(ProgressView(
              status: UiFlowStatus.failure,
              deploymentStatus: OnboardingStage.failed,
              pollingAttempts: 20,
              instance: null,
              error: 'Host provisioning timed out',
              onAbort: () {},
              onRetry: () {},
            )),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'DetailsView',
        useCases: [
          WidgetbookUseCase(
            name: 'running instance',
            builder: (_) => _app(DetailsView(
              instance: Instance(
                id: 'pc-demo-01',
                label: 'PocketCoder Demo',
                ipAddress: '203.0.113.42',
                status: InstanceStatus.running,
                created: DateTime(2026, 8, 9, 12, 30),
                region: 'Fremont',
                planType: 'Shared 2GB',
                provider: 'linode',
              ),
              credentials: const PocketCoderCredentials(
                instanceId: 'pc-demo-01',
                adminEmail: 'admin@example.test',
                adminPassword: 'demo-password',
              ),
              onRefresh: () {},
              onLogin: () {},
              onUpdate: () {},
              onDismiss: () {},
            )),
          ),
        ],
      ),
    ],
  ),
];
