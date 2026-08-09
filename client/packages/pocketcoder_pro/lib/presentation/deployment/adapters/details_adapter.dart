import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/details_view.dart';

class DetailsAdapter extends CubitAdapter<DeploymentCubit, DeploymentState> {
  const DetailsAdapter({
    super.key,
    required this.instanceId,
    required this.credentialStore,
    required this.mapper,
  });

  final String instanceId;
  final PocketCoderCredentialStore credentialStore;
  final DeploymentMessageMapper mapper;

  static DeploymentState _selectState(DeploymentState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<DeploymentCubit, DeploymentState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<DeploymentCubit>();
    return UiFlowListener<DeploymentCubit, DeploymentState>(
      mapper: mapper,
      child: ValueListenableBuilder<DeploymentState>(
        valueListenable: state,
        builder: (context, value, _) => _DetailsCredentials(
          store: credentialStore,
          instanceId: instanceId,
          builder: (credentials) => _DetailsLifecycle(
            cubit: cubit,
            child: DetailsView(
              instance: value.instance,
              credentials: credentials,
              onRefresh: () => cubit.refreshInstanceStatus(instanceId),
              onLogin: () => _login(context, value.instance, credentials),
              onUpdate: () => context.pushNamed(
                RouteNames.updateServer,
                queryParameters: {'instanceId': instanceId},
              ),
              onDismiss: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _login(
    BuildContext context,
    Instance? instance,
    PocketCoderCredentials? credentials,
  ) {
    if (instance == null || credentials == null) return;
    context.pushNamed(
      RouteNames.onboardingLogin,
      extra: OnboardingPrefill(
        url: 'https://${instance.ipAddress.replaceAll('.', '-')}.sslip.io',
        email: credentials.adminEmail,
        password: credentials.adminPassword,
      ),
    );
  }
}

class _DetailsCredentials extends StatefulWidget {
  const _DetailsCredentials({
    required this.store,
    required this.instanceId,
    required this.builder,
  });

  final PocketCoderCredentialStore store;
  final String instanceId;
  final Widget Function(PocketCoderCredentials?) builder;

  @override
  State<_DetailsCredentials> createState() => _DetailsCredentialsState();
}

class _DetailsCredentialsState extends State<_DetailsCredentials> {
  late final Future<PocketCoderCredentials?> _credentials;

  @override
  void initState() {
    super.initState();
    _credentials = widget.store.get(widget.instanceId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PocketCoderCredentials?>(
        future: _credentials,
        builder: (context, snapshot) => widget.builder(snapshot.data),
      );
}

class _DetailsLifecycle extends StatefulWidget {
  const _DetailsLifecycle({required this.cubit, required this.child});
  final DeploymentCubit cubit;
  final Widget child;

  @override
  State<_DetailsLifecycle> createState() => _DetailsLifecycleState();
}

class _DetailsLifecycleState extends State<_DetailsLifecycle> {
  @override
  void dispose() {
    widget.cubit.cancelDeployment();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
