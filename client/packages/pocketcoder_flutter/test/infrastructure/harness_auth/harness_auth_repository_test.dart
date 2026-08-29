import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';

void main() {
  test('maps structured device-code challenge fields without losing semantics', () {
    final challenge = generated.HarnessAuthChallenge((b) {
      b.type = 'device';
      b.text = 'Use the browser to continue';
      b.kind = generated.HarnessAuthChallengeKindEnum.deviceCode;
      b.verificationUri = 'https://example.test/device';
      b.userCode = 'ABCD-1234';
      b.codeDestination =
          generated.HarnessAuthChallengeCodeDestinationEnum.browser;
      b.pollIntervalSeconds = 4;
    });

    final domain = HarnessAuthChallenge.fromGenerated(challenge);

    expect(domain.kind, 'device_code');
    expect(domain.verificationUri, Uri.parse('https://example.test/device'));
    expect(domain.userCode, 'ABCD-1234');
    expect(domain.codeDestination, HarnessAuthCodeDestination.browser);
    expect(domain.pollIntervalSeconds, 4);
  });

  test('legacy-only challenge does not infer structured fields from prose', () {
    final challenge = generated.HarnessAuthChallenge((b) {
      b.type = 'input';
      b.text = 'Enter this one-time code ABCD-1234 in your browser';
      b.target = 'code';
      b.details = 'legacy challenge';
    });

    final domain = HarnessAuthChallenge.fromGenerated(challenge);

    expect(domain.kind, isNull);
    expect(domain.verificationUri, isNull);
    expect(domain.userCode, isNull);
    expect(domain.codeDestination, HarnessAuthCodeDestination.unknown);
    expect(domain.pollIntervalSeconds, isNull);
    expect(domain.legacyText, challenge.text);
  });
}
