import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_aeroform/application/config/config_cubit.dart';
import 'package:flutter_aeroform/application/config/config_state.dart';
import 'package:flutter_aeroform/application/deployment/deployment_cubit.dart';
import 'package:flutter_aeroform/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Configuration screen for deployment settings
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.I<ConfigCubit>()),
        BlocProvider(create: (_) => GetIt.I<DeploymentCubit>()),
      ],
      child: UiFlowListener<ConfigCubit, ConfigState>(
        child: const _ConfigView(),
      ),
    );
  }
}

class _ConfigView extends StatefulWidget {
  const _ConfigView();

  @override
  State<_ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<_ConfigView> {
  final _emailController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _linodeTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load plans and regions on init
    context.read<ConfigCubit>().loadPlansAndRegions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _apiKeyController.dispose();
    _linodeTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final configCubit = context.read<ConfigCubit>();
    final deploymentCubit = context.read<DeploymentCubit>();

    return BlocConsumer<ConfigCubit, ConfigState>(
      listener: (context, state) {
        // Update controllers when config changes
        if (state.config != null) {
          final config = state.config!;
          if (_emailController.text != config.adminEmail) {
            _emailController.text = config.adminEmail;
          }
          if (_apiKeyController.text != config.geminiApiKey) {
            _apiKeyController.text = config.geminiApiKey;
          }
          if (_linodeTokenController.text != (config.linodeToken ?? '')) {
            _linodeTokenController.text = config.linodeToken ?? '';
          }
        }
      },
      builder: (context, configState) {
        return BlocListener<DeploymentCubit, DeploymentState>(
          listener: (context, deploymentState) {
            // Navigate to ProgressScreen on deployment start
            if (deploymentState.status == UiFlowStatus.loading &&
                deploymentState.deploymentStatus == DeploymentStatus.creating) {
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
                          title: 'ADMIN CREDENTIALS',
                          child: Column(
                            children: [
                              TerminalTextField(
                                controller: _emailController,
                                label: 'ADMIN EMAIL',
                                hint: 'YOU@DOMAIN.COM',
                                errorText:
                                    configState.validationErrors?['adminEmail'],
                                onChanged: (value) =>
                                    _updateConfig(configCubit),
                              ),
                              VSpace.x2,
                              TerminalTextField(
                                controller: _apiKeyController,
                                label: 'GEMINI API KEY',
                                hint: 'ENTER KEY',
                                obscureText: true,
                                errorText: configState
                                    .validationErrors?['geminiApiKey'],
                                onChanged: (value) =>
                                    _updateConfig(configCubit),
                              ),
                            ],
                          ),
                        ),
                        VSpace.x2,
                        BiosSection(
                          title: 'NOTIFICATIONS (OPTIONAL)',
                          child: Column(
                            children: [
                              TerminalTextField(
                                controller: _linodeTokenController,
                                label: 'LINODE TOKEN',
                                hint: 'FOR NTFY RELAY',
                                obscureText: true,
                                onChanged: (value) =>
                                    _updateConfig(configCubit),
                              ),
                              VSpace.x1,
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
  }) {
    final current = cubit.state.config;
    if (current != null) {
      cubit.updateConfig(
        current.copyWith(
          planType: planType ?? current.planType,
          region: region ?? current.region,
          adminEmail: _emailController.text,
          geminiApiKey: _apiKeyController.text,
          linodeToken: _linodeTokenController.text.isEmpty
              ? null
              : _linodeTokenController.text,
        ),
      );
    } else {
      cubit.updateConfig(
        DeploymentConfig(
          planType: planType ?? '',
          region: region ?? '',
          adminEmail: _emailController.text,
          geminiApiKey: _apiKeyController.text,
          linodeToken: _linodeTokenController.text.isEmpty
              ? null
              : _linodeTokenController.text,
          ntfyEnabled: cubit.state.config?.ntfyEnabled ?? false,
          cloudInitTemplateUrl: '',
        ),
      );
    }
  }

  void _deploy(ConfigCubit configCubit, DeploymentCubit deploymentCubit) {
    final config = configCubit.state.config;
    if (config != null) {
      deploymentCubit.deploy(config);
    }
  }
}
