/// The four top-level destinations. Order is the order they appear in the
/// footer and is not a display concern -- it is the taxonomy.
enum NavPillar {
  chat, // talk to the agent
  config, // set up what the agent can do
  status, // watch the machine
  control; // operate the machine

  /// `control` is only present when server control is available, so the footer
  /// must render correctly at three pillars as well as four.
  bool get isConditional => this == NavPillar.control;
}
