import 'dart:convert';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/app_bootstrap.dart';
import 'package:flutter_aeroform/domain/models/host_spec.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_aeroform/domain/security/i_ssh_key_generator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';
import 'package:pocketcoder_pro/application/config/config_state.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_cloud_init.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/config_view.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/selected_cloud_provider.dart';

const _pocketCoderReleaseRef =
    String.fromEnvironment('POCKETCODER_RELEASE_REF', defaultValue: 'main');

class ConfigAdapter extends CubitAdapter<ConfigCubit, ConfigState> {
  const ConfigAdapter({super.key, this.credentials});

  final DeployCredentials? credentials;

  static ConfigState _selectState(ConfigState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ConfigCubit, ConfigState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final configCubit = context.read<ConfigCubit>();
    final deploymentCubit = context.read<DeploymentCubit>();
    var progressOpened = false;

    return UiFlowListener<ConfigCubit, ConfigState>(
      child: UiFlowListener<DeploymentCubit, DeploymentState>(
        listener: (context, deploymentState) {
          // Navigate to ProgressScreen on deployment start.
          if (!progressOpened &&
              deploymentState.status == UiFlowStatus.loading &&
              deploymentState.deploymentStatus != null) {
            progressOpened = true;
            context.pushNamed(RouteNames.deploymentProgress);
          }
          // Navigate to DetailsScreen on deployment completion.
          if (deploymentState.status == UiFlowStatus.success &&
              deploymentState.deploymentStatus == OnboardingStage.ready &&
              deploymentState.instance != null) {
            context.pushNamed(
              RouteNames.deploymentDetails,
              queryParameters: {'instanceId': deploymentState.instance!.id},
            );
          }
        },
        child: ValueListenableBuilder<ConfigState>(
          valueListenable: state,
          builder: (context, value, _) => StreamBuilder<DeploymentState>(
            initialData: deploymentCubit.state,
            stream: deploymentCubit.stream,
            builder: (context, deploymentSnapshot) => ConfigView(
              plans: value.plans,
              regions: value.regions,
              selectedPlan: value.config?.planType,
              selectedRegion: value.config?.region,
              isValid: value.isValid,
              backend: value.config?.backend ?? ProvisionBackendKind.nixos,
              distribution: value.config?.standardLinuxDistribution ??
                  StandardLinuxDistribution.debian,
              onPlanSelected: (plan) => _updateConfig(configCubit, planType: plan),
              onRegionSelected: (region) => _updateConfig(configCubit, region: region),
              onBackendSelected: (backend) =>
                  _updateConfig(configCubit, backend: backend),
              onDistributionSelected: (distribution) => _updateConfig(
                configCubit,
                standardLinuxDistribution: distribution,
              ),
              onDeploy: () => _deploy(configCubit, deploymentCubit),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deploy(
    ConfigCubit configCubit,
    DeploymentCubit deploymentCubit,
  ) async {
    final config = configCubit.state.config;
    final deployCredentials = credentials;
    if (config == null || deployCredentials == null) return;

    final keyPair = await getIt<ISshKeyGenerator>().generate();
    final host = config.backend == ProvisionBackendKind.nixos
        ? ImageBakedHostSpec(
            labelPrefix: pocketCoderHostLabelPrefix,
            authorizedKey: keyPair.publicKey,
          )
        : GeneratedConfigHostSpec(
            labelPrefix: pocketCoderHostLabelPrefix,
            authorizedKey: keyPair.publicKey,
            reverseProxyPort: 8090,
            hostname: HostnameStrategy.sslipIo,
            acmeEmail: deployCredentials.email,
            staticPaths: const {'/_pocketcoder': '/var/lib/pocketcoder/public'},
          );
    final bootstrap = config.backend == ProvisionBackendKind.nixos
        ? StackScriptBootstrap(
            stackScriptId: 2174743,
            udfData: {
              'ADMIN_USER_DATA': base64Encode(utf8.encode([
                'POCKETBASE_ADMIN_EMAIL=${deployCredentials.email}',
                'POCKETBASE_ADMIN_PASSWORD=${deployCredentials.password}',
                'NTFY_ENABLED=false',
                'root_ssh_key=${keyPair.publicKey}',
              ].join('\n'))),
            },
            image: const ImageArtifact(url: '', sha256: '', uncompressedBytes: 0),
          )
        : PocketCoderCloudInit.build(
            adminEmail: deployCredentials.email,
            adminPassword: deployCredentials.password,
            rootSshKey: keyPair.publicKey,
            sourceCommit: _pocketCoderReleaseRef,
          );
    await deploymentCubit.deploy(
      config,
      host: host,
      appBootstrap: bootstrap,
      instanceCredentials: InstanceCredentials(
        instanceId: '',
        rootSshPrivateKey: keyPair.privateKey,
      ),
      pocketCoderCredentials: PocketCoderCredentials(
        instanceId: '',
        adminPassword: deployCredentials.password,
        adminEmail: deployCredentials.email,
      ),
    );
  }

  void _updateConfig(
    ConfigCubit cubit, {
    String? planType,
    String? region,
    ProvisionBackendKind? backend,
    StandardLinuxDistribution? standardLinuxDistribution,
  }) {
    final base = cubit.state.config ??
        ProvisionConfig(
          planType: '',
          region: '',
          backend: ProvisionBackendKind.nixos,
          standardLinuxDistribution: StandardLinuxDistribution.debian,
        );
    cubit.updateConfig(
      base.copyWith(
        planType: planType ?? base.planType,
        region: region ?? base.region,
        backend: backend ?? base.backend,
        standardLinuxDistribution:
            standardLinuxDistribution ?? base.standardLinuxDistribution,
      ),
    );
  }
}
