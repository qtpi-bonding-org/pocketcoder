import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_aeroform/application/auth/auth_cubit.dart';
import 'package:flutter_aeroform/application/auth/auth_message_mapper.dart';
import 'package:flutter_aeroform/application/auth/auth_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:get_it/get_it.dart';

/// Authentication screen for Linode OAuth login
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<AuthCubit, AuthState>(
      mapper: GetIt.I<AuthMessageMapper>(),
      child: const _AuthView(),
    );
  }
}

class _AuthView extends StatelessWidget {
  const _AuthView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final authCubit = context.read<AuthCubit>();

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Navigate to ConfigScreen on successful authentication
        if (state.isSuccess && state.isAuthenticated == true) {
          context.pushNamed(RouteNames.config);
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return TerminalScaffold(
            title: 'CLOUD PROVISIONING AUTH',
            actions: [
              TerminalAction(
                label: state.isLoading ? 'CONNECTING...' : 'LOGIN VIA LINODE',
                onTap: state.isLoading ? () {} : () => authCubit.authenticate(),
              ),
              TerminalAction(
                label: 'BACK',
                onTap: () => context.pop(),
              ),
            ],
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: BiosFrame(
                  title: 'OAUTH GATEWAY',
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          size: 64,
                          color: colors.primary,
                        ),
                        VSpace.x2,
                        Text(
                          'DEPLOY POCKETCODER',
                          style: TextStyle(
                            fontFamily: AppFonts.headerFamily,
                            fontSize: AppSizes.fontBig,
                            color: colors.onSurface,
                            fontWeight: AppFonts.heavy,
                          ),
                        ),
                        VSpace.x2,
                        Text(
                          'SIGN IN WITH YOUR LINODE ACCOUNT TO PROVISION AN ISOLATED INSTANCE. DATA RETAINMENT REMAINS UNDER YOUR EXCLUSIVE CONTROL.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                        if (state.isLoading) ...[
                          VSpace.x4,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.primary),
                                ),
                              ),
                              HSpace.x2,
                              Text(
                                'WAITING FOR BROWSER AUTH...',
                                style: TextStyle(
                                  fontFamily: AppFonts.bodyFamily,
                                  color: colors.primary,
                                  fontSize: AppSizes.fontTiny,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (state.hasError) ...[
                          VSpace.x4,
                          Container(
                            padding: EdgeInsets.all(AppSizes.space),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.error),
                              color: colors.error.withValues(alpha: 0.1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: colors.error, size: 16),
                                HSpace.x2,
                                Expanded(
                                  child: Text(
                                    _getErrorMessage(state.error).toUpperCase(),
                                    style: TextStyle(
                                      color: colors.error,
                                      fontFamily: AppFonts.bodyFamily,
                                      fontSize: AppSizes.fontTiny,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getErrorMessage(Object? error) {
    if (error == null) return 'AN ERROR OCCURRED';
    final errorStr = error.toString();
    if (errorStr.contains('cancelled') || errorStr.contains('CANCELED')) {
      return 'AUTHENTICATION CANCELLED';
    }
    return errorStr;
  }
}
