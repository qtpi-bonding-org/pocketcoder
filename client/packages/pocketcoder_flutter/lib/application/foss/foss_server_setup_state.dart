enum FossServerSetupPhase { idle, keyReady, testing, connected }

final class FossServerSetupState {
  const FossServerSetupState({
    this.phase = FossServerSetupPhase.idle,
    this.publicKey,
    this.error,
  });

  final FossServerSetupPhase phase;
  final String? publicKey;
  final String? error;

  FossServerSetupState copyWith({
    FossServerSetupPhase? phase,
    String? publicKey,
    String? error,
    bool clearError = false,
  }) =>
      FossServerSetupState(
        phase: phase ?? this.phase,
        publicKey: publicKey ?? this.publicKey,
        error: clearError ? null : (error ?? this.error),
      );
}
