import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

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
    required this.providerRepository,
    required this.loadOllamaModels,
  });

  final IProviderRepository providerRepository;
  final Future<List<OllamaModel>> Function() loadOllamaModels;

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _titleController = TextEditingController();
  final _cwdController = TextEditingController();
  Harnesse? _selectedHarness;
  _ModelChoice? _selectedModel;
  Future<List<OllamaModel>>? _ollamaModels;
  String? _cwdError;

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
        setState(() => _cwdError = error);
        return;
      }
    }
    final title = _titleController.text.trim();
    Navigator.of(context).pop(NewChatSelection(
      title: title.isEmpty ? 'New Chat' : title,
      harness: _selectedHarness?.id,
      harnessModelOverride: _selectedModel?.harnessModelId,
      ollamaModelOverride: _selectedModel?.ollamaModel,
      workspaceOverride: cwd.isEmpty ? null : [cwd],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Harnesse>>(
      stream: widget.providerRepository.watchHarnesses(),
      initialData: const [],
      builder: (context, harnessSnap) {
        final harnesses = harnessSnap.data ?? const [];
        return StreamBuilder<List<Model>>(
          stream: widget.providerRepository.watchModels(),
          initialData: const [],
          builder: (context, modelSnap) {
            final models = modelSnap.data ?? const [];
            return StreamBuilder<List<HarnessModel>>(
              stream: widget.providerRepository.watchHarnessModels(),
              initialData: const [],
              builder: (context, hmSnap) {
                final harnessModels = hmSnap.data ?? const [];
                return StreamBuilder<List<ProviderKey>>(
                  stream: widget.providerRepository.watchProviderKeys(),
                  initialData: const [],
                  builder: (context, keySnap) {
                    final providerKeys = keySnap.data ?? const [];
                    final selectedHarness = _selectedHarness;
                    final availableModels = selectedHarness == null
                        ? const <HarnessModel>[]
                        : selectableModels(
                            harnessId: selectedHarness.id,
                            harnessModels: harnessModels,
                            models: models,
                            providerKeys: providerKeys,
                          );

                    return FutureBuilder<List<OllamaModel>>(
                      future: _ollamaModels,
                      initialData: const [],
                      builder: (context, ollamaSnap) => _buildDialog(
                        context,
                        harnesses: harnesses,
                        models: models,
                        availableModels: availableModels,
                        ollamaModels: ollamaSnap.data ?? const [],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDialog(
    BuildContext context, {
    required List<Harnesse> harnesses,
    required List<Model> models,
    required List<HarnessModel> availableModels,
    required List<OllamaModel> ollamaModels,
  }) {
    final choices = [
      for (final hm in availableModels)
        _ModelChoice.catalog(hm.id, _modelDisplayName(models, hm)),
      if (_selectedHarness != null &&
          supportsOllamaHarness(_selectedHarness!.cliId))
        for (final model in ollamaModels) _ModelChoice.ollama(model.name),
    ];
    return TerminalDialog(
      title: context.l10n.newChatTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalTextField(
            controller: _titleController,
            label: context.l10n.newChatTitleField,
          ),
          VSpace.x2,
          _PickerField<Harnesse>(
            label: context.l10n.newChatHarnessField,
            dialogTitle: context.l10n.newChatSelectHarness,
            emptyLabel: context.l10n.newChatSelectHarness,
            options: harnesses,
            selected: _selectedHarness,
            optionLabel: (h) => h.name,
            onSelected: (h) => setState(() {
              _selectedHarness = h;
              _selectedModel = null;
              _ollamaModels = supportsOllamaHarness(h.cliId)
                  ? widget.loadOllamaModels()
                  : null;
            }),
          ),
          VSpace.x2,
          _PickerField<_ModelChoice>(
            label: context.l10n.newChatModelField,
            dialogTitle: context.l10n.newChatSelectModel,
            emptyLabel: context.l10n.newChatSelectModel,
            noOptionsLabel: context.l10n.newChatNoModelsAvailable,
            options: choices,
            selected: _selectedModel,
            optionLabel: (choice) => choice.label,
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
          isPrimary: false,
          onTap: () => Navigator.of(context).pop(),
        ),
        HSpace.x2,
        TerminalButton(
          label: context.l10n.newChatCreate,
          onTap: _submit,
        ),
      ],
    );
  }

  String _modelDisplayName(List<Model> models, HarnessModel hm) {
    for (final m in models) {
      if (m.id == hm.model) {
        final dn = m.displayName;
        return dn != null && dn.isNotEmpty ? dn : m.name;
      }
    }
    return hm.harnessModelId;
  }
}

class _ModelChoice {
  const _ModelChoice.catalog(this.harnessModelId, this.label)
      : ollamaModel = null;

  const _ModelChoice.ollama(String name)
      : harnessModelId = null,
        ollamaModel = name,
        label = '$name (LOCAL)';

  final String? harnessModelId;
  final String? ollamaModel;
  final String label;
}

/// A tap-to-open picker matching the terminal/BIOS UI's existing convention
/// (see `_HarnessPicker` in `provider_screen.dart`) — no shared/exported
/// dropdown widget exists in `design_system/` to reuse, so this mirrors that
/// same InkWell-opens-a-list-`TerminalDialog` pattern generically.
class _PickerField<T> extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.dialogTitle,
    required this.emptyLabel,
    required this.options,
    required this.selected,
    required this.optionLabel,
    required this.onSelected,
    this.noOptionsLabel,
    super.key,
  });

  final String label;
  final String dialogTitle;
  final String emptyLabel;
  final String? noOptionsLabel;
  final List<T> options;
  final T? selected;
  final String Function(T) optionLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final selectedValue = selected;
    final currentLabel =
        selectedValue == null ? emptyLabel : optionLabel(selectedValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalText.tiny(label.toUpperCase(), color: colors.onSurface),
        VSpace.x1,
        InkWell(
          onTap: () => _openPicker(context),
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border:
                  Border.all(color: colors.onSurface.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    currentLabel,
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

  void _openPicker(BuildContext context) async {
    final picked = await showDialog<T>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: dialogTitle,
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: options.isEmpty
              ? Center(
                  child: TerminalText(
                    noOptionsLabel ?? emptyLabel,
                    alpha: 0.5,
                  ),
                )
              : ListView(
                  children: [
                    for (final option in options)
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(option),
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space),
                          child: TerminalText(optionLabel(option)),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TerminalButton(
            label: context.l10n.newChatCancel,
            isPrimary: false,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
    if (picked != null) onSelected(picked);
  }
}
