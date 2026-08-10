import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/config_view.dart';

void main() {
  testWidgets('supports multi-select while keeping at least one harness', (
    tester,
  ) async {
    var selected = <String>['goose'];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) => ConfigView(
            plans: null,
            regions: null,
            selectedPlan: null,
            selectedRegion: null,
            isValid: true,
            backend: ProvisionBackendKind.standardLinux,
            distribution: StandardLinuxDistribution.debian,
            harnesses: DeploymentHarnessCatalog.bundled.harnesses,
            selectedHarnesses: selected,
            onPlanSelected: (_) {},
            onRegionSelected: (_) {},
            onBackendSelected: (_) {},
            onDistributionSelected: (_) {},
            onHarnessesSelected: (value) => setState(() => selected = value),
            onDeploy: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(selected, ['goose']);
    await tester.tap(find.text('CODEX'));
    await tester.pump();
    expect(selected, ['goose', 'codex']);

    await tester.tap(find.text('GOOSE'));
    await tester.pump();
    expect(selected, ['codex']);

    await tester.tap(find.text('CODEX'));
    await tester.pump();
    expect(selected, ['codex']);
  });
}
