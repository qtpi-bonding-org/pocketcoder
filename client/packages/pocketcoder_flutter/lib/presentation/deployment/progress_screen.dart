import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_result.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Progress screen showing deployment status
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<DeploymentCubit, DeploymentState>(
      mapper: GetIt.I<DeploymentMessageMapper>(),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatefulWidget {
  const _ProgressView();

  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  @override
  void initState() {
    super.initState();
    // Start monitoring deployment if not already started
    final cubit = context.read<DeploymentCubit>();
    final state = cubit.state;
    if (state.instanceId != null && !cubit.isMonitoring) {
      cubit.monitorDeployment(state.instanceId!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<DeploymentCubit>();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Deploying Instance'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            cubit.cancelDeployment();
            context.pop();
          },
        ),
      ),
      body: BlocListener<DeploymentCubit, DeploymentState>(
        listener: (context, state) {
          // Navigate to DetailsScreen on deployment completion
          if (state.status == UiFlowStatus.success &&
              state.deploymentStatus == DeploymentStatus.ready &&
              state.instance != null) {
            context.pushNamed(
              RouteNames.deploymentDetails,
              queryParameters: {'instanceId': state.instance!.id},
            );
          }
        },
        child: BlocBuilder<DeploymentCubit, DeploymentState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Main content
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Status icon
                        _buildStatusIcon(state.deploymentStatus),
                        SizedBox(height: AppSizes.space * 3),
                        // Status text
                        _buildStatusText(state.deploymentStatus),
                        SizedBox(height: AppSizes.space * 2),
                        // Polling attempt counter
                        if (state.pollingAttempts > 0)
                          Text(
                            'Attempt ${state.pollingAttempts} of 20',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        SizedBox(height: AppSizes.space * 3),
                        // Progress indicator
                        if (state.status == UiFlowStatus.loading)
                          LinearProgressIndicator(
                            minHeight: 4,
                            value: _getProgressValue(state.pollingAttempts),
                          ),
                        SizedBox(height: AppSizes.space * 4),
                        // Instance info
                        if (state.instance != null) ...[
                          _buildInfoRow(
                            'IP Address',
                            state.instance!.ipAddress,
                          ),
                          SizedBox(height: AppSizes.space),
                          _buildInfoRow(
                            'Region',
                            state.instance!.region,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Loading overlay
                if (state.status == UiFlowStatus.loading) ...[
                  Container(
                    color: colors.surface.withValues(alpha: 0.9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: AppSizes.space * 2),
                          Text(
                            _getLoadingMessage(state.deploymentStatus),
                            style: context.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Error and retry
                if (state.status == UiFlowStatus.failure) ...[
                  _buildErrorOverlay(state.error.toString()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusIcon(DeploymentStatus? status) {
    IconData icon;
    Color color;

    switch (status) {
      case DeploymentStatus.creating:
        icon = Icons.cloud_queue;
        color = context.colorScheme.primary;
        break;
      case DeploymentStatus.provisioning:
        icon = Icons.settings;
        color = Colors.amber;
        break;
      case DeploymentStatus.ready:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DeploymentStatus.failed:
        icon = Icons.error;
        color = context.colorScheme.error;
        break;
      case null:
        icon = Icons.hourglass_empty;
        color = context.colorScheme.onSurface.withValues(alpha: 0.5);
        break;
    }

    return Icon(
      icon,
      size: 80,
      color: color,
    );
  }

  Widget _buildStatusText(DeploymentStatus? status) {
    String text;
    TextStyle style;

    switch (status) {
      case DeploymentStatus.creating:
        text = 'Creating your instance...';
        style = context.textTheme.headlineSmall!;
        break;
      case DeploymentStatus.provisioning:
        text = 'Provisioning your instance...\nThis may take a few minutes';
        style = context.textTheme.headlineSmall!;
        break;
      case DeploymentStatus.ready:
        text = 'Instance ready!';
        style = context.textTheme.headlineSmall!.copyWith(
          color: Colors.green,
        );
        break;
      case DeploymentStatus.failed:
        text = 'Deployment failed';
        style = context.textTheme.headlineSmall!.copyWith(
          color: context.colorScheme.error,
        );
        break;
      case null:
        text = 'Preparing deployment...';
        style = context.textTheme.headlineSmall!;
        break;
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: style,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay(String error) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(AppSizes.space * 2),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer,
          border: Border(
            top: BorderSide(
              color: context.colorScheme.error,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: context.colorScheme.error,
                ),
                SizedBox(width: AppSizes.space),
                Expanded(
                  child: Text(
                    'Deployment failed',
                    style: TextStyle(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.space),
            Text(
              error,
              style: TextStyle(
                color: context.colorScheme.onErrorContainer,
              ),
            ),
            SizedBox(height: AppSizes.space * 2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: AppSizes.space),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final state = context.read<DeploymentCubit>().state;
                      if (state.instanceId != null) {
                        context
                            .read<DeploymentCubit>()
                            .monitorDeployment(state.instanceId!);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _getProgressValue(int attempts) {
    // Exponential progress: 0.05, 0.1, 0.2, 0.4, 0.8, 1.0
    if (attempts >= 5) return 1.0;
    return (1 << (attempts - 1)) / 32;
  }

  String _getLoadingMessage(DeploymentStatus? status) {
    switch (status) {
      case DeploymentStatus.creating:
        return 'Creating your Linode instance...';
      case DeploymentStatus.provisioning:
        return 'Running cloud-init configuration...';
      case DeploymentStatus.ready:
        return 'Instance is ready!';
      case DeploymentStatus.failed:
        return 'Deployment failed';
      case null:
        return 'Preparing deployment...';
    }
  }
}