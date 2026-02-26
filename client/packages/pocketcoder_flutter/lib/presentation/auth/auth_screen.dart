import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_aeroform/application/auth/auth_cubit.dart';
import 'package:flutter_aeroform/application/auth/auth_message_mapper.dart';
import 'package:flutter_aeroform/application/auth/auth_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
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

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            // Navigate to ConfigScreen on successful authentication
            if (state.isSuccess && state.isAuthenticated == true) {
              context.pushNamed(RouteNames.config);
            }
          },
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Main content
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space * 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo/Icon
                          Icon(
                            Icons.cloud_outlined,
                            size: 80,
                            color: colors.primary,
                          ),
                          SizedBox(height: AppSizes.space),
                          Text(
                            'Deploy PocketCoder',
                            style: context.textTheme.headlineMedium,
                          ),
                          SizedBox(height: AppSizes.space),
                          Text(
                            'Sign in with your Linode account to deploy your own PocketCoder instance',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppSizes.space * 4),
                          // Sign in button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: state.isLoading
                                  ? null
                                  : () => authCubit.authenticate(),
                              icon: const Icon(Icons.login),
                              label: const Text('Sign in with Linode'),
                            ),
                          ),
                          SizedBox(height: AppSizes.space * 2),
                          // Error message
                          if (state.hasError) ...[
                            Container(
                              padding: EdgeInsets.all(AppSizes.space),
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.1),
                                border: Border.all(color: colors.error),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colors.error,
                                  ),
                                  SizedBox(width: AppSizes.space),
                                  Expanded(
                                    child: Text(
                                      _getErrorMessage(state.error),
                                      style: TextStyle(color: colors.error),
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
                  // Loading overlay
                  if (state.isLoading) ...[
                    Container(
                      color: colors.surface.withValues(alpha: 0.9),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            SizedBox(height: AppSizes.space * 2),
                            Text(
                              'Authenticating with Linode...',
                              style: context.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(Object? error) {
    if (error == null) return 'An error occurred';
    final errorStr = error.toString();
    if (errorStr.contains('cancelled') || errorStr.contains('CANCELED')) {
      return 'Authentication was cancelled';
    }
    return errorStr;
  }
}