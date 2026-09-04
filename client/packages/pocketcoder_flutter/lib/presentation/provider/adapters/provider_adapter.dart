import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

class ProviderAdapter extends CubitAdapter<ProviderCubit, ProviderState> {
  const ProviderAdapter({super.key});

  static ProviderState _selectState(ProviderState state) => state;

  @override
  Widget buildAdapter(BuildContext context,
      CubitAdapterState<ProviderCubit, ProviderState> adapter) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<ProviderCubit>();
    return UiFlowListener<ProviderCubit, ProviderState>(
        child: ValueListenableBuilder<ProviderState>(
            valueListenable: state,
            builder: (context, value, _) => ProviderView(
                state: value,
                onDelete: cubit.deleteProviderAPIKey,
                onSave: cubit.saveProviderAPIKey)));
  }
}

/// Read-only listing of [HarnessModel]s plus CRUD for [ProviderApiKey]s.
///
/// Two sections: the first lists the supported `harness_models` (read-
/// only — they're catalog data seeded by migrations, not user-creatable), the
/// second lists the user's `provider_api_keys` with add/edit/delete.
///
/// Every credential is provider-scoped, not harness-scoped: a
/// `ProviderApiKey.provider` is always a `providers` collection record id
/// (never a harness cliId or a models.dev provider_id string), so one key
/// can serve every harness with a `harness_providers` edge to that provider.
class ProviderView extends StatelessWidget {
  const ProviderView(
      {super.key,
      required this.state,
      required this.onDelete,
      required this.onSave});

  final ProviderState state;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(ProviderApiKey key) onSave;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        title: context.l10n.providerScreenTitle,
        activePillar: NavPillar.configure,
        showBack: true,
        body: _buildBody(context, state));
  }

  Widget _buildBody(BuildContext context, ProviderState state) {
    if (state.isLoading &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty) {
      return Center(
          child: TerminalLoadingIndicator(
              label: context.l10n.providerScreenLoading));
    }

    if (state.isFailure &&
        state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty) {
      return Center(
          child: TerminalText(
              context.l10n.providerScreenErrorPrefix(
                  state.error?.toString() ?? context.l10n.errorGeneric),
              role: TextRole.warn,
              textAlign: TextAlign.center));
    }

    final showEmptyHint = state.harnessModels.isEmpty &&
        state.harnesses.isEmpty &&
        state.providerAPIKeys.isEmpty;

    return ListView(padding: EdgeInsets.all(AppSizes.space), children: [
      SectionHeader(
          name: context.l10n.providerScreenHarnessModelsSection.toLowerCase()),
      _buildHarnessModelList(context, state),
      SectionHeader(
          name: context.l10n.providerScreenApiKeysSection.toLowerCase()),
      _buildProviderKeyList(context, state),
      if (showEmptyHint)
        Center(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 2),
            child: TerminalText(
              context.l10n.providerScreenEmptyHint,
              role: TextRole.body,
            ),
          ),
        ),
    ]);
  }

  Widget _buildHarnessModelList(BuildContext context, ProviderState state) {
    if (state.harnessModels.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Center(
          child: TerminalText(
            context.l10n.providerScreenNoHarnessModels,
            role: TextRole.body,
          ),
        ),
      );
    }

    final byHarness = <String, List<HarnessModel>>{};
    for (final hm in state.harnessModels) {
      (byHarness[hm.harness] ??= []).add(hm);
    }
    final harnessIds = byHarness.keys.toList()
      ..sort((a, b) =>
          _harnessNameFor(state, a).compareTo(_harnessNameFor(state, b)));

    return Column(children: [
      for (final harnessId in harnessIds)
        _HarnessGroupSection(
            harnessName: _harnessNameFor(state, harnessId),
            models: byHarness[harnessId]!,
            modelNameFor: (hm) => _modelNameFor(state, hm)),
    ]);
  }

  String _harnessNameFor(ProviderState state, String harnessId) {
    for (final h in state.harnesses) {
      if (h.id == harnessId) return h.name;
    }
    return harnessId;
  }

  String _modelNameFor(ProviderState state, HarnessModel hm) {
    for (final m in state.models) {
      if (m.id == hm.model) {
        final dn = m.displayName;
        return dn != null && dn.isNotEmpty ? dn : m.name;
      }
    }
    // A catalog row can arrive before its referenced model record. In that
    // case the harness-specific id is the useful display value (and is also
    // what the picker exposes), rather than the opaque model foreign key.
    return hm.harnessModelId;
  }

  Widget _buildProviderKeyList(BuildContext context, ProviderState state) {
    if (state.providerAPIKeys.isEmpty) {
      return Padding(
          padding: EdgeInsets.all(AppSizes.space * 2),
          child: Column(children: [
            Center(
              child: TerminalText(
                context.l10n.providerScreenNoApiKeys,
                role: TextRole.body,
              ),
            ),
            VSpace.x2,
            _buildAddKeyButton(context, state),
          ]));
    }

    return Column(children: [
      for (final key in state.providerAPIKeys)
        _buildProviderKeyTile(context, state, key),
      VSpace.x2,
      _buildAddKeyButton(context, state),
    ]);
  }

  Widget _buildAddKeyButton(BuildContext context, ProviderState state) {
    return TerminalButton(
        label: context.l10n.providerScreenAddKey,
        onTap: state.providerCatalog.isEmpty
            ? () {}
            : () => _openKeyEditor(context, state, null));
  }

  Widget _buildProviderKeyTile(
      BuildContext context, ProviderState state, ProviderApiKey key) {
    final colors = context.colorScheme;

    final providerLabel =
        state.providerCatalog.firstWhere((p) => p.id == key.provider).name;

    return DetailRow(
      label: providerLabel,
      value: _maskKeyPreview(key.apiKey),
      trailing: TextButton(
          child: Text(context.l10n.providerScreenDeleteKeyAction,
              style:
                  TextStyle(color: colors.error, fontWeight: AppFonts.heavy)),
          onPressed: () => onDelete(key.id)),
    );
  }

  void _openKeyEditor(
      BuildContext context, ProviderState state, ProviderApiKey? existing) {
    showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return ProviderKeyEditorDialog(
              providerCatalog: state.providerCatalog,
              existing: existing,
              onSave: (key) {
                onSave(key);
                Navigator.of(dialogContext).pop();
              });
        });
  }

  /// Shows a short prefix and suffix of the provider API key.
  String _maskKeyPreview(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return '***';
    if (apiKey.length > 8) {
      return '${apiKey.substring(0, 4)}..${apiKey.substring(apiKey.length - 4)}';
    }
    return '****';
  }
}

