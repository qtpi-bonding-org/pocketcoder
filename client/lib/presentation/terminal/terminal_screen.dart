import 'package:flutter/material.dart';
import 'package:test_app/app/bootstrap.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/terminal_footer.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/terminal_input.dart';
import 'package:test_app/application/system/system_status_cubit.dart';
import 'package:test_app/application/system/system_status_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<String> _logs = [
    'SYSTEM INITIALIZED',
    'GATEKEEPER ACTIVE',
    'WAITING FOR INPUT...',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('>> $message');
      if (_logs.length > 20) _logs.removeAt(0);
    });
  }

  Future<void> _handleInputSubmit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    _addLog('% $input');
    _inputController.clear();

    if (input.toUpperCase().startsWith('LOGIN')) {
      final parts = input.trim().split(' ');
      if (parts.length == 3) {
        await _handleLogin(parts[1], parts[2]);
      } else {
        _addLog('USAGE: LOGIN <EMAIL> <PASSWORD>');
      }
    } else if (input.toUpperCase().startsWith('AUTHORIZE')) {
      final parts = input.trim().split(' ');
      if (parts.length == 2) {
        await _handleAuthorize(parts[1]);
      } else {
        _addLog('USAGE: AUTHORIZE <PERMISSION_ID>');
      }
    } else if (input.toUpperCase() == 'HELP') {
      _addLog('AVAILABLE COMMANDS: LOGIN, AUTHORIZE, HELP');
    } else {
      _addLog('UNKNOWN COMMAND. TYPE "HELP" FOR OPTIONS.');
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    _addLog('AUTHENTICATING USER: $email...');
    final repo = getIt<IAuthRepository>();
    final success = await repo.login(email, password);

    if (success) {
      _addLog('LOGIN SUCCESSFUL. WELCOME OPERATOR.');
      _addLog('SESSION TOKEN ACQUIRED.');
    } else {
      _addLog('LOGIN FAILED. CHECK CREDENTIALS.');
    }
  }

  Future<void> _handleAuthorize(String permissionId) async {
    _addLog('APPROVING PERMISSION: $permissionId...');
    final repo = getIt<IAuthRepository>();
    final success = await repo.approvePermission(permissionId);

    if (success) {
      _addLog('PERMISSION GRANTED. EXECUTING...');
    } else {
      _addLog('AUTHORIZATION FAILED. CHECK SYSTEM STATUS.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary,
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                VSpace.x3,
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppPalette.primary.textPrimary
                            .withValues(alpha: 0.2),
                      ),
                      color: AppPalette.primary.backgroundPrimary
                          .withValues(alpha: 0.3),
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _buildLogView()),
                        _buildInput(),
                        VSpace.x1, // Padding bottom for input
                      ],
                    ),
                  ),
                ),
                VSpace.x1_5,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            keyLabel: 'F1',
            label: 'ARTIFACTS',
            onTap: () => context.goNamed(RouteNames.artifact),
          ),
          TerminalAction(
            keyLabel: 'F3',
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
          TerminalAction(
            keyLabel: 'F10',
            label: 'LOGOUT',
            onTap: () => context.goNamed(RouteNames.onboarding),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: Column(
              children: [
                PocoAnimator(fontSize: AppSizes.fontBig),
                VSpace.x0_5,
                Text(
                  'Poco',
                  style: context.textTheme.labelSmall?.copyWith(
                    color:
                        AppPalette.primary.textPrimary.withValues(alpha: 0.8),
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontTiny,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        VSpace.x2,
        BlocBuilder<SystemStatusCubit, SystemStatusState>(
            builder: (context, state) {
          final isConnected = state.isConnected;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'POCKETCODER v1.0.4',
                style: context.textTheme.titleSmall?.copyWith(
                  color: AppPalette.primary.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '[ ${isConnected ? 'ONLINE' : 'OFFLINE'} ]',
                style: TextStyle(
                  color: isConnected
                      ? AppPalette.primary.textPrimary
                      : AppPalette.primary.errorColor,
                  fontSize: AppSizes.fontMini,
                  letterSpacing: 1,
                ),
              ),
            ],
          );
        }),
        VSpace.x1,
        Container(
          height: 1,
          width: double.infinity,
          color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildLogView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space,
      ),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: Text(
            _logs[index],
            style: TextStyle(
              color: AppPalette.primary
                  .primaryColor, // Using slightly different green for logs
              fontSize: AppSizes.fontSmall,
              fontFamily: AppFonts.bodyFamily,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return TerminalInput(
      controller: _inputController,
      onSubmitted: _handleInputSubmit,
      prompt: '#',
    );
  }
}
