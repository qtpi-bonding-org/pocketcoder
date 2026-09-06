import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';

/// Colour is a suspicion signal, independent of posture.
enum PocoMood {
  happy,
  awake,
  cheeky,
  amazed,
  thinking,
  winkLeft,
  winkRight,
  sleepy,
  shy,
  nervous,
  vigilantLeft,
  vigilantRight,
  skeptical,
  surprised,
  lookRight,
  lookLeft,
  mad,
  mistaken,
  panic,
  sad,

  /// Compatibility name for callers describing the amber suspicion state.
  suspicious;

  Color get color => switch (this) {
        happy ||
        awake ||
        cheeky ||
        amazed ||
        thinking ||
        winkLeft ||
        winkRight =>
          AppPalette.bright,
        sleepy || shy => AppPalette.body,
        _ => AppPalette.amber,
      };
}

/// Armor is a location signal, independent of mood.
enum PocoPosture {
  armored,
  fortified,
}
