/// Sub-organization within a pillar. Declared in **blast-radius order**, so
/// `Layer.values` is already the correct display order and a screen cannot
/// present them in a sequence that puts the irreversible operation first.
enum Layer {
  /// What the AI can do. Cheap and reversible.
  agent,

  /// The PocketCoder stack -- the containers on the box. Costs a minute.
  app,

  /// The operating system. The box goes down.
  ///
  /// NixOS is not the name of this layer; it is a *value* inside it. The
  /// header is the category a person already understands from games consoles;
  /// the specific OS and its version are facts rendered as label/value rows.
  system,

  /// Backups and restore. Irreversible.
  data;
}
