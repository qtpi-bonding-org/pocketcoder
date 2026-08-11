import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/domain/deployment/poco_code_section.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/provisioning_lesson_card.dart';

class ProvisioningTourPanel extends StatefulWidget {
  const ProvisioningTourPanel({
    super.key,
    required this.stage,
    required this.sourceCommit,
    required this.sourceService,
    required this.backend,
  });

  final OnboardingStage? stage;
  final String? sourceCommit;
  final GithubProvisioningSourceService sourceService;
  final ProvisionBackendKind backend;

  @override
  State<ProvisioningTourPanel> createState() => _ProvisioningTourPanelState();
}

class _ProvisioningTourPanelState extends State<ProvisioningTourPanel> {
  Future<List<_LoadedLesson>>? _lessons;
  String? _loadedCommit;
  ProvisionBackendKind? _loadedBackend;
  String? _selectedId;
  bool _showFullCode = false;

  @override
  void initState() {
    super.initState();
    _selectedId = _preferredLessonId(widget.stage);
    _loadSource();
  }

  @override
  void didUpdateWidget(covariant ProvisioningTourPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) {
      _selectedId = _preferredLessonId(widget.stage);
      _showFullCode = false;
    }
    if (oldWidget.sourceCommit != widget.sourceCommit ||
        oldWidget.backend != widget.backend) {
      _loadSource();
    }
  }

  void _loadSource() {
    final commit = widget.sourceCommit ?? '';
    if (!widget.sourceService.isImmutableCommit(commit)) {
      _loadedCommit = null;
      _loadedBackend = null;
      _lessons = null;
      return;
    }
    if (_loadedCommit == commit && _loadedBackend == widget.backend) return;
    _loadedCommit = commit;
    _loadedBackend = widget.backend;
    _lessons = _fetchLessons(commit, widget.backend);
  }

  Future<List<_LoadedLesson>> _fetchLessons(
    String commit,
    ProvisionBackendKind backend,
  ) async {
    final byId = <String, (PocoCodeSection, ProvisioningSourceFile)>{};
    final sourceFiles = provisioningSourceFilesFor(backend);
    final sectionGroups = await Future.wait(
      sourceFiles.map(
        (file) => widget.sourceService.fetchSections(
          sourceCommit: commit,
          file: file,
        ),
      ),
    );
    for (var index = 0; index < sourceFiles.length; index += 1) {
      final file = sourceFiles[index];
      final sections = sectionGroups[index];
      for (final section in sections) {
        byId[section.id] = (section, file);
      }
    }
    return _lessonDefinitions
        .map((definition) {
          final parts = definition.sectionIds
              .map((id) {
                final value = byId[id];
                if (value == null) return null;
                return _LoadedLessonPart(
                  section: value.$1,
                  sourceFile: value.$2,
                );
              })
              .whereType<_LoadedLessonPart>()
              .toList(growable: false);
          if (parts.isEmpty) return null;
          return _LoadedLesson(
            definition: definition,
            parts: parts,
          );
        })
        .whereType<_LoadedLesson>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final future = _lessons;
    return BiosFrame(
      title: context.l10n.pocoProvisioningTourTitle,
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: future == null
            ? PocoBubble(
                message: context.l10n.pocoProvisioningWaitingForSource,
                sequence: PocoExpressions.scanning,
                pocoSize: AppSizes.fontLarge,
              )
            : FutureBuilder<List<_LoadedLesson>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return PocoBubble(
                      message: context.l10n.pocoProvisioningLoadingSource,
                      sequence: PocoExpressions.scanning,
                      pocoSize: AppSizes.fontLarge,
                    );
                  }
                  final lessons = snapshot.data ?? const <_LoadedLesson>[];
                  if (snapshot.hasError || lessons.isEmpty) {
                    return PocoBubble(
                      message: context.l10n.pocoProvisioningSourceUnavailable,
                      sequence: PocoExpressions.nervous,
                      pocoSize: AppSizes.fontLarge,
                    );
                  }
                  return _buildLesson(context, lessons);
                },
              ),
      ),
    );
  }

  Widget _buildLesson(BuildContext context, List<_LoadedLesson> lessons) {
    var index =
        lessons.indexWhere((lesson) => lesson.definition.id == _selectedId);
    if (index < 0) index = 0;
    final lesson = lessons[index];
    return ProvisioningLessonCard(
      title: _lessonTitle(context, lesson.copyId),
      explanation: _lessonExplanation(context, lesson.copyId),
      codeBlocks: lesson.parts
          .map(
            (part) => ProvisioningLessonCodeBlock(
              title: _lessonTitle(context, part.section.id),
              sourceLabel: '${part.sourceFile.path}:${part.section.startLine}',
              code: part.section.code,
              importantCode: part.section.importantCode,
            ),
          )
          .toList(growable: false),
      lessonNumber: index + 1,
      lessonCount: lessons.length,
      expanded: _showFullCode,
      onExpandedChanged: (value) => setState(() => _showFullCode = value),
      onPrevious: index == 0
          ? null
          : () => setState(() {
                _selectedId = lessons[index - 1].definition.id;
                _showFullCode = false;
              }),
      onNext: index == lessons.length - 1
          ? null
          : () => setState(() {
                _selectedId = lessons[index + 1].definition.id;
                _showFullCode = false;
              }),
    );
  }
}

