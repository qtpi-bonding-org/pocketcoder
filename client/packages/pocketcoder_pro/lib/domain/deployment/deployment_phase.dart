import 'onboarding_stage.dart';

enum DeploymentPhase {
  waitingForCaddy,
  installingHost,
  fetchingRelease,
  loadingImages,
  composeUp,
  bootstrapComplete,
  ready,
  failed,
  timedOut,
}

extension DeploymentPhaseX on DeploymentPhase {
  static DeploymentPhase fromWireName(String? wire) => switch (wire) {
        'installing_host' => DeploymentPhase.installingHost,
        'fetching_release' => DeploymentPhase.fetchingRelease,
        'loading_images' => DeploymentPhase.loadingImages,
        'compose_up' => DeploymentPhase.composeUp,
        'bootstrap_complete' => DeploymentPhase.bootstrapComplete,
        _ => DeploymentPhase.waitingForCaddy,
      };

  OnboardingStage toOnboardingStage() => switch (this) {
        DeploymentPhase.waitingForCaddy => OnboardingStage.securingConnection,
        DeploymentPhase.installingHost => OnboardingStage.installingHost,
        DeploymentPhase.fetchingRelease => OnboardingStage.fetchingRelease,
        DeploymentPhase.loadingImages => OnboardingStage.loadingImages,
        DeploymentPhase.composeUp => OnboardingStage.startingServices,
        DeploymentPhase.bootstrapComplete => OnboardingStage.finishingUp,
        DeploymentPhase.ready => OnboardingStage.ready,
        DeploymentPhase.failed || DeploymentPhase.timedOut => OnboardingStage.failed,
      };
}
