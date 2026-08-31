/// Privileged owner operations that the Flutter client may invoke.
///
/// This intentionally is not an arbitrary shell-command API. Adding an
/// operation requires a reviewed command mapping in the SSH implementation.
enum RootSshCommand {
  restartPocketCoder,
  updatePocketCoder,
  restartNixOs,
  updateNixOs,
  saveBackup,
  restoreBackup,
  exportCaddyCaFingerprint,
  rollback,
}
