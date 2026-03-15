import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class ToolPermissionsScreen extends StatelessWidget {
  const ToolPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ToolPermissionsCubit>()..load(),
      child: UiFlowListener<ToolPermissionsCubit, ToolPermissionsState>(
        child: const ToolPermissionsView(),
      ),
    );
  }
}

class ToolPermissionsView extends StatelessWidget {
  const ToolPermissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: 'GATEKEEPER CONFIGURATION',
      activePillar: NavPillar.configure,
      showBack: true,
      body: const BiosFrame(
        title: 'TOOL PERMISSIONS',
        child: PermissionsTab(),
      ),
    );
  }
}

class PermissionsTab extends StatelessWidget {
  const PermissionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ToolPermissionsCubit, ToolPermissionsState>(
      builder: (context, state) {
        final colors = context.colorScheme;
        return Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: TerminalLoadingIndicator(label: 'LOADING PERMISSIONS'))
                  : state.toolPermissions.isEmpty
                      ? Center(
                          child: Text('NO PERMISSIONS DEFINED.',
                              style: TextStyle(
                                  color:
                                      colors.onSurface.withValues(alpha: 0.5))))
                      : ListView.builder(
                          itemCount: state.toolPermissions.length,
                          itemBuilder: (context, index) {
                            final perm = state.toolPermissions[index];
                            return _buildPermTile(context, perm);
                          },
                        ),
            ),
            VSpace.x2,
            TerminalButton(
              label: 'ADD PERMISSION',
              onTap: () => _showAddPermissionDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermTile(BuildContext context, ToolPermission perm) {
    final colors = context.colorScheme;
    final isActive = perm.active ?? true;
    final textColor = isActive
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.5);

    final scope = perm.agent?.isNotEmpty == true
        ? 'AGENT'
        : 'GLOBAL';

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perm.tool.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                Text(
                  '$scope | pattern: ${perm.pattern} | ${perm.action.name}',
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontTiny,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            activeThumbColor: colors.onSurface,
            activeTrackColor: colors.onSurface.withValues(alpha: 0.2),
            onChanged: (val) =>
                context.read<ToolPermissionsCubit>().toggleToolPermission(perm.id, val),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
            onPressed: () =>
                context.read<ToolPermissionsCubit>().deleteToolPermission(perm.id),
          ),
        ],
      ),
    );
  }

  void _showAddPermissionDialog(BuildContext context) {
    final toolController = TextEditingController();
    final patternController = TextEditingController(text: '*');
    String action = 'ask';

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: 'ADD TOOL PERMISSION',
        content: StatefulBuilder(builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTerminalTextField(
                  context: context,
                  controller: toolController,
                  label: 'TOOL (e.g. bash, edit, cao_*)'),
              VSpace.x2,
              _buildTerminalTextField(
                  context: context,
                  controller: patternController,
                  label: 'PATTERN (e.g. *, git *, rm *)'),
              VSpace.x2,
              Row(
                children: [
                  Text('ACTION:',
                      style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: context.colorScheme.onSurface,
                          fontSize: AppSizes.fontTiny)),
                  HSpace.x2,
                  _buildActionOption(context, 'allow', action, (val) {
                    setState(() => action = val);
                  }),
                  HSpace.x2,
                  _buildActionOption(context, 'ask', action, (val) {
                    setState(() => action = val);
                  }),
                  HSpace.x2,
                  _buildActionOption(context, 'deny', action, (val) {
                    setState(() => action = val);
                  }),
                ],
              ),
            ],
          );
        }),
        actions: [
          TerminalButton(
            label: 'CANCEL',
            isPrimary: false,
            onTap: () => Navigator.pop(dialogContext),
          ),
          HSpace.x2,
          TerminalButton(
            label: 'CREATE',
            onTap: () {
              if (toolController.text.isNotEmpty) {
                context.read<ToolPermissionsCubit>().createToolPermission(
                      tool: toolController.text,
                      pattern: patternController.text.isEmpty
                          ? '*'
                          : patternController.text,
                      action: action,
                    );
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionOption(BuildContext context, String value, String selected,
      Function(String) onChanged) {
    final colors = context.colorScheme;
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Text(
        '[ ${value.toUpperCase()} ]',
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: isSelected
              ? colors.onSurface
              : colors.onSurface.withValues(alpha: 0.5),
          fontSize: AppSizes.fontTiny,
          fontWeight: isSelected ? AppFonts.heavy : AppFonts.medium,
        ),
      ),
    );
  }
}

Widget _buildTerminalTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
}) {
  final colors = context.colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: colors.onSurface,
          fontSize: AppSizes.fontTiny,
        ),
      ),
      VSpace.x1,
      TextField(
        controller: controller,
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: colors.onSurface,
          fontSize: AppSizes.fontSmall,
        ),
        cursorColor: colors.onSurface,
        decoration: const InputDecoration(),
      ),
    ],
  );
}
