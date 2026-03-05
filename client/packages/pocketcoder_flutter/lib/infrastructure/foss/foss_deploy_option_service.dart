import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';

/// FOSS implementation — only shows free self-host providers.
class FossDeployOptionService implements IDeployOptionService {
  @override
  List<DeployOption> getAvailableProviders() => const [
        DeployOption(
          id: 'hetzner',
          name: 'Hetzner Cloud',
          description: 'Self-host on your own VPS. Affordable, EU-based.',
          url: 'https://hetzner.cloud/?ref=yourReferralCode',
        ),
      ];
}
