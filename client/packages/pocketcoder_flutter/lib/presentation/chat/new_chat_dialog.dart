import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart'
    show validateWorkspacePath, WorkspacePathValidationError, supportsOllamaHarness;
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_picker_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

/// The selection a confirmed [NewChatDialog] returns — `null` fields mean
/// "no override, inherit from the chat's poco_config" (design spec §5.7).
class NewChatSelection {
  const NewChatSelection({
    required this.title,
    this.harness,
    this.harnessModelOverride,
    this.ollamaModelOverride,
    this.workspaceOverride,
  });

  final String title;
  final String? harness;
  final String? harnessModelOverride;
  final String? ollamaModelOverride;
  final List<String>? workspaceOverride;
}

/// Lets a user pick cwd + harness + model before a chat is created (design
/// spec §1, §7) — the same choice a terminal user makes picking a working
/// directory and a CLI before starting a session. Reuses the existing
/// [IProviderRepository] streams (already built for [ProviderScreen]) rather
/// than adding new PocketBase-facing surface.
class NewChatDialog extends StatefulWidget {
  const NewChatDialog({
    super.key,
    required this.harnesses,
    required this.models,
    required this.harnessModels,
    required this.harnessProviders,
    this.providers = const [],
    required this.providerAPIKeys,
    this.credentialSelections = const [],
    this.harnessOAuthAccounts = const [],
    required this.ollamaModels,
  });

  final List<Harnesse> harnesses;
  final List<Model> models;
  final List<HarnessModel> harnessModels;
  final List<HarnessProvider> harnessProviders;
  final List<domain.Provider> providers;
  final List<ProviderApiKey> providerAPIKeys;
  final List<CredentialSelection> credentialSelections;
  final List<HarnessOauthAccount> harnessOAuthAccounts;
  final List<OllamaModel> ollamaModels;

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _titleController = TextEditingController();
  final _cwdController = TextEditingController();
  Harnesse? _selectedHarness;
  _ModelChoice? _selectedModel;
  String? _cwdError;

  late final _modelsById = {for (final m in widget.models) m.id: m};
  late final _providerNamesById = {
    for (final p in widget.providers) p.id: p.name,
  };
  late final _keyedProviderIds = {
    for (final k in widget.providerAPIKeys) k.provider,
    for (final c in widget.credentialSelections) c.provider,
    for (final a in widget.harnessOAuthAccounts)
      if (a.status == HarnessOauthAccountStatus.connected) a.provider,
  };

  @override
  void dispose() {
    _titleController.dispose();
    _cwdController.dispose();
    super.dispose();
  }

  void _submit() {
    final cwd = _cwdController.text.trim();
    if (cwd.isNotEmpty) {
      final error = validateWorkspacePath(cwd);
      if (error != null) {
        setState(() {
          _cwdError = switch (error) {
            WorkspacePathValidationError.empty =>
              context.l10n.newChatWorkspaceErrorEmpty,
            WorkspacePathValidationError.outsideWorkspace =>
              context.l10n.newChatWorkspaceErrorInvalid,
          };
        });
        return;
      }
    }
    final title = _titleController.text.trim();
    Navigator.of(context).pop(NewChatSelection(
      title: title.isEmpty ? context.l10n.newChatTitle : title,
      harness: _selectedHarness?.id,
      harnessModelOverride: _selectedModel?.harnessModelId,
      ollamaModelOverride: _selectedModel?.ollamaModel,
      workspaceOverride: cwd.isEmpty ? null : [cwd],
    ));
  }

  bool _isUsable(HarnessModel hm, Harnesse harness) {
    if (harness.providerFanout != true) return true;
    final provider = _modelsById[hm.model]?.provider;
    return provider == null || _keyedProviderIds.contains(provider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedHarness = _selectedHarness;
    final availableModels = selectedHarness == null
        ? const <HarnessModel>[]
        : widget.harnessModels
            .where((hm) =>
                hm.harness == selectedHarness.id &&
                _isUsable(hm, selectedHarness))
            .toList();

    return _buildDialog(
      context,
      harnesses: widget.harnesses,
      availableModels: availableModels,
      ollamaModels: widget.ollamaModels,
    );
  }

  Widget _buildDialog(
    BuildContext context, {
    required List<Harnesse> harnesses,
    required List<HarnessModel> availableModels,
    required List<OllamaModel> ollamaModels,
  }) {
    final selectedHarness = _selectedHarness;
    final choices = [
      for (final hm in availableModels)
        _ModelChoice.catalog(
            hm.id, _modelDisplayName(hm), _providerGroupLabel(hm)),
      if (selectedHarness != null &&
          supportsOllamaHarness(selectedHarness.cliId))
        for (final model in ollamaModels) _ModelChoice.ollama(model.name),
    ];
    return TerminalDialog(
      title: context.l10n.newChatTitle.toLowerCase(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalTextField(
            controller: _titleController,
            label: context.l10n.newChatTitleField,
          ),
          VSpace.x2,
          ChatPickerField<Harnesse>(
            label: context.l10n.newChatHarnessField,
            dialogTitle: context.l10n.newChatSelectHarness,
            emptyLabel: context.l10n.newChatSelectHarness,
            options: harnesses,
            selected: _selectedHarness,
            optionLabel: (h) => h.name,
            onSelected: (h) => setState(() {
              _selectedHarness = h;
              _selectedModel = null;
            }),
          ),
          VSpace.x2,
          ChatPickerField<_ModelChoice>(
            label: context.l10n.newChatModelField,
            dialogTitle: context.l10n.newChatSelectModel,
            emptyLabel: context.l10n.newChatSelectModel,
            noOptionsLabel: context.l10n.newChatNoModelsAvailable,
            options: choices,
            selected: _selectedModel,
            optionLabel: (choice) => choice.label,
            groupLabel: (choice) => choice.groupLabel,
            onSelected: (choice) => setState(() => _selectedModel = choice),
          ),
          VSpace.x2,
          TerminalTextField(
            controller: _cwdController,
            label: context.l10n.newChatCwdField,
            hint: context.l10n.newChatCwdHint,
            errorText: _cwdError,
          ),
        ],
      ),
      actions: [
        TerminalButton(
          label: context.l10n.newChatCancel,
          kind: ActionKind.neutral,
          onTap: () => Navigator.of(context).pop(),
        ),
        TerminalButton(
          label: context.l10n.newChatCreate,
          onTap: _submit,
        ),
      ],
    );
  }

  String _modelDisplayName(HarnessModel hm) {
    final m = _modelsById[hm.model];
    if (m == null) return hm.harnessModelId;
    final dn = m.displayName;
    return dn != null && dn.isNotEmpty ? dn : m.name;
  }

  String _providerGroupLabel(HarnessModel hm) {
    final providerId = _modelsById[hm.model]?.provider;
    return _providerNamesById[providerId] ?? '';
  }
}

class _ModelChoice {
  const _ModelChoice.catalog(this.harnessModelId, this.label, this.groupLabel)
      : ollamaModel = null;

  const _ModelChoice.ollama(String name)
      : harnessModelId = null,
        ollamaModel = name,
        label = '$name (LOCAL)',
        groupLabel = 'Local';

  final String? harnessModelId;
  final String? ollamaModel;
  final String label;
  final String groupLabel;
}
