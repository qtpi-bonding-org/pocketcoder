import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_aeroform/application/deployment/deployment_cubit.dart';
import 'package:flutter_aeroform/application/deployment/deployment_state.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';

/// Message mapper for deployment state to user-friendly messages
@injectable
class DeploymentMessageMapper implements IStateMessageMapper<DeploymentState> {
  @override
  MessageKey? map(DeploymentState state) {
    // Handle success states with specific messages
    if (state.status.isSuccess && state.deploymentStatus != null) {
      return switch (state.deploymentStatus!) {
        DeploymentStatus.creating => MessageKey.info(
          'deployment.creating',
          {'instanceId': state.instanceId ?? ''},
        ),
        DeploymentStatus.provisioning => MessageKey.info(
          'deployment.provisioning',
          {'attempts': state.pollingAttempts.toString()},
        ),
        DeploymentStatus.ready => MessageKey.success(
          'deployment.ready',
          {'ipAddress': state.instance?.ipAddress ?? ''},
        ),
        DeploymentStatus.failed => MessageKey.error(
          'deployment.failed',
          {'error': state.error?.toString() ?? 'Unknown error'},
        ),
      };
    }

    // Handle loading states
    if (state.status.isLoading) {
      if (state.pollingAttempts > 0) {
        return MessageKey.info(
          'deployment.monitoring',
          {'attempts': state.pollingAttempts.toString()},
        );
      }
      return MessageKey.info('deployment.inProgress');
    }

    // Handle error states - use exception mapper for specific errors
    if (state.hasError) {
      if (state.error is DeploymentValidationException) {
        final validationError = state.error as DeploymentValidationException;
        return MessageKey.error(
          'deployment.validationError',
          {'message': validationError.message},
        );
      }

      if (state.error is DeploymentException) {
        return MessageKey.error(
          'deployment.error',
          {'message': (state.error as DeploymentException).message},
        );
      }

      // Generic error fallback
      return MessageKey.error(
        'deployment.error',
        {'message': state.error.toString()},
      );
    }

    return null;
  }
}