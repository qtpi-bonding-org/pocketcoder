import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_posture_scope.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

const _owners = <String>{
  'lib/presentation/core/widgets/poco_posture_scope.dart',
  'lib/presentation/core/widgets/poco_bubble.dart',
  'lib/presentation/core/widgets/poco_animator.dart',
  'lib/presentation/core/widgets/ascii_art.dart',
  'lib/presentation/core/widgets/pocketcoder_shell.dart',
};

void main() {
  testWidgets('defaults to armored with no scope above it', (tester) async {
    late PocoPosture seen;
    await tester.pumpWidget(Builder(builder: (context) {
      seen = PocoPostureScope.of(context);
      return const SizedBox();
    }));
    expect(seen, PocoPosture.armored);
  });

  testWidgets('takes the nearest scope', (tester) async {
    late PocoPosture seen;
    await tester.pumpWidget(PocoPostureScope(
      posture: PocoPosture.fortified,
      child: Builder(builder: (context) {
        seen = PocoPostureScope.of(context);
        return const SizedBox();
      }),
    ));
    expect(seen, PocoPosture.fortified);
  });

  testWidgets('a wizard page is armored and an in-app page is fortified',
      (tester) async {
    Widget wrap(ShellFooter footer) => MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PocketCoderShell(footer: footer, body: const SizedBox()),
        );

    await tester.pumpWidget(wrap(const WizardFooter(
      step: 1,
      totalSteps: 2,
      onNext: _noop,
    )));
    expect(PocoPostureScope.of(tester.element(find.byType(TerminalScaffold))),
        PocoPosture.armored);

    await tester.pumpWidget(wrap(PillarFooter(
      active: NavPillar.chat,
      onSelect: (_) {},
    )));
    expect(PocoPostureScope.of(tester.element(find.byType(TerminalScaffold))),
        PocoPosture.fortified);
  });

  test('presentation screens do not name a posture', () {
    final offenders = <String>[];
    final root = Directory('lib/presentation');
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_owners.any(entity.path.endsWith)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (RegExp(r'PocoPosture\.').hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

void _noop() {}
