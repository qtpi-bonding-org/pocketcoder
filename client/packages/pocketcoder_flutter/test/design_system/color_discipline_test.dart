import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _allowedDangerSites = {
  'lib/presentation/core/widgets/bios_row.dart',
  'lib/presentation/provider/adapters/provider_adapter.dart',
  'lib/presentation/mcp/widgets/mcp_management_view.dart',
};

void main() {
  test('colorScheme.error / terminalColors.danger stays rare and reviewed',
      () {
    final result = Process.runSync(
      'grep',
      [
        '-rl',
        r'colorScheme\.error\|colors\.error\|terminalColors\.danger\|terminal\.danger',
        'lib',
      ],
      workingDirectory: Directory.current.path,
    );
    final hits = (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();

    final unexpected = hits.difference(_allowedDangerSites);
    expect(
      unexpected,
      isEmpty,
      reason: 'New/unreviewed colorScheme.error or terminalColors.danger '
          'usage found outside the reviewed exception list: $unexpected. '
          'Per the terminal color system spec, default to '
          'terminalColors.warning and only add to _allowedDangerSites for '
          'a genuine, reviewed destructive-action confirmation.',
    );
  });
}
