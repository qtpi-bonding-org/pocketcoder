import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({
    super.key,
    this.credentials,
    required this.plans,
    required this.regions,
    required this.selectedPlan,
    required this.selectedRegion,
    required this.isValid,
    required this.backend,
    required this.distribution,
    required this.harnesses,
    required this.selectedHarnesses,
    required this.onPlanSelected,
    required this.onRegionSelected,
    required this.onBackendSelected,
    required this.onDistributionSelected,
    required this.onHarnessesSelected,
    required this.onDeploy,
  });

  final DeployCredentials? credentials;
  final List<InstancePlan>? plans;
  final List<Region>? regions;
  final String? selectedPlan;
  final String? selectedRegion;
  final bool? isValid;
  final ProvisionBackendKind backend;
  final StandardLinuxDistribution distribution;
  final List<DeploymentHarness> harnesses;
  final List<String> selectedHarnesses;
  final ValueChanged<String> onPlanSelected;
  final ValueChanged<String> onRegionSelected;
  final ValueChanged<ProvisionBackendKind> onBackendSelected;
  final ValueChanged<StandardLinuxDistribution> onDistributionSelected;
  final ValueChanged<List<String>> onHarnessesSelected;
  final VoidCallback onDeploy;

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  @override
  Widget build(BuildContext context) => TerminalScaffold(
        title: context.l10n.deploymentManifestConfiguration,
        actions: [
          TerminalAction(
              label: context.l10n.deploymentActionBack,
              onTap: () => Navigator.of(context).pop()),
          TerminalAction(
            label: context.l10n.deploymentActionDeployInstance,
            onTap: widget.isValid == true ? widget.onDeploy : () {},
          ),
        ],
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space),
          child: Column(children: [
            BiosFrame(
              title: context.l10n.deploymentSystemParameters,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox.shrink(),
                  VSpace.x2,
                  BiosSection(
                    title: context.l10n.deploymentHardwareGeography,
                    child: Column(children: [
                      if (widget.plans != null)
                        _buildPlanSelector(context, widget.plans!)
                      else
                        Text(context.l10n.deploymentInitializingHardware),
                      VSpace.x2,
                      if (widget.regions != null)
                        _buildRegionSelector(context, widget.regions!)
                      else
                        Text(context.l10n.deploymentScanningRegions),
                    ]),
                  ),
                  VSpace.x2,
                  BiosSection(
                    title: context.l10n.deploymentCodingHarnesses,
                    child: _buildHarnessSelector(context),
                  ),
                  VSpace.x2,
                  BiosSection(
                    title: context.l10n.deploymentOperatingSystem,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackendSelector(context),
                        if (widget.backend ==
                            ProvisionBackendKind.standardLinux) ...[
                          VSpace.x1,
                          _buildDistributionSelector(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _buildPlanSelector(BuildContext context, List<InstancePlan> plans) {
    final colors = context.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.deploymentInstancePlan,
          style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny)),
      VSpace.x1,
      Container(
        height: 150,
        decoration: BoxDecoration(
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2))),
        child: ListView.builder(
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final selected = plan.id == widget.selectedPlan;
            return InkWell(
              onTap: () => widget.onPlanSelected(plan.id),
              child: Container(
                padding: EdgeInsets.all(AppSizes.space),
                color: selected ? colors.primary.withValues(alpha: 0.1) : null,
                child: Row(children: [
                  Expanded(
                      child: Text('${plan.name} (${plan.memoryMB}MB RAM)',
                          style: TextStyle(
                              fontFamily: AppFonts.bodyFamily,
                              color:
                                  selected ? colors.primary : colors.onSurface,
                              fontSize: AppSizes.fontMini))),
                  Text(
                      context.l10n.deploymentMonthlyPrice(
                          plan.monthlyPriceUSD.toStringAsFixed(2)),
                      style: TextStyle(
                          fontFamily: AppFonts.bodyFamily,
                          color: colors.primary,
                          fontSize: AppSizes.fontMini,
                          fontWeight: AppFonts.heavy)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildRegionSelector(BuildContext context, List<Region> regions) {
    final colors = context.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.deploymentRegion,
          style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny)),
      VSpace.x1,
      Container(
        height: 150,
        decoration: BoxDecoration(
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2))),
        child: ListView.builder(
          itemCount: regions.length,
          itemBuilder: (context, index) {
            final region = regions[index];
            final selected = region.id == widget.selectedRegion;
            return InkWell(
              onTap: () => widget.onRegionSelected(region.id),
              child: Container(
                padding: EdgeInsets.all(AppSizes.space),
                color: selected ? colors.primary.withValues(alpha: 0.1) : null,
                child: Text(
                    '${region.city.toUpperCase()} (${region.country.toUpperCase()})',
                    style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: selected ? colors.primary : colors.onSurface,
                        fontSize: AppSizes.fontMini)),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildBackendSelector(BuildContext context) {
    final colors = context.colorScheme;
    return Row(children: [
      Expanded(
          child: Text(context.l10n.deploymentBackend,
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontSize: AppSizes.fontTiny))),
      DropdownButton<ProvisionBackendKind>(
        value: widget.backend,
        onChanged: (value) {
          if (value != null) widget.onBackendSelected(value);
        },
        items: [
          DropdownMenuItem(
              value: ProvisionBackendKind.nixos,
              child: Text(context.l10n.deploymentNixos)),
          DropdownMenuItem(
              value: ProvisionBackendKind.standardLinux,
              child: Text(context.l10n.deploymentStandardLinux)),
        ],
      ),
    ]);
  }

  Widget _buildDistributionSelector(BuildContext context) {
    final colors = context.colorScheme;
    return Row(children: [
      Expanded(
          child: Text(context.l10n.deploymentDistribution,
              style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface,
                  fontSize: AppSizes.fontTiny))),
      DropdownButton<StandardLinuxDistribution>(
        value: widget.distribution,
        onChanged: (value) {
          if (value != null) widget.onDistributionSelected(value);
        },
        items: [
          DropdownMenuItem(
              value: StandardLinuxDistribution.debian,
              child: Text(context.l10n.deploymentDebian)),
          DropdownMenuItem(
              value: StandardLinuxDistribution.ubuntu,
              child: Text(context.l10n.deploymentUbuntu)),
        ],
      ),
    ]);
  }

  Widget _buildHarnessSelector(BuildContext context) {
    final colors = context.colorScheme;
    final selected = widget.selectedHarnesses.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.deploymentHarnessSelectionDescription,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.72),
            fontSize: AppSizes.fontMini,
          ),
        ),
        VSpace.x1,
        Wrap(
          spacing: AppSizes.space,
          runSpacing: AppSizes.space,
          children: [
            for (final harness in widget.harnesses)
              _HarnessChoice(
                label: harness.id.replaceAll('-', ' ').toUpperCase(),
                selected: selected.contains(harness.id),
                onTap: () {
                  final next = {...selected};
                  if (!next.add(harness.id)) {
                    if (next.length == 1) return;
                    next.remove(harness.id);
                  }
                  widget.onHarnessesSelected([
                    for (final candidate in widget.harnesses)
                      if (next.contains(candidate.id)) candidate.id,
                  ]);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _HarnessChoice extends StatelessWidget {
  const _HarnessChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      checked: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.space,
            vertical: AppSizes.space / 2,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: AppSizes.iconSmall,
                color: selected ? colors.primary : colors.onSurface,
              ),
              SizedBox(width: AppSizes.space / 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: selected ? colors.primary : colors.onSurface,
                  fontSize: AppSizes.fontMini,
                  fontWeight: selected ? AppFonts.heavy : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
