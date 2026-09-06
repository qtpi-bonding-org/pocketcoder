import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/layer.dart';

void main() {
  test('layers are declared in blast-radius order', () {
    expect(Layer.values, [Layer.agent, Layer.app, Layer.system, Layer.data],
        reason: 'a screen that iterates Layer.values cannot put the '
            'irreversible operation first');
  });

  test('every layer has a lowercase display name matching its own name', () {
    // The four names are the vocabulary, learned once and reused everywhere
    // they apply -- so a screen cannot invent a synonym for one of them.
    for (final layer in Layer.values) {
      expect(layer.label, layer.name);
      expect(layer.label, layer.label.toLowerCase());
    }
  });
}
