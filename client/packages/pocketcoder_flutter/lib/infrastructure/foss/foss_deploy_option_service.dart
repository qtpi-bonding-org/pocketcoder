import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';

/// FOSS implementation — no guided providers are supported right now.
class FossDeployOptionService implements IDeployOptionService {
  @override
  List<DeployOption> getAvailableProviders() => const [
        // Hetzner is intentionally hidden until its deployment path is
        // implemented and supported end to end.
      ];
}
