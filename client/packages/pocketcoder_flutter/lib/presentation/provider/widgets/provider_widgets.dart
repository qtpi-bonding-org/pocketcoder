import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

/// One selectable target for a [ProviderKey]: either a single-provider
/// ("self"-scoped) harness like Claude Code or Codex -- where `provider`
/// must equal that harness's own `cliId` -- or a models.dev catalog entry
/// (Anthropic, OpenAI, OpenRouter, ...) covering every multi-provider
/// ("any"-scoped) harness at once, e.g. Goose and OpenCode -- where
/// `provider` must equal the models.dev provider id, since renderEnv
/// (harness_provision.go) derives the real env var name for a multi-provider
/// harness from that id via internal/modelcatalog's synced cache, not from
/// which harness happened to be selected.
sealed class ProviderKeyTarget {
  const ProviderKeyTarget();

  /// The value stored in `ProviderKey.provider`.
  String get storedProvider;

  /// The display label for this target.
  String get label;
}

class HarnessKeyTarget extends ProviderKeyTarget {
  const HarnessKeyTarget(this.harness);
  final Harnesse harness;

  @override
  String get storedProvider => harness.cliId;

  @override
  String get label => harness.name.toUpperCase();
}

class CatalogProviderKeyTarget extends ProviderKeyTarget {
  const CatalogProviderKeyTarget(this.provider);
  final domain.Provider provider;

  @override
  String get storedProvider => provider.providerId;

  @override
  String get label => provider.name.toUpperCase();
}

/// Stateful edit dialog body for a single [ProviderKey].
///
/// Lets the user pick a target (a single-provider harness, or a
/// models.dev-cataloged LLM provider shared by every multi-provider
/// harness -- see [ProviderKeyTarget]) and enter a single generic
/// `API_KEY` env var value. The backend translates that generic value into
/// whichever real env var name the target actually needs.
class ProviderKeyEditorDialog extends StatefulWidget {
  const ProviderKeyEditorDialog({
    super.key,
    required this.harnesses,
    required this.providerCatalog,
    required this.onSave,
    this.existing,
  });

  final List<Harnesse> harnesses;
  final List<domain.Provider> providerCatalog;
  final ProviderKey? existing;
  final void Function(ProviderKey updated) onSave;

  @override
  State<ProviderKeyEditorDialog> createState() =>
      ProviderKeyEditorDialogState();
}

class ProviderKeyEditorDialogState extends State<ProviderKeyEditorDialog> {
  late final TextEditingController _apiKeyController;
  ProviderKeyTarget? _selectedTarget;

