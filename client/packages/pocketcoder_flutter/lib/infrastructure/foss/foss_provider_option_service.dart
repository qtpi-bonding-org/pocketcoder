import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';

/// FOSS implementation — no guided providers are supported right now.
class FossProviderOptionService implements IProviderOptionService {
  @override
  List<ProviderOption> getAvailableProviders() => const [
        // Hetzner is intentionally hidden until its deployment path is
        // implemented and supported end to end.
      ];
}
