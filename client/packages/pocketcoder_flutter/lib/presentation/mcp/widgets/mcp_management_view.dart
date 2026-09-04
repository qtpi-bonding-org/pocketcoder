import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

class McpManagementView extends StatelessWidget {
  const McpManagementView(
      {required this.servers,
      required this.oauthProviders,
      required this.hasPendingDelivery,
      required this.onAuthorize,
      required this.onDeny,
      required this.onConnectOAuth,
      required this.onRetryOAuth,
      required this.onCreateServer,
      super.key});

  final List<McpServer> servers;
  final Future<List<McpOAuthProvider>> oauthProviders;
  final bool Function(String id) hasPendingDelivery;
  final void Function(String id, Map<String, dynamic>? config) onAuthorize;
  final void Function(String id) onDeny;
  final void Function(McpServer server) onConnectOAuth;
  final void Function(String id) onRetryOAuth;
  final void Function(
      {required String name,
      String? image,
      String? oauthProvider,
      String? oauthTokenEnvVar}) onCreateServer;

  @override
  Widget build(BuildContext context) {
    final pending =
        servers.where((s) => s.status == McpServerStatus.pending).toList();
    final active =
        servers.where((s) => s.status != McpServerStatus.pending).toList();
    return PocketCoderShell(
        title: context.l10n.mcpTitle.toLowerCase(),
        activePillar: NavPillar.configure,
        showBack: true,
        body: DecisionFrame(
            title: context.l10n.mcpCapabilitiesRegistry.toLowerCase(),
            child: ListView(children: [
              Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: TerminalButton(
                      label: context.l10n.mcpAddNew,
                      onTap: () => _addDialog(context))),
              if (pending.isNotEmpty) ...[
                SectionHeader(
                    name: context.l10n.mcpPendingApproval.toLowerCase()),
                Column(
                    children: pending.map((s) => _server(context, s)).toList()),
              ],
              if (active.isNotEmpty) ...[
                SectionHeader(
                    name: context.l10n.mcpActiveCapabilities.toLowerCase()),
                Column(
                    children: active.map((s) => _server(context, s)).toList()),
              ],
              if (servers.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 4),
                    child: TerminalText(
                      context.l10n.mcpNoCapabilities,
                      role: TextRole.body,
                    ),
                  ),
                ),
            ])));
  }

  Widget _server(BuildContext context, McpServer server) {
    final pending = server.status == McpServerStatus.pending;
    final schema = _resolveConfigSchema(server);
    final image = server.image;
    final reason = server.reason;
    final footer = server.oauthProvider?.isNotEmpty == true
        ? null
        : pending
            ? BiosActionStrip(actions: [
                BiosActionStripItem(
                    label: context.l10n.mcpAuthorizeCap,
                    isActive: true,
                    onTap: () => _configDialog(context, server)),
                BiosActionStripItem(
                    label: context.l10n.mcpDeny,
                    color: context.terminalColors.warning,
                    onTap: () => onDeny(server.id)),
              ])
            : server.status == McpServerStatus.approved
                ? BiosActionStrip(actions: [
                    BiosActionStripItem(
                        label: context.l10n.mcpEditConfig,
                        onTap: () => _configDialog(context, server)),
                    BiosActionStripItem(
                        label: context.l10n.mcpRevoke,
                        color: context.terminalColors.danger,
                        onTap: () => onDeny(server.id)),
                  ])
                : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
          label: server.name, value: server.status.name, warning: pending),
      VSpace.x1,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image?.isNotEmpty == true) ...[
          TerminalText(
            context.l10n.mcpImageLabel(image ?? ''),
            role: TextRole.body,
          ),
          VSpace.x1,
        ],
        if (reason?.isNotEmpty == true) ...[
          TerminalText(
            context.l10n.mcpPurposeLabel(reason ?? ''),
            role: TextRole.body,
          ),
          VSpace.x1,
        ],
        if (pending &&
            server.oauthProvider?.isEmpty != false &&
            server.configSchema is Map) ...[
          TerminalText(
            context.l10n.mcpRequiredConfig,
            role: TextRole.label,
          ),
          VSpace.x1,
          for (final key in schema.keys) DetailRow(label: key, value: null),
        ],
        if (server.oauthProvider?.isNotEmpty == true) _oauth(context, server),
      ]),
      if (footer != null) ...[VSpace.x1, footer],
      VSpace.x2,
    ]);
  }

  Widget _oauth(BuildContext context, McpServer server) =>
      FutureBuilder<List<McpOAuthProvider>>(
          future: oauthProviders,
          builder: (context, snapshot) {
            final matched = (snapshot.data ?? const <McpOAuthProvider>[])
                .where((p) => p.id == server.oauthProvider)
                .firstOrNull;
            final oauthProvider = server.oauthProvider;
            final unsupported =
                snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null &&
                    matched == null;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalText(
                    context.l10n.mcpOauthRequiredLabel(
                        matched?.displayName ?? oauthProvider ?? ''),
                    role: TextRole.body,
                  ),
                  VSpace.x1,
                  if (unsupported)
                    TerminalText(
                        context.l10n.mcpOauthProviderNotConfiguredLabel(
                            oauthProvider ?? ''),
                        role: TextRole.warn)
                  else
                    Row(children: [
                      Expanded(
                          child: TerminalButton(
                              label: hasPendingDelivery(server.id)
                                  ? context.l10n.mcpRetryDeliveryCap
                                  : context.l10n.mcpConnectCap,
                              onTap: () => hasPendingDelivery(server.id)
                                  ? onRetryOAuth(server.id)
                                  : onConnectOAuth(server))),
                      if (!server.status.isPending) ...[
                        HSpace.x2,
                        Expanded(
                            child: TerminalButton(
                                label: context.l10n.mcpRevoke,
                                color: context.terminalColors.danger,
                                onTap: () => onDeny(server.id))),
                      ],
                    ]),
                ]);
          });

  void _configDialog(BuildContext context, McpServer server) {
    final controllers = <String, TextEditingController>{};
    final schema = _resolveConfigSchema(server);
    final existing = server.config is Map
        ? Map<String, dynamic>.from(server.config as Map)
        : <String, dynamic>{};
    for (final key in schema.keys) {
      controllers[key] =
          TextEditingController(text: existing[key]?.toString() ?? '');
    }
    final image = server.image;
    _show(
        context,
        server.status == McpServerStatus.pending
            ? context.l10n.mcpAuthorizeDialogTitle(server.name.toUpperCase())
            : context.l10n
                .mcpUpdateConfigDialogTitle(server.name.toUpperCase()),
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (image?.isNotEmpty == true)
            TerminalText(image ?? '', role: TextRole.body),
          if (controllers.isEmpty)
            TerminalText(context.l10n.mcpNoConfigRequired, role: TextRole.body),
          if (controllers.isNotEmpty) ...[
            TerminalText(context.l10n.mcpEnterSecrets, role: TextRole.body),
            ...controllers.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSizes.space),
                child: TerminalTextField(
                    controller: e.value,
                    label: e.key.toUpperCase(),
                    obscureText: false))),
          ],
        ]),
        context.l10n.actionCancel,
        server.status == McpServerStatus.pending
            ? context.l10n.mcpAuthorize
            : context.l10n.mcpEditConfig, () {
      final config = <String, dynamic>{};
      for (final e in controllers.entries) {
        if (e.value.text.isNotEmpty) config[e.key] = e.value.text;
      }
      onAuthorize(server.id, config.isEmpty ? null : config);
    });
  }

  void _addDialog(BuildContext context) {
    final n = TextEditingController(),
        i = TextEditingController(),
        p = TextEditingController(),
        t = TextEditingController();
    _show(
        context,
        context.l10n.mcpAddDialogTitle,
        Column(mainAxisSize: MainAxisSize.min, children: [
          TerminalTextField(
              controller: n,
              label: context.l10n.mcpServerNameLabel,
              obscureText: false),
          VSpace.x2,
          TerminalTextField(
              controller: i,
              label: context.l10n.mcpImageOptionalLabel,
              obscureText: false),
          VSpace.x2,
          TerminalTextField(
              controller: p,
              label: context.l10n.mcpOauthProviderOptionalLabel,
              obscureText: false),
          VSpace.x2,
          TerminalTextField(
              controller: t,
              label: context.l10n.mcpOauthTokenEnvVarOptionalLabel,
              obscureText: false),
        ]),
        context.l10n.actionCancel,
        context.l10n.actionAdd, () {
      if (n.text.trim().isNotEmpty) {
        onCreateServer(
            name: n.text.trim(),
            image: i.text.trim().isEmpty ? null : i.text.trim(),
            oauthProvider: p.text.trim().isEmpty ? null : p.text.trim(),
            oauthTokenEnvVar: t.text.trim().isEmpty ? null : t.text.trim());
      }
    });
  }

  void _show(BuildContext context, String title, Widget content, String cancel,
          String submitLabel, VoidCallback submit) =>
      showDialog<void>(
          context: context,
          builder: (dialogContext) =>
              TerminalDialog(title: title.toLowerCase(), content: content, actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(cancel)),
                HSpace.x2,
                TextButton(
                    onPressed: () {
                      submit();
                      Navigator.pop(dialogContext);
                    },
                    child: Text(submitLabel)),
              ]));
}

Map<String, dynamic> _resolveConfigSchema(McpServer server) =>
    server.configSchema is Map
        ? Map<String, dynamic>.from(server.configSchema as Map)
        : <String, dynamic>{};

extension on McpServerStatus {
  bool get isPending => this == McpServerStatus.pending;
}

extension on Iterable<McpOAuthProvider> {
  McpOAuthProvider? get firstOrNull => isEmpty ? null : first;
}
