import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/whitelist/whitelist_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class WhitelistScreen extends StatelessWidget {
  const WhitelistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<WhitelistCubit>()..load(),
      child: UiFlowListener<WhitelistCubit, WhitelistState>(
        child: const WhitelistView(),
      ),
    );
  }
}

class WhitelistView extends StatefulWidget {
  const WhitelistView({super.key});

  @override
  State<WhitelistView> createState() => _WhitelistViewState();
}

class _WhitelistViewState extends State<WhitelistView> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 2),
            child: Column(
              children: [
                const TerminalHeader(title: 'GATEKEEPER CONFIGURATION'),
                VSpace.x2,
                Expanded(
                  child: BiosFrame(
                    title: _activeTab == 0 ? 'ACTION RULES' : 'TARGETS',
                    child: _activeTab == 0
                        ? const ActionsTab()
                        : const TargetsTab(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            label: 'ACTIONS',
            onTap: () => setState(() => _activeTab = 0),
          ),
          TerminalAction(
            label: 'TARGETS',
            onTap: () => setState(() => _activeTab = 1),
          ),
          TerminalAction(
            label: 'BACK',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

class ActionsTab extends StatelessWidget {
  const ActionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhitelistCubit, WhitelistState>(
      builder: (context, state) {
        final colors = context.colorScheme;
        return Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: TerminalLoadingIndicator(label: 'LOADING RULES'))
                  : state.actions.isEmpty
                      ? Center(
                          child: Text('NO RULES DEFINED.',
                              style: TextStyle(
                                  color:
                                      colors.onSurface.withValues(alpha: 0.5))))
                      : ListView.builder(
                          itemCount: state.actions.length,
                          itemBuilder: (context, index) {
                            final action = state.actions[index];
                            return _buildRuleTile(context, action);
                          },
                        ),
            ),
            VSpace.x2,
            TerminalButton(
              label: 'ADD NEW RULE',
              onTap: () => _showAddActionDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRuleTile(BuildContext context, dynamic action) {
    final colors = context.colorScheme;
    final textColor = action.active
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.5);

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
                  action.permission.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                Text(
                  '${action.kind}: ${action.value}',
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
            value: action.active,
            activeThumbColor: colors.onSurface,
            activeTrackColor: colors.onSurface.withValues(alpha: 0.2),
            onChanged: (val) =>
                context.read<WhitelistCubit>().toggleAction(action.id, val),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
            onPressed: () =>
                context.read<WhitelistCubit>().deleteAction(action.id),
          ),
        ],
      ),
    );
  }

  void _showAddActionDialog(BuildContext context) {
    final permissionController = TextEditingController();
    final valueController = TextEditingController();
    String kind = 'pattern';

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: 'ADD ACTION RULE',
        content: StatefulBuilder(builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTerminalTextField(
                  context: context,
                  controller: permissionController,
                  label: 'PERMISSION (e.g. bash.run)'),
              VSpace.x2,
              _buildTerminalTextField(
                  context: context,
                  controller: valueController,
                  label: 'VALUE (e.g. git *)'),
              VSpace.x2,
              Row(
                children: [
                  Text('KIND:',
                      style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: context.colorScheme.onSurface,
                          fontSize: AppSizes.fontTiny)),
                  HSpace.x2,
                  _buildKindOption(context, 'pattern', kind, (val) {
                    setState(() => kind = val);
                  }),
                  HSpace.x2,
                  _buildKindOption(context, 'strict', kind, (val) {
                    setState(() => kind = val);
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
              if (permissionController.text.isNotEmpty) {
                context.read<WhitelistCubit>().createAction(
                      permissionController.text,
                      kind: kind,
                      value: valueController.text,
                    );
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKindOption(BuildContext context, String value, String selected,
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

class TargetsTab extends StatelessWidget {
  const TargetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhitelistCubit, WhitelistState>(
      builder: (context, state) {
        final colors = context.colorScheme;
        return Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: TerminalLoadingIndicator(label: 'LOADING TARGETS'))
                  : state.targets.isEmpty
                      ? Center(
                          child: Text('NO TARGETS DEFINED.',
                              style: TextStyle(
                                  color:
                                      colors.onSurface.withValues(alpha: 0.5))))
                      : ListView.builder(
                          itemCount: state.targets.length,
                          itemBuilder: (context, index) {
                            final target = state.targets[index];
                            return _buildTargetTile(context, target);
                          },
                        ),
            ),
            VSpace.x2,
            TerminalButton(
              label: 'ADD NEW TARGET',
              onTap: () => _showAddTargetDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTargetTile(BuildContext context, dynamic target) {
    final colors = context.colorScheme;
    final textColor = colors.onSurface;

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
                  target.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
                Text(
                  target.pattern,
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: AppSizes.fontTiny,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
            onPressed: () =>
                context.read<WhitelistCubit>().deleteTarget(target.id),
          ),
        ],
      ),
    );
  }

  void _showAddTargetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final patternController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: 'ADD TARGET',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTerminalTextField(
                context: dialogContext,
                controller: nameController,
                label: 'NAME (e.g. GitHub)'),
            VSpace.x2,
            _buildTerminalTextField(
                context: dialogContext,
                controller: patternController,
                label: 'PATTERN (e.g. github.com/*)'),
          ],
        ),
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
              if (nameController.text.isNotEmpty &&
                  patternController.text.isNotEmpty) {
                context.read<WhitelistCubit>().createTarget(
                      nameController.text,
                      patternController.text,
                    );
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
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
