import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/auth/auth_state.dart';

/// Message mapper for authentication state to user-friendly messages
@injectable
class AuthMessageMapper implements IStateMessageMapper<AuthState> {
  @override
  MessageKey? map(AuthState state) {
    // Handle success states with specific messages
    if (state.status.isSuccess && state.isAuthenticated == true) {
      return MessageKey.success('auth.success');
    }

    // Handle loading states
    if (state.status.isLoading) {
      return MessageKey.info('auth.authenticating');
    }

    // Handle error states
    if (state.hasError) {
      final error = state.error;

      if (error.toString().contains('cancelled') ||
          error.toString().contains('CANCELED')) {
        return MessageKey.info('auth.cancelled');
      }

      if (error.toString().contains('not authenticated') ||
          error.toString().contains('Not authenticated')) {
        return MessageKey.info('auth.notAuthenticated');
      }

      // Generic authentication error
      return MessageKey.error(
        'auth.error',
        {'message': error.toString()},
      );
    }

    // Handle logged out state
    if (state.status.isSuccess && state.isAuthenticated == false) {
      return MessageKey.info('auth.loggedOut');
    }

    return null;
  }
}