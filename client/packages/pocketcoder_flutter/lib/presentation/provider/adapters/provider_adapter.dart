import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

class ProviderAdapter extends CubitAdapter<ProviderCubit, ProviderState> {
  const ProviderAdapter({super.key});

  static ProviderState _selectState(ProviderState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ProviderCubit, ProviderState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<ProviderCubit>();
    return UiFlowListener<ProviderCubit, ProviderState>(
      child: ValueListenableBuilder<ProviderState>(
        valueListenable: state,
        builder: (context, value, _) => ProviderView(
          state: value,
          onDelete: cubit.deleteProviderAPIKey,
          onSave: cubit.saveProviderAPIKey,
        ),
      ),
    );
  }
}

/// Read-only listing of [HarnessModel]s plus CRUD for [ProviderApiKey]s.
///
/// Two `BiosSection`s: the first lists the supported `harness_models` (read-
/// only — they're catalog data seeded by migrations, not user-creatable), the
/// second lists the user's `provider_api_keys` with add/edit/delete.
///
/// Every credential is provider-scoped, not harness-scoped: a
/// `ProviderApiKey.provider` is always a `providers` collection record id
/// (never a harness cliId or a models.dev provider_id string), so one key
/// can serve every harness with a `harness_providers` edge to that provider.
class ProviderView extends StatelessWidget {
  const ProviderView({
    super.key,
    required this.state,
    required this.onDelete,
    required this.onSave,
  });

  final ProviderState state;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(ProviderApiKey key) onSave;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.providerScreenTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ProviderState state) {
    if (state.isLoading &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty) {
      return Center(
        child: TerminalLoadingIndicator(
          label: context.l10n.providerScreenLoading,
        ),
      );
    }

    if (state.isFailure &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty) {
      return Center(
        child: TerminalText(
          context.l10n.providerScreenErrorPrefix(
            state.error?.toString() ?? context.l10n.errorGeneric,
          ),
          color: context.terminalColors.warning,
          textAlign: TextAlign.center,
        ),
      );
    }

    final showEmptyHint = state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty;

    return ListView(
      padding: EdgeInsets.all(AppSizes.space),
      children: [
        // ── HARNESS MODELS (read-only) ──
        BiosSection(
          title: context.l10n.providerScreenHarnessModelsSection,
          child: _buildHarnessModelList(context, state),
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

    return BiosRow(
      label: harnessName,
      value: modelName,
      hasBadge: isDefault,
    );
  }

  // ── PROVIDER KEYS ──

  Widget _buildProviderKeyList(BuildContext context, ProviderState state) {
    if (state.providerAPIKeys.isEmpty) {
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
        for (final key in state.providerAPIKeys)
          _buildProviderKeyTile(context, state, key),
        VSpace.x2,
        _buildAddKeyButton(context, state),
      ],
    );
  }

  Widget _buildAddKeyButton(BuildContext context, ProviderState state) {
    return TerminalButton(
      label: context.l10n.providerScreenAddKey,
      onTap: state.providerCatalog.isEmpty
          ? () {}
          : () => _openKeyEditor(context, state, null),
    );
  }

  Widget _buildProviderKeyTile(
    BuildContext context,
    ProviderState state,
    ProviderApiKey key,
  ) {
    final colors = context.colorScheme;

    final providerLabel =
        state.providerCatalog.firstWhere((p) => p.id == key.provider).name;

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
                  _maskKeyPreview(key.apiKey),
                  alpha: 0.5,
                ),
              ],
            ),
          ),
          TextButton(
            child: Text(
              'DELETE',
              style: TextStyle(
                color: colors.error,
                fontWeight: AppFonts.heavy,
              ),
            ),
            onPressed: () => onDelete(key.id),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ──

  void _openKeyEditor(
    BuildContext context,
    ProviderState state,
    ProviderApiKey? existing,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ProviderKeyEditorDialog(
          providerCatalog: state.providerCatalog,
          existing: existing,
          onSave: (key) {
            onSave(key);
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  // ── HELPERS ──

  /// Shows a short prefix and suffix of the provider API key.
  String _maskKeyPreview(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return '***';
    if (apiKey.length > 8) {
      return '${apiKey.substring(0, 4)}..${apiKey.substring(apiKey.length - 4)}';
    }
    return '****';
  }
}
