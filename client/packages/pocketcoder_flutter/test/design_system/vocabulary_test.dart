import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/layer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

void main() {
  group('StatusMarker', () {
    test('carries a bare word, never brackets', () {
      for (final m in StatusMarker.values) {
        expect(m.word, isNot(contains('[')));
        expect(m.word, isNot(contains(']')));
      }
    });

    test('maps to the specified roles', () {
      expect(StatusMarker.ok.role, TextRole.ok);
      expect(StatusMarker.attention.role, TextRole.warn);
      expect(StatusMarker.failed.role, TextRole.fail);
      expect(StatusMarker.pending.role, TextRole.label);
    });
  });

  group('ActionKind', () {
    test('a refusal is never red', () {
      expect(ActionKind.refusal.role, TextRole.warn);
      expect(ActionKind.refusal.role, isNot(TextRole.fail));
    });

    test('only destructive is red', () {
      final red = ActionKind.values.where((k) => k.role == TextRole.fail);
      expect(red, [ActionKind.destructive]);
    });

    test('destructive may not lead a row', () {
      expect(ActionKind.destructive.mayLeadRow, isFalse);
      for (final k
          in ActionKind.values.where((k) => k != ActionKind.destructive)) {
        expect(k.mayLeadRow, isTrue);
      }
    });
  });

  group('RowAffordance', () {
    test('navigate and expand are different glyphs', () {
      // Right means "go there"; down means "open this". Using one for the
      // other is an error, not a stylistic choice.
      expect(RowAffordance.navigate.glyph, '▸');
      expect(RowAffordance.expand.glyph, '▾');
      expect(RowAffordance.collapse.glyph, '▴');
      expect(RowAffordance.navigate.glyph, isNot(RowAffordance.expand.glyph));
    });

    test('markers are unwrapped -- the row is the tap target', () {
      for (final a in RowAffordance.values) {
        expect(a.glyph, isNot(contains('<')));
        expect(a.glyph, isNot(contains('[')));
      }
    });
  });

  test('pillars are declared in footer order', () {
    expect(NavPillar.values, [
      NavPillar.chat,
      NavPillar.config,
      NavPillar.status,
      NavPillar.control,
    ]);
    // `control` is the only conditional one -- the footer must render
    // correctly at three pillars as well as four.
    expect(NavPillar.control.isConditional, isTrue);
    expect(NavPillar.values.where((p) => p.isConditional).length, 1);
  });

  test('layers are declared in blast-radius order', () {
    // Layer.values IS the display order, so a section list built by
    // iterating cannot put the irreversible operation first.
    expect(Layer.values, [Layer.agent, Layer.app, Layer.system, Layer.data]);
    expect(Layer.values.last, Layer.data,
        reason: 'data is irreversible and belongs at the bottom');
  });
}
