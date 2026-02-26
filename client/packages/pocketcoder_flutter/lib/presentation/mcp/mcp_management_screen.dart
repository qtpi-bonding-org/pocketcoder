import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class McpManagementScreen extends StatelessWidget {
  const McpManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<McpCubit>()..watchServers(),
      child: UiFlowListener<McpCubit, McpState>(
        child: const _McpManagementView(),
      ),
    );
  }
}

class _McpManagementView extends StatelessWidget {
  const _McpManagementView();

  @override
  Widget build(BuildContext context) {
    return TerminalScaffold(
      title: 'MCP MANAGEMENT',
      actions: [
        TerminalAction(
          label: 'BACK',
          onTap: () => context.pop(),
        ),
        TerminalAction(
          label: 'ADD NEW',
          onTap: () {}, // TODO: Implement add new MCP
        ),
      ],
      body: BiosFrame(
        title: 'CAPABILITIES REGISTRY',
        child: BlocBuilder<McpCubit, McpState>(
          builder: (context, state) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (servers) {
                final pending = servers
                    .where((s) => s.status == McpServerStatus.pending)
                    .toList();
                final active = servers
                    .where((s) => s.status != McpServerStatus.pending)
                    .toList();

                return ListView(
                  children: [
                    if (pending.isNotEmpty)
                      BiosSection(
                        title: 'PENDING APPROVAL',
                        child: Column(
                          children: pending
                              .map((s) => _buildMcpItem(context, s))
                              .toList(),
                        ),
                      ),
                    if (active.isNotEmpty)
                      BiosSection(
                        title: 'ACTIVE CAPABILITIES',
                        child: Column(
                          children: active
                              .map((s) => _buildMcpItem(context, s))
                              .toList(),
                        ),
                      ),
                    if (servers.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space * 4),
                          child: Text(
                            'NO CAPABILITIES REGISTERED',
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.5),
                              fontFamily: AppFonts.bodyFamily,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (msg) => Center(
                child: Text(
                  'ERROR: $msg',
                  style: TextStyle(color: colors.error),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMcpItem(BuildContext context, McpServer server) {
    final colors = context.colorScheme;
    final isPending = server.status == McpServerStatus.pending;

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPending
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.3),
        ),
        color: isPending ? colors.primary.withValues(alpha: 0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                server.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontWeight: AppFonts.heavy,
                ),
              ),
              Text(
                server.status.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: isPending
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.7),
                  fontSize: AppSizes.fontTiny,
                  fontWeight: AppFonts.heavy,
                ),
              ),
            ],
          ),
          if (server.image != null && server.image!.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'IMAGE: ${server.image}',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          if (server.reason != null && server.reason!.isNotEmpty) ...[
            VSpace.x1,
            Text(
              'PURPOSE: ${server.reason}',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          if (isPending && server.configSchema != null) ...[
            VSpace.x1,
            Text(
              'REQUIRED CONFIG:',
              style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: colors.primary.withValues(alpha: 0.8),
                fontSize: AppSizes.fontMini,
                fontWeight: AppFonts.heavy,
              ),
            ),
            VSpace.x1,
            ..._buildConfigSchemaList(context, server.configSchema),
          ],
          if (isPending) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showAuthorizeDialog(context, server),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('AUTHORIZE CAPABILITY'),
                  ),
                ),
                HSpace.x2,
                OutlinedButton(
                  onPressed: () => context.read<McpCubit>().deny(server.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text('DENY'),
                ),
              ],
            ),
          ] else if (server.status == McpServerStatus.approved) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showAuthorizeDialog(context, server),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface.withValues(alpha: 0.7),
                      side: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('EDIT CONFIGURATION'),
                  ),
                ),
                HSpace.x2,
                OutlinedButton(
                  onPressed: () => context.read<McpCubit>().deny(server.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error.withValues(alpha: 0.7),
                    side:
                        BorderSide(color: colors.error.withValues(alpha: 0.3)),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text('REVOKE'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildConfigSchemaList(
      BuildContext context, dynamic configSchema) {
    final colors = Theme.of(context).colorScheme;
    if (configSchema == null) return [];

    final Map<String, dynamic> schema;
    if (configSchema is Map) {
      schema = Map<String, dynamic>.from(configSchema);
    } else {
      return [];
    }

    return schema.entries.map((entry) {
      return Padding(
        padding: EdgeInsets.only(left: AppSizes.space),
        child: Text(
          '• ${entry.key}',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.6),
            fontSize: AppSizes.fontMini,
          ),
        ),
      );
    }).toList();
  }

  void _showAuthorizeDialog(BuildContext context, McpServer server) {
    final colors = Theme.of(context).colorScheme;
    final Map<String, TextEditingController> controllers = {};
    final Map<String, dynamic> schema = {};

    if (server.configSchema != null && server.configSchema is Map) {
      final Map<String, dynamic> configSchema =
          Map<String, dynamic>.from(server.configSchema);
      configSchema.forEach((key, value) {
        controllers[key] = TextEditingController();
        schema[key] = value;
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: server.status == McpServerStatus.pending
            ? 'AUTHORIZE: ${server.name.toUpperCase()}'
            : 'UPDATE CONFIG: ${server.name.toUpperCase()}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (server.image != null && server.image!.isNotEmpty) ...[
              Text(
                'IMAGE: ${server.image}',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: AppSizes.fontSmall,
                ),
              ),
              VSpace.x2,
            ],
            if (controllers.isEmpty) ...[
              Text(
                'No configuration required.',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: AppSizes.fontStandard,
                ),
              ),
            ] else ...[
              Text(
                'Enter required secrets:',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontSize: AppSizes.fontStandard,
                ),
              ),
              VSpace.x2,
              ...controllers.entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSizes.space),
                  child: TerminalTextField(
                    controller: entry.value,
                    label: entry.key.toUpperCase(),
                    obscureText: true,
                  ),
                );
              }),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('CANCEL'),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final config = <String, dynamic>{};
              controllers.forEach((key, controller) {
                if (controller.text.isNotEmpty) {
                  config[key] = controller.text;
                }
              });
              context.read<McpCubit>().authorize(server.id,
                  config: config.isNotEmpty ? config : null);
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('AUTHORIZE'),
          ),
        ],
      ),
    );
  }
}
