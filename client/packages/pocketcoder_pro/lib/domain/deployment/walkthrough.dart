import 'package:flutter_aeroform/domain/models/provision_progress.dart';

/// A source-backed walkthrough is one provisioning file shown to the owner.
///
/// The source sections are resolved later, after the deployed immutable commit
/// is known. Keeping this outline separate from deployment status means a
/// walkthrough can be read at the owner's pace.
class Walkthrough {
  Walkthrough({
    required this.id,
    required this.briefs,
  })  : assert(id != ''),
        assert(briefs.length > 0);

  final String id;
  final List<WalkthroughBrief> briefs;
}

/// One meaningful explanation within a [Walkthrough].
class WalkthroughBrief {
  WalkthroughBrief({
    required this.id,
    required this.sectionIds,
  })  : assert(id != ''),
        assert(sectionIds.length > 0);

  final String id;

  /// Annotated source sections that provide the code snippets for this
  /// brief. A brief may draw from more than one section in the same
  /// walkthrough file.
  final List<String> sectionIds;
}

/// Immutable content identity for a walkthrough session.
///
/// The content is reset only when either the deployed source commit or target
/// operating-system backend changes. Deployment progress changes do not appear
/// here and therefore cannot reset reading progress.
class WalkthroughContent {
  WalkthroughContent({
    required this.sourceCommit,
    required this.backend,
    required this.walkthroughs,
  })  : assert(sourceCommit != ''),
        assert(walkthroughs.length > 0);

  final String sourceCommit;
  final ProvisionBackendKind backend;
  final List<Walkthrough> walkthroughs;

  bool hasSameIdentityAs(WalkthroughContent other) =>
      sourceCommit == other.sourceCommit && backend == other.backend;
}

/// A prepared local question and response appended to a walkthrough session.
class WalkthroughFaqTurn {
  const WalkthroughFaqTurn({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
