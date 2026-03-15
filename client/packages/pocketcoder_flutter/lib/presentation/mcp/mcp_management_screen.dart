import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
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
    return PocketCoderShell(
      title: 'MCP MANAGEMENT',
      activePillar: NavPillar.configure,
      showBack: true,
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
                    // Inline ADD NEW button
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: 'ADD NEW',
                        onTap: () {}, // TODO: Implement add new MCP
                      ),
                    ),
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
                          child: TerminalText(
                            'NO CAPABILITIES REGISTERED',
                            alpha: 0.5,
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

    return TerminalCard(
      isActive: isPending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TerminalText(
                server.name.toUpperCase(),
                weight: TerminalTextWeight.heavy,
              ),
              TerminalText(
                server.status.name.toUpperCase(),
                size: TerminalTextSize.tiny,
                weight: TerminalTextWeight.heavy,
                color: isPending ? colors.primary : null,
                alpha: isPending ? null : 0.7,
              ),
            ],
          ),
          if (server.image?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(
              'IMAGE: ${server.image}',
              alpha: 0.5,
            ),
          ],
          if (server.reason?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(
              'PURPOSE: ${server.reason}',
              alpha: 0.5,
            ),
          ],
          if (isPending && server.configSchema != null) ...[
            VSpace.x1,
            TerminalText.label(
              'REQUIRED CONFIG:',
              color: colors.primary,
              alpha: 0.8,
            ),
            VSpace.x1,
            ..._buildConfigSchemaList(context, server.configSchema),
          ],
          if (isPending) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: 'AUTHORIZE CAPABILITY',
                    onTap: () => _showAuthorizeDialog(context, server),
                  ),
                ),
                HSpace.x2,
                TerminalButton(
                  label: 'DENY',
                  onTap: () => context.read<McpCubit>().deny(server.id),
                  color: colors.error,
                ),
              ],
            ),
          ] else if (server.status == McpServerStatus.approved) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: 'EDIT CONFIGURATION',
                    isPrimary: false,
                    onTap: () => _showAuthorizeDialog(context, server),
                  ),
                ),
                HSpace.x2,
                TerminalButton(
                  label: 'REVOKE',
                  onTap: () => context.read<McpCubit>().deny(server.id),
                  color: colors.error,
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
        child: TerminalText.mini(
          '• ${entry.key}',
          alpha: 0.6,
        ),
      );
    }).toList();
  }

  void _showAuthorizeDialog(BuildContext context, McpServer server) {
    final colors = Theme.of(context).colorScheme;
    final Map<String, TextEditingController> controllers = {};
    final Map<String, dynamic> schema = {};

    Map<String, dynamic>? existingConfig;
    if (server.config != null && server.config is Map) {
      existingConfig = Map<String, dynamic>.from(server.config);
    }

    if (server.configSchema != null && server.configSchema is Map) {
      final Map<String, dynamic> configSchema =
          Map<String, dynamic>.from(server.configSchema);
      configSchema.forEach((key, value) {
        controllers[key] =
            TextEditingController(text: existingConfig?[key]?.toString() ?? '');
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
            if (server.image?.isNotEmpty == true) ...[
              TerminalText(
                'IMAGE: ${server.image}',
                alpha: 0.7,
              ),
              VSpace.x2,
            ],
            if (controllers.isEmpty) ...[
              TerminalText(
                'No configuration required.',
                size: TerminalTextSize.base,
                alpha: 0.7,
              ),
            ] else ...[
              TerminalText(
                'Enter required secrets:',
                size: TerminalTextSize.base,
                alpha: 0.7,
              ),
              VSpace.x2,
              ...controllers.entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSizes.space),
                  child: TerminalTextField(
                    controller: entry.value,
                    label: entry.key.toUpperCase(),
                    obscureText: false,
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
