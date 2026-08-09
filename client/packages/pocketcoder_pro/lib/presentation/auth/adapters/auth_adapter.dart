import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_pro/application/auth/auth_cubit.dart';
import 'package:pocketcoder_pro/application/auth/auth_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import '../widgets/auth_view.dart';

class AuthAdapter extends CubitAdapter<AuthCubit, AuthState> {
  const AuthAdapter({super.key, this.credentials});

  final DeployCredentials? credentials;

  static AuthState _selectState(AuthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<AuthCubit, AuthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<AuthCubit>();

    return UiFlowListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isSuccess && state.isAuthenticated == true &&
            context.mounted) {
          OnboardingLogger.event(
            'Linode auth screen connected; opening deployment config',
          );
          context.pushNamed(RouteNames.config, extra: credentials);
        }
      },
      child: ValueListenableBuilder<AuthState>(
        valueListenable: state,
        builder: (context, value, _) => AuthView(
          isLoading: value.isLoading,
          errorMessage: _errorMessage(value.error),
          onAuthenticate: cubit.authenticate,
          onBack: () => AppNavigation.back(context),
        ),
      ),
    );
  }

  static String? _errorMessage(Object? error) {
    if (error == null) return null;
    final text = error.toString();
    if (text.contains('cancelled') || text.contains('CANCELED')) {
      return 'AUTHENTICATION CANCELLED';
    }
    return text;
  }
}