  /// Single-provider harnesses selectable directly; multi-provider harnesses
  /// (Goose, OpenCode, ...) are represented by the provider catalog instead
  /// -- one key covers all of them for that provider.
  List<ProviderKeyTarget> get _targets => [
        for (final h in widget.harnesses)
          if (h.providerScope != HarnesseProviderScope.any) HarnessKeyTarget(h),
        for (final p in widget.providerCatalog) CatalogProviderKeyTarget(p),
      ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final initialEnvValue = _envValueFrom(existing.envVars);
    _apiKeyController.text = initialEnvValue ?? '';
    for (final target in _targets) {
      if (target.storedProvider == existing.provider) {
        _selectedTarget = target;
        break;
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final value = _apiKeyController.text.trim();
    if (value.isEmpty) return;
    final target = _selectedTarget;
    if (target == null) return;

    final existing = widget.existing;
    widget.onSave(
      ProviderKey(
        id: existing?.id ?? '',
        user: existing?.user ?? '',
        provider: target.storedProvider,
        envVars: <String, dynamic>{'API_KEY': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final selected = _selectedTarget;

    final title = selected == null
        ? context.l10n.providerScreenSelectProvider
        : context.l10n.providerScreenAddKeyTitle(selected.label);

    final initialEntry =
        widget.existing == null ? <String, String>{} : <String, String>{};
    final existingEnv = _envValueFrom(widget.existing?.envVars);
    if (existingEnv != null) {
      initialEntry['API_KEY'] = existingEnv;
    }

    return TerminalDialog(
      title: title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalText(
              selected == null
                  ? context.l10n.providerScreenAddKey
                  : context.l10n.providerScreenAddKeyBody(selected.label),
              alpha: 0.7,
            ),
            VSpace.x2,
            ProviderTargetPicker(
              targets: _targets,
              selectedProvider: selected?.storedProvider,
              onSelected: (t) => setState(() => _selectedTarget = t),
            ),
            VSpace.x2,
            TerminalTextField(
              controller: _apiKeyController,
              label: 'API_KEY',
              hint: 'API_KEY',
              obscureText: true,
            ),
            VSpace.x2,
            Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalText.tiny(
                    'CURRENT VALUE',
                    color: colors.onSurface,
                  ),
                  VSpace.x1,
                  TerminalText(
                    existingEnv == null
                        ? '(not set)'
                        : _maskKeyPreview(initialEntry),
                    color: colors.onSurface,
                    alpha: existingEnv == null ? 0.5 : 1.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TerminalButton(
          label: context.l10n.actionCancel,
          isPrimary: false,
          onTap: () => Navigator.of(context).pop(),
        ),
        HSpace.x2,
        TerminalButton(
          label: context.l10n.actionSave,
          onTap: _handleSave,
        ),
      ],
    );
  }

  String _maskKeyPreview(Map<String, String> envVars) {
    if (envVars.isEmpty) return '***';
    final firstValue = envVars.values.first;
    if (firstValue.length > 8) {
      final head = firstValue.substring(0, 4);
      final tail = firstValue.substring(firstValue.length - 4);
      return '$head..$tail';
    }
    return '****';
  }

  /// Best-effort extraction of an `API_KEY` value from the dynamic-typed
  /// `ProviderKey.envVars` field (a JSON-deserialized map of unknown shape).
  /// Returns `null` when nothing usable is found so the caller can fall back.
  String? _envValueFrom(dynamic envVars) {
    if (envVars == null) return null;
    if (envVars is Map) {
      for (final entry in envVars.entries) {
        final key = entry.key.toString();
        final value = entry.value.toString();
        if (key.toUpperCase().contains('API_KEY') ||
            key.toUpperCase().contains('APIKEY') ||
            key.toUpperCase().contains('TOKEN') ||
            key.toUpperCase().contains('KEY')) {
          return value;
        }
      }
      if (envVars.isNotEmpty) {
        final firstValue = envVars.values.first;
        if (firstValue != null) return firstValue.toString();
      }
    }
    return null;
  }
}

class ProviderTargetPicker extends StatelessWidget {
  const ProviderTargetPicker({
    super.key,
    required this.targets,
    required this.selectedProvider,
    required this.onSelected,
  });

  final List<ProviderKeyTarget> targets;
  final String? selectedProvider;
  final ValueChanged<ProviderKeyTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    return BiosRow(
      label: 'PROVIDER',
      value: _currentValueLabel(context),
      variant: BiosRowVariant.expand,
      onTap: () async {
            final picked = await showDialog<ProviderKeyTarget>(
              context: context,
              builder: (dialogContext) => _ProviderTargetSearchDialog(
                targets: targets,
                selectedProvider: selectedProvider,
              ),
            );
            if (picked != null) onSelected(picked);
          },
    );
  }

  String _currentValueLabel(BuildContext context) {
    for (final t in targets) {
      if (t.storedProvider == selectedProvider) {
        return t.label;
      }
    }
    return context.l10n.providerScreenSelectProvider.toUpperCase();
  }
}

/// The provider list is now synced from models.dev's full catalog (no
/// PocketCoder-side curation -- see internal/modelcatalog), which can run
/// to a couple hundred entries. A live text filter keeps that browsable
/// instead of dumping the whole list in an unsearchable ListView.
class _ProviderTargetSearchDialog extends StatefulWidget {
  const _ProviderTargetSearchDialog({
    required this.targets,
    required this.selectedProvider,
  });

  final List<ProviderKeyTarget> targets;
  final String? selectedProvider;

  @override
  State<_ProviderTargetSearchDialog> createState() =>
      _ProviderTargetSearchDialogState();
}

class _ProviderTargetSearchDialogState
    extends State<_ProviderTargetSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProviderKeyTarget> get _filtered {
    if (_query.isEmpty) return widget.targets;
    final q = _query.toLowerCase();
    return widget.targets
        .where((t) =>
            t.label.toLowerCase().contains(q) ||
            t.storedProvider.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return TerminalDialog(
      title: context.l10n.providerScreenSelectProvider,
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: widget.targets.isEmpty
            ? Center(
                child: TerminalText(
                  context.l10n.providerScreenNoProviders,
                  alpha: 0.5,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TerminalTextField(
                    controller: _searchController,
                    label: context.l10n.providerScreenSearchLabel,
                    hint: context.l10n.providerScreenSearchHint,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  VSpace.x2,
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: TerminalText(
                              context.l10n.providerScreenSearchNoMatches,
                              alpha: 0.5,
                            ),
                          )
                        : ListView(
                            children: [
                              for (final t in filtered)
                                ProviderTargetOption(
                                  target: t,
                                  isSelected:
                                      widget.selectedProvider == t.storedProvider,
                                  onTap: () => Navigator.of(context).pop(t),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TerminalButton(
          label: context.l10n.actionCancel,
          isPrimary: false,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class ProviderTargetOption extends StatelessWidget {
  const ProviderTargetOption({
    super.key,
    required this.target,
    required this.isSelected,
    required this.onTap,
  });

  final ProviderKeyTarget target;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSizes.space),
        margin: EdgeInsets.only(bottom: AppSizes.space * 0.5),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TerminalText(
                target.label,
                weight: TerminalTextWeight.heavy,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TerminalText.mini(
              target.storedProvider,
              alpha: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
