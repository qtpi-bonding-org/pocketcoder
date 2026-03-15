import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/llm/llm_cubit.dart';
import 'package:pocketcoder_flutter/application/llm/llm_state.dart';
import 'package:pocketcoder_flutter/domain/models/llm_provider.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class LlmManagementScreen extends StatelessWidget {
  const LlmManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<LlmCubit>()..watchAll(),
      child: UiFlowListener<LlmCubit, LlmState>(
        child: const _LlmManagementView(),
      ),
    );
  }
}

class _LlmManagementView extends StatelessWidget {
  const _LlmManagementView();

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.llmTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BlocBuilder<LlmCubit, LlmState>(
        builder: (context, state) {
          if (state.isLoading && state.providers.isEmpty) {
            return Center(
              child: TerminalLoadingIndicator(label: context.l10n.llmLoadingProviders),
            );
          }

          return ListView(
            padding: EdgeInsets.all(AppSizes.space),
            children: [
              // ── ACTIVE MODEL ──
              BiosSection(
                title: context.l10n.llmActiveModelSection,
                child: _buildActiveModel(context, state),
              ),

              // ── PROVIDERS & KEYS ──
              BiosSection(
                title: context.l10n.llmProvidersSection,
                child: _buildProviderList(context, state),
              ),

              // ── CONFIGURED KEYS ──
              if (state.keys.isNotEmpty)
                BiosSection(
                  title: context.l10n.llmApiKeysSection,
                  child: _buildKeyList(context, state),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── ACTIVE MODEL SECTION ──

  Widget _buildActiveModel(BuildContext context, LlmState state) {
    final colors = context.colorScheme;
    final globalConfig = state.configs.where((c) => c.chat == null).toList();
    final currentModel =
        globalConfig.isNotEmpty ? globalConfig.first.model : null;

    // Collect all available models from connected providers
    final allModels = _collectAvailableModels(state);

    return BiosFrame(
      title: context.l10n.llmGlobalDefault,
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    currentModel?.toUpperCase() ?? context.l10n.llmNotSet,
                    size: TerminalTextSize.base,
                    weight: TerminalTextWeight.heavy,
                    color: currentModel != null
                        ? colors.primary
                        : null,
                    alpha: currentModel != null ? null : 0.5,
                  ),
                ),
                TerminalButton(
                  label: context.l10n.actionChange,
                  onTap: allModels.isNotEmpty
                      ? () => _showModelPicker(context, allModels)
                      : () {},
                ),
              ],
            ),
            if (allModels.isEmpty) ...[
              VSpace.x1,
              TerminalText.mini(
                context.l10n.llmAddKeyHint,
                alpha: 0.5,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── PROVIDER LIST ──

  Widget _buildProviderList(BuildContext context, LlmState state) {
    if (state.providers.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Center(
          child: TerminalText(
            context.l10n.llmNoProviders,
            alpha: 0.5,
          ),
        ),
      );
    }

    return Column(
      children: state.providers.map((provider) {
        final hasKey = state.keys.any((k) => k.providerId == provider.providerId);
        return _buildProviderTile(context, provider, hasKey);
      }).toList(),
    );
  }

  Widget _buildProviderTile(
      BuildContext context, LlmProvider provider, bool hasKey) {
    final colors = context.colorScheme;

    final models = _parseModels(provider.models);
    final modelCount = models.length;

    return TerminalCard(
      isActive: hasKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TerminalText(
                provider.name.toUpperCase(),
                weight: TerminalTextWeight.heavy,
              ),
              TerminalText.label(
                hasKey ? context.l10n.llmConnected : context.l10n.llmNoKey,
                color: hasKey ? colors.primary : null,
                alpha: hasKey ? null : 0.5,
              ),
            ],
          ),
          if (modelCount > 0) ...[
            VSpace.x1,
            TerminalText.mini(
              context.l10n.llmModelsAvailable(modelCount),
              alpha: 0.5,
            ),
          ],
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: hasKey ? context.l10n.llmUpdateKey : context.l10n.llmAddKey,
                  onTap: () => _showKeyDialog(context, provider),
                ),
              ),
              if (hasKey) ...[
                HSpace.x2,
                TerminalButton(
                  label: context.l10n.llmModelsButton,
                  isPrimary: false,
                  onTap: () =>
                      _showProviderModels(context, provider),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── KEY LIST ──

  Widget _buildKeyList(BuildContext context, LlmState state) {
    final colors = context.colorScheme;

    return Column(
      children: state.keys.map((key) {
        // Find the provider name for display
        final provider = state.providers
            .where((p) => p.providerId == key.providerId)
            .toList();
        final providerName =
            provider.isNotEmpty ? provider.first.name : key.providerId;

        return TerminalCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TerminalText(
                      providerName.toUpperCase(),
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
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: colors.error,
                ),
                onPressed: () => context.read<LlmCubit>().deleteKey(key.id),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── DIALOGS ──

  void _showKeyDialog(BuildContext context, LlmProvider provider) {
    final Map<String, TextEditingController> controllers = {};

    if (provider.envVars != null && provider.envVars is Map) {
      final schema = Map<String, dynamic>.from(provider.envVars);
      schema.forEach((key, value) {
        controllers[key] = TextEditingController();
      });
    }

    // Fallback: if no schema, provide a single generic key field
    if (controllers.isEmpty) {
      controllers['API_KEY'] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.llmApiKeyDialogTitle(provider.name.toUpperCase()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalText(
              context.l10n.llmEnterCredentials(provider.name),
              alpha: 0.7,
            ),
            VSpace.x2,
            ...controllers.entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(bottom: AppSizes.space),
                child: TerminalTextField(
                  controller: entry.value,
                  label: entry.key,
                  obscureText: true,
                  hint: entry.key,
                ),
              );
            }),
          ],
        ),
        actions: [
          TerminalButton(
            label: context.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.pop(dialogContext),
          ),
          HSpace.x2,
          TerminalButton(
            label: context.l10n.actionSave,
            onTap: () {
              final envVars = <String, dynamic>{};
              controllers.forEach((key, controller) {
                if (controller.text.isNotEmpty) {
                  envVars[key] = controller.text;
                }
              });
              if (envVars.isNotEmpty) {
                context
                    .read<LlmCubit>()
                    .saveKey(provider.providerId, envVars);
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showModelPicker(BuildContext context, List<String> models) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return TerminalDialog(
          title: context.l10n.llmSelectModelTitle,
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (ctx, index) {
                final model = models[index];
                return InkWell(
                  onTap: () {
                    context.read<LlmCubit>().setModel(model);
                    Navigator.pop(dialogContext);
                  },
                  child: Container(
                    padding: EdgeInsets.all(AppSizes.space),
                    margin: EdgeInsets.only(bottom: AppSizes.space * 0.5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TerminalText(
                      model.toUpperCase(),
                      weight: TerminalTextWeight.heavy,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TerminalButton(
              label: context.l10n.actionCancel,
              isPrimary: false,
              onTap: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }

  void _showProviderModels(BuildContext context, LlmProvider provider) {
    final models = _parseModels(provider.models);
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.llmProviderModelsTitle(provider.name.toUpperCase()),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: models.isEmpty
              ? Center(
                  child: TerminalText(
                    context.l10n.llmNoModels,
                    alpha: 0.5,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (ctx, index) {
                    final model = models[index];
                    return InkWell(
                      onTap: () {
                        context.read<LlmCubit>().setModel(model);
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        padding: EdgeInsets.all(AppSizes.space),
                        margin:
                            EdgeInsets.only(bottom: AppSizes.space * 0.5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                colors.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TerminalText(
                                model.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TerminalText.label(
                              context.l10n.llmSelect,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TerminalButton(
            label: context.l10n.actionClose,
            isPrimary: false,
            onTap: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──

  List<String> _collectAvailableModels(LlmState state) {
    final connectedProviderIds =
        state.keys.map((k) => k.providerId).toSet();
    final models = <String>[];
    for (final provider in state.providers) {
      if (connectedProviderIds.contains(provider.providerId)) {
        models.addAll(_parseModels(provider.models));
      }
    }
    return models;
  }

  List<String> _parseModels(dynamic models) {
    if (models == null) return [];
    if (models is List) {
      return models.map((m) => m.toString()).toList();
    }
    return [];
  }

  String _maskKeyPreview(dynamic envVars) {
    if (envVars == null) return '***';
    if (envVars is Map && envVars.isNotEmpty) {
      final firstValue = envVars.values.first.toString();
      if (firstValue.length > 8) {
        return '${firstValue.substring(0, 4)}..${firstValue.substring(firstValue.length - 4)}';
      }
      return '****';
    }
    return '***';
  }
}
