import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_flutter/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/instance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:get_it/get_it.dart';

/// Details screen showing instance connection information
class DetailsScreen extends StatelessWidget {
  final String instanceId;

  const DetailsScreen({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<DeploymentCubit, DeploymentState>(
      mapper: GetIt.I<DeploymentMessageMapper>(),
      child: _DetailsView(instanceId: instanceId),
    );
  }
}

class _DetailsView extends StatefulWidget {
  final String instanceId;

  const _DetailsView({required this.instanceId});

  @override
  State<_DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<_DetailsView> {
  @override
  void initState() {
    super.initState();
    // Start periodic status refresh
    final cubit = context.read<DeploymentCubit>();
    cubit.refreshInstanceStatus(widget.instanceId);
  }

  @override
  void dispose() {
    // Stop periodic refresh when leaving
    context.read<DeploymentCubit>().cancelDeployment();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<DeploymentCubit>();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Instance Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => cubit.refreshInstanceStatus(widget.instanceId),
          ),
        ],
      ),
      body: BlocBuilder<DeploymentCubit, DeploymentState>(
        builder: (context, state) {
          final instance = state.instance;

          return SingleChildScrollView(
            padding: EdgeInsets.all(AppSizes.space * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                _buildStatusCard(instance),
                SizedBox(height: AppSizes.space * 3),
                // Connection details
                _buildSectionTitle('Connection Details'),
                if (instance != null) ...[
                  _buildCopyableRow(
                    'IP Address',
                    instance.ipAddress,
                    Icons.dns,
                  ),
                  SizedBox(height: AppSizes.space),
                  _buildCopyableRow(
                    'HTTPS URL',
                    instance.httpsUrl,
                    Icons.https,
                  ),
                ],
                SizedBox(height: AppSizes.space * 3),
                // Admin information
                _buildSectionTitle('Admin Information'),
                if (instance != null && instance.adminEmail != null) ...[
                  _buildInfoRow(
                    'Admin Email',
                    instance.adminEmail!,
                    Icons.email,
                  ),
                ],
                SizedBox(height: AppSizes.space),
                _buildInfoRow(
                  'Created',
                  instance?.created != null
                      ? _formatDateTime(instance!.created)
                      : 'Unknown',
                  Icons.calendar_today,
                ),
                SizedBox(height: AppSizes.space),
                _buildInfoRow(
                  'Region',
                  instance?.region ?? 'Unknown',
                  Icons.location_on,
                ),
                SizedBox(height: AppSizes.space),
                _buildInfoRow(
                  'Plan',
                  instance?.planType ?? 'Unknown',
                  Icons.dashboard,
                ),
                SizedBox(height: AppSizes.space * 4),
                // Security note
                Container(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: colors.primary,
                      ),
                      SizedBox(width: AppSizes.space),
                      Expanded(
                        child: Text(
                          'Your credentials are securely stored in the app\'s secure storage.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSizes.space * 2),
                // Note about passwords
                Container(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  decoration: BoxDecoration(
                    color: colors.tertiary.withValues(alpha: 0.1),
                    border: Border.all(color: colors.tertiary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colors.tertiary,
                      ),
                      SizedBox(width: AppSizes.space),
                      Expanded(
                        child: Text(
                          'Passwords are not displayed here for security reasons. They are stored securely and used automatically for authentication.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(Instance? instance) {
    final status = instance?.status ?? InstanceStatus.provisioning;
    Color statusColor;
    String statusText;

    switch (status) {
      case InstanceStatus.running:
        statusColor = Colors.green;
        statusText = 'Running';
        break;
      case InstanceStatus.offline:
        statusColor = Colors.red;
        statusText = 'Offline';
        break;
      case InstanceStatus.provisioning:
        statusColor = Colors.amber;
        statusText = 'Provisioning';
        break;
      case InstanceStatus.creating:
        statusColor = Colors.blue;
        statusText = 'Creating';
        break;
      case InstanceStatus.failed:
        statusColor = Colors.red;
        statusText = 'Failed';
        break;
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSizes.space),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (status == InstanceStatus.running)
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: statusColor,
                  size: 16,
                ),
                SizedBox(width: AppSizes.space),
                Text(
                  'Secure',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
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

  Widget _buildCopyableRow(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(
          color: context.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () => _copyToClipboard(value),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: context.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    // Use the clipboard API
    // This will be handled by the system
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}