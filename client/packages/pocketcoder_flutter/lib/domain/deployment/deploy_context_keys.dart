import 'package:flutter_aeroform/domain/deployment/context_key.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';

/// Seeded by pocketcoder_pro's engine (spec §4.5's "Deploy-track context
/// seeding") via hydrateInstance() before every runTrack call for the
/// deploy track, whether the immediate post-handoff entry or a later
/// resume. Defined here, not in pocketcoder_pro, because pocketcoder_pro
/// depends on pocketcoder_flutter and not the reverse; the engine imports
/// this key from here.
final instanceContextKey = ContextKey<Instance>(
  'deploy.instance',
  (v) => v.toJson(),
  (j) => Instance.fromJson(j as Map<String, dynamic>),
);