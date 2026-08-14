import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

class McpManagementView extends StatelessWidget {
  const McpManagementView({
    required this.servers,
    required this.oauthProviders,
    required this.hasPendingDelivery,
    required this.onAuthorize,
    required this.onDeny,
    required this.onConnectOAuth,
    required this.onRetryOAuth,
    required this.onCreateServer,
    super.key,
  });

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
      title: context.l10n.mcpTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.mcpCapabilitiesRegistry,
        child: ListView(children: [
          Padding(
              padding: EdgeInsets.all(AppSizes.space),
              child: TerminalButton(
                  label: context.l10n.mcpAddNew,
                  onTap: () => _addDialog(context))),
          if (pending.isNotEmpty)
            BiosSection(
                title: context.l10n.mcpPendingApproval,
                child: Column(
                    children:
                        pending.map((s) => _server(context, s)).toList())),
          if (active.isNotEmpty)
            BiosSection(
                title: context.l10n.mcpActiveCapabilities,
                child: Column(
                    children: active.map((s) => _server(context, s)).toList())),
          if (servers.isEmpty)
            Center(
                child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 4),
                    child: TerminalText(context.l10n.mcpNoCapabilities,
                        alpha: .5))),
        ]),
      ),
    );
  }

  Widget _server(BuildContext context, McpServer server) {
    final colors = context.colorScheme;
    final pending = server.status == McpServerStatus.pending;
    final image = server.image;
    final reason = server.reason;
    return TerminalCard(
        isActive: pending,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TerminalText(server.name.toUpperCase(),
                weight: TerminalTextWeight.heavy),
            TerminalText(server.status.name.toUpperCase(),
                size: TerminalTextSize.tiny,
                weight: TerminalTextWeight.heavy,
                color: pending ? colors.primary : null,
                alpha: pending ? null : .7),
          ]),
          if (image?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(context.l10n.mcpImageLabel(image ?? ''),
                alpha: .5)
          ],
          if (reason?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(context.l10n.mcpPurposeLabel(reason ?? ''),
                alpha: .5)
          ],
          if (pending &&
              server.oauthProvider?.isEmpty != false &&
              server.configSchema is Map) ...[
            VSpace.x1,
            TerminalText.label(context.l10n.mcpRequiredConfig,
                color: colors.primary, alpha: .8),
            VSpace.x1,
            ...Map<String, dynamic>.from(server.configSchema as Map).keys.map(
                  (key) => Padding(
                    padding: EdgeInsets.only(left: AppSizes.space),
                    child: TerminalText.mini('• $key', alpha: .6),
                  ),
                ),
          ],
          if (server.oauthProvider?.isNotEmpty == true) ...[
            VSpace.x1,
            _oauth(context, server)
          ] else if (pending) ...[
            VSpace.x1,
            _buttons(context, server, authorize: true)
          ] else if (server.status == McpServerStatus.approved) ...[
            VSpace.x1,
            _buttons(context, server, authorize: true, edit: true)
          ],
        ]));
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
                TerminalText.mini(
                    context.l10n.mcpOauthRequiredLabel(
                        matched?.displayName ?? oauthProvider ?? ''),
                    color: context.colorScheme.primary,
                    alpha: .8),
                VSpace.x1,
                if (unsupported)
                  TerminalText.mini(
                      context.l10n.mcpOauthProviderNotConfiguredLabel(
                          oauthProvider ?? ''),
                      color: context.colorScheme.error,
                      alpha: .8)
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
                      TerminalButton(
                          label: context.l10n.mcpRevoke,
                          onTap: () => onDeny(server.id),
                          color: context.colorScheme.error)
                    ],
                  ]),
              ]);
        },
      );

  Widget _buttons(BuildContext context, McpServer server,
          {required bool authorize, bool edit = false}) =>
      Row(children: [
        Expanded(
            child: TerminalButton(
                label: edit
                    ? context.l10n.mcpEditConfig
                    : context.l10n.mcpAuthorizeCap,
                isPrimary: !edit,
                onTap: () => _configDialog(context, server))),
        HSpace.x2,
        TerminalButton(
            label: pendingLabel(context, server),
            onTap: () => onDeny(server.id),
            color: context.colorScheme.error),
      ]);

  String pendingLabel(BuildContext context, McpServer server) =>
      server.status == McpServerStatus.pending
          ? context.l10n.mcpDeny
          : context.l10n.mcpRevoke;

  void _configDialog(BuildContext context, McpServer server) {
    final controllers = <String, TextEditingController>{};
    final schema = server.configSchema is Map
        ? Map<String, dynamic>.from(server.configSchema as Map)
        : <String, dynamic>{};
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
          if (image?.isNotEmpty == true) TerminalText(image ?? '', alpha: .7),
          if (controllers.isEmpty)
            TerminalText(context.l10n.mcpNoConfigRequired, alpha: .7)
          else ...[
            TerminalText(context.l10n.mcpEnterSecrets, alpha: .7),
            ...controllers.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSizes.space),
                child: TerminalTextField(
                    controller: e.value,
                    label: e.key.toUpperCase(),
                    obscureText: false)))
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
              TerminalDialog(title: title, content: content, actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(cancel)),
                HSpace.x2,
                TextButton(
                    onPressed: () {
                      submit();
                      Navigator.pop(dialogContext);
                    },
                    child: Text(submitLabel))
              ]));
}

extension on McpServerStatus {
  bool get isPending => this == McpServerStatus.pending;
}

extension on Iterable<McpOAuthProvider> {
  McpOAuthProvider? get firstOrNull => isEmpty ? null : first;
}
