import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_aeroform/application/deployment/deployment_cubit.dart';
import 'package:flutter_aeroform/application/deployment/deployment_message_mapper.dart';
import 'package:flutter_aeroform/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
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

    return BlocBuilder<DeploymentCubit, DeploymentState>(
      builder: (context, state) {
        final instance = state.instance;

        return TerminalScaffold(
          title: 'INSTANCE MANIFEST',
          actions: [
            TerminalAction(
              label: 'REFRESH',
              onTap: () => cubit.refreshInstanceStatus(widget.instanceId),
            ),
            TerminalAction(
              label: 'DISMISS',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Column(
              children: [
                _buildStatusBanner(instance, colors),
                VSpace.x2,
                BiosFrame(
                  title: 'CONNECTION PARAMETERS',
                  child: Column(
                    children: [
                      if (instance != null) ...[
                        _buildCopyableField(
                            'IP ADDRESS', instance.ipAddress, colors),
                        VSpace.x2,
                        _buildCopyableField(
                            'HTTPS ENDPOINT', instance.httpsUrl, colors),
                      ],
                    ],
                  ),
                ),
                VSpace.x2,
                BiosFrame(
                  title: 'METADATA REGISTRY',
                  child: Column(
                    children: [
                      if (instance != null) ...[
                        _buildInfoRow('ADMIN IDENTITY',
                            instance.adminEmail ?? 'N/A', colors),
                        VSpace.x1,
                        _buildInfoRow(
                          'PROVISIONED',
                          _formatDateTime(instance.created),
                          colors,
                        ),
                        VSpace.x1,
                        _buildInfoRow('CLOUD REGION',
                            instance.region.toUpperCase(), colors),
                        VSpace.x1,
                        _buildInfoRow('HARDWARE PLAN',
                            instance.planType.toUpperCase(), colors),
                      ],
                    ],
                  ),
                ),
                VSpace.x3,
                Container(
                  padding: EdgeInsets.all(AppSizes.space),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: colors.primary, size: 16),
                      HSpace.x2,
                      Expanded(
                        child: Text(
                          'SECURITY NOTICE: CREDENTIALS ARE STORED IN LOCAL SECURE ENCLAVE. PASSPHRASE RETAINS ENCRYPTION AT REST.',
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontSize: AppSizes.fontTiny,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(Instance? instance, ColorScheme colors) {
    final status = instance?.status ?? InstanceStatus.provisioning;
    final color = _getStatusColor(status, colors);
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          HSpace.x2,
          Text(
            'STATUS: ${status.name.toUpperCase()}',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: color,
              fontWeight: AppFonts.heavy,
              fontSize: AppSizes.fontStandard,
            ),
          ),
          const Spacer(),
          if (status == InstanceStatus.running)
            Text(
              '[SECURE]',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: color,
                fontSize: AppSizes.fontTiny,
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(InstanceStatus status, ColorScheme colors) {
    switch (status) {
      case InstanceStatus.running:
        return Colors.green;
      case InstanceStatus.offline:
      case InstanceStatus.failed:
        return colors.error;
      case InstanceStatus.provisioning:
      case InstanceStatus.creating:
        return Colors.amber;
    }
  }

  Widget _buildCopyableField(String label, String value, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
          ),
        ),
        VSpace.x1,
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label COPIED TO BUFFER'),
                backgroundColor: colors.primary,
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border:
                  Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                ),
                Icon(Icons.content_copy, color: colors.primary, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
          ),
        ),
        Text(
          value.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
