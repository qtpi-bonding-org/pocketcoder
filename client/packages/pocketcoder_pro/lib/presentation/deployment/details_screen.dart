import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
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
  InstanceCredentials? _credentials;
  bool _passwordVisible = false;
  // Captured in initState rather than re-read in dispose() -- by the time
  // dispose() runs the element tree may already be deactivated, and
  // context.read() on a deactivated element throws.
  late final DeploymentCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<DeploymentCubit>();
    // Cubit state is in-memory only. Hydrate the instance when Details is
    // opened from a restored/deep-linked instance ID.
    if (_cubit.state.instance?.id != widget.instanceId) {
      _cubit.loadInstance(widget.instanceId);
    }
    // Start periodic status refresh
    _cubit.refreshInstanceStatus(widget.instanceId);
    _loadCredentials();
  }

  @override
  void dispose() {
    // Stop periodic refresh when leaving
    _cubit.cancelDeployment();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final credentials = await GetIt.I<ISecureStorage>()
        .getInstanceCredentials(widget.instanceId);
    if (mounted) {
      setState(() => _credentials = credentials);
    }
  }

  void _handleLoginNow(Instance? instance) {
    final credentials = _credentials;
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
            if (_credentials != null)
              TerminalAction(
                label: 'LOG IN NOW',
                onTap: () => _handleLoginNow(instance),
              ),
            TerminalAction(
              label: 'REFRESH',
              onTap: () => cubit.refreshInstanceStatus(widget.instanceId),
            ),
            TerminalAction(
              label: 'UPDATE',
              onTap: () => context.pushNamed(
                RouteNames.updateServer,
                queryParameters: {'instanceId': widget.instanceId},
              ),
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
                            'HTTPS ENDPOINT',
                            'https://${instance.ipAddress.replaceAll('.', '-')}.sslip.io',
                            colors),
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
                        if (_credentials != null) ...[
                          VSpace.x1,
                          _buildPasswordRow('ADMIN PASSWORD',
                              _credentials!.adminPassword, colors),
                        ],
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
        HSpace.x2,
        Flexible(
          child: Text(
            value.toUpperCase(),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny,
              fontWeight: AppFonts.heavy,
            ),
          ),
        ),
      ],
    );
  }

  // Unlike _buildInfoRow's short fixed values (region, plan type, etc.),
  // a generated admin password is long enough to overflow a single
  // spaceBetween Row -- lay it out like _buildCopyableField instead:
  // label above, a full-width row below with the value wrapped in
  // Expanded/ellipsis so it can never blow out the layout regardless of
  // password length.
  Widget _buildPasswordRow(String label, String value, ColorScheme colors) {
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
        Row(
          children: [
            Expanded(
              child: Text(
                _passwordVisible ? value : '•' * value.length,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                ),
              ),
            ),
            IconButton(
              tooltip: _passwordVisible ? 'Hide $label' : 'Show $label',
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible ? Icons.visibility_off : Icons.visibility,
                color: colors.primary,
                size: 14,
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label COPIED TO BUFFER'),
                    backgroundColor: colors.primary,
                  ),
                );
              },
              icon: Icon(Icons.content_copy, color: colors.primary, size: 14),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