class _LoadedLesson {
  const _LoadedLesson({required this.definition, required this.parts});

  final _LessonDefinition definition;
  final List<_LoadedLessonPart> parts;

  String get copyId {
    if (parts.any((part) => part.section.id == definition.copyId)) {
      return definition.copyId;
    }
    return parts.first.section.id;
  }
}

class _LoadedLessonPart {
  const _LoadedLessonPart({required this.section, required this.sourceFile});

  final PocoCodeSection section;
  final ProvisioningSourceFile sourceFile;
}

class _LessonDefinition {
  const _LessonDefinition({
    required this.id,
    required this.copyId,
    required this.sectionIds,
  });

  final String id;
  final String copyId;
  final List<String> sectionIds;
}

const _lessonDefinitions = [
  _LessonDefinition(
    id: 'host-boundaries',
    copyId: 'vps-public-firewall',
    sectionIds: [
      'vps-storage',
      'vps-public-firewall',
      'vps-container-firewall',
      'vps-key-only-ssh',
    ],
  ),
  _LessonDefinition(
    id: 'host-runtime',
    copyId: 'vps-docker-engine',
    sectionIds: [
      'vps-docker-engine',
      'bootstrap-owner-config',
      'bootstrap-local-secrets',
    ],
  ),
  _LessonDefinition(
    id: 'verified-release',
    copyId: 'bootstrap-release-source',
    sectionIds: [
      'bootstrap-release-source',
      'bootstrap-verified-images',
      'bootstrap-compose-start',
    ],
  ),
  _LessonDefinition(
    id: 'core-and-agent',
    copyId: 'compose-pocketbase',
    sectionIds: ['compose-pocketbase', 'compose-agent'],
  ),
  _LessonDefinition(
    id: 'optional-runtimes',
    copyId: 'compose-local-model',
    sectionIds: ['compose-local-model', 'compose-harness-images'],
  ),
  _LessonDefinition(
    id: 'tool-sandbox',
    copyId: 'compose-mcp-sandbox',
    sectionIds: ['compose-mcp-sandbox'],
  ),
  _LessonDefinition(
    id: 'scoped-control',
    copyId: 'compose-memory',
    sectionIds: ['compose-memory', 'compose-pocketbase-docker-access'],
  ),
  _LessonDefinition(
    id: 'private-interfaces',
    copyId: 'compose-dashboard',
    sectionIds: [
      'compose-dashboard',
      'compose-notifications',
      'compose-private-access',
    ],
  ),
  _LessonDefinition(
    id: 'durable-edge',
    copyId: 'compose-local-caddy',
    sectionIds: ['compose-local-caddy', 'compose-persistent-volumes'],
  ),
  _LessonDefinition(
    id: 'private-networks',
    copyId: 'compose-private-networks',
    sectionIds: ['compose-private-networks'],
  ),
];

String? _preferredLessonId(OnboardingStage? stage) => switch (stage) {
      OnboardingStage.validating ||
      OnboardingStage.creatingServer ||
      OnboardingStage.preparingHost ||
      OnboardingStage.hostReady ||
      OnboardingStage.securingConnection =>
        'host-boundaries',
      OnboardingStage.installingHost => 'host-runtime',
      OnboardingStage.fetchingRelease ||
      OnboardingStage.loadingImages =>
        'verified-release',
      OnboardingStage.startingServices => 'core-and-agent',
      OnboardingStage.finishingUp ||
      OnboardingStage.ready =>
        'private-networks',
      OnboardingStage.failed || null => null,
    };

