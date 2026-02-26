import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/config/config_cubit.dart';
import 'package:pocketcoder_flutter/application/config/config_state.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/cloud_provider.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_result.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
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

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Configure Deployment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<ConfigCubit, ConfigState>(
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
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Admin Email
                      _buildSectionTitle('Admin Credentials'),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Admin Email',
                        hint: 'your@email.com',
                        keyboardType: TextInputType.emailAddress,
                        error: configState.validationErrors?['adminEmail'],
                        onChanged: (value) => _updateConfig(configCubit),
                      ),
                      SizedBox(height: AppSizes.space * 2),
                      // Gemini API Key
                      _buildTextField(
                        controller: _apiKeyController,
                        label: 'Gemini API Key',
                        hint: 'AIza...',
                        obscureText: true,
                        error: configState.validationErrors?['geminiApiKey'],
                        onChanged: (value) => _updateConfig(configCubit),
                      ),
                      SizedBox(height: AppSizes.space * 2),
                      // Optional Linode Token
                      _buildTextField(
                        controller: _linodeTokenController,
                        label: 'Linode Token (Optional)',
                        hint: 'For ntfy notifications',
                        obscureText: true,
                        onChanged: (value) => _updateConfig(configCubit),
                      ),
                      SizedBox(height: AppSizes.space * 2),
                      // NTFY Toggle
                      _buildSwitchTile(
                        title: 'Enable NTFY Notifications',
                        subtitle: 'Requires Linode token',
                        value: configState.config?.ntfyEnabled ?? false,
                        onChanged: (value) {
                          final current = configState.config;
                          if (current != null) {
                            configCubit.updateConfig(
                              current.copyWith(ntfyEnabled: value),
                            );
                          }
                        },
                      ),
                      SizedBox(height: AppSizes.space * 3),
                      // Plan Selection
                      _buildSectionTitle('Instance Plan'),
                      if (configState.status == UiFlowStatus.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (configState.plans != null)
                        _buildPlanDropdown(
                          configState.plans!,
                          configState.config?.planType,
                          configState.validationErrors?['planType'],
                          (plan) => _updateConfig(configCubit, planType: plan),
                        )
                      else
                        Text(
                          'Failed to load plans',
                          style: TextStyle(color: colors.error),
                        ),
                      SizedBox(height: AppSizes.space * 3),
                      // Region Selection
                      _buildSectionTitle('Region'),
                      if (configState.status == UiFlowStatus.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (configState.regions != null)
                        _buildRegionDropdown(
                          configState.regions!,
                          configState.config?.region,
                          configState.validationErrors?['region'],
                          (region) => _updateConfig(configCubit, region: region),
                        )
                      else
                        Text(
                          'Failed to load regions',
                          style: TextStyle(color: colors.error),
                        ),
                      SizedBox(height: AppSizes.space * 4),
                      // Deploy Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: configState.isValid == true
                              ? () => _deploy(configCubit, deploymentCubit)
                              : null,
                          child: const Text('Deploy Instance'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading overlay
                if (configState.status == UiFlowStatus.loading) ...[
                  Container(
                    color: colors.surface.withValues(alpha: 0.9),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.space),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? error,
    TextInputType? keyboardType,
    bool obscureText = false,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            errorText: error,
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildPlanDropdown(
    List<InstancePlan> plans,
    String? selectedPlanId,
    String? error,
    void Function(String) onSelected,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedPlanId,
      decoration: InputDecoration(
        labelText: 'Select Plan',
        border: const OutlineInputBorder(),
        errorText: error,
      ),
      items: plans.map((plan) {
        return DropdownMenuItem<String>(
          value: plan.id,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${plan.name} (${plan.memoryMB}MB RAM)',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '\$${plan.monthlyPriceUSD.toStringAsFixed(2)}/mo',
                style: TextStyle(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (plan.recommended) ...[
                SizedBox(width: AppSizes.space),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.space,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }

  Widget _buildRegionDropdown(
    List<Region> regions,
    String? selectedRegionId,
    String? error,
    void Function(String) onSelected,
  ) {
    return DropdownButtonFormField<String>(
      value: selectedRegionId,
      decoration: InputDecoration(
        labelText: 'Select Region',
        border: const OutlineInputBorder(),
        errorText: error,
      ),
      items: regions.map((region) {
        return DropdownMenuItem<String>(
          value: region.id,
          child: Row(
            children: [
              Text('${region.city} (${region.country.toUpperCase()})'),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
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
          linodeToken:
              _linodeTokenController.text.isEmpty ? null : _linodeTokenController.text,
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