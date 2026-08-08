enum OnboardingStage {
  validating,
  creatingServer,
  preparingHost,
  hostReady,
  securingConnection,
  installingHost,
  fetchingRelease,
  loadingImages,
  startingServices,
  finishingUp,
  ready,
  failed,
}

extension OnboardingStageX on OnboardingStage {
  String get wireName => name;
}
