import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';

class DeploymentMessageMapper implements IStateMessageMapper<DeploymentState> {
  @override
  MessageKey? map(DeploymentState state) {
    final stage = state.deploymentStatus;
    if (stage == null) return null;
    if (stage == OnboardingStage.failed) {
      return MessageKey.error('deployment.failed', {
        'error': state.error?.toString() ?? 'Unknown error',
      });
    }
    if (stage == OnboardingStage.ready) {
      return MessageKey.success('deployment.ready', {
        'ipAddress': state.instance?.ipAddress ?? '',
      });
    }
    return MessageKey.info('deployment.inProgress', {'stage': stage.name});
  }
}