String _lessonTitle(BuildContext context, String id) => switch (id) {
      'vps-storage' => context.l10n.pocoLessonVpsStorageTitle,
      'vps-public-firewall' => context.l10n.pocoLessonPublicFirewallTitle,
      'vps-container-firewall' => context.l10n.pocoLessonContainerFirewallTitle,
      'vps-key-only-ssh' => context.l10n.pocoLessonSshTitle,
      'vps-docker-engine' => context.l10n.pocoLessonDockerTitle,
      'bootstrap-owner-config' => context.l10n.pocoLessonOwnerConfigTitle,
      'bootstrap-local-secrets' => context.l10n.pocoLessonLocalSecretsTitle,
      'bootstrap-release-source' => context.l10n.pocoLessonReleaseSourceTitle,
      'bootstrap-verified-images' => context.l10n.pocoLessonVerifiedImagesTitle,
      'bootstrap-compose-start' => context.l10n.pocoLessonComposeStartTitle,
      'compose-pocketbase' => context.l10n.pocoLessonPocketbaseTitle,
      'compose-agent' => context.l10n.pocoLessonAgentTitle,
      'compose-local-model' => context.l10n.pocoLessonLocalModelTitle,
      'compose-harness-images' => context.l10n.pocoLessonHarnessImagesTitle,
      'compose-mcp-sandbox' => context.l10n.pocoLessonMcpSandboxTitle,
      'compose-memory' => context.l10n.pocoLessonMemoryTitle,
      'compose-pocketbase-docker-access' =>
        context.l10n.pocoLessonPocketbaseDockerAccessTitle,
      'compose-dashboard' => context.l10n.pocoLessonDashboardTitle,
      'compose-notifications' => context.l10n.pocoLessonNotificationsTitle,
      'compose-private-access' => context.l10n.pocoLessonPrivateAccessTitle,
      'compose-local-caddy' => context.l10n.pocoLessonLocalCaddyTitle,
      'compose-persistent-volumes' => context.l10n.pocoLessonVolumesTitle,
      'compose-private-networks' => context.l10n.pocoLessonNetworksTitle,
      _ => id,
    };

String _lessonExplanation(BuildContext context, String id) => switch (id) {
      'vps-storage' => context.l10n.pocoLessonVpsStorageExplanation,
      'vps-public-firewall' => context.l10n.pocoLessonPublicFirewallExplanation,
      'vps-container-firewall' =>
        context.l10n.pocoLessonContainerFirewallExplanation,
      'vps-key-only-ssh' => context.l10n.pocoLessonSshExplanation,
      'vps-docker-engine' => context.l10n.pocoLessonDockerExplanation,
      'bootstrap-owner-config' => context.l10n.pocoLessonOwnerConfigExplanation,
      'bootstrap-local-secrets' =>
        context.l10n.pocoLessonLocalSecretsExplanation,
      'bootstrap-release-source' =>
        context.l10n.pocoLessonReleaseSourceExplanation,
      'bootstrap-verified-images' =>
        context.l10n.pocoLessonVerifiedImagesExplanation,
      'bootstrap-compose-start' =>
        context.l10n.pocoLessonComposeStartExplanation,
      'compose-pocketbase' => context.l10n.pocoLessonPocketbaseExplanation,
      'compose-agent' => context.l10n.pocoLessonAgentExplanation,
      'compose-local-model' => context.l10n.pocoLessonLocalModelExplanation,
      'compose-harness-images' =>
        context.l10n.pocoLessonHarnessImagesExplanation,
      'compose-mcp-sandbox' => context.l10n.pocoLessonMcpSandboxExplanation,
      'compose-memory' => context.l10n.pocoLessonMemoryExplanation,
      'compose-pocketbase-docker-access' =>
        context.l10n.pocoLessonPocketbaseDockerAccessExplanation,
      'compose-dashboard' => context.l10n.pocoLessonDashboardExplanation,
      'compose-notifications' =>
        context.l10n.pocoLessonNotificationsExplanation,
      'compose-private-access' =>
        context.l10n.pocoLessonPrivateAccessExplanation,
      'compose-local-caddy' => context.l10n.pocoLessonLocalCaddyExplanation,
      'compose-persistent-volumes' => context.l10n.pocoLessonVolumesExplanation,
      'compose-private-networks' => context.l10n.pocoLessonNetworksExplanation,
      _ => id,
    };
