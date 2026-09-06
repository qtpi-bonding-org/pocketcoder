import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_sizes.dart';

Future<void> _loadMonoFont() async {
  final loader = FontLoader('packages/pocketcoder_flutter/Noto Sans Mono')
    ..addFont(rootBundle.load(
      'packages/pocketcoder_flutter/assets/Noto_Sans_Mono/static/NotoSansMono-Regular.ttf',
    ));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the advance ratio is measured from the real font, not assumed',
      (tester) async {
    await _loadMonoFont();
    // Noto Sans Mono is 600/1000 upm. Measuring at fontSize 1.0 rounds badly
    // and used to trip the unloaded-font check, pinning this at 0.5 -- which
    // made every horizontal grid unit 17% short.
    expect(monoAdvanceRatio, closeTo(0.6, 0.005),
        reason: 'measured $monoAdvanceRatio; expected the font\'s real 0.6');
  });

  test('the fallback is the true ratio, not a smaller "safe" one', () {
    // Understating the advance makes ch too small, which makes
    // contentMaxWidth too narrow and clamps text earlier than the screen
    // requires. A wrong-but-generous value is not safer here.
    expect(kFallbackMonoAdvanceRatio, 0.6);
  });

  test('ch derives from the ratio and the body size', () {
    expect(measureCharacterAdvance(20), closeTo(monoAdvanceRatio * 20, 0.001));
  });
}
