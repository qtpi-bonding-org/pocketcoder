/// Supplies the credential+proof headers ReleaseContentService attaches
/// to every image-relay request. Split from pocketcoder_pro's actual
/// RootKeyService/CredentialService/ProofSigningService the same way
/// this package already keeps RevenueCat out of its own dependency
/// graph -- see pocketcoder/client/CLAUDE.md's "Flutter only talks to
/// PocketBase" rule and this repo's existing IImageRelayCredentialProvider
/// precedent.
abstract class IImageRelayProofProvider {
  Future<String> credential();
  Future<String> proof({required String method, required String url});
}
