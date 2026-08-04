import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/infrastructure/ollama/ollama_api.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

/// Top-level screen for the provider configuration surface (plan Task 12).
///
/// Provides the [ProviderCubit] via [BlocProvider] and wraps the body in a
/// [UiFlowListener] so toasts fire on save/delete errors. The body lives in
/// [ProviderView] so widget tests can wrap just that widget with their own
/// `BlocProvider`s + fake cubits, mirroring the same split
/// `AgentConfigScreen`/`AgentConfigView` uses.
class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProviderCubit>()..watchAll(),
      child: UiFlowListener<ProviderCubit, ProviderState>(
        child: const ProviderView(),
      ),
    );
  }
}

/// Read-only listing of [HarnessModel]s plus CRUD for [ProviderKey]s.
///
/// Two `BiosSection`s: the first lists the supported `harness_models` (read-
/// only — they're catalog data seeded by migrations, not user-creatable), the
/// second lists the user's `provider_keys` with add/edit/delete.
///
/// Intentional differences from the legacy `llm_management_screen.dart`:
/// - no "global default" model picker (there's no `chats.model` default in
///   the new schema — see Task 12 description),
/// - provider picker is by `Harnesse.cliId` (matches `ProviderKey.provider`,
///   confirmed a free-text column in `provider_keys`),
/// - a generic single `API_KEY` env var field per `ProviderKey` is offered
///   (no schema-driven env var forms — `Harnesse` doesn't have one).
class ProviderView extends StatelessWidget {
  const ProviderView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProviderCubit, ProviderState>(
      builder: (context, state) {
        return PocketCoderShell(
          title: context.l10n.providerScreenTitle,
          activePillar: NavPillar.configure,
          showBack: true,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProviderState state) {
    final colors = context.colorScheme;

    if (state.isLoading &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerKeys.isEmpty) {
      return Center(
        child: TerminalLoadingIndicator(
          label: context.l10n.providerScreenLoading,
        ),
      );
    }

    if (state.isFailure &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerKeys.isEmpty) {
      return Center(
        child: TerminalText(
          context.l10n.providerScreenErrorPrefix(
            state.error?.toString() ?? context.l10n.errorGeneric,
          ),
          color: colors.error,
          textAlign: TextAlign.center,
        ),
      );
    }

    final showEmptyHint = state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerKeys.isEmpty;

    return ListView(
      padding: EdgeInsets.all(AppSizes.space),
      children: [
        // ── HARNESS MODELS (read-only) ──
        BiosSection(
          title: context.l10n.providerScreenHarnessModelsSection,
          child: _buildHarnessModelList(context, state),
        ),

        if (getIt.isRegistered<OllamaApi>())
          BiosSection(
            title: 'LOCAL OLLAMA MODELS',
            child: _OllamaModelsPanel(api: getIt<OllamaApi>()),
          ),

        // ── PROVIDER KEYS (CRUD) ──
        BiosSection(
          title: context.l10n.providerScreenApiKeysSection,
          child: _buildProviderKeyList(context, state),
        ),

        if (showEmptyHint)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: TerminalText(
                context.l10n.providerScreenEmptyHint,
                alpha: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  // ── HARNESS MODELS ──

  Widget _buildHarnessModelList(BuildContext context, ProviderState state) {
    if (state.harnessModels.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Center(
          child: TerminalText(
            context.l10n.providerScreenNoHarnessModels,
            alpha: 0.5,
          ),
        ),
      );
    }

    return Column(
      children: state.harnessModels
          .map((hm) => _buildHarnessModelTile(context, state, hm))
          .toList(),
    );
  }

  Widget _buildHarnessModelTile(
    BuildContext context,
    ProviderState state,
    HarnessModel hm,
  ) {
    final colors = context.colorScheme;

    String harnessName = hm.harness;
    for (final h in state.harnesses) {
      if (h.id == hm.harness) {
        harnessName = h.name;
        break;
      }
    }

    String modelName = hm.model;
    for (final m in state.models) {
      if (m.id == hm.model) {
        final dn = m.displayName;
        modelName = dn != null && dn.isNotEmpty ? dn : m.name;
        break;
      }
    }

    final isDefault = hm.isDefault ?? false;

    return TerminalCard(
      isActive: isDefault,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TerminalText(
                  harnessName.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
                TerminalText.mini(
                  modelName.toUpperCase(),
                  alpha: 0.7,
                ),
              ],
            ),
          ),
          if (isDefault)
            TerminalText.label(
              context.l10n.providerScreenDefaultBadge,
              color: colors.primary,
            ),
        ],
      ),
    );
  }

  // ── PROVIDER KEYS ──

  Widget _buildProviderKeyList(BuildContext context, ProviderState state) {
    if (state.providerKeys.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Column(
          children: [
            Center(
              child: TerminalText(
                context.l10n.providerScreenNoApiKeys,
                alpha: 0.5,
              ),
            ),
            VSpace.x2,
            _buildAddKeyButton(context, state),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final key in state.providerKeys)
          _buildProviderKeyTile(context, state, key),
        VSpace.x2,
        _buildAddKeyButton(context, state),
      ],
    );
  }

  Widget _buildAddKeyButton(BuildContext context, ProviderState state) {
    return TerminalButton(
      label: context.l10n.providerScreenAddKey,
      onTap: state.harnesses.isEmpty
          ? () {}
          : () => _openKeyEditor(context, state, null),
    );
  }

  Widget _buildProviderKeyTile(
    BuildContext context,
    ProviderState state,
    ProviderKey key,
  ) {
    final colors = context.colorScheme;

    final harness = state.harnesses.firstWhere(
      (h) => h.cliId == key.provider,
      orElse: () => _emptyHarnesse,
    );
    final providerLabel = harness.id.isEmpty ? key.provider : harness.name;

    return TerminalCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TerminalText(
                  providerLabel.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
                TerminalText.mini(
                  _maskKeyPreview(key.envVars),
                  alpha: 0.5,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline,
              size: 16,
              color: colors.error,
            ),
            onPressed: () => context.read<ProviderCubit>().deleteProviderKey(
                  key.id,
                ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ──

  void _openKeyEditor(
    BuildContext context,
    ProviderState state,
    ProviderKey? existing,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ProviderKeyEditorDialog(
          harnesses: state.harnesses,
          existing: existing,
          onSave: (key) {
            context.read<ProviderCubit>().saveProviderKey(key);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  // ── HELPERS ──

  /// Same shape as `_maskKeyPreview` in the legacy `llm_management_screen.dart`
  /// — show a short prefix and suffix of the first env var value, or a fixed
  /// placeholder when no value is present.
  String _maskKeyPreview(dynamic envVars) {
    if (envVars == null) return '***';
    if (envVars is Map && envVars.isNotEmpty) {
      final firstValue = envVars.values.first.toString();
      if (firstValue.length > 8) {
        final head = firstValue.substring(0, 4);
        final tail = firstValue.substring(firstValue.length - 4);
        return '$head..$tail';
      }
      return '****';
    }
    return '***';
  }

  /// Sentinel `Harnesse` used by `firstWhere`/`orElse` to keep the
  /// `providerLabel` lookup total without a nullable local. Empty `id`
  /// signals "not found".
  static const Harnesse _emptyHarnesse = Harnesse(
    id: '',
    name: '',
    cliId: '',
    acpTransport: HarnesseAcpTransport.unknown,
  );
}

class _OllamaModelsPanel extends StatefulWidget {
  const _OllamaModelsPanel({required this.api});

  final OllamaApi api;

  @override
  State<_OllamaModelsPanel> createState() => _OllamaModelsPanelState();
}

class _OllamaModelsPanelState extends State<_OllamaModelsPanel> {
  final _modelController = TextEditingController();
  late Future<List<OllamaModel>> _models;
  String? _status;
  String? _error;
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    _models = widget.api.listModels();
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _pull() async {
    final model = _modelController.text.trim();
    if (model.isEmpty || _pulling) return;
    setState(() {
      _pulling = true;
      _status = 'Starting download…';
      _error = null;
    });
    try {
      await for (final status in widget.api.pull(model)) {
        if (mounted) setState(() => _status = status);
      }
      if (mounted) {
        setState(() {
          _models = widget.api.listModels();
          _status = 'Downloaded $model';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<List<OllamaModel>>(
          future: _models,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TerminalLoadingIndicator(label: 'LOADING MODELS');
            }
            if (snapshot.hasError) {
              return TerminalText('OLLAMA UNAVAILABLE', color: colors.error);
            }
            final models = snapshot.data ?? const [];
            if (models.isEmpty) {
              return TerminalText.mini('NO LOCAL MODELS INSTALLED', alpha: 0.5);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final model in models)
                  TerminalText.mini(model.name.toUpperCase(), alpha: 0.8),
              ],
            );
          },
        ),
        VSpace.x2,
        TerminalTextField(
          controller: _modelController,
          label: 'MODEL TO DOWNLOAD',
          hint: 'qwen2.5:0.5b',
        ),
        VSpace.x1,
        TerminalButton(
          label: _pulling ? 'DOWNLOADING…' : 'DOWNLOAD MODEL',
          onTap: _pulling ? () {} : _pull,
        ),
        if (_status != null) ...[
          VSpace.x1,
          TerminalText.mini(_status!.toUpperCase(), alpha: 0.6),
        ],
        if (_error != null) ...[
          VSpace.x1,
          TerminalText.mini(_error!, color: colors.error),
        ],
      ],
    );
  }
}

/// Stateful edit dialog body for a single [ProviderKey].
///
/// Lets the user pick a harness (by `cliId`, which is what
/// `ProviderKey.provider` holds) and enter a single generic `API_KEY` env
/// var value — there's no HarnessModel/Harnesse schema-driven env var list
/// in the seeded catalog, so a single field is the right scope.
class _ProviderKeyEditorDialog extends StatefulWidget {
  const _ProviderKeyEditorDialog({
    required this.harnesses,
    required this.onSave,
    this.existing,
  });

  final List<Harnesse> harnesses;
  final ProviderKey? existing;
  final void Function(ProviderKey updated) onSave;

  @override
  State<_ProviderKeyEditorDialog> createState() =>
      _ProviderKeyEditorDialogState();
}

class _ProviderKeyEditorDialogState extends State<_ProviderKeyEditorDialog> {
  late final TextEditingController _apiKeyController;
  Harnesse? _selectedHarness;

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
    for (final h in widget.harnesses) {
      if (h.cliId == existing.provider) {
        _selectedHarness = h;
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
    if (_selectedHarness == null) return;

    final existing = widget.existing;
    widget.onSave(
      ProviderKey(
        id: existing?.id ?? '',
        user: existing?.user ?? '',
        provider: _selectedHarness?.cliId ?? '',
        envVars: <String, dynamic>{'API_KEY': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final harnesses = widget.harnesses;
    final selected = _selectedHarness;

    final title = selected == null
        ? context.l10n.providerScreenSelectProvider
        : context.l10n.providerScreenAddKeyTitle(selected.name.toUpperCase());

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
                  : context.l10n.providerScreenAddKeyBody(selected.name),
              alpha: 0.7,
            ),
            VSpace.x2,
            _HarnessPicker(
              harnesses: harnesses,
              selectedHarnessId: selected?.id,
              onSelected: (h) => setState(() => _selectedHarness = h),
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

class _HarnessPicker extends StatelessWidget {
  const _HarnessPicker({
    required this.harnesses,
    required this.selectedHarnessId,
    required this.onSelected,
  });

  final List<Harnesse> harnesses;
  final String? selectedHarnessId;
  final ValueChanged<Harnesse> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalText.tiny(
          'HARNESS',
          color: colors.onSurface,
        ),
        VSpace.x1,
        InkWell(
          onTap: () async {
            final picked = await showDialog<Harnesse>(
              context: context,
              builder: (dialogContext) => TerminalDialog(
                title: context.l10n.providerScreenSelectProvider,
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: harnesses.isEmpty
                      ? Center(
                          child: TerminalText(
                            context.l10n.providerScreenNoProviders,
                            alpha: 0.5,
                          ),
                        )
                      : ListView(
                          children: [
                            for (final h in harnesses)
                              _HarnessOption(
                                harness: h,
                                isSelected: selectedHarnessId == h.id,
                                onTap: () => Navigator.of(dialogContext).pop(h),
                              ),
                          ],
                        ),
                ),
                actions: [
                  TerminalButton(
                    label: context.l10n.actionCancel,
                    isPrimary: false,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            );
            if (picked != null) onSelected(picked);
          },
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    _currentValueLabel(context),
                    color: colors.onSurface,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: colors.onSurface),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _currentValueLabel(BuildContext context) {
    for (final h in harnesses) {
      if (h.id == selectedHarnessId) {
        return h.name.toUpperCase();
      }
    }
    return context.l10n.providerScreenSelectProvider.toUpperCase();
  }
}

class _HarnessOption extends StatelessWidget {
  const _HarnessOption({
    required this.harness,
    required this.isSelected,
    required this.onTap,
  });

  final Harnesse harness;
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
                harness.name.toUpperCase(),
                weight: TerminalTextWeight.heavy,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TerminalText.mini(
              harness.cliId,
              alpha: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
