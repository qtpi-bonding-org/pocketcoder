import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';

class DetailsView extends StatefulWidget {
  const DetailsView({
    super.key,
    required this.instance,
    required this.credentials,
    required this.onRefresh,
    required this.onLogin,
    required this.onUpdate,
    required this.onDismiss,
  });

  final Instance? instance;
  final PocketCoderCredentials? credentials;
  final VoidCallback onRefresh;
  final VoidCallback onLogin;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final instance = widget.instance;
    return TerminalScaffold(
      title: 'INSTANCE MANIFEST',
      actions: [
        if (widget.credentials != null)
          TerminalAction(label: 'LOG IN NOW', onTap: widget.onLogin),
        TerminalAction(label: 'REFRESH', onTap: widget.onRefresh),
        TerminalAction(label: 'UPDATE', onTap: widget.onUpdate),
        TerminalAction(label: 'DISMISS', onTap: widget.onDismiss),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Column(children: [
          _statusBanner(instance, colors),
          VSpace.x2,
          _outputSection(
            title: 'CONNECTION PARAMETERS',
            child: Column(children: [
              if (instance != null) ...[
                _copyableField('IP ADDRESS', instance.ipAddress, colors),
                VSpace.x2,
                _copyableField(
                    'HTTPS ENDPOINT',
                    'https://${instance.ipAddress.replaceAll('.', '-')}.sslip.io',
                    colors),
              ],
            ]),
          ),
          VSpace.x2,
          _outputSection(
            title: 'METADATA REGISTRY',
            child: Column(children: [
              if (instance != null) ...[
                _infoRow('ADMIN IDENTITY',
                    widget.credentials?.adminEmail ?? 'N/A', colors),
                if (widget.credentials != null) ...[
                  VSpace.x1,
                  _passwordRow('ADMIN PASSWORD',
                      widget.credentials!.adminPassword, colors),
                ],
                VSpace.x1,
                _infoRow(
                    'PROVISIONED', _formatDateTime(instance.created), colors),
                VSpace.x1,
                _infoRow('CLOUD REGION', instance.region.toUpperCase(), colors),
                VSpace.x1,
                _infoRow(
                    'HARDWARE PLAN', instance.planType.toUpperCase(), colors),
              ],
            ]),
          ),
          VSpace.x3,
          Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
                border:
                    Border.all(color: colors.primary.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.security, color: colors.primary, size: 16),
              HSpace.x2,
              Expanded(
                  child: Text(
                'SECURITY NOTICE: CREDENTIALS ARE STORED IN LOCAL SECURE ENCLAVE. PASSPHRASE RETAINS ENCRYPTION AT REST.',
                style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontTiny),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _outputSection({required String title, required Widget child}) {
    final colors = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: colors.primary.withValues(alpha: 0.25),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText.label(title),
          VSpace.x2,
          child,
        ],
      ),
    );
  }

  Widget _statusBanner(Instance? instance, ColorScheme colors) {
    final status = instance?.status ?? InstanceStatus.provisioning;
    final color = switch (status) {
      InstanceStatus.running => Colors.green,
      InstanceStatus.offline || InstanceStatus.failed => colors.error,
      InstanceStatus.provisioning || InstanceStatus.creating => Colors.amber,
    };
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color)),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        HSpace.x2,
        Text('STATUS: ${status.name.toUpperCase()}',
            style: TextStyle(
                fontFamily: AppFonts.bodyFamily,
                color: color,
                fontWeight: AppFonts.heavy,
                fontSize: AppSizes.fontStandard)),
        const Spacer(),
        if (status == InstanceStatus.running)
          Text('[SECURE]',
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: color,
                  fontSize: AppSizes.fontTiny)),
      ]),
    );
  }

  Widget _copyableField(String label, String value, ColorScheme colors) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: AppSizes.fontTiny)),
          VSpace.x1,
          InkWell(
            onTap: () => _copy(label, value, colors),
            child: Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.1))),
              child: Row(children: [
                Expanded(
                    child: Text(value,
                        style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface,
                            fontSize: AppSizes.fontSmall))),
                Icon(Icons.content_copy, color: colors.primary, size: 16),
              ]),
            ),
          ),
        ],
      );

  Widget _infoRow(String label, String value, ColorScheme colors) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: AppSizes.fontTiny)),
          HSpace.x2,
          Flexible(
              child: Text(value.toUpperCase(),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontSize: AppSizes.fontTiny,
                      fontWeight: AppFonts.heavy))),
        ],
      );

  Widget _passwordRow(String label, String value, ColorScheme colors) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: AppSizes.fontTiny)),
          VSpace.x1,
          Row(children: [
            Expanded(
                child: Text(_passwordVisible ? value : '•' * value.length,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: colors.onSurface,
                        fontSize: AppSizes.fontTiny,
                        fontWeight: AppFonts.heavy))),
            IconButton(
                tooltip: _passwordVisible ? 'Hide $label' : 'Show $label',
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                    color: colors.primary,
                    size: 14),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero),
            IconButton(
                tooltip: 'Copy $label',
                onPressed: () => _copy(label, value, colors),
                icon: Icon(Icons.content_copy, color: colors.primary, size: 14),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero),
          ]),
        ],
      );

  void _copy(String label, String value, ColorScheme colors) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label COPIED TO BUFFER'),
        backgroundColor: colors.primary));
  }

  String _formatDateTime(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
