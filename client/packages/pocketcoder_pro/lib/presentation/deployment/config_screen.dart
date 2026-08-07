import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';
import 'package:pocketcoder_pro/application/config/config_state.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/app_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';
import 'package:flutter_aeroform/domain/models/deployment_progress.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Configuration screen for deployment settings
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.I<ConfigCubit>()),
        // DeploymentCubit is route-shared so the progress/details pages see
        // the accepted deployment and its monitor. Using value prevents the
        // ConfigScreen from closing the app-scoped controller when it pops.
        BlocProvider.value(value: GetIt.I<DeploymentCubit>()),
      ],
      child: UiFlowListener<ConfigCubit, ConfigState>(
        child: _ConfigView(credentials: credentials),
      ),
    );
  }
}

class _ConfigView extends StatefulWidget {
  const _ConfigView({this.credentials});

  final DeployCredentials? credentials;

  @override
  State<_ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<_ConfigView> {
  late final String _adminEmail = widget.credentials?.email ?? '';
  late final String _adminPassword = widget.credentials?.password ?? '';
  DeploymentBackendKind _selectedBackend = DeploymentBackendKind.nixos;
  StandardLinuxDistribution _selectedDistribution =
      StandardLinuxDistribution.debian;
  bool _progressOpened = false;

  @override
  void initState() {
    super.initState();
    context.read<DeploymentCubit>().resetDeployment();
    context.read<ConfigCubit>().loadPlansAndRegions();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final configCubit = context.read<ConfigCubit>();
    final deploymentCubit = context.read<DeploymentCubit>();

    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, configState) {
        return BlocListener<DeploymentCubit, DeploymentState>(
          listener: (context, deploymentState) {
            // Navigate to ProgressScreen on deployment start
            if (!_progressOpened &&
                deploymentState.status == UiFlowStatus.loading &&
                deploymentState.deploymentStatus != null) {
              _progressOpened = true;
              context.pushNamed(RouteNames.deploymentProgress);
            }
            // Navigate to DetailsScreen on deployment completion
            if (deploymentState.status == UiFlowStatus.success &&
                deploymentState.deploymentStatus == DeploymentStatus.ready &&
                deploymentState.instance != null) {
              context.pushNamed(
                RouteNames.deploymentDetails,
                queryParameters: {'instanceId': deploymentState.instance!.id},
              );
            }
          },
          child: TerminalScaffold(
            title: 'MANIFEST CONFIGURATION',
            actions: [
              TerminalAction(
                label: 'BACK',
                onTap: () => context.pop(),
              ),
              TerminalAction(
                label: 'DEPLOY INSTANCE',
                onTap: configState.isValid == true
                    ? () => _deploy(configCubit, deploymentCubit)
                    : () {},
              ),
            ],
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space),
              child: Column(
                children: [
                  BiosFrame(
                    title: 'SYSTEM PARAMETERS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BiosSection(
                          title: 'NOTIFICATIONS (OPTIONAL)',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ENABLE NTFY RELAY',
                                      style: TextStyle(
                                        fontFamily: AppFonts.bodyFamily,
                                        color: colors.onSurface,
                                        fontSize: AppSizes.fontMini,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: configState.config?.ntfyEnabled ??
                                        false,
                                    onChanged: (value) {
                                      final current = configState.config;
                                      if (current != null) {
                                        configCubit.updateConfig(
                                          current.copyWith(ntfyEnabled: value),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        VSpace.x2,
                        BiosSection(
                          title: 'HARDWARE & GEOGRAPHY',
                          child: Column(
                            children: [
                              if (configState.plans != null)
                                _buildPlanSelector(
                                  context,
                                  configState.plans!,
                                  configState.config?.planType,
                                  (plan) => _updateConfig(configCubit,
                                      planType: plan),
                                )
                              else
                                const Text('INITIALIZING HW REGISTRY...'),
                              VSpace.x2,
                              if (configState.regions != null)
                                _buildRegionSelector(
                                  context,
                                  configState.regions!,
                                  configState.config?.region,
                                  (region) => _updateConfig(configCubit,
                                      region: region),
                                )
                              else
                                const Text('SCANNING GLOBAL REGIONS...'),
                            ],
                          ),
                        ),
                        VSpace.x2,
                        BiosSection(
                          title: 'OPERATING SYSTEM',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBackendSelector(
                                context,
                                configState.config?.backend ?? _selectedBackend,
                                (backend) => _updateConfig(
                                  configCubit,
                                  backend: backend,
                                ),
                              ),
                              if ((configState.config?.backend ??
                                      _selectedBackend) ==
                                  DeploymentBackendKind.standardLinux) ...[
                                VSpace.x1,
                                _buildDistributionSelector(
                                  context,
                                  configState
                                          .config?.standardLinuxDistribution ??
                                      _selectedDistribution,
                                  (distribution) => _updateConfig(
                                    configCubit,
                                    standardLinuxDistribution: distribution,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanSelector(
    BuildContext context,
    List<InstancePlan> plans,
    String? selectedPlanId,
    void Function(String) onSelected,
  ) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSTANCE PLAN',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
          ),
        ),
        VSpace.x1,
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          child: ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isSelected = plan.id == selectedPlanId;
              return InkWell(
                onTap: () => onSelected(plan.id),
                child: Container(
                  padding: EdgeInsets.all(AppSizes.space),
                  color:
                      isSelected ? colors.primary.withValues(alpha: 0.1) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${plan.name} (${plan.memoryMB}MB RAM)',
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color:
                                isSelected ? colors.primary : colors.onSurface,
                            fontSize: AppSizes.fontMini,
                          ),
                        ),
                      ),
                      Text(
                        '\$${plan.monthlyPriceUSD.toStringAsFixed(2)}/MO',
                        style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: colors.primary,
                          fontSize: AppSizes.fontMini,
                          fontWeight: AppFonts.heavy,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRegionSelector(
    BuildContext context,
    List<Region> regions,
    String? selectedRegionId,
    void Function(String) onSelected,
  ) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEPLOYMENT REGION',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
          ),
        ),
        VSpace.x1,
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          child: ListView.builder(
            itemCount: regions.length,
            itemBuilder: (context, index) {
              final region = regions[index];
              final isSelected = region.id == selectedRegionId;
              return InkWell(
                onTap: () => onSelected(region.id),
                child: Container(
                  padding: EdgeInsets.all(AppSizes.space),
                  color:
                      isSelected ? colors.primary.withValues(alpha: 0.1) : null,
                  child: Text(
                    '${region.city.toUpperCase()} (${region.country.toUpperCase()})',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontSize: AppSizes.fontMini,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateConfig(
    ConfigCubit cubit, {
    String? planType,
    String? region,
    DeploymentBackendKind? backend,
    StandardLinuxDistribution? standardLinuxDistribution,
  }) {
    final current = cubit.state.config;
    final selectedBackend = backend ?? current?.backend ?? _selectedBackend;
    final selectedDistribution = standardLinuxDistribution ??
        current?.standardLinuxDistribution ??
        _selectedDistribution;
    _selectedBackend = selectedBackend;
    _selectedDistribution = selectedDistribution;
    if (current != null) {
      cubit.updateConfig(
        current.copyWith(
          planType: planType ?? current.planType,
          region: region ?? current.region,
          backend: selectedBackend,
          standardLinuxDistribution: selectedDistribution,
        ),
      );
    } else {
      cubit.updateConfig(
        DeploymentConfig(
          planType: planType ?? '',
          region: region ?? '',
          adminEmail: _adminEmail,
          ntfyEnabled: cubit.state.config?.ntfyEnabled ?? false,
          imageRelayUrl: AppConfig.kImageRelayUrl,
          nixosImageLabel: AppConfig.kNixosImageLabel,
          backend: selectedBackend,
          standardLinuxDistribution: selectedDistribution,
        ),
      );
    }
  }

  Widget _buildBackendSelector(
    BuildContext context,
    DeploymentBackendKind selected,
    ValueChanged<DeploymentBackendKind> onSelected,
  ) {
    final colors = context.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'BACKEND',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny,
            ),
          ),
        ),
        DropdownButton<DeploymentBackendKind>(
          value: selected,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          items: const [
            DropdownMenuItem(
              value: DeploymentBackendKind.nixos,
              child: Text('NixOS'),
            ),
            DropdownMenuItem(
              value: DeploymentBackendKind.standardLinux,
              child: Text('Standard Linux'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistributionSelector(
    BuildContext context,
    StandardLinuxDistribution selected,
    ValueChanged<StandardLinuxDistribution> onSelected,
  ) {
    final colors = context.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'DISTRIBUTION',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny,
            ),
          ),
        ),
        DropdownButton<StandardLinuxDistribution>(
          value: selected,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          items: const [
            DropdownMenuItem(
              value: StandardLinuxDistribution.debian,
              child: Text('Debian'),
            ),
            DropdownMenuItem(
              value: StandardLinuxDistribution.ubuntu,
              child: Text('Ubuntu'),
            ),
          ],
        ),
      ],
    );
  }

  void _deploy(ConfigCubit configCubit, DeploymentCubit deploymentCubit) {
    final config = configCubit.state.config;
    if (config != null) {
      deploymentCubit.deploy(config, adminPassword: _adminPassword);
    }
  }
}
