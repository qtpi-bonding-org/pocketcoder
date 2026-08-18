enum ReadinessPhase {
  waitingForCaddy,
  configuringOperatingSystem,
  fetchingRelease,
  loadingImages,
  composeUp,
  bootstrapComplete,
  ready,
  failed,
  timedOut,
}

extension ReadinessPhaseX on ReadinessPhase {
  static ReadinessPhase fromWireName(String? wire) => switch (wire) {
    'configuring_operating_system' => ReadinessPhase.configuringOperatingSystem,
    'fetching_release' => ReadinessPhase.fetchingRelease,
    'loading_images' => ReadinessPhase.loadingImages,
    'compose_up' => ReadinessPhase.composeUp,
    'bootstrap_complete' => ReadinessPhase.bootstrapComplete,
    'ready' => ReadinessPhase.ready,
    'failed' => ReadinessPhase.failed,
    'timed_out' => ReadinessPhase.timedOut,
    _ => ReadinessPhase.waitingForCaddy,
  };
}
