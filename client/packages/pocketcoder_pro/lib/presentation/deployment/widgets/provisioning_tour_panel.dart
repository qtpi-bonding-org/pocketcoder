import 'package:flutter/material.dart';
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
  });

  final OnboardingStage? stage;
  final String? sourceCommit;
  final GithubProvisioningSourceService sourceService;

  @override
  State<ProvisioningTourPanel> createState() => _ProvisioningTourPanelState();
}

class _ProvisioningTourPanelState extends State<ProvisioningTourPanel> {
  Future<List<_LoadedLesson>>? _lessons;
  String? _loadedCommit;
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
    if (oldWidget.sourceCommit != widget.sourceCommit) _loadSource();
  }

  void _loadSource() {
    final commit = widget.sourceCommit ?? '';
    if (!widget.sourceService.isImmutableCommit(commit)) {
      _loadedCommit = null;
      _lessons = null;
      return;
    }
    if (_loadedCommit == commit) return;
    _loadedCommit = commit;
    _lessons = _fetchLessons(commit);
  }

  Future<List<_LoadedLesson>> _fetchLessons(String commit) async {
    final byId = <String, (PocoCodeSection, ProvisioningSourceFile)>{};
    final sectionGroups = await Future.wait(
      ProvisioningSourceFile.values.map(
        (file) => widget.sourceService.fetchSections(
          sourceCommit: commit,
          file: file,
        ),
      ),
    );
    for (var index = 0;
        index < ProvisioningSourceFile.values.length;
        index += 1) {
      final file = ProvisioningSourceFile.values[index];
      final sections = sectionGroups[index];
      for (final section in sections) {
        byId[section.id] = (section, file);
      }
    }
    return _lessonOrder
        .map((id) {
          final value = byId[id];
          if (value == null) return null;
          return _LoadedLesson(
            section: value.$1,
            sourceFile: value.$2,
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
        lessons.indexWhere((lesson) => lesson.section.id == _selectedId);
    if (index < 0) index = 0;
    final lesson = lessons[index];
    return ProvisioningLessonCard(
      title: _lessonTitle(context, lesson.section.id),
      explanation: _lessonExplanation(context, lesson.section.id),
      importantCode: _importantCode(lesson.section.code),
      codeBlocks: [
        ProvisioningLessonCodeBlock(
          title: _lessonTitle(context, lesson.section.id),
          sourceLabel: '${lesson.sourceFile.path}:${lesson.section.startLine}',
          code: lesson.section.code,
        ),
      ],
      lessonNumber: index + 1,
      lessonCount: lessons.length,
      expanded: _showFullCode,
      onExpandedChanged: (value) => setState(() => _showFullCode = value),
      onPrevious: index == 0
          ? null
          : () => setState(() {
                _selectedId = lessons[index - 1].section.id;
                _showFullCode = false;
              }),
      onNext: index == lessons.length - 1
          ? null
          : () => setState(() {
                _selectedId = lessons[index + 1].section.id;
                _showFullCode = false;
              }),
    );
  }

  String _importantCode(String code) {
    final lines = code.split('\n');
    if (lines.length <= 18) return code;
    return lines.take(18).join('\n');
  }
}

class _LoadedLesson {
  const _LoadedLesson({required this.section, required this.sourceFile});
  final PocoCodeSection section;
  final ProvisioningSourceFile sourceFile;
}

const _lessonOrder = [
  'vps-storage',
  'vps-public-firewall',
  'vps-container-firewall',
  'vps-key-only-ssh',
  'vps-docker-engine',
  'bootstrap-owner-config',
  'bootstrap-local-secrets',
  'bootstrap-release-source',
  'bootstrap-verified-images',
  'bootstrap-compose-start',
  'compose-pocketbase',
  'compose-agent',
  'compose-local-model',
  'compose-harness-images',
  'compose-mcp-sandbox',
  'compose-memory',
  'compose-pocketbase-docker-access',
  'compose-dashboard',
  'compose-notifications',
  'compose-private-access',
  'compose-local-caddy',
  'compose-persistent-volumes',
  'compose-private-networks',
];

String? _preferredLessonId(OnboardingStage? stage) => switch (stage) {
      OnboardingStage.validating ||
      OnboardingStage.creatingServer ||
      OnboardingStage.preparingHost ||
      OnboardingStage.hostReady ||
      OnboardingStage.securingConnection =>
        'vps-public-firewall',
      OnboardingStage.installingHost => 'vps-key-only-ssh',
      OnboardingStage.fetchingRelease => 'bootstrap-release-source',
      OnboardingStage.loadingImages => 'bootstrap-verified-images',
      OnboardingStage.startingServices => 'compose-pocketbase',
      OnboardingStage.finishingUp ||
      OnboardingStage.ready =>
        'compose-private-networks',
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
