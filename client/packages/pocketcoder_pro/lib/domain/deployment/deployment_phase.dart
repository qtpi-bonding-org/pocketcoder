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

extension DeploymentPhaseWire on DeploymentPhase {
  static DeploymentPhase fromWireName(String? wire) => switch (wire) {
        'installing_host' => DeploymentPhase.installingHost,
        'fetching_release' => DeploymentPhase.fetchingRelease,
        'loading_images' => DeploymentPhase.loadingImages,
        'compose_up' => DeploymentPhase.composeUp,
        'bootstrap_complete' => DeploymentPhase.bootstrapComplete,
        _ => DeploymentPhase.waitingForCaddy,
      };
}