class _HarnessGroupSection extends StatefulWidget {
  const _HarnessGroupSection(
      {required this.harnessName,
      required this.models,
      required this.modelNameFor});

  final String harnessName;
  final List<HarnessModel> models;
  final String Function(HarnessModel) modelNameFor;

  static const _inlineTileLimit = 50;

  @override
  State<_HarnessGroupSection> createState() => _HarnessGroupSectionState();
}

class _HarnessGroupSectionState extends State<_HarnessGroupSection> {
  bool _expanded = false;

  Widget _tile(HarnessModel hm) => DetailRow(
      label: widget.modelNameFor(hm), hasBadge: hm.isDefault ?? false);

  Future<void> _browseAll(BuildContext context) async {
    await showDialog<HarnessModel>(
        context: context,
        builder: (dialogContext) => SearchablePickerDialog<HarnessModel>(
            title: widget.harnessName,
            items: widget.models,
            itemLabel: widget.modelNameFor,
            itemBuilder: (context, hm, {required isSelected, required onTap}) =>
                _tile(hm),
            searchLabel: dialogContext.l10n.providerScreenSearchLabel,
            searchHint: dialogContext.l10n.providerScreenSearchHint,
            emptyLabel: dialogContext.l10n.providerScreenNoHarnessModels,
            noMatchesLabel: dialogContext.l10n.providerScreenSearchNoMatches));
  }

  @override
  Widget build(BuildContext context) {
    final overLimit =
        widget.models.length > _HarnessGroupSection._inlineTileLimit;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
          label: widget.harnessName,
          value: context.l10n
              .providerScreenHarnessModelCount(widget.models.length),
          affordance: _expanded ? RowAffordance.collapse : RowAffordance.expand,
          onTap: () => setState(() => _expanded = !_expanded)),
      if (_expanded && !overLimit)
        for (final hm in widget.models) _tile(hm),
      if (_expanded && overLimit)
        Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: TerminalButton(
                label: context.l10n
                    .providerScreenBrowseAllModels(widget.models.length),
                onTap: () => _browseAll(context))),
    ]);
  }
}
