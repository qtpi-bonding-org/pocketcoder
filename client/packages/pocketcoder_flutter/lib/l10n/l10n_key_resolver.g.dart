// GENERATED CODE - DO NOT MODIFY BY HAND
// Generator: l10n_key_resolver
// Generated at: 2026-08-12T04:40:47.914044

import 'app_localizations.dart';

/// Generated resolver for l10n keys.
///
/// Maps dot-notation keys to AppLocalizations getters.
///
/// Usage:
/// ```dart
/// final resolver = L10nKeyResolver(l10n);
/// final message = resolver.resolve('error.auth.failed');
/// ```
class L10nKeyResolver {
  final AppLocalizations _l10n;

  const L10nKeyResolver(this._l10n);

  /// Resolves a dot-notation key to its localized string.
  ///
  /// Returns null if the key is not found.
  ///
  /// For parameterized messages, pass the arguments map.
  String? resolve(String key, {Map<String, dynamic>? args}) {
    return (switch (key) {
      // Simple keys (no parameters)
      'action.add' => _l10n.actionAdd,
      'action.add.new' => _l10n.actionAddNew,
      'action.authorize' => _l10n.actionAuthorize,
      'action.back' => _l10n.actionBack,
      'action.cancel' => _l10n.actionCancel,
      'action.change' => _l10n.actionChange,
      'action.close' => _l10n.actionClose,
      'action.configure' => _l10n.actionConfigure,
      'action.continue' => _l10n.actionContinue,
      'action.create' => _l10n.actionCreate,
      'action.deny' => _l10n.actionDeny,
      'action.refresh' => _l10n.actionRefresh,
      'action.reject' => _l10n.actionReject,
      'action.restore' => _l10n.actionRestore,
      'action.save' => _l10n.actionSave,
      'agent.config.default.badge' => _l10n.agentConfigDefaultBadge,
      'agent.config.delete' => _l10n.agentConfigDelete,
      'agent.config.delete.confirm.title' => _l10n.agentConfigDeleteConfirmTitle,
      'agent.config.empty' => _l10n.agentConfigEmpty,
      'agent.config.harness.model.label' => _l10n.agentConfigHarnessModelLabel,
      'agent.config.is.default.label' => _l10n.agentConfigIsDefaultLabel,
      'agent.config.mode.label' => _l10n.agentConfigModeLabel,
      'agent.config.name.label' => _l10n.agentConfigNameLabel,
      'agent.config.no.harness.models' => _l10n.agentConfigNoHarnessModels,
      'agent.config.no.modes' => _l10n.agentConfigNoModes,
      'agent.config.no.prompts' => _l10n.agentConfigNoPrompts,
      'agent.config.prompt.label' => _l10n.agentConfigPromptLabel,
      'agent.config.registry' => _l10n.agentConfigRegistry,
      'agent.config.select.harness.model' => _l10n.agentConfigSelectHarnessModel,
      'agent.config.select.mode' => _l10n.agentConfigSelectMode,
      'agent.config.select.prompt' => _l10n.agentConfigSelectPrompt,
      'agent.config.title' => _l10n.agentConfigTitle,
      'agent.default.tuned' => _l10n.agentDefaultTuned,
      'agent.description.label' => _l10n.agentDescriptionLabel,
      'agent.models.label' => _l10n.agentModelsLabel,
      'agent.models.personas' => _l10n.agentModelsPersonas,
      'agent.name.label' => _l10n.agentNameLabel,
      'agent.none' => _l10n.agentNone,
      'agent.none.selected' => _l10n.agentNoneSelected,
      'agent.parameters.label' => _l10n.agentParametersLabel,
      'agent.prompts.label' => _l10n.agentPromptsLabel,
      'agent.registry.empty' => _l10n.agentRegistryEmpty,
      'agent.searching' => _l10n.agentSearching,
      'agent.select.to.configure' => _l10n.agentSelectToConfigure,
      'agent.title' => _l10n.agentTitle,
      'ai.error' => _l10n.aiError,
      'ai.fetch.failed' => _l10n.aiFetchFailed,
      'ai.save.failed' => _l10n.aiSaveFailed,
      'app.title' => _l10n.appTitle,
      'auth.error' => _l10n.authError,
      'auth.login.failed' => _l10n.authLoginFailed,
      'auth.not.authenticated' => _l10n.authNotAuthenticated,
      'auth.token.expired' => _l10n.authTokenExpired,
      'boot.checking.connection' => _l10n.bootCheckingConnection,
      'boot.connection.failed' => _l10n.bootConnectionFailed,
      'boot.load.error' => _l10n.bootLoadError,
      'boot.poco.intro' => _l10n.bootPocoIntro,
      'boot.systems.nominal' => _l10n.bootSystemsNominal,
      'boot.welcome.back' => _l10n.bootWelcomeBack,
      'chat.command.output' => _l10n.chatCommandOutput,
      'chat.commander.role' => _l10n.chatCommanderRole,
      'chat.created' => _l10n.chatCreated,
      'chat.decline' => _l10n.chatDecline,
      'chat.elicitation.request' => _l10n.chatElicitationRequest,
      'chat.error' => _l10n.chatError,
      'chat.fetch.failed' => _l10n.chatFetchFailed,
      'chat.files.action' => _l10n.chatFilesAction,
      'chat.list.archive' => _l10n.chatListArchive,
      'chat.list.delete' => _l10n.chatListDelete,
      'chat.list.error' => _l10n.chatListError,
      'chat.list.new.chat' => _l10n.chatListNewChat,
      'chat.list.no.messages' => _l10n.chatListNoMessages,
      'chat.list.timestamp.now' => _l10n.chatListTimestampNow,
      'chat.message.sent' => _l10n.chatMessageSent,
      'chat.model.default' => _l10n.chatModelDefault,
      'chat.model.label' => _l10n.chatModelLabel,
      'chat.model.per.chat' => _l10n.chatModelPerChat,
      'chat.new.capability.request' => _l10n.chatNewCapabilityRequest,
      'chat.no.fields.requested' => _l10n.chatNoFieldsRequested,
      'chat.not.found' => _l10n.chatNotFound,
      'chat.poco.role' => _l10n.chatPocoRole,
      'chat.select.model.title' => _l10n.chatSelectModelTitle,
      'chat.send.failed' => _l10n.chatSendFailed,
      'chat.send.tooltip' => _l10n.chatSendTooltip,
      'chat.session.action' => _l10n.chatSessionAction,
      'chat.session.title' => _l10n.chatSessionTitle,
      'chat.submit' => _l10n.chatSubmit,
      'chat.terminal.action' => _l10n.chatTerminalAction,
      'chat.thinking' => _l10n.chatThinking,
      'chat.thinking.live' => _l10n.chatThinkingLive,
      'chat.thinking.role' => _l10n.chatThinkingRole,
      'chat.thought' => _l10n.chatThought,
      'chat.use.global.default' => _l10n.chatUseGlobalDefault,
      'deploy.choose.provider' => _l10n.deployChooseProvider,
      'deploy.coming.soon' => _l10n.deployComingSoon,
      'deploy.pro.badge' => _l10n.deployProBadge,
      'deploy.select.provider' => _l10n.deploySelectProvider,
      'deploy.title' => _l10n.deployTitle,
      'deployment.action.abort' => _l10n.deploymentActionAbort,
      'deployment.action.back' => _l10n.deploymentActionBack,
      'deployment.action.deploy.instance' => _l10n.deploymentActionDeployInstance,
      'deployment.action.dismiss' => _l10n.deploymentActionDismiss,
      'deployment.action.login.now' => _l10n.deploymentActionLoginNow,
      'deployment.action.refresh' => _l10n.deploymentActionRefresh,
      'deployment.action.retry.scan' => _l10n.deploymentActionRetryScan,
      'deployment.action.update' => _l10n.deploymentActionUpdate,
      'deployment.admin.identity' => _l10n.deploymentAdminIdentity,
      'deployment.admin.password' => _l10n.deploymentAdminPassword,
      'deployment.backend' => _l10n.deploymentBackend,
      'deployment.cloud.region' => _l10n.deploymentCloudRegion,
      'deployment.coding.harnesses' => _l10n.deploymentCodingHarnesses,
      'deployment.connection.parameters' => _l10n.deploymentConnectionParameters,
      'deployment.copy.label' => _l10n.deploymentCopyLabel,
      'deployment.current.operation' => _l10n.deploymentCurrentOperation,
      'deployment.debian' => _l10n.deploymentDebian,
      'deployment.description.constructing' => _l10n.deploymentDescriptionConstructing,
      'deployment.description.failed' => _l10n.deploymentDescriptionFailed,
      'deployment.description.fetching' => _l10n.deploymentDescriptionFetching,
      'deployment.description.finishing' => _l10n.deploymentDescriptionFinishing,
      'deployment.description.initializing' => _l10n.deploymentDescriptionInitializing,
      'deployment.description.installing' => _l10n.deploymentDescriptionInstalling,
      'deployment.description.loading.images' => _l10n.deploymentDescriptionLoadingImages,
      'deployment.description.preparing.host' => _l10n.deploymentDescriptionPreparingHost,
      'deployment.description.ready' => _l10n.deploymentDescriptionReady,
      'deployment.description.securing' => _l10n.deploymentDescriptionSecuring,
      'deployment.description.starting' => _l10n.deploymentDescriptionStarting,
      'deployment.description.validating' => _l10n.deploymentDescriptionValidating,
      'deployment.distribution' => _l10n.deploymentDistribution,
      'deployment.error.code' => _l10n.deploymentErrorCode,
      'deployment.geo.grid' => _l10n.deploymentGeoGrid,
      'deployment.hardware.geography' => _l10n.deploymentHardwareGeography,
      'deployment.hardware.plan' => _l10n.deploymentHardwarePlan,
      'deployment.harness.selection.description' => _l10n.deploymentHarnessSelectionDescription,
      'deployment.https.endpoint' => _l10n.deploymentHttpsEndpoint,
      'deployment.initializing.hardware' => _l10n.deploymentInitializingHardware,
      'deployment.instance.manifest' => _l10n.deploymentInstanceManifest,
      'deployment.instance.plan' => _l10n.deploymentInstancePlan,
      'deployment.ip.address' => _l10n.deploymentIpAddress,
      'deployment.last.signal' => _l10n.deploymentLastSignal,
      'deployment.manifest.configuration' => _l10n.deploymentManifestConfiguration,
      'deployment.metadata.registry' => _l10n.deploymentMetadataRegistry,
      'deployment.network.ip' => _l10n.deploymentNetworkIp,
      'deployment.nixos' => _l10n.deploymentNixos,
      'deployment.operating.system' => _l10n.deploymentOperatingSystem,
      'deployment.provisioned' => _l10n.deploymentProvisioned,
      'deployment.region' => _l10n.deploymentRegion,
      'deployment.run.id' => _l10n.deploymentRunId,
      'deployment.scanning.regions' => _l10n.deploymentScanningRegions,
      'deployment.screen.title' => _l10n.deploymentScreenTitle,
      'deployment.secure' => _l10n.deploymentSecure,
      'deployment.security.notice' => _l10n.deploymentSecurityNotice,
      'deployment.source.commit' => _l10n.deploymentSourceCommit,
      'deployment.standard.linux' => _l10n.deploymentStandardLinux,
      'deployment.status.constructing' => _l10n.deploymentStatusConstructing,
      'deployment.status.failed' => _l10n.deploymentStatusFailed,
      'deployment.status.fetching' => _l10n.deploymentStatusFetching,
      'deployment.status.finishing' => _l10n.deploymentStatusFinishing,
      'deployment.status.initializing' => _l10n.deploymentStatusInitializing,
      'deployment.status.installing' => _l10n.deploymentStatusInstalling,
      'deployment.status.loading.images' => _l10n.deploymentStatusLoadingImages,
      'deployment.status.preparing.host' => _l10n.deploymentStatusPreparingHost,
      'deployment.status.ready' => _l10n.deploymentStatusReady,
      'deployment.status.schema' => _l10n.deploymentStatusSchema,
      'deployment.status.securing' => _l10n.deploymentStatusSecuring,
      'deployment.status.starting' => _l10n.deploymentStatusStarting,
      'deployment.status.validating' => _l10n.deploymentStatusValidating,
      'deployment.system.parameters' => _l10n.deploymentSystemParameters,
      'deployment.ubuntu' => _l10n.deploymentUbuntu,
      'deployment.unknown' => _l10n.deploymentUnknown,
      'error.auth.failed' => _l10n.errorAuthFailed,
      'error.auth.unauthorized' => _l10n.errorAuthUnauthorized,
      'error.generic' => _l10n.errorGeneric,
      'error.network' => _l10n.errorNetwork,
      'error.timeout' => _l10n.errorTimeout,
      'errors.clear.all' => _l10n.errorsClearAll,
      'errors.copied' => _l10n.errorsCopied,
      'errors.copy' => _l10n.errorsCopy,
      'errors.copy.all' => _l10n.errorsCopyAll,
      'errors.empty' => _l10n.errorsEmpty,
      'errors.title' => _l10n.errorsTitle,
      'file.clear.action' => _l10n.fileClearAction,
      'file.dashboard.action' => _l10n.fileDashboardAction,
      'file.empty' => _l10n.fileEmpty,
      'file.fetching' => _l10n.fileFetching,
      'file.no.file.selected' => _l10n.fileNoFileSelected,
      'file.select.from.chat' => _l10n.fileSelectFromChat,
      'file.title' => _l10n.fileTitle,
      'files.cant.preview.type' => _l10n.filesCantPreviewType,
      'files.empty' => _l10n.filesEmpty,
      'files.title' => _l10n.filesTitle,
      'files.too.large.to.preview' => _l10n.filesTooLargeToPreview,
      'harness.auth.challenge.target.copied' => _l10n.harnessAuthChallengeTargetCopied,
      'home.loading.chats' => _l10n.homeLoadingChats,
      'home.new.chat' => _l10n.homeNewChat,
      'home.no.chats' => _l10n.homeNoChats,
      'home.title' => _l10n.homeTitle,
      'llm.active.model.section' => _l10n.llmActiveModelSection,
      'llm.add.key' => _l10n.llmAddKey,
      'llm.add.key.hint' => _l10n.llmAddKeyHint,
      'llm.api.keys.section' => _l10n.llmApiKeysSection,
      'llm.connected' => _l10n.llmConnected,
      'llm.global.default' => _l10n.llmGlobalDefault,
      'llm.loading.providers' => _l10n.llmLoadingProviders,
      'llm.models.button' => _l10n.llmModelsButton,
      'llm.no.key' => _l10n.llmNoKey,
      'llm.no.models' => _l10n.llmNoModels,
      'llm.no.providers' => _l10n.llmNoProviders,
      'llm.not.set' => _l10n.llmNotSet,
      'llm.providers.section' => _l10n.llmProvidersSection,
      'llm.select' => _l10n.llmSelect,
      'llm.select.model.title' => _l10n.llmSelectModelTitle,
      'llm.title' => _l10n.llmTitle,
      'llm.update.key' => _l10n.llmUpdateKey,
      'mcp.active.capabilities' => _l10n.mcpActiveCapabilities,
      'mcp.add.config.optional' => _l10n.mcpAddConfigOptional,
      'mcp.add.dialog.title' => _l10n.mcpAddDialogTitle,
      'mcp.authorize.cap' => _l10n.mcpAuthorizeCap,
      'mcp.capabilities.registry' => _l10n.mcpCapabilitiesRegistry,
      'mcp.connect.cap' => _l10n.mcpConnectCap,
      'mcp.edit.config' => _l10n.mcpEditConfig,
      'mcp.enter.secrets' => _l10n.mcpEnterSecrets,
      'mcp.image.optional.label' => _l10n.mcpImageOptionalLabel,
      'mcp.no.capabilities' => _l10n.mcpNoCapabilities,
      'mcp.no.config.required' => _l10n.mcpNoConfigRequired,
      'mcp.oauth.provider.optional.label' => _l10n.mcpOauthProviderOptionalLabel,
      'mcp.oauth.token.env.var.optional.label' => _l10n.mcpOauthTokenEnvVarOptionalLabel,
      'mcp.pending.approval' => _l10n.mcpPendingApproval,
      'mcp.required.config' => _l10n.mcpRequiredConfig,
      'mcp.retry.delivery.cap' => _l10n.mcpRetryDeliveryCap,
      'mcp.revoke' => _l10n.mcpRevoke,
      'mcp.server.name.label' => _l10n.mcpServerNameLabel,
      'mcp.title' => _l10n.mcpTitle,
      'monitor.agent.activity' => _l10n.monitorAgentActivity,
      'monitor.cost.label' => _l10n.monitorCostLabel,
      'monitor.fetching.telemetry' => _l10n.monitorFetchingTelemetry,
      'monitor.key.metrics' => _l10n.monitorKeyMetrics,
      'monitor.messages.label' => _l10n.monitorMessagesLabel,
      'monitor.no.data' => _l10n.monitorNoData,
      'monitor.system.health' => _l10n.monitorSystemHealth,
      'monitor.telemetry.unavailable' => _l10n.monitorTelemetryUnavailable,
      'monitor.title' => _l10n.monitorTitle,
      'monitor.token.usage' => _l10n.monitorTokenUsage,
      'monitor.tokens.label' => _l10n.monitorTokensLabel,
      'nav.chats' => _l10n.navChats,
      'nav.configure' => _l10n.navConfigure,
      'nav.monitor' => _l10n.navMonitor,
      'new.chat.cancel' => _l10n.newChatCancel,
      'new.chat.create' => _l10n.newChatCreate,
      'new.chat.cwd.field' => _l10n.newChatCwdField,
      'new.chat.cwd.hint' => _l10n.newChatCwdHint,
      'new.chat.harness.field' => _l10n.newChatHarnessField,
      'new.chat.model.field' => _l10n.newChatModelField,
      'new.chat.no.models.available' => _l10n.newChatNoModelsAvailable,
      'new.chat.select.harness' => _l10n.newChatSelectHarness,
      'new.chat.select.model' => _l10n.newChatSelectModel,
      'new.chat.title' => _l10n.newChatTitle,
      'new.chat.title.field' => _l10n.newChatTitleField,
      'new.chat.workspace.error.empty' => _l10n.newChatWorkspaceErrorEmpty,
      'new.chat.workspace.error.invalid' => _l10n.newChatWorkspaceErrorInvalid,
      'notification.settings.chat.reply.label' => _l10n.notificationSettingsChatReplyLabel,
      'notification.settings.schedule.label' => _l10n.notificationSettingsScheduleLabel,
      'notification.settings.screen.title' => _l10n.notificationSettingsScreenTitle,
      'notification.settings.task.complete.label' => _l10n.notificationSettingsTaskCompleteLabel,
      'notification.settings.task.error.label' => _l10n.notificationSettingsTaskErrorLabel,
      'observability.backend' => _l10n.observabilityBackend,
      'observability.cost' => _l10n.observabilityCost,
      'observability.log.terminal' => _l10n.observabilityLogTerminal,
      'observability.msgs' => _l10n.observabilityMsgs,
      'observability.registry' => _l10n.observabilityRegistry,
      'observability.select.container' => _l10n.observabilitySelectContainer,
      'observability.title' => _l10n.observabilityTitle,
      'observability.tokens' => _l10n.observabilityTokens,
      'onboarding.access.denied' => _l10n.onboardingAccessDenied,
      'onboarding.account.login' => _l10n.onboardingAccountLogin,
      'onboarding.authenticating' => _l10n.onboardingAuthenticating,
      'onboarding.authorization.code' => _l10n.onboardingAuthorizationCode,
      'onboarding.authorization.code.hint' => _l10n.onboardingAuthorizationCodeHint,
      'onboarding.check.status' => _l10n.onboardingCheckStatus,
      'onboarding.choose.harness.body' => _l10n.onboardingChooseHarnessBody,
      'onboarding.choose.harness.title' => _l10n.onboardingChooseHarnessTitle,
      'onboarding.claude.account.login' => _l10n.onboardingClaudeAccountLogin,
      'onboarding.codex.account.login' => _l10n.onboardingCodexAccountLogin,
      'onboarding.connect.or.deploy' => _l10n.onboardingConnectOrDeploy,
      'onboarding.connected' => _l10n.onboardingConnected,
      'onboarding.create.server' => _l10n.onboardingCreateServer,
      'onboarding.deploy' => _l10n.onboardingDeploy,
      'onboarding.deploy.title' => _l10n.onboardingDeployTitle,
      'onboarding.docker.intro.action.start' => _l10n.onboardingDockerIntroActionStart,
      'onboarding.docker.intro.chip.component' => _l10n.onboardingDockerIntroChipComponent,
      'onboarding.docker.intro.chip.connections' => _l10n.onboardingDockerIntroChipConnections,
      'onboarding.docker.intro.chip.container' => _l10n.onboardingDockerIntroChipContainer,
      'onboarding.docker.intro.chip.saved.data' => _l10n.onboardingDockerIntroChipSavedData,
      'onboarding.docker.intro.eyebrow' => _l10n.onboardingDockerIntroEyebrow,
      'onboarding.docker.intro.poco' => _l10n.onboardingDockerIntroPoco,
      'onboarding.docker.intro.title' => _l10n.onboardingDockerIntroTitle,
      'onboarding.email' => _l10n.onboardingEmail,
      'onboarding.email.hint' => _l10n.onboardingEmailHint,
      'onboarding.email.hint.short' => _l10n.onboardingEmailHintShort,
      'onboarding.existing.server' => _l10n.onboardingExistingServer,
      'onboarding.failure.action.back.to.setup' => _l10n.onboardingFailureActionBackToSetup,
      'onboarding.failure.action.retry.connection' => _l10n.onboardingFailureActionRetryConnection,
      'onboarding.failure.action.technical.details' => _l10n.onboardingFailureActionTechnicalDetails,
      'onboarding.failure.action.view.server.details' => _l10n.onboardingFailureActionViewServerDetails,
      'onboarding.failure.create.poco' => _l10n.onboardingFailureCreatePoco,
      'onboarding.harness.not.found' => _l10n.onboardingHarnessNotFound,
      'onboarding.harness.poco' => _l10n.onboardingHarnessPoco,
      'onboarding.harness.title' => _l10n.onboardingHarnessTitle,
      'onboarding.home.server' => _l10n.onboardingHomeServer,
      'onboarding.identity.label' => _l10n.onboardingIdentityLabel,
      'onboarding.intent.chip.cloud.models' => _l10n.onboardingIntentChipCloudModels,
      'onboarding.intent.chip.local.models' => _l10n.onboardingIntentChipLocalModels,
      'onboarding.intent.poco' => _l10n.onboardingIntentPoco,
      'onboarding.login' => _l10n.onboardingLogin,
      'onboarding.no.server.chip.existing' => _l10n.onboardingNoServerChipExisting,
      'onboarding.no.server.chip.new' => _l10n.onboardingNoServerChipNew,
      'onboarding.no.server.looking.poco' => _l10n.onboardingNoServerLookingPoco,
      'onboarding.no.server.poco' => _l10n.onboardingNoServerPoco,
      'onboarding.open.authorization' => _l10n.onboardingOpenAuthorization,
      'onboarding.orientation.action.continue' => _l10n.onboardingOrientationActionContinue,
      'onboarding.orientation.action.skip' => _l10n.onboardingOrientationActionSkip,
      'onboarding.orientation.title' => _l10n.onboardingOrientationTitle,
      'onboarding.os.debian.label' => _l10n.onboardingOsDebianLabel,
      'onboarding.os.nixos.label' => _l10n.onboardingOsNixosLabel,
      'onboarding.os.poco' => _l10n.onboardingOsPoco,
      'onboarding.os.title' => _l10n.onboardingOsTitle,
      'onboarding.passphrase.label' => _l10n.onboardingPassphraseLabel,
      'onboarding.password' => _l10n.onboardingPassword,
      'onboarding.password.hint' => _l10n.onboardingPasswordHint,
      'onboarding.plan.title' => _l10n.onboardingPlanTitle,
      'onboarding.pocketbase.admin.email' => _l10n.onboardingPocketbaseAdminEmail,
      'onboarding.pocketbase.admin.password' => _l10n.onboardingPocketbaseAdminPassword,
      'onboarding.poco.challenge.message' => _l10n.onboardingPocoChallengeMessage,
      'onboarding.poco.welcome' => _l10n.onboardingPocoWelcome,
      'onboarding.processing' => _l10n.onboardingProcessing,
      'onboarding.provider.authorization.poco' => _l10n.onboardingProviderAuthorizationPoco,
      'onboarding.provider.authorization.title' => _l10n.onboardingProviderAuthorizationTitle,
      'onboarding.provider.chip.elestio.coming.soon' => _l10n.onboardingProviderChipElestioComingSoon,
      'onboarding.provider.chip.linode' => _l10n.onboardingProviderChipLinode,
      'onboarding.provider.poco' => _l10n.onboardingProviderPoco,
      'onboarding.provider.title' => _l10n.onboardingProviderTitle,
      'onboarding.provisioning.poco' => _l10n.onboardingProvisioningPoco,
      'onboarding.ready.action.login' => _l10n.onboardingReadyActionLogin,
      'onboarding.ready.poco' => _l10n.onboardingReadyPoco,
      'onboarding.region.consent.chip.choose.myself' => _l10n.onboardingRegionConsentChipChooseMyself,
      'onboarding.region.consent.chip.use.location' => _l10n.onboardingRegionConsentChipUseLocation,
      'onboarding.region.consent.poco' => _l10n.onboardingRegionConsentPoco,
      'onboarding.region.poco' => _l10n.onboardingRegionPoco,
      'onboarding.region.title' => _l10n.onboardingRegionTitle,
      'onboarding.required.fields' => _l10n.onboardingRequiredFields,
      'onboarding.review.action.provision' => _l10n.onboardingReviewActionProvision,
      'onboarding.review.title' => _l10n.onboardingReviewTitle,
      'onboarding.server.connecting' => _l10n.onboardingServerConnecting,
      'onboarding.server.login.title' => _l10n.onboardingServerLoginTitle,
      'onboarding.server.url' => _l10n.onboardingServerUrl,
      'onboarding.server.url.hint' => _l10n.onboardingServerUrlHint,
      'onboarding.setup.title' => _l10n.onboardingSetupTitle,
      'onboarding.sign.in.poco' => _l10n.onboardingSignInPoco,
      'onboarding.sign.in.title' => _l10n.onboardingSignInTitle,
      'onboarding.submit.code' => _l10n.onboardingSubmitCode,
      'onboarding.title' => _l10n.onboardingTitle,
      'onboarding.trial.chip.not.now' => _l10n.onboardingTrialChipNotNow,
      'onboarding.trial.chip.start' => _l10n.onboardingTrialChipStart,
      'permission.error' => _l10n.permissionError,
      'permission.fetch.failed' => _l10n.permissionFetchFailed,
      'permission.patterns.label' => _l10n.permissionPatternsLabel,
      'permission.signoff.title' => _l10n.permissionSignoffTitle,
      'permission.update.failed' => _l10n.permissionUpdateFailed,
      'pocket.coder.progress.active' => _l10n.pocketCoderProgressActive,
      'pocket.coder.progress.complete' => _l10n.pocketCoderProgressComplete,
      'pocket.coder.progress.deploy.pocket.coder' => _l10n.pocketCoderProgressDeployPocketCoder,
      'pocket.coder.progress.failed' => _l10n.pocketCoderProgressFailed,
      'pocket.coder.progress.initializing' => _l10n.pocketCoderProgressInitializing,
      'pocket.coder.progress.provision.server' => _l10n.pocketCoderProgressProvisionServer,
      'pocket.coder.progress.waiting' => _l10n.pocketCoderProgressWaiting,
      'poco.lesson.agent.explanation' => _l10n.pocoLessonAgentExplanation,
      'poco.lesson.agent.title' => _l10n.pocoLessonAgentTitle,
      'poco.lesson.compose.start.explanation' => _l10n.pocoLessonComposeStartExplanation,
      'poco.lesson.compose.start.title' => _l10n.pocoLessonComposeStartTitle,
      'poco.lesson.container.firewall.explanation' => _l10n.pocoLessonContainerFirewallExplanation,
      'poco.lesson.container.firewall.title' => _l10n.pocoLessonContainerFirewallTitle,
      'poco.lesson.dashboard.explanation' => _l10n.pocoLessonDashboardExplanation,
      'poco.lesson.dashboard.title' => _l10n.pocoLessonDashboardTitle,
      'poco.lesson.docker.explanation' => _l10n.pocoLessonDockerExplanation,
      'poco.lesson.docker.title' => _l10n.pocoLessonDockerTitle,
      'poco.lesson.harness.images.explanation' => _l10n.pocoLessonHarnessImagesExplanation,
      'poco.lesson.harness.images.title' => _l10n.pocoLessonHarnessImagesTitle,
      'poco.lesson.local.caddy.explanation' => _l10n.pocoLessonLocalCaddyExplanation,
      'poco.lesson.local.caddy.title' => _l10n.pocoLessonLocalCaddyTitle,
      'poco.lesson.local.model.explanation' => _l10n.pocoLessonLocalModelExplanation,
      'poco.lesson.local.model.title' => _l10n.pocoLessonLocalModelTitle,
      'poco.lesson.local.secrets.explanation' => _l10n.pocoLessonLocalSecretsExplanation,
      'poco.lesson.local.secrets.title' => _l10n.pocoLessonLocalSecretsTitle,
      'poco.lesson.mcp.sandbox.explanation' => _l10n.pocoLessonMcpSandboxExplanation,
      'poco.lesson.mcp.sandbox.title' => _l10n.pocoLessonMcpSandboxTitle,
      'poco.lesson.memory.explanation' => _l10n.pocoLessonMemoryExplanation,
      'poco.lesson.memory.title' => _l10n.pocoLessonMemoryTitle,
      'poco.lesson.networks.explanation' => _l10n.pocoLessonNetworksExplanation,
      'poco.lesson.networks.title' => _l10n.pocoLessonNetworksTitle,
      'poco.lesson.notifications.explanation' => _l10n.pocoLessonNotificationsExplanation,
      'poco.lesson.notifications.title' => _l10n.pocoLessonNotificationsTitle,
      'poco.lesson.owner.config.explanation' => _l10n.pocoLessonOwnerConfigExplanation,
      'poco.lesson.owner.config.title' => _l10n.pocoLessonOwnerConfigTitle,
      'poco.lesson.pocketbase.docker.access.explanation' => _l10n.pocoLessonPocketbaseDockerAccessExplanation,
      'poco.lesson.pocketbase.docker.access.title' => _l10n.pocoLessonPocketbaseDockerAccessTitle,
      'poco.lesson.pocketbase.explanation' => _l10n.pocoLessonPocketbaseExplanation,
      'poco.lesson.pocketbase.title' => _l10n.pocoLessonPocketbaseTitle,
      'poco.lesson.private.access.explanation' => _l10n.pocoLessonPrivateAccessExplanation,
      'poco.lesson.private.access.title' => _l10n.pocoLessonPrivateAccessTitle,
      'poco.lesson.public.firewall.explanation' => _l10n.pocoLessonPublicFirewallExplanation,
      'poco.lesson.public.firewall.title' => _l10n.pocoLessonPublicFirewallTitle,
      'poco.lesson.release.source.explanation' => _l10n.pocoLessonReleaseSourceExplanation,
      'poco.lesson.release.source.title' => _l10n.pocoLessonReleaseSourceTitle,
      'poco.lesson.ssh.explanation' => _l10n.pocoLessonSshExplanation,
      'poco.lesson.ssh.title' => _l10n.pocoLessonSshTitle,
      'poco.lesson.verified.images.explanation' => _l10n.pocoLessonVerifiedImagesExplanation,
      'poco.lesson.verified.images.title' => _l10n.pocoLessonVerifiedImagesTitle,
      'poco.lesson.volumes.explanation' => _l10n.pocoLessonVolumesExplanation,
      'poco.lesson.volumes.title' => _l10n.pocoLessonVolumesTitle,
      'poco.lesson.vps.storage.explanation' => _l10n.pocoLessonVpsStorageExplanation,
      'poco.lesson.vps.storage.title' => _l10n.pocoLessonVpsStorageTitle,
      'poco.provisioning.loading.source' => _l10n.pocoProvisioningLoadingSource,
      'poco.provisioning.next' => _l10n.pocoProvisioningNext,
      'poco.provisioning.previous' => _l10n.pocoProvisioningPrevious,
      'poco.provisioning.show.concise' => _l10n.pocoProvisioningShowConcise,
      'poco.provisioning.show.full' => _l10n.pocoProvisioningShowFull,
      'poco.provisioning.source.unavailable' => _l10n.pocoProvisioningSourceUnavailable,
      'poco.provisioning.tour.title' => _l10n.pocoProvisioningTourTitle,
      'poco.provisioning.waiting.for.source' => _l10n.pocoProvisioningWaitingForSource,
      'provider.screen.add.key' => _l10n.providerScreenAddKey,
      'provider.screen.api.keys.section' => _l10n.providerScreenApiKeysSection,
      'provider.screen.default.badge' => _l10n.providerScreenDefaultBadge,
      'provider.screen.empty.hint' => _l10n.providerScreenEmptyHint,
      'provider.screen.harness.models.section' => _l10n.providerScreenHarnessModelsSection,
      'provider.screen.loading' => _l10n.providerScreenLoading,
      'provider.screen.no.api.keys' => _l10n.providerScreenNoApiKeys,
      'provider.screen.no.harness.models' => _l10n.providerScreenNoHarnessModels,
      'provider.screen.no.providers' => _l10n.providerScreenNoProviders,
      'provider.screen.select.provider' => _l10n.providerScreenSelectProvider,
      'provider.screen.title' => _l10n.providerScreenTitle,
      'provider.screen.update.key' => _l10n.providerScreenUpdateKey,
      'question.incoming.title' => _l10n.questionIncomingTitle,
      'question.poco.asking' => _l10n.questionPocoAsking,
      'question.send.reply' => _l10n.questionSendReply,
      'relay.activate' => _l10n.relayActivate,
      'relay.active' => _l10n.relayActive,
      'relay.checking.status' => _l10n.relayCheckingStatus,
      'relay.config.section' => _l10n.relayConfigSection,
      'relay.functional.overview.body' => _l10n.relayFunctionalOverviewBody,
      'relay.functional.overview.title' => _l10n.relayFunctionalOverviewTitle,
      'relay.ntfy.description' => _l10n.relayNtfyDescription,
      'relay.ntfy.title' => _l10n.relayNtfyTitle,
      'relay.permission.relay.label' => _l10n.relayPermissionRelayLabel,
      'relay.restore' => _l10n.relayRestore,
      'relay.subsystem' => _l10n.relaySubsystem,
      'relay.subsystems.nominal' => _l10n.relaySubsystemsNominal,
      'relay.title' => _l10n.relayTitle,
      'relay.unlimited.capacity' => _l10n.relayUnlimitedCapacity,
      'scheduler.add.button' => _l10n.schedulerAddButton,
      'scheduler.add.dialog.title' => _l10n.schedulerAddDialogTitle,
      'scheduler.cron.label' => _l10n.schedulerCronLabel,
      'scheduler.delete.button' => _l10n.schedulerDeleteButton,
      'scheduler.edit.button' => _l10n.schedulerEditButton,
      'scheduler.name.label' => _l10n.schedulerNameLabel,
      'scheduler.no.schedules' => _l10n.schedulerNoSchedules,
      'scheduler.pause.button' => _l10n.schedulerPauseButton,
      'scheduler.paused.badge' => _l10n.schedulerPausedBadge,
      'scheduler.prompt.label' => _l10n.schedulerPromptLabel,
      'scheduler.registry.title' => _l10n.schedulerRegistryTitle,
      'scheduler.resume.button' => _l10n.schedulerResumeButton,
      'scheduler.run.now.button' => _l10n.schedulerRunNowButton,
      'scheduler.running.badge' => _l10n.schedulerRunningBadge,
      'scheduler.save.button' => _l10n.schedulerSaveButton,
      'scheduler.title' => _l10n.schedulerTitle,
      'settings.account.section' => _l10n.settingsAccountSection,
      'settings.ai.agents.section' => _l10n.settingsAiAgentsSection,
      'settings.automation.section' => _l10n.settingsAutomationSection,
      'settings.governance.section' => _l10n.settingsGovernanceSection,
      'settings.logout.cancel' => _l10n.settingsLogoutCancel,
      'settings.logout.confirm' => _l10n.settingsLogoutConfirm,
      'settings.logout.confirm.body' => _l10n.settingsLogoutConfirmBody,
      'settings.logout.confirm.title' => _l10n.settingsLogoutConfirmTitle,
      'settings.observability.section' => _l10n.settingsObservabilitySection,
      'settings.security.section' => _l10n.settingsSecuritySection,
      'settings.system.section' => _l10n.settingsSystemSection,
      'settings.title' => _l10n.settingsTitle,
      'skills.add.button' => _l10n.skillsAddButton,
      'skills.add.dialog.title' => _l10n.skillsAddDialogTitle,
      'skills.content.label' => _l10n.skillsContentLabel,
      'skills.delete.button' => _l10n.skillsDeleteButton,
      'skills.description.label' => _l10n.skillsDescriptionLabel,
      'skills.edit.button' => _l10n.skillsEditButton,
      'skills.global.label' => _l10n.skillsGlobalLabel,
      'skills.global.section' => _l10n.skillsGlobalSection,
      'skills.name.label' => _l10n.skillsNameLabel,
      'skills.no.eligible.config' => _l10n.skillsNoEligibleConfig,
      'skills.no.skills' => _l10n.skillsNoSkills,
      'skills.project.label' => _l10n.skillsProjectLabel,
      'skills.project.section' => _l10n.skillsProjectSection,
      'skills.registry.title' => _l10n.skillsRegistryTitle,
      'skills.save.button' => _l10n.skillsSaveButton,
      'skills.title' => _l10n.skillsTitle,
      'system.checks.diagnostics' => _l10n.systemChecksDiagnostics,
      'system.checks.empty' => _l10n.systemChecksEmpty,
      'system.checks.title' => _l10n.systemChecksTitle,
      'terminal.connecting' => _l10n.terminalConnecting,
      'terminal.connection.failed' => _l10n.terminalConnectionFailed,
      'terminal.connection.status' => _l10n.terminalConnectionStatus,
      'terminal.destination.path' => _l10n.terminalDestinationPath,
      'terminal.offline' => _l10n.terminalOffline,
      'terminal.online' => _l10n.terminalOnline,
      'terminal.reconnect' => _l10n.terminalReconnect,
      'terminal.retry' => _l10n.terminalRetry,
      'terminal.sftp.title' => _l10n.terminalSftpTitle,
      'terminal.title' => _l10n.terminalTitle,
      'terminal.transfer' => _l10n.terminalTransfer,
      'terminal.upload' => _l10n.terminalUpload,
      'thoughts.waiting' => _l10n.thoughtsWaiting,
      'tool.permissions.action.label' => _l10n.toolPermissionsActionLabel,
      'tool.permissions.add' => _l10n.toolPermissionsAdd,
      'tool.permissions.add.rule.title' => _l10n.toolPermissionsAddRuleTitle,
      'tool.permissions.add.title' => _l10n.toolPermissionsAddTitle,
      'tool.permissions.allow.label' => _l10n.toolPermissionsAllowLabel,
      'tool.permissions.ask.label' => _l10n.toolPermissionsAskLabel,
      'tool.permissions.deny.label' => _l10n.toolPermissionsDenyLabel,
      'tool.permissions.empty' => _l10n.toolPermissionsEmpty,
      'tool.permissions.error' => _l10n.toolPermissionsError,
      'tool.permissions.fetch.failed' => _l10n.toolPermissionsFetchFailed,
      'tool.permissions.frame.title' => _l10n.toolPermissionsFrameTitle,
      'tool.permissions.loading' => _l10n.toolPermissionsLoading,
      'tool.permissions.no.rules' => _l10n.toolPermissionsNoRules,
      'tool.permissions.pattern.label' => _l10n.toolPermissionsPatternLabel,
      'tool.permissions.rules.registry' => _l10n.toolPermissionsRulesRegistry,
      'tool.permissions.scope.agent' => _l10n.toolPermissionsScopeAgent,
      'tool.permissions.scope.global' => _l10n.toolPermissionsScopeGlobal,
      'tool.permissions.screen.title' => _l10n.toolPermissionsScreenTitle,
      'tool.permissions.title' => _l10n.toolPermissionsTitle,
      'tool.permissions.tool.label' => _l10n.toolPermissionsToolLabel,
      'tool.permissions.tool.name.label' => _l10n.toolPermissionsToolNameLabel,
      'tool.permissions.update.failed' => _l10n.toolPermissionsUpdateFailed,
      'walkthrough.action.show.concise.code' => _l10n.walkthroughActionShowConciseCode,
      'walkthrough.action.show.full.code' => _l10n.walkthroughActionShowFullCode,
      'walkthrough.activation.health.poco' => _l10n.walkthroughActivationHealthPoco,
      'walkthrough.activation.health.title' => _l10n.walkthroughActivationHealthTitle,
      'walkthrough.activation.prepare.poco' => _l10n.walkthroughActivationPreparePoco,
      'walkthrough.activation.prepare.title' => _l10n.walkthroughActivationPrepareTitle,
      'walkthrough.activation.selected.software.poco' => _l10n.walkthroughActivationSelectedSoftwarePoco,
      'walkthrough.activation.selected.software.title' => _l10n.walkthroughActivationSelectedSoftwareTitle,
      'walkthrough.activation.switch.poco' => _l10n.walkthroughActivationSwitchPoco,
      'walkthrough.activation.switch.title' => _l10n.walkthroughActivationSwitchTitle,
      'walkthrough.ask.poco' => _l10n.walkthroughAskPoco,
      'walkthrough.brief.divider' => _l10n.walkthroughBriefDivider,
      'walkthrough.caddy.address.chip.https' => _l10n.walkthroughCaddyAddressChipHttps,
      'walkthrough.caddy.address.chip.ip.address' => _l10n.walkthroughCaddyAddressChipIpAddress,
      'walkthrough.caddy.address.chip.sslip' => _l10n.walkthroughCaddyAddressChipSslip,
      'walkthrough.caddy.address.poco' => _l10n.walkthroughCaddyAddressPoco,
      'walkthrough.caddy.address.title' => _l10n.walkthroughCaddyAddressTitle,
      'walkthrough.caddy.web.entry.chip.caddy' => _l10n.walkthroughCaddyWebEntryChipCaddy,
      'walkthrough.caddy.web.entry.chip.private.port' => _l10n.walkthroughCaddyWebEntryChipPrivatePort,
      'walkthrough.caddy.web.entry.poco' => _l10n.walkthroughCaddyWebEntryPoco,
      'walkthrough.caddy.web.entry.title' => _l10n.walkthroughCaddyWebEntryTitle,
      'walkthrough.debian.setup.status.chip.failure' => _l10n.walkthroughDebianSetupStatusChipFailure,
      'walkthrough.debian.setup.status.chip.status' => _l10n.walkthroughDebianSetupStatusChipStatus,
      'walkthrough.debian.setup.status.poco' => _l10n.walkthroughDebianSetupStatusPoco,
      'walkthrough.debian.setup.status.title' => _l10n.walkthroughDebianSetupStatusTitle,
      'walkthrough.nixos.docker.poco' => _l10n.walkthroughNixosDockerPoco,
      'walkthrough.nixos.docker.rules.poco' => _l10n.walkthroughNixosDockerRulesPoco,
      'walkthrough.nixos.docker.rules.title' => _l10n.walkthroughNixosDockerRulesTitle,
      'walkthrough.nixos.docker.title' => _l10n.walkthroughNixosDockerTitle,
      'walkthrough.nixos.network.chip.docker.rules' => _l10n.walkthroughNixosNetworkChipDockerRules,
      'walkthrough.nixos.network.chip.ip.versions' => _l10n.walkthroughNixosNetworkChipIpVersions,
      'walkthrough.nixos.network.chip.ports' => _l10n.walkthroughNixosNetworkChipPorts,
      'walkthrough.nixos.network.poco' => _l10n.walkthroughNixosNetworkPoco,
      'walkthrough.nixos.network.title' => _l10n.walkthroughNixosNetworkTitle,
      'walkthrough.nixos.ssh.poco' => _l10n.walkthroughNixosSshPoco,
      'walkthrough.nixos.ssh.title' => _l10n.walkthroughNixosSshTitle,
      'walkthrough.nixos.storage.poco' => _l10n.walkthroughNixosStoragePoco,
      'walkthrough.nixos.storage.title' => _l10n.walkthroughNixosStorageTitle,
      'walkthrough.runtime.settings.chip.local.settings' => _l10n.walkthroughRuntimeSettingsChipLocalSettings,
      'walkthrough.runtime.settings.poco' => _l10n.walkthroughRuntimeSettingsPoco,
      'walkthrough.runtime.settings.title' => _l10n.walkthroughRuntimeSettingsTitle,
      'walkthrough.runtime.version.poco' => _l10n.walkthroughRuntimeVersionPoco,
      'walkthrough.runtime.version.title' => _l10n.walkthroughRuntimeVersionTitle,
      'walkthrough.server.key.chip.private' => _l10n.walkthroughServerKeyChipPrivate,
      'walkthrough.server.key.chip.public' => _l10n.walkthroughServerKeyChipPublic,
      'walkthrough.server.key.chip.ssh' => _l10n.walkthroughServerKeyChipSsh,
      'walkthrough.server.key.poco' => _l10n.walkthroughServerKeyPoco,
      'walkthrough.server.key.title' => _l10n.walkthroughServerKeyTitle,
      'walkthrough.services.cognee.badge' => _l10n.walkthroughServicesCogneeBadge,
      'walkthrough.services.cognee.poco' => _l10n.walkthroughServicesCogneePoco,
      'walkthrough.services.cognee.title' => _l10n.walkthroughServicesCogneeTitle,
      'walkthrough.services.compose.chip.docker.compose' => _l10n.walkthroughServicesComposeChipDockerCompose,
      'walkthrough.services.compose.chip.private.connections' => _l10n.walkthroughServicesComposeChipPrivateConnections,
      'walkthrough.services.compose.chip.saved.data' => _l10n.walkthroughServicesComposeChipSavedData,
      'walkthrough.services.compose.poco' => _l10n.walkthroughServicesComposePoco,
      'walkthrough.services.compose.title' => _l10n.walkthroughServicesComposeTitle,
      'walkthrough.services.harnesses.chip.add' => _l10n.walkthroughServicesHarnessesChipAdd,
      'walkthrough.services.harnesses.chip.harness' => _l10n.walkthroughServicesHarnessesChipHarness,
      'walkthrough.services.harnesses.chip.workspace' => _l10n.walkthroughServicesHarnessesChipWorkspace,
      'walkthrough.services.harnesses.title' => _l10n.walkthroughServicesHarnessesTitle,
      'walkthrough.services.ollama.chip.download' => _l10n.walkthroughServicesOllamaChipDownload,
      'walkthrough.services.ollama.chip.gpu' => _l10n.walkthroughServicesOllamaChipGpu,
      'walkthrough.services.ollama.chip.local.model' => _l10n.walkthroughServicesOllamaChipLocalModel,
      'walkthrough.services.ollama.poco' => _l10n.walkthroughServicesOllamaPoco,
      'walkthrough.services.ollama.title' => _l10n.walkthroughServicesOllamaTitle,
      'walkthrough.services.pocket.base.chip.keeps' => _l10n.walkthroughServicesPocketBaseChipKeeps,
      'walkthrough.services.pocket.base.chip.sign.in' => _l10n.walkthroughServicesPocketBaseChipSignIn,
      'walkthrough.services.pocket.base.chip.updates' => _l10n.walkthroughServicesPocketBaseChipUpdates,
      'walkthrough.services.pocket.base.poco' => _l10n.walkthroughServicesPocketBasePoco,
      'walkthrough.services.pocket.base.title' => _l10n.walkthroughServicesPocketBaseTitle,
      'walkthrough.services.sql.page.chip.contents' => _l10n.walkthroughServicesSqlPageChipContents,
      'walkthrough.services.sql.page.chip.start.order' => _l10n.walkthroughServicesSqlPageChipStartOrder,
      'walkthrough.services.sql.page.poco' => _l10n.walkthroughServicesSqlPagePoco,
      'walkthrough.services.sql.page.title' => _l10n.walkthroughServicesSqlPageTitle,
      'walkthrough.services.tools.chip.harness.tools' => _l10n.walkthroughServicesToolsChipHarnessTools,
      'walkthrough.services.tools.chip.mcp' => _l10n.walkthroughServicesToolsChipMcp,
      'walkthrough.services.tools.chip.proxy' => _l10n.walkthroughServicesToolsChipProxy,
      'walkthrough.services.tools.poco' => _l10n.walkthroughServicesToolsPoco,
      'walkthrough.services.tools.title' => _l10n.walkthroughServicesToolsTitle,
      'walkthrough.start.pocket.coder.chip.add.harness' => _l10n.walkthroughStartPocketCoderChipAddHarness,
      'walkthrough.start.pocket.coder.chip.what.starts' => _l10n.walkthroughStartPocketCoderChipWhatStarts,
      'walkthrough.start.pocket.coder.poco' => _l10n.walkthroughStartPocketCoderPoco,
      'walkthrough.start.pocket.coder.title' => _l10n.walkthroughStartPocketCoderTitle,
      'walkthrough.transition.deployment' => _l10n.walkthroughTransitionDeployment,
      'walkthrough.transition.provisioning' => _l10n.walkthroughTransitionProvisioning,
      'walkthrough.verified.version.chip.download.failure' => _l10n.walkthroughVerifiedVersionChipDownloadFailure,
      'walkthrough.verified.version.chip.updates' => _l10n.walkthroughVerifiedVersionChipUpdates,
      'walkthrough.verified.version.chip.verification' => _l10n.walkthroughVerifiedVersionChipVerification,
      'walkthrough.verified.version.poco' => _l10n.walkthroughVerifiedVersionPoco,
      'walkthrough.verified.version.title' => _l10n.walkthroughVerifiedVersionTitle,

      // Parameterized keys
      'agent.config.delete.confirm.body' => _l10n.agentConfigDeleteConfirmBody(args?['name'] as String? ?? ''),
      'agent.config.dialog.title' => _l10n.agentConfigDialogTitle(args?['name'] as String? ?? ''),
      'agent.config.error.prefix' => _l10n.agentConfigErrorPrefix(args?['error'] as String? ?? ''),
      'agent.dialog.title' => _l10n.agentDialogTitle(args?['name'] as String? ?? ''),
      'brief.label' => _l10n.briefLabel(args?['current'] as int? ?? 0, args?['total'] as int? ?? 0),
      'chat.list.timestamp.days.ago' => _l10n.chatListTimestampDaysAgo(args?['count'] as int? ?? 0),
      'chat.list.timestamp.hours.ago' => _l10n.chatListTimestampHoursAgo(args?['count'] as int? ?? 0),
      'chat.list.timestamp.minutes.ago' => _l10n.chatListTimestampMinutesAgo(args?['count'] as int? ?? 0),
      'deployment.copied.to.buffer' => _l10n.deploymentCopiedToBuffer(args?['label'] as String? ?? ''),
      'deployment.fault.detected' => _l10n.deploymentFaultDetected(args?['error'] as String? ?? ''),
      'deployment.monthly.price' => _l10n.deploymentMonthlyPrice(args?['price'] as String? ?? ''),
      'deployment.status.prefix' => _l10n.deploymentStatusPrefix(args?['status'] as String? ?? ''),
      'deployment.sync.attempt' => _l10n.deploymentSyncAttempt(args?['attempt'] as int? ?? 0),
      'errors.occurred' => _l10n.errorsOccurred(args?['count'] as int? ?? 0),
      'home.error.prefix' => _l10n.homeErrorPrefix(args?['error'] as String? ?? ''),
      'llm.api.key.dialog.title' => _l10n.llmApiKeyDialogTitle(args?['provider'] as String? ?? ''),
      'llm.enter.credentials' => _l10n.llmEnterCredentials(args?['provider'] as String? ?? ''),
      'llm.models.available' => _l10n.llmModelsAvailable(args?['count'] as int? ?? 0),
      'llm.provider.models.title' => _l10n.llmProviderModelsTitle(args?['provider'] as String? ?? ''),
      'mcp.authorize.dialog.title' => _l10n.mcpAuthorizeDialogTitle(args?['name'] as String? ?? ''),
      'mcp.image.label' => _l10n.mcpImageLabel(args?['image'] as String? ?? ''),
      'mcp.oauth.provider.not.configured.label' => _l10n.mcpOauthProviderNotConfiguredLabel(args?['provider'] as String? ?? ''),
      'mcp.oauth.required.label' => _l10n.mcpOauthRequiredLabel(args?['provider'] as String? ?? ''),
      'mcp.purpose.label' => _l10n.mcpPurposeLabel(args?['reason'] as String? ?? ''),
      'mcp.update.config.dialog.title' => _l10n.mcpUpdateConfigDialogTitle(args?['name'] as String? ?? ''),
      'notification.signal.received' => _l10n.notificationSignalReceived(args?['title'] as String? ?? ''),
      'onboarding.failure.connection.poco' => _l10n.onboardingFailureConnectionPoco(args?['providerName'] as String? ?? ''),
      'onboarding.harness.login.title' => _l10n.onboardingHarnessLoginTitle(args?['provider'] as String? ?? ''),
      'onboarding.open.chat.failed' => _l10n.onboardingOpenChatFailed(args?['error'] as String? ?? ''),
      'onboarding.os.debian.description' => _l10n.onboardingOsDebianDescription(args?['minutes'] as int? ?? 0),
      'onboarding.os.nixos.description' => _l10n.onboardingOsNixosDescription(args?['minutes'] as int? ?? 0),
      'onboarding.plan.poco' => _l10n.onboardingPlanPoco(args?['providerName'] as String? ?? ''),
      'onboarding.provider.authorization.action' => _l10n.onboardingProviderAuthorizationAction(args?['providerName'] as String? ?? ''),
      'onboarding.review.poco' => _l10n.onboardingReviewPoco(args?['providerName'] as String? ?? ''),
      'onboarding.trial.poco' => _l10n.onboardingTrialPoco(args?['trialDuration'] as String? ?? ''),
      'permission.requesting.label' => _l10n.permissionRequestingLabel(args?['source'] as String? ?? ''),
      'provider.screen.add.key.body' => _l10n.providerScreenAddKeyBody(args?['provider'] as String? ?? ''),
      'provider.screen.add.key.title' => _l10n.providerScreenAddKeyTitle(args?['provider'] as String? ?? ''),
      'provider.screen.error.prefix' => _l10n.providerScreenErrorPrefix(args?['error'] as String? ?? ''),
      'scheduler.edit.dialog.title' => _l10n.schedulerEditDialogTitle(args?['name'] as String? ?? ''),
      'skills.edit.dialog.title' => _l10n.skillsEditDialogTitle(args?['name'] as String? ?? ''),
      'terminal.ssh.link' => _l10n.terminalSshLink(args?['host'] as String? ?? '', args?['port'] as String? ?? ''),
      'walkthrough.header' => _l10n.walkthroughHeader(args?['os'] as String? ?? '', args?['current'] as int? ?? 0, args?['total'] as int? ?? 0),
      'walkthrough.label' => _l10n.walkthroughLabel(args?['current'] as int? ?? 0, args?['total'] as int? ?? 0),
      'walkthrough.progress' => _l10n.walkthroughProgress(args?['current'] as int? ?? 0, args?['total'] as int? ?? 0, args?['brief'] as String? ?? ''),
      'walkthrough.services.harnesses.poco' => _l10n.walkthroughServicesHarnessesPoco(args?['selectedHarnesses'] as String? ?? ''),

      _ => null,
    }) as String?;
  }

  /// Set of all known keys (for validation/debugging).
  static const knownKeys = <String>{
    'action.add',
    'action.add.new',
    'action.authorize',
    'action.back',
    'action.cancel',
    'action.change',
    'action.close',
    'action.configure',
    'action.continue',
    'action.create',
    'action.deny',
    'action.refresh',
    'action.reject',
    'action.restore',
    'action.save',
    'agent.config.default.badge',
    'agent.config.delete',
    'agent.config.delete.confirm.body',
    'agent.config.delete.confirm.title',
    'agent.config.dialog.title',
    'agent.config.empty',
    'agent.config.error.prefix',
    'agent.config.harness.model.label',
    'agent.config.is.default.label',
    'agent.config.mode.label',
    'agent.config.name.label',
    'agent.config.no.harness.models',
    'agent.config.no.modes',
    'agent.config.no.prompts',
    'agent.config.prompt.label',
    'agent.config.registry',
    'agent.config.select.harness.model',
    'agent.config.select.mode',
    'agent.config.select.prompt',
    'agent.config.title',
    'agent.default.tuned',
    'agent.description.label',
    'agent.dialog.title',
    'agent.models.label',
    'agent.models.personas',
    'agent.name.label',
    'agent.none',
    'agent.none.selected',
    'agent.parameters.label',
    'agent.prompts.label',
    'agent.registry.empty',
    'agent.searching',
    'agent.select.to.configure',
    'agent.title',
    'ai.error',
    'ai.fetch.failed',
    'ai.save.failed',
    'app.title',
    'auth.error',
    'auth.login.failed',
    'auth.not.authenticated',
    'auth.token.expired',
    'boot.checking.connection',
    'boot.connection.failed',
    'boot.load.error',
    'boot.poco.intro',
    'boot.systems.nominal',
    'boot.welcome.back',
    'brief.label',
    'chat.command.output',
    'chat.commander.role',
    'chat.created',
    'chat.decline',
    'chat.elicitation.request',
    'chat.error',
    'chat.fetch.failed',
    'chat.files.action',
    'chat.list.archive',
    'chat.list.delete',
    'chat.list.error',
    'chat.list.new.chat',
    'chat.list.no.messages',
    'chat.list.timestamp.days.ago',
    'chat.list.timestamp.hours.ago',
    'chat.list.timestamp.minutes.ago',
    'chat.list.timestamp.now',
    'chat.message.sent',
    'chat.model.default',
    'chat.model.label',
    'chat.model.per.chat',
    'chat.new.capability.request',
    'chat.no.fields.requested',
    'chat.not.found',
    'chat.poco.role',
    'chat.select.model.title',
    'chat.send.failed',
    'chat.send.tooltip',
    'chat.session.action',
    'chat.session.title',
    'chat.submit',
    'chat.terminal.action',
    'chat.thinking',
    'chat.thinking.live',
    'chat.thinking.role',
    'chat.thought',
    'chat.use.global.default',
    'deploy.choose.provider',
    'deploy.coming.soon',
    'deploy.pro.badge',
    'deploy.select.provider',
    'deploy.title',
    'deployment.action.abort',
    'deployment.action.back',
    'deployment.action.deploy.instance',
    'deployment.action.dismiss',
    'deployment.action.login.now',
    'deployment.action.refresh',
    'deployment.action.retry.scan',
    'deployment.action.update',
    'deployment.admin.identity',
    'deployment.admin.password',
    'deployment.backend',
    'deployment.cloud.region',
    'deployment.coding.harnesses',
    'deployment.connection.parameters',
    'deployment.copied.to.buffer',
    'deployment.copy.label',
    'deployment.current.operation',
    'deployment.debian',
    'deployment.description.constructing',
    'deployment.description.failed',
    'deployment.description.fetching',
    'deployment.description.finishing',
    'deployment.description.initializing',
    'deployment.description.installing',
    'deployment.description.loading.images',
    'deployment.description.preparing.host',
    'deployment.description.ready',
    'deployment.description.securing',
    'deployment.description.starting',
    'deployment.description.validating',
    'deployment.distribution',
    'deployment.error.code',
    'deployment.fault.detected',
    'deployment.geo.grid',
    'deployment.hardware.geography',
    'deployment.hardware.plan',
    'deployment.harness.selection.description',
    'deployment.https.endpoint',
    'deployment.initializing.hardware',
    'deployment.instance.manifest',
    'deployment.instance.plan',
    'deployment.ip.address',
    'deployment.last.signal',
    'deployment.manifest.configuration',
    'deployment.metadata.registry',
    'deployment.monthly.price',
    'deployment.network.ip',
    'deployment.nixos',
    'deployment.operating.system',
    'deployment.provisioned',
    'deployment.region',
    'deployment.run.id',
    'deployment.scanning.regions',
    'deployment.screen.title',
    'deployment.secure',
    'deployment.security.notice',
    'deployment.source.commit',
    'deployment.standard.linux',
    'deployment.status.constructing',
    'deployment.status.failed',
    'deployment.status.fetching',
    'deployment.status.finishing',
    'deployment.status.initializing',
    'deployment.status.installing',
    'deployment.status.loading.images',
    'deployment.status.prefix',
    'deployment.status.preparing.host',
    'deployment.status.ready',
    'deployment.status.schema',
    'deployment.status.securing',
    'deployment.status.starting',
    'deployment.status.validating',
    'deployment.sync.attempt',
    'deployment.system.parameters',
    'deployment.ubuntu',
    'deployment.unknown',
    'error.auth.failed',
    'error.auth.unauthorized',
    'error.generic',
    'error.network',
    'error.timeout',
    'errors.clear.all',
    'errors.copied',
    'errors.copy',
    'errors.copy.all',
    'errors.empty',
    'errors.occurred',
    'errors.title',
    'file.clear.action',
    'file.dashboard.action',
    'file.empty',
    'file.fetching',
    'file.no.file.selected',
    'file.select.from.chat',
    'file.title',
    'files.cant.preview.type',
    'files.empty',
    'files.title',
    'files.too.large.to.preview',
    'harness.auth.challenge.target.copied',
    'home.error.prefix',
    'home.loading.chats',
    'home.new.chat',
    'home.no.chats',
    'home.title',
    'llm.active.model.section',
    'llm.add.key',
    'llm.add.key.hint',
    'llm.api.key.dialog.title',
    'llm.api.keys.section',
    'llm.connected',
    'llm.enter.credentials',
    'llm.global.default',
    'llm.loading.providers',
    'llm.models.available',
    'llm.models.button',
    'llm.no.key',
    'llm.no.models',
    'llm.no.providers',
    'llm.not.set',
    'llm.provider.models.title',
    'llm.providers.section',
    'llm.select',
    'llm.select.model.title',
    'llm.title',
    'llm.update.key',
    'mcp.active.capabilities',
    'mcp.add.config.optional',
    'mcp.add.dialog.title',
    'mcp.authorize.cap',
    'mcp.authorize.dialog.title',
    'mcp.capabilities.registry',
    'mcp.connect.cap',
    'mcp.edit.config',
    'mcp.enter.secrets',
    'mcp.image.label',
    'mcp.image.optional.label',
    'mcp.no.capabilities',
    'mcp.no.config.required',
    'mcp.oauth.provider.not.configured.label',
    'mcp.oauth.provider.optional.label',
    'mcp.oauth.required.label',
    'mcp.oauth.token.env.var.optional.label',
    'mcp.pending.approval',
    'mcp.purpose.label',
    'mcp.required.config',
    'mcp.retry.delivery.cap',
    'mcp.revoke',
    'mcp.server.name.label',
    'mcp.title',
    'mcp.update.config.dialog.title',
    'monitor.agent.activity',
    'monitor.cost.label',
    'monitor.fetching.telemetry',
    'monitor.key.metrics',
    'monitor.messages.label',
    'monitor.no.data',
    'monitor.system.health',
    'monitor.telemetry.unavailable',
    'monitor.title',
    'monitor.token.usage',
    'monitor.tokens.label',
    'nav.chats',
    'nav.configure',
    'nav.monitor',
    'new.chat.cancel',
    'new.chat.create',
    'new.chat.cwd.field',
    'new.chat.cwd.hint',
    'new.chat.harness.field',
    'new.chat.model.field',
    'new.chat.no.models.available',
    'new.chat.select.harness',
    'new.chat.select.model',
    'new.chat.title',
    'new.chat.title.field',
    'new.chat.workspace.error.empty',
    'new.chat.workspace.error.invalid',
    'notification.settings.chat.reply.label',
    'notification.settings.schedule.label',
    'notification.settings.screen.title',
    'notification.settings.task.complete.label',
    'notification.settings.task.error.label',
    'notification.signal.received',
    'observability.backend',
    'observability.cost',
    'observability.log.terminal',
    'observability.msgs',
    'observability.registry',
    'observability.select.container',
    'observability.title',
    'observability.tokens',
    'onboarding.access.denied',
    'onboarding.account.login',
    'onboarding.authenticating',
    'onboarding.authorization.code',
    'onboarding.authorization.code.hint',
    'onboarding.check.status',
    'onboarding.choose.harness.body',
    'onboarding.choose.harness.title',
    'onboarding.claude.account.login',
    'onboarding.codex.account.login',
    'onboarding.connect.or.deploy',
    'onboarding.connected',
    'onboarding.create.server',
    'onboarding.deploy',
    'onboarding.deploy.title',
    'onboarding.docker.intro.action.start',
    'onboarding.docker.intro.chip.component',
    'onboarding.docker.intro.chip.connections',
    'onboarding.docker.intro.chip.container',
    'onboarding.docker.intro.chip.saved.data',
    'onboarding.docker.intro.eyebrow',
    'onboarding.docker.intro.poco',
    'onboarding.docker.intro.title',
    'onboarding.email',
    'onboarding.email.hint',
    'onboarding.email.hint.short',
    'onboarding.existing.server',
    'onboarding.failure.action.back.to.setup',
    'onboarding.failure.action.retry.connection',
    'onboarding.failure.action.technical.details',
    'onboarding.failure.action.view.server.details',
    'onboarding.failure.connection.poco',
    'onboarding.failure.create.poco',
    'onboarding.harness.login.title',
    'onboarding.harness.not.found',
    'onboarding.harness.poco',
    'onboarding.harness.title',
    'onboarding.home.server',
    'onboarding.identity.label',
    'onboarding.intent.chip.cloud.models',
    'onboarding.intent.chip.local.models',
    'onboarding.intent.poco',
    'onboarding.login',
    'onboarding.no.server.chip.existing',
    'onboarding.no.server.chip.new',
    'onboarding.no.server.looking.poco',
    'onboarding.no.server.poco',
    'onboarding.open.authorization',
    'onboarding.open.chat.failed',
    'onboarding.orientation.action.continue',
    'onboarding.orientation.action.skip',
    'onboarding.orientation.title',
    'onboarding.os.debian.description',
    'onboarding.os.debian.label',
    'onboarding.os.nixos.description',
    'onboarding.os.nixos.label',
    'onboarding.os.poco',
    'onboarding.os.title',
    'onboarding.passphrase.label',
    'onboarding.password',
    'onboarding.password.hint',
    'onboarding.plan.poco',
    'onboarding.plan.title',
    'onboarding.pocketbase.admin.email',
    'onboarding.pocketbase.admin.password',
    'onboarding.poco.challenge.message',
    'onboarding.poco.welcome',
    'onboarding.processing',
    'onboarding.provider.authorization.action',
    'onboarding.provider.authorization.poco',
    'onboarding.provider.authorization.title',
    'onboarding.provider.chip.elestio.coming.soon',
    'onboarding.provider.chip.linode',
    'onboarding.provider.poco',
    'onboarding.provider.title',
    'onboarding.provisioning.poco',
    'onboarding.ready.action.login',
    'onboarding.ready.poco',
    'onboarding.region.consent.chip.choose.myself',
    'onboarding.region.consent.chip.use.location',
    'onboarding.region.consent.poco',
    'onboarding.region.poco',
    'onboarding.region.title',
    'onboarding.required.fields',
    'onboarding.review.action.provision',
    'onboarding.review.poco',
    'onboarding.review.title',
    'onboarding.server.connecting',
    'onboarding.server.login.title',
    'onboarding.server.url',
    'onboarding.server.url.hint',
    'onboarding.setup.title',
    'onboarding.sign.in.poco',
    'onboarding.sign.in.title',
    'onboarding.submit.code',
    'onboarding.title',
    'onboarding.trial.chip.not.now',
    'onboarding.trial.chip.start',
    'onboarding.trial.poco',
    'permission.error',
    'permission.fetch.failed',
    'permission.patterns.label',
    'permission.requesting.label',
    'permission.signoff.title',
    'permission.update.failed',
    'pocket.coder.progress.active',
    'pocket.coder.progress.complete',
    'pocket.coder.progress.deploy.pocket.coder',
    'pocket.coder.progress.failed',
    'pocket.coder.progress.initializing',
    'pocket.coder.progress.provision.server',
    'pocket.coder.progress.waiting',
    'poco.lesson.agent.explanation',
    'poco.lesson.agent.title',
    'poco.lesson.compose.start.explanation',
    'poco.lesson.compose.start.title',
    'poco.lesson.container.firewall.explanation',
    'poco.lesson.container.firewall.title',
    'poco.lesson.dashboard.explanation',
    'poco.lesson.dashboard.title',
    'poco.lesson.docker.explanation',
    'poco.lesson.docker.title',
    'poco.lesson.harness.images.explanation',
    'poco.lesson.harness.images.title',
    'poco.lesson.local.caddy.explanation',
    'poco.lesson.local.caddy.title',
    'poco.lesson.local.model.explanation',
    'poco.lesson.local.model.title',
    'poco.lesson.local.secrets.explanation',
    'poco.lesson.local.secrets.title',
    'poco.lesson.mcp.sandbox.explanation',
    'poco.lesson.mcp.sandbox.title',
    'poco.lesson.memory.explanation',
    'poco.lesson.memory.title',
    'poco.lesson.networks.explanation',
    'poco.lesson.networks.title',
    'poco.lesson.notifications.explanation',
    'poco.lesson.notifications.title',
    'poco.lesson.owner.config.explanation',
    'poco.lesson.owner.config.title',
    'poco.lesson.pocketbase.docker.access.explanation',
    'poco.lesson.pocketbase.docker.access.title',
    'poco.lesson.pocketbase.explanation',
    'poco.lesson.pocketbase.title',
    'poco.lesson.private.access.explanation',
    'poco.lesson.private.access.title',
    'poco.lesson.public.firewall.explanation',
    'poco.lesson.public.firewall.title',
    'poco.lesson.release.source.explanation',
    'poco.lesson.release.source.title',
    'poco.lesson.ssh.explanation',
    'poco.lesson.ssh.title',
    'poco.lesson.verified.images.explanation',
    'poco.lesson.verified.images.title',
    'poco.lesson.volumes.explanation',
    'poco.lesson.volumes.title',
    'poco.lesson.vps.storage.explanation',
    'poco.lesson.vps.storage.title',
    'poco.provisioning.loading.source',
    'poco.provisioning.next',
    'poco.provisioning.previous',
    'poco.provisioning.show.concise',
    'poco.provisioning.show.full',
    'poco.provisioning.source.unavailable',
    'poco.provisioning.tour.title',
    'poco.provisioning.waiting.for.source',
    'provider.screen.add.key',
    'provider.screen.add.key.body',
    'provider.screen.add.key.title',
    'provider.screen.api.keys.section',
    'provider.screen.default.badge',
    'provider.screen.empty.hint',
    'provider.screen.error.prefix',
    'provider.screen.harness.models.section',
    'provider.screen.loading',
    'provider.screen.no.api.keys',
    'provider.screen.no.harness.models',
    'provider.screen.no.providers',
    'provider.screen.select.provider',
    'provider.screen.title',
    'provider.screen.update.key',
    'question.incoming.title',
    'question.poco.asking',
    'question.send.reply',
    'relay.activate',
    'relay.active',
    'relay.checking.status',
    'relay.config.section',
    'relay.functional.overview.body',
    'relay.functional.overview.title',
    'relay.ntfy.description',
    'relay.ntfy.title',
    'relay.permission.relay.label',
    'relay.restore',
    'relay.subsystem',
    'relay.subsystems.nominal',
    'relay.title',
    'relay.unlimited.capacity',
    'scheduler.add.button',
    'scheduler.add.dialog.title',
    'scheduler.cron.label',
    'scheduler.delete.button',
    'scheduler.edit.button',
    'scheduler.edit.dialog.title',
    'scheduler.name.label',
    'scheduler.no.schedules',
    'scheduler.pause.button',
    'scheduler.paused.badge',
    'scheduler.prompt.label',
    'scheduler.registry.title',
    'scheduler.resume.button',
    'scheduler.run.now.button',
    'scheduler.running.badge',
    'scheduler.save.button',
    'scheduler.title',
    'settings.account.section',
    'settings.ai.agents.section',
    'settings.automation.section',
    'settings.governance.section',
    'settings.logout.cancel',
    'settings.logout.confirm',
    'settings.logout.confirm.body',
    'settings.logout.confirm.title',
    'settings.observability.section',
    'settings.security.section',
    'settings.system.section',
    'settings.title',
    'skills.add.button',
    'skills.add.dialog.title',
    'skills.content.label',
    'skills.delete.button',
    'skills.description.label',
    'skills.edit.button',
    'skills.edit.dialog.title',
    'skills.global.label',
    'skills.global.section',
    'skills.name.label',
    'skills.no.eligible.config',
    'skills.no.skills',
    'skills.project.label',
    'skills.project.section',
    'skills.registry.title',
    'skills.save.button',
    'skills.title',
    'system.checks.diagnostics',
    'system.checks.empty',
    'system.checks.title',
    'terminal.connecting',
    'terminal.connection.failed',
    'terminal.connection.status',
    'terminal.destination.path',
    'terminal.offline',
    'terminal.online',
    'terminal.reconnect',
    'terminal.retry',
    'terminal.sftp.title',
    'terminal.ssh.link',
    'terminal.title',
    'terminal.transfer',
    'terminal.upload',
    'thoughts.waiting',
    'tool.permissions.action.label',
    'tool.permissions.add',
    'tool.permissions.add.rule.title',
    'tool.permissions.add.title',
    'tool.permissions.allow.label',
    'tool.permissions.ask.label',
    'tool.permissions.deny.label',
    'tool.permissions.empty',
    'tool.permissions.error',
    'tool.permissions.fetch.failed',
    'tool.permissions.frame.title',
    'tool.permissions.loading',
    'tool.permissions.no.rules',
    'tool.permissions.pattern.label',
    'tool.permissions.rules.registry',
    'tool.permissions.scope.agent',
    'tool.permissions.scope.global',
    'tool.permissions.screen.title',
    'tool.permissions.title',
    'tool.permissions.tool.label',
    'tool.permissions.tool.name.label',
    'tool.permissions.update.failed',
    'walkthrough.action.show.concise.code',
    'walkthrough.action.show.full.code',
    'walkthrough.activation.health.poco',
    'walkthrough.activation.health.title',
    'walkthrough.activation.prepare.poco',
    'walkthrough.activation.prepare.title',
    'walkthrough.activation.selected.software.poco',
    'walkthrough.activation.selected.software.title',
    'walkthrough.activation.switch.poco',
    'walkthrough.activation.switch.title',
    'walkthrough.ask.poco',
    'walkthrough.brief.divider',
    'walkthrough.caddy.address.chip.https',
    'walkthrough.caddy.address.chip.ip.address',
    'walkthrough.caddy.address.chip.sslip',
    'walkthrough.caddy.address.poco',
    'walkthrough.caddy.address.title',
    'walkthrough.caddy.web.entry.chip.caddy',
    'walkthrough.caddy.web.entry.chip.private.port',
    'walkthrough.caddy.web.entry.poco',
    'walkthrough.caddy.web.entry.title',
    'walkthrough.debian.setup.status.chip.failure',
    'walkthrough.debian.setup.status.chip.status',
    'walkthrough.debian.setup.status.poco',
    'walkthrough.debian.setup.status.title',
    'walkthrough.header',
    'walkthrough.label',
    'walkthrough.nixos.docker.poco',
    'walkthrough.nixos.docker.rules.poco',
    'walkthrough.nixos.docker.rules.title',
    'walkthrough.nixos.docker.title',
    'walkthrough.nixos.network.chip.docker.rules',
    'walkthrough.nixos.network.chip.ip.versions',
    'walkthrough.nixos.network.chip.ports',
    'walkthrough.nixos.network.poco',
    'walkthrough.nixos.network.title',
    'walkthrough.nixos.ssh.poco',
    'walkthrough.nixos.ssh.title',
    'walkthrough.nixos.storage.poco',
    'walkthrough.nixos.storage.title',
    'walkthrough.progress',
    'walkthrough.runtime.settings.chip.local.settings',
    'walkthrough.runtime.settings.poco',
    'walkthrough.runtime.settings.title',
    'walkthrough.runtime.version.poco',
    'walkthrough.runtime.version.title',
    'walkthrough.server.key.chip.private',
    'walkthrough.server.key.chip.public',
    'walkthrough.server.key.chip.ssh',
    'walkthrough.server.key.poco',
    'walkthrough.server.key.title',
    'walkthrough.services.cognee.badge',
    'walkthrough.services.cognee.poco',
    'walkthrough.services.cognee.title',
    'walkthrough.services.compose.chip.docker.compose',
    'walkthrough.services.compose.chip.private.connections',
    'walkthrough.services.compose.chip.saved.data',
    'walkthrough.services.compose.poco',
    'walkthrough.services.compose.title',
    'walkthrough.services.harnesses.chip.add',
    'walkthrough.services.harnesses.chip.harness',
    'walkthrough.services.harnesses.chip.workspace',
    'walkthrough.services.harnesses.poco',
    'walkthrough.services.harnesses.title',
    'walkthrough.services.ollama.chip.download',
    'walkthrough.services.ollama.chip.gpu',
    'walkthrough.services.ollama.chip.local.model',
    'walkthrough.services.ollama.poco',
    'walkthrough.services.ollama.title',
    'walkthrough.services.pocket.base.chip.keeps',
    'walkthrough.services.pocket.base.chip.sign.in',
    'walkthrough.services.pocket.base.chip.updates',
    'walkthrough.services.pocket.base.poco',
    'walkthrough.services.pocket.base.title',
    'walkthrough.services.sql.page.chip.contents',
    'walkthrough.services.sql.page.chip.start.order',
    'walkthrough.services.sql.page.poco',
    'walkthrough.services.sql.page.title',
    'walkthrough.services.tools.chip.harness.tools',
    'walkthrough.services.tools.chip.mcp',
    'walkthrough.services.tools.chip.proxy',
    'walkthrough.services.tools.poco',
    'walkthrough.services.tools.title',
    'walkthrough.start.pocket.coder.chip.add.harness',
    'walkthrough.start.pocket.coder.chip.what.starts',
    'walkthrough.start.pocket.coder.poco',
    'walkthrough.start.pocket.coder.title',
    'walkthrough.transition.deployment',
    'walkthrough.transition.provisioning',
    'walkthrough.verified.version.chip.download.failure',
    'walkthrough.verified.version.chip.updates',
    'walkthrough.verified.version.chip.verification',
    'walkthrough.verified.version.poco',
    'walkthrough.verified.version.title',
  };

  /// Checks if a key is known to this resolver.
  static bool hasKey(String key) => knownKeys.contains(key);

  /// Maps ARB camelCase keys to dot-notation keys.
  static const arbToDotKey = <String, String>{
    'actionAdd': 'action.add',
    'actionAddNew': 'action.add.new',
    'actionAuthorize': 'action.authorize',
    'actionBack': 'action.back',
    'actionCancel': 'action.cancel',
    'actionChange': 'action.change',
    'actionClose': 'action.close',
    'actionConfigure': 'action.configure',
    'actionContinue': 'action.continue',
    'actionCreate': 'action.create',
    'actionDeny': 'action.deny',
    'actionRefresh': 'action.refresh',
    'actionReject': 'action.reject',
    'actionRestore': 'action.restore',
    'actionSave': 'action.save',
    'agentConfigDefaultBadge': 'agent.config.default.badge',
    'agentConfigDelete': 'agent.config.delete',
    'agentConfigDeleteConfirmBody': 'agent.config.delete.confirm.body',
    'agentConfigDeleteConfirmTitle': 'agent.config.delete.confirm.title',
    'agentConfigDialogTitle': 'agent.config.dialog.title',
    'agentConfigEmpty': 'agent.config.empty',
    'agentConfigErrorPrefix': 'agent.config.error.prefix',
    'agentConfigHarnessModelLabel': 'agent.config.harness.model.label',
    'agentConfigIsDefaultLabel': 'agent.config.is.default.label',
    'agentConfigModeLabel': 'agent.config.mode.label',
    'agentConfigNameLabel': 'agent.config.name.label',
    'agentConfigNoHarnessModels': 'agent.config.no.harness.models',
    'agentConfigNoModes': 'agent.config.no.modes',
    'agentConfigNoPrompts': 'agent.config.no.prompts',
    'agentConfigPromptLabel': 'agent.config.prompt.label',
    'agentConfigRegistry': 'agent.config.registry',
    'agentConfigSelectHarnessModel': 'agent.config.select.harness.model',
    'agentConfigSelectMode': 'agent.config.select.mode',
    'agentConfigSelectPrompt': 'agent.config.select.prompt',
    'agentConfigTitle': 'agent.config.title',
    'agentDefaultTuned': 'agent.default.tuned',
    'agentDescriptionLabel': 'agent.description.label',
    'agentDialogTitle': 'agent.dialog.title',
    'agentModelsLabel': 'agent.models.label',
    'agentModelsPersonas': 'agent.models.personas',
    'agentNameLabel': 'agent.name.label',
    'agentNone': 'agent.none',
    'agentNoneSelected': 'agent.none.selected',
    'agentParametersLabel': 'agent.parameters.label',
    'agentPromptsLabel': 'agent.prompts.label',
    'agentRegistryEmpty': 'agent.registry.empty',
    'agentSearching': 'agent.searching',
    'agentSelectToConfigure': 'agent.select.to.configure',
    'agentTitle': 'agent.title',
    'aiError': 'ai.error',
    'aiFetchFailed': 'ai.fetch.failed',
    'aiSaveFailed': 'ai.save.failed',
    'appTitle': 'app.title',
    'authError': 'auth.error',
    'authLoginFailed': 'auth.login.failed',
    'authNotAuthenticated': 'auth.not.authenticated',
    'authTokenExpired': 'auth.token.expired',
    'bootCheckingConnection': 'boot.checking.connection',
    'bootConnectionFailed': 'boot.connection.failed',
    'bootLoadError': 'boot.load.error',
    'bootPocoIntro': 'boot.poco.intro',
    'bootSystemsNominal': 'boot.systems.nominal',
    'bootWelcomeBack': 'boot.welcome.back',
    'briefLabel': 'brief.label',
    'chatCommandOutput': 'chat.command.output',
    'chatCommanderRole': 'chat.commander.role',
    'chatCreated': 'chat.created',
    'chatDecline': 'chat.decline',
    'chatElicitationRequest': 'chat.elicitation.request',
    'chatError': 'chat.error',
    'chatFetchFailed': 'chat.fetch.failed',
    'chatFilesAction': 'chat.files.action',
    'chatListArchive': 'chat.list.archive',
    'chatListDelete': 'chat.list.delete',
    'chatListError': 'chat.list.error',
    'chatListNewChat': 'chat.list.new.chat',
    'chatListNoMessages': 'chat.list.no.messages',
    'chatListTimestampDaysAgo': 'chat.list.timestamp.days.ago',
    'chatListTimestampHoursAgo': 'chat.list.timestamp.hours.ago',
    'chatListTimestampMinutesAgo': 'chat.list.timestamp.minutes.ago',
    'chatListTimestampNow': 'chat.list.timestamp.now',
    'chatMessageSent': 'chat.message.sent',
    'chatModelDefault': 'chat.model.default',
    'chatModelLabel': 'chat.model.label',
    'chatModelPerChat': 'chat.model.per.chat',
    'chatNewCapabilityRequest': 'chat.new.capability.request',
    'chatNoFieldsRequested': 'chat.no.fields.requested',
    'chatNotFound': 'chat.not.found',
    'chatPocoRole': 'chat.poco.role',
    'chatSelectModelTitle': 'chat.select.model.title',
    'chatSendFailed': 'chat.send.failed',
    'chatSendTooltip': 'chat.send.tooltip',
    'chatSessionAction': 'chat.session.action',
    'chatSessionTitle': 'chat.session.title',
    'chatSubmit': 'chat.submit',
    'chatTerminalAction': 'chat.terminal.action',
    'chatThinking': 'chat.thinking',
    'chatThinkingLive': 'chat.thinking.live',
    'chatThinkingRole': 'chat.thinking.role',
    'chatThought': 'chat.thought',
    'chatUseGlobalDefault': 'chat.use.global.default',
    'deployChooseProvider': 'deploy.choose.provider',
    'deployComingSoon': 'deploy.coming.soon',
    'deployProBadge': 'deploy.pro.badge',
    'deploySelectProvider': 'deploy.select.provider',
    'deployTitle': 'deploy.title',
    'deploymentActionAbort': 'deployment.action.abort',
    'deploymentActionBack': 'deployment.action.back',
    'deploymentActionDeployInstance': 'deployment.action.deploy.instance',
    'deploymentActionDismiss': 'deployment.action.dismiss',
    'deploymentActionLoginNow': 'deployment.action.login.now',
    'deploymentActionRefresh': 'deployment.action.refresh',
    'deploymentActionRetryScan': 'deployment.action.retry.scan',
    'deploymentActionUpdate': 'deployment.action.update',
    'deploymentAdminIdentity': 'deployment.admin.identity',
    'deploymentAdminPassword': 'deployment.admin.password',
    'deploymentBackend': 'deployment.backend',
    'deploymentCloudRegion': 'deployment.cloud.region',
    'deploymentCodingHarnesses': 'deployment.coding.harnesses',
    'deploymentConnectionParameters': 'deployment.connection.parameters',
    'deploymentCopiedToBuffer': 'deployment.copied.to.buffer',
    'deploymentCopyLabel': 'deployment.copy.label',
    'deploymentCurrentOperation': 'deployment.current.operation',
    'deploymentDebian': 'deployment.debian',
    'deploymentDescriptionConstructing': 'deployment.description.constructing',
    'deploymentDescriptionFailed': 'deployment.description.failed',
    'deploymentDescriptionFetching': 'deployment.description.fetching',
    'deploymentDescriptionFinishing': 'deployment.description.finishing',
    'deploymentDescriptionInitializing': 'deployment.description.initializing',
    'deploymentDescriptionInstalling': 'deployment.description.installing',
    'deploymentDescriptionLoadingImages': 'deployment.description.loading.images',
    'deploymentDescriptionPreparingHost': 'deployment.description.preparing.host',
    'deploymentDescriptionReady': 'deployment.description.ready',
    'deploymentDescriptionSecuring': 'deployment.description.securing',
    'deploymentDescriptionStarting': 'deployment.description.starting',
    'deploymentDescriptionValidating': 'deployment.description.validating',
    'deploymentDistribution': 'deployment.distribution',
    'deploymentErrorCode': 'deployment.error.code',
    'deploymentFaultDetected': 'deployment.fault.detected',
    'deploymentGeoGrid': 'deployment.geo.grid',
    'deploymentHardwareGeography': 'deployment.hardware.geography',
    'deploymentHardwarePlan': 'deployment.hardware.plan',
    'deploymentHarnessSelectionDescription': 'deployment.harness.selection.description',
    'deploymentHttpsEndpoint': 'deployment.https.endpoint',
    'deploymentInitializingHardware': 'deployment.initializing.hardware',
    'deploymentInstanceManifest': 'deployment.instance.manifest',
    'deploymentInstancePlan': 'deployment.instance.plan',
    'deploymentIpAddress': 'deployment.ip.address',
    'deploymentLastSignal': 'deployment.last.signal',
    'deploymentManifestConfiguration': 'deployment.manifest.configuration',
    'deploymentMetadataRegistry': 'deployment.metadata.registry',
    'deploymentMonthlyPrice': 'deployment.monthly.price',
    'deploymentNetworkIp': 'deployment.network.ip',
    'deploymentNixos': 'deployment.nixos',
    'deploymentOperatingSystem': 'deployment.operating.system',
    'deploymentProvisioned': 'deployment.provisioned',
    'deploymentRegion': 'deployment.region',
    'deploymentRunId': 'deployment.run.id',
    'deploymentScanningRegions': 'deployment.scanning.regions',
    'deploymentScreenTitle': 'deployment.screen.title',
    'deploymentSecure': 'deployment.secure',
    'deploymentSecurityNotice': 'deployment.security.notice',
    'deploymentSourceCommit': 'deployment.source.commit',
    'deploymentStandardLinux': 'deployment.standard.linux',
    'deploymentStatusConstructing': 'deployment.status.constructing',
    'deploymentStatusFailed': 'deployment.status.failed',
    'deploymentStatusFetching': 'deployment.status.fetching',
    'deploymentStatusFinishing': 'deployment.status.finishing',
    'deploymentStatusInitializing': 'deployment.status.initializing',
    'deploymentStatusInstalling': 'deployment.status.installing',
    'deploymentStatusLoadingImages': 'deployment.status.loading.images',
    'deploymentStatusPrefix': 'deployment.status.prefix',
    'deploymentStatusPreparingHost': 'deployment.status.preparing.host',
    'deploymentStatusReady': 'deployment.status.ready',
    'deploymentStatusSchema': 'deployment.status.schema',
    'deploymentStatusSecuring': 'deployment.status.securing',
    'deploymentStatusStarting': 'deployment.status.starting',
    'deploymentStatusValidating': 'deployment.status.validating',
    'deploymentSyncAttempt': 'deployment.sync.attempt',
    'deploymentSystemParameters': 'deployment.system.parameters',
    'deploymentUbuntu': 'deployment.ubuntu',
    'deploymentUnknown': 'deployment.unknown',
    'errorAuthFailed': 'error.auth.failed',
    'errorAuthUnauthorized': 'error.auth.unauthorized',
    'errorGeneric': 'error.generic',
    'errorNetwork': 'error.network',
    'errorTimeout': 'error.timeout',
    'errorsClearAll': 'errors.clear.all',
    'errorsCopied': 'errors.copied',
    'errorsCopy': 'errors.copy',
    'errorsCopyAll': 'errors.copy.all',
    'errorsEmpty': 'errors.empty',
    'errorsOccurred': 'errors.occurred',
    'errorsTitle': 'errors.title',
    'fileClearAction': 'file.clear.action',
    'fileDashboardAction': 'file.dashboard.action',
    'fileEmpty': 'file.empty',
    'fileFetching': 'file.fetching',
    'fileNoFileSelected': 'file.no.file.selected',
    'fileSelectFromChat': 'file.select.from.chat',
    'fileTitle': 'file.title',
    'filesCantPreviewType': 'files.cant.preview.type',
    'filesEmpty': 'files.empty',
    'filesTitle': 'files.title',
    'filesTooLargeToPreview': 'files.too.large.to.preview',
    'harnessAuthChallengeTargetCopied': 'harness.auth.challenge.target.copied',
    'homeErrorPrefix': 'home.error.prefix',
    'homeLoadingChats': 'home.loading.chats',
    'homeNewChat': 'home.new.chat',
    'homeNoChats': 'home.no.chats',
    'homeTitle': 'home.title',
    'llmActiveModelSection': 'llm.active.model.section',
    'llmAddKey': 'llm.add.key',
    'llmAddKeyHint': 'llm.add.key.hint',
    'llmApiKeyDialogTitle': 'llm.api.key.dialog.title',
    'llmApiKeysSection': 'llm.api.keys.section',
    'llmConnected': 'llm.connected',
    'llmEnterCredentials': 'llm.enter.credentials',
    'llmGlobalDefault': 'llm.global.default',
    'llmLoadingProviders': 'llm.loading.providers',
    'llmModelsAvailable': 'llm.models.available',
    'llmModelsButton': 'llm.models.button',
    'llmNoKey': 'llm.no.key',
    'llmNoModels': 'llm.no.models',
    'llmNoProviders': 'llm.no.providers',
    'llmNotSet': 'llm.not.set',
    'llmProviderModelsTitle': 'llm.provider.models.title',
    'llmProvidersSection': 'llm.providers.section',
    'llmSelect': 'llm.select',
    'llmSelectModelTitle': 'llm.select.model.title',
    'llmTitle': 'llm.title',
    'llmUpdateKey': 'llm.update.key',
    'mcpActiveCapabilities': 'mcp.active.capabilities',
    'mcpAddConfigOptional': 'mcp.add.config.optional',
    'mcpAddDialogTitle': 'mcp.add.dialog.title',
    'mcpAuthorizeCap': 'mcp.authorize.cap',
    'mcpAuthorizeDialogTitle': 'mcp.authorize.dialog.title',
    'mcpCapabilitiesRegistry': 'mcp.capabilities.registry',
    'mcpConnectCap': 'mcp.connect.cap',
    'mcpEditConfig': 'mcp.edit.config',
    'mcpEnterSecrets': 'mcp.enter.secrets',
    'mcpImageLabel': 'mcp.image.label',
    'mcpImageOptionalLabel': 'mcp.image.optional.label',
    'mcpNoCapabilities': 'mcp.no.capabilities',
    'mcpNoConfigRequired': 'mcp.no.config.required',
    'mcpOauthProviderNotConfiguredLabel': 'mcp.oauth.provider.not.configured.label',
    'mcpOauthProviderOptionalLabel': 'mcp.oauth.provider.optional.label',
    'mcpOauthRequiredLabel': 'mcp.oauth.required.label',
    'mcpOauthTokenEnvVarOptionalLabel': 'mcp.oauth.token.env.var.optional.label',
    'mcpPendingApproval': 'mcp.pending.approval',
    'mcpPurposeLabel': 'mcp.purpose.label',
    'mcpRequiredConfig': 'mcp.required.config',
    'mcpRetryDeliveryCap': 'mcp.retry.delivery.cap',
    'mcpRevoke': 'mcp.revoke',
    'mcpServerNameLabel': 'mcp.server.name.label',
    'mcpTitle': 'mcp.title',
    'mcpUpdateConfigDialogTitle': 'mcp.update.config.dialog.title',
    'monitorAgentActivity': 'monitor.agent.activity',
    'monitorCostLabel': 'monitor.cost.label',
    'monitorFetchingTelemetry': 'monitor.fetching.telemetry',
    'monitorKeyMetrics': 'monitor.key.metrics',
    'monitorMessagesLabel': 'monitor.messages.label',
    'monitorNoData': 'monitor.no.data',
    'monitorSystemHealth': 'monitor.system.health',
    'monitorTelemetryUnavailable': 'monitor.telemetry.unavailable',
    'monitorTitle': 'monitor.title',
    'monitorTokenUsage': 'monitor.token.usage',
    'monitorTokensLabel': 'monitor.tokens.label',
    'navChats': 'nav.chats',
    'navConfigure': 'nav.configure',
    'navMonitor': 'nav.monitor',
    'newChatCancel': 'new.chat.cancel',
    'newChatCreate': 'new.chat.create',
    'newChatCwdField': 'new.chat.cwd.field',
    'newChatCwdHint': 'new.chat.cwd.hint',
    'newChatHarnessField': 'new.chat.harness.field',
    'newChatModelField': 'new.chat.model.field',
    'newChatNoModelsAvailable': 'new.chat.no.models.available',
    'newChatSelectHarness': 'new.chat.select.harness',
    'newChatSelectModel': 'new.chat.select.model',
    'newChatTitle': 'new.chat.title',
    'newChatTitleField': 'new.chat.title.field',
    'newChatWorkspaceErrorEmpty': 'new.chat.workspace.error.empty',
    'newChatWorkspaceErrorInvalid': 'new.chat.workspace.error.invalid',
    'notificationSettingsChatReplyLabel': 'notification.settings.chat.reply.label',
    'notificationSettingsScheduleLabel': 'notification.settings.schedule.label',
    'notificationSettingsScreenTitle': 'notification.settings.screen.title',
    'notificationSettingsTaskCompleteLabel': 'notification.settings.task.complete.label',
    'notificationSettingsTaskErrorLabel': 'notification.settings.task.error.label',
    'notificationSignalReceived': 'notification.signal.received',
    'observabilityBackend': 'observability.backend',
    'observabilityCost': 'observability.cost',
    'observabilityLogTerminal': 'observability.log.terminal',
    'observabilityMsgs': 'observability.msgs',
    'observabilityRegistry': 'observability.registry',
    'observabilitySelectContainer': 'observability.select.container',
    'observabilityTitle': 'observability.title',
    'observabilityTokens': 'observability.tokens',
    'onboardingAccessDenied': 'onboarding.access.denied',
    'onboardingAccountLogin': 'onboarding.account.login',
    'onboardingAuthenticating': 'onboarding.authenticating',
    'onboardingAuthorizationCode': 'onboarding.authorization.code',
    'onboardingAuthorizationCodeHint': 'onboarding.authorization.code.hint',
    'onboardingCheckStatus': 'onboarding.check.status',
    'onboardingChooseHarnessBody': 'onboarding.choose.harness.body',
    'onboardingChooseHarnessTitle': 'onboarding.choose.harness.title',
    'onboardingClaudeAccountLogin': 'onboarding.claude.account.login',
    'onboardingCodexAccountLogin': 'onboarding.codex.account.login',
    'onboardingConnectOrDeploy': 'onboarding.connect.or.deploy',
    'onboardingConnected': 'onboarding.connected',
    'onboardingCreateServer': 'onboarding.create.server',
    'onboardingDeploy': 'onboarding.deploy',
    'onboardingDeployTitle': 'onboarding.deploy.title',
    'onboardingDockerIntroActionStart': 'onboarding.docker.intro.action.start',
    'onboardingDockerIntroChipComponent': 'onboarding.docker.intro.chip.component',
    'onboardingDockerIntroChipConnections': 'onboarding.docker.intro.chip.connections',
    'onboardingDockerIntroChipContainer': 'onboarding.docker.intro.chip.container',
    'onboardingDockerIntroChipSavedData': 'onboarding.docker.intro.chip.saved.data',
    'onboardingDockerIntroEyebrow': 'onboarding.docker.intro.eyebrow',
    'onboardingDockerIntroPoco': 'onboarding.docker.intro.poco',
    'onboardingDockerIntroTitle': 'onboarding.docker.intro.title',
    'onboardingEmail': 'onboarding.email',
    'onboardingEmailHint': 'onboarding.email.hint',
    'onboardingEmailHintShort': 'onboarding.email.hint.short',
    'onboardingExistingServer': 'onboarding.existing.server',
    'onboardingFailureActionBackToSetup': 'onboarding.failure.action.back.to.setup',
    'onboardingFailureActionRetryConnection': 'onboarding.failure.action.retry.connection',
    'onboardingFailureActionTechnicalDetails': 'onboarding.failure.action.technical.details',
    'onboardingFailureActionViewServerDetails': 'onboarding.failure.action.view.server.details',
    'onboardingFailureConnectionPoco': 'onboarding.failure.connection.poco',
    'onboardingFailureCreatePoco': 'onboarding.failure.create.poco',
    'onboardingHarnessLoginTitle': 'onboarding.harness.login.title',
    'onboardingHarnessNotFound': 'onboarding.harness.not.found',
    'onboardingHarnessPoco': 'onboarding.harness.poco',
    'onboardingHarnessTitle': 'onboarding.harness.title',
    'onboardingHomeServer': 'onboarding.home.server',
    'onboardingIdentityLabel': 'onboarding.identity.label',
    'onboardingIntentChipCloudModels': 'onboarding.intent.chip.cloud.models',
    'onboardingIntentChipLocalModels': 'onboarding.intent.chip.local.models',
    'onboardingIntentPoco': 'onboarding.intent.poco',
    'onboardingLogin': 'onboarding.login',
    'onboardingNoServerChipExisting': 'onboarding.no.server.chip.existing',
    'onboardingNoServerChipNew': 'onboarding.no.server.chip.new',
    'onboardingNoServerLookingPoco': 'onboarding.no.server.looking.poco',
    'onboardingNoServerPoco': 'onboarding.no.server.poco',
    'onboardingOpenAuthorization': 'onboarding.open.authorization',
    'onboardingOpenChatFailed': 'onboarding.open.chat.failed',
    'onboardingOrientationActionContinue': 'onboarding.orientation.action.continue',
    'onboardingOrientationActionSkip': 'onboarding.orientation.action.skip',
    'onboardingOrientationTitle': 'onboarding.orientation.title',
    'onboardingOsDebianDescription': 'onboarding.os.debian.description',
    'onboardingOsDebianLabel': 'onboarding.os.debian.label',
    'onboardingOsNixosDescription': 'onboarding.os.nixos.description',
    'onboardingOsNixosLabel': 'onboarding.os.nixos.label',
    'onboardingOsPoco': 'onboarding.os.poco',
    'onboardingOsTitle': 'onboarding.os.title',
    'onboardingPassphraseLabel': 'onboarding.passphrase.label',
    'onboardingPassword': 'onboarding.password',
    'onboardingPasswordHint': 'onboarding.password.hint',
    'onboardingPlanPoco': 'onboarding.plan.poco',
    'onboardingPlanTitle': 'onboarding.plan.title',
    'onboardingPocketbaseAdminEmail': 'onboarding.pocketbase.admin.email',
    'onboardingPocketbaseAdminPassword': 'onboarding.pocketbase.admin.password',
    'onboardingPocoChallengeMessage': 'onboarding.poco.challenge.message',
    'onboardingPocoWelcome': 'onboarding.poco.welcome',
    'onboardingProcessing': 'onboarding.processing',
    'onboardingProviderAuthorizationAction': 'onboarding.provider.authorization.action',
    'onboardingProviderAuthorizationPoco': 'onboarding.provider.authorization.poco',
    'onboardingProviderAuthorizationTitle': 'onboarding.provider.authorization.title',
    'onboardingProviderChipElestioComingSoon': 'onboarding.provider.chip.elestio.coming.soon',
    'onboardingProviderChipLinode': 'onboarding.provider.chip.linode',
    'onboardingProviderPoco': 'onboarding.provider.poco',
    'onboardingProviderTitle': 'onboarding.provider.title',
    'onboardingProvisioningPoco': 'onboarding.provisioning.poco',
    'onboardingReadyActionLogin': 'onboarding.ready.action.login',
    'onboardingReadyPoco': 'onboarding.ready.poco',
    'onboardingRegionConsentChipChooseMyself': 'onboarding.region.consent.chip.choose.myself',
    'onboardingRegionConsentChipUseLocation': 'onboarding.region.consent.chip.use.location',
    'onboardingRegionConsentPoco': 'onboarding.region.consent.poco',
    'onboardingRegionPoco': 'onboarding.region.poco',
    'onboardingRegionTitle': 'onboarding.region.title',
    'onboardingRequiredFields': 'onboarding.required.fields',
    'onboardingReviewActionProvision': 'onboarding.review.action.provision',
    'onboardingReviewPoco': 'onboarding.review.poco',
    'onboardingReviewTitle': 'onboarding.review.title',
    'onboardingServerConnecting': 'onboarding.server.connecting',
    'onboardingServerLoginTitle': 'onboarding.server.login.title',
    'onboardingServerUrl': 'onboarding.server.url',
    'onboardingServerUrlHint': 'onboarding.server.url.hint',
    'onboardingSetupTitle': 'onboarding.setup.title',
    'onboardingSignInPoco': 'onboarding.sign.in.poco',
    'onboardingSignInTitle': 'onboarding.sign.in.title',
    'onboardingSubmitCode': 'onboarding.submit.code',
    'onboardingTitle': 'onboarding.title',
    'onboardingTrialChipNotNow': 'onboarding.trial.chip.not.now',
    'onboardingTrialChipStart': 'onboarding.trial.chip.start',
    'onboardingTrialPoco': 'onboarding.trial.poco',
    'permissionError': 'permission.error',
    'permissionFetchFailed': 'permission.fetch.failed',
    'permissionPatternsLabel': 'permission.patterns.label',
    'permissionRequestingLabel': 'permission.requesting.label',
    'permissionSignoffTitle': 'permission.signoff.title',
    'permissionUpdateFailed': 'permission.update.failed',
    'pocketCoderProgressActive': 'pocket.coder.progress.active',
    'pocketCoderProgressComplete': 'pocket.coder.progress.complete',
    'pocketCoderProgressDeployPocketCoder': 'pocket.coder.progress.deploy.pocket.coder',
    'pocketCoderProgressFailed': 'pocket.coder.progress.failed',
    'pocketCoderProgressInitializing': 'pocket.coder.progress.initializing',
    'pocketCoderProgressProvisionServer': 'pocket.coder.progress.provision.server',
    'pocketCoderProgressWaiting': 'pocket.coder.progress.waiting',
    'pocoLessonAgentExplanation': 'poco.lesson.agent.explanation',
    'pocoLessonAgentTitle': 'poco.lesson.agent.title',
    'pocoLessonComposeStartExplanation': 'poco.lesson.compose.start.explanation',
    'pocoLessonComposeStartTitle': 'poco.lesson.compose.start.title',
    'pocoLessonContainerFirewallExplanation': 'poco.lesson.container.firewall.explanation',
    'pocoLessonContainerFirewallTitle': 'poco.lesson.container.firewall.title',
    'pocoLessonDashboardExplanation': 'poco.lesson.dashboard.explanation',
    'pocoLessonDashboardTitle': 'poco.lesson.dashboard.title',
    'pocoLessonDockerExplanation': 'poco.lesson.docker.explanation',
    'pocoLessonDockerTitle': 'poco.lesson.docker.title',
    'pocoLessonHarnessImagesExplanation': 'poco.lesson.harness.images.explanation',
    'pocoLessonHarnessImagesTitle': 'poco.lesson.harness.images.title',
    'pocoLessonLocalCaddyExplanation': 'poco.lesson.local.caddy.explanation',
    'pocoLessonLocalCaddyTitle': 'poco.lesson.local.caddy.title',
    'pocoLessonLocalModelExplanation': 'poco.lesson.local.model.explanation',
    'pocoLessonLocalModelTitle': 'poco.lesson.local.model.title',
    'pocoLessonLocalSecretsExplanation': 'poco.lesson.local.secrets.explanation',
    'pocoLessonLocalSecretsTitle': 'poco.lesson.local.secrets.title',
    'pocoLessonMcpSandboxExplanation': 'poco.lesson.mcp.sandbox.explanation',
    'pocoLessonMcpSandboxTitle': 'poco.lesson.mcp.sandbox.title',
    'pocoLessonMemoryExplanation': 'poco.lesson.memory.explanation',
    'pocoLessonMemoryTitle': 'poco.lesson.memory.title',
    'pocoLessonNetworksExplanation': 'poco.lesson.networks.explanation',
    'pocoLessonNetworksTitle': 'poco.lesson.networks.title',
    'pocoLessonNotificationsExplanation': 'poco.lesson.notifications.explanation',
    'pocoLessonNotificationsTitle': 'poco.lesson.notifications.title',
    'pocoLessonOwnerConfigExplanation': 'poco.lesson.owner.config.explanation',
    'pocoLessonOwnerConfigTitle': 'poco.lesson.owner.config.title',
    'pocoLessonPocketbaseDockerAccessExplanation': 'poco.lesson.pocketbase.docker.access.explanation',
    'pocoLessonPocketbaseDockerAccessTitle': 'poco.lesson.pocketbase.docker.access.title',
    'pocoLessonPocketbaseExplanation': 'poco.lesson.pocketbase.explanation',
    'pocoLessonPocketbaseTitle': 'poco.lesson.pocketbase.title',
    'pocoLessonPrivateAccessExplanation': 'poco.lesson.private.access.explanation',
    'pocoLessonPrivateAccessTitle': 'poco.lesson.private.access.title',
    'pocoLessonPublicFirewallExplanation': 'poco.lesson.public.firewall.explanation',
    'pocoLessonPublicFirewallTitle': 'poco.lesson.public.firewall.title',
    'pocoLessonReleaseSourceExplanation': 'poco.lesson.release.source.explanation',
    'pocoLessonReleaseSourceTitle': 'poco.lesson.release.source.title',
    'pocoLessonSshExplanation': 'poco.lesson.ssh.explanation',
    'pocoLessonSshTitle': 'poco.lesson.ssh.title',
    'pocoLessonVerifiedImagesExplanation': 'poco.lesson.verified.images.explanation',
    'pocoLessonVerifiedImagesTitle': 'poco.lesson.verified.images.title',
    'pocoLessonVolumesExplanation': 'poco.lesson.volumes.explanation',
    'pocoLessonVolumesTitle': 'poco.lesson.volumes.title',
    'pocoLessonVpsStorageExplanation': 'poco.lesson.vps.storage.explanation',
    'pocoLessonVpsStorageTitle': 'poco.lesson.vps.storage.title',
    'pocoProvisioningLoadingSource': 'poco.provisioning.loading.source',
    'pocoProvisioningNext': 'poco.provisioning.next',
    'pocoProvisioningPrevious': 'poco.provisioning.previous',
    'pocoProvisioningShowConcise': 'poco.provisioning.show.concise',
    'pocoProvisioningShowFull': 'poco.provisioning.show.full',
    'pocoProvisioningSourceUnavailable': 'poco.provisioning.source.unavailable',
    'pocoProvisioningTourTitle': 'poco.provisioning.tour.title',
    'pocoProvisioningWaitingForSource': 'poco.provisioning.waiting.for.source',
    'providerScreenAddKey': 'provider.screen.add.key',
    'providerScreenAddKeyBody': 'provider.screen.add.key.body',
    'providerScreenAddKeyTitle': 'provider.screen.add.key.title',
    'providerScreenApiKeysSection': 'provider.screen.api.keys.section',
    'providerScreenDefaultBadge': 'provider.screen.default.badge',
    'providerScreenEmptyHint': 'provider.screen.empty.hint',
    'providerScreenErrorPrefix': 'provider.screen.error.prefix',
    'providerScreenHarnessModelsSection': 'provider.screen.harness.models.section',
    'providerScreenLoading': 'provider.screen.loading',
    'providerScreenNoApiKeys': 'provider.screen.no.api.keys',
    'providerScreenNoHarnessModels': 'provider.screen.no.harness.models',
    'providerScreenNoProviders': 'provider.screen.no.providers',
    'providerScreenSelectProvider': 'provider.screen.select.provider',
    'providerScreenTitle': 'provider.screen.title',
    'providerScreenUpdateKey': 'provider.screen.update.key',
    'questionIncomingTitle': 'question.incoming.title',
    'questionPocoAsking': 'question.poco.asking',
    'questionSendReply': 'question.send.reply',
    'relayActivate': 'relay.activate',
    'relayActive': 'relay.active',
    'relayCheckingStatus': 'relay.checking.status',
    'relayConfigSection': 'relay.config.section',
    'relayFunctionalOverviewBody': 'relay.functional.overview.body',
    'relayFunctionalOverviewTitle': 'relay.functional.overview.title',
    'relayNtfyDescription': 'relay.ntfy.description',
    'relayNtfyTitle': 'relay.ntfy.title',
    'relayPermissionRelayLabel': 'relay.permission.relay.label',
    'relayRestore': 'relay.restore',
    'relaySubsystem': 'relay.subsystem',
    'relaySubsystemsNominal': 'relay.subsystems.nominal',
    'relayTitle': 'relay.title',
    'relayUnlimitedCapacity': 'relay.unlimited.capacity',
    'schedulerAddButton': 'scheduler.add.button',
    'schedulerAddDialogTitle': 'scheduler.add.dialog.title',
    'schedulerCronLabel': 'scheduler.cron.label',
    'schedulerDeleteButton': 'scheduler.delete.button',
    'schedulerEditButton': 'scheduler.edit.button',
    'schedulerEditDialogTitle': 'scheduler.edit.dialog.title',
    'schedulerNameLabel': 'scheduler.name.label',
    'schedulerNoSchedules': 'scheduler.no.schedules',
    'schedulerPauseButton': 'scheduler.pause.button',
    'schedulerPausedBadge': 'scheduler.paused.badge',
    'schedulerPromptLabel': 'scheduler.prompt.label',
    'schedulerRegistryTitle': 'scheduler.registry.title',
    'schedulerResumeButton': 'scheduler.resume.button',
    'schedulerRunNowButton': 'scheduler.run.now.button',
    'schedulerRunningBadge': 'scheduler.running.badge',
    'schedulerSaveButton': 'scheduler.save.button',
    'schedulerTitle': 'scheduler.title',
    'settingsAccountSection': 'settings.account.section',
    'settingsAiAgentsSection': 'settings.ai.agents.section',
    'settingsAutomationSection': 'settings.automation.section',
    'settingsGovernanceSection': 'settings.governance.section',
    'settingsLogoutCancel': 'settings.logout.cancel',
    'settingsLogoutConfirm': 'settings.logout.confirm',
    'settingsLogoutConfirmBody': 'settings.logout.confirm.body',
    'settingsLogoutConfirmTitle': 'settings.logout.confirm.title',
    'settingsObservabilitySection': 'settings.observability.section',
    'settingsSecuritySection': 'settings.security.section',
    'settingsSystemSection': 'settings.system.section',
    'settingsTitle': 'settings.title',
    'skillsAddButton': 'skills.add.button',
    'skillsAddDialogTitle': 'skills.add.dialog.title',
    'skillsContentLabel': 'skills.content.label',
    'skillsDeleteButton': 'skills.delete.button',
    'skillsDescriptionLabel': 'skills.description.label',
    'skillsEditButton': 'skills.edit.button',
    'skillsEditDialogTitle': 'skills.edit.dialog.title',
    'skillsGlobalLabel': 'skills.global.label',
    'skillsGlobalSection': 'skills.global.section',
    'skillsNameLabel': 'skills.name.label',
    'skillsNoEligibleConfig': 'skills.no.eligible.config',
    'skillsNoSkills': 'skills.no.skills',
    'skillsProjectLabel': 'skills.project.label',
    'skillsProjectSection': 'skills.project.section',
    'skillsRegistryTitle': 'skills.registry.title',
    'skillsSaveButton': 'skills.save.button',
    'skillsTitle': 'skills.title',
    'systemChecksDiagnostics': 'system.checks.diagnostics',
    'systemChecksEmpty': 'system.checks.empty',
    'systemChecksTitle': 'system.checks.title',
    'terminalConnecting': 'terminal.connecting',
    'terminalConnectionFailed': 'terminal.connection.failed',
    'terminalConnectionStatus': 'terminal.connection.status',
    'terminalDestinationPath': 'terminal.destination.path',
    'terminalOffline': 'terminal.offline',
    'terminalOnline': 'terminal.online',
    'terminalReconnect': 'terminal.reconnect',
    'terminalRetry': 'terminal.retry',
    'terminalSftpTitle': 'terminal.sftp.title',
    'terminalSshLink': 'terminal.ssh.link',
    'terminalTitle': 'terminal.title',
    'terminalTransfer': 'terminal.transfer',
    'terminalUpload': 'terminal.upload',
    'thoughtsWaiting': 'thoughts.waiting',
    'toolPermissionsActionLabel': 'tool.permissions.action.label',
    'toolPermissionsAdd': 'tool.permissions.add',
    'toolPermissionsAddRuleTitle': 'tool.permissions.add.rule.title',
    'toolPermissionsAddTitle': 'tool.permissions.add.title',
    'toolPermissionsAllowLabel': 'tool.permissions.allow.label',
    'toolPermissionsAskLabel': 'tool.permissions.ask.label',
    'toolPermissionsDenyLabel': 'tool.permissions.deny.label',
    'toolPermissionsEmpty': 'tool.permissions.empty',
    'toolPermissionsError': 'tool.permissions.error',
    'toolPermissionsFetchFailed': 'tool.permissions.fetch.failed',
    'toolPermissionsFrameTitle': 'tool.permissions.frame.title',
    'toolPermissionsLoading': 'tool.permissions.loading',
    'toolPermissionsNoRules': 'tool.permissions.no.rules',
    'toolPermissionsPatternLabel': 'tool.permissions.pattern.label',
    'toolPermissionsRulesRegistry': 'tool.permissions.rules.registry',
    'toolPermissionsScopeAgent': 'tool.permissions.scope.agent',
    'toolPermissionsScopeGlobal': 'tool.permissions.scope.global',
    'toolPermissionsScreenTitle': 'tool.permissions.screen.title',
    'toolPermissionsTitle': 'tool.permissions.title',
    'toolPermissionsToolLabel': 'tool.permissions.tool.label',
    'toolPermissionsToolNameLabel': 'tool.permissions.tool.name.label',
    'toolPermissionsUpdateFailed': 'tool.permissions.update.failed',
    'walkthroughActionShowConciseCode': 'walkthrough.action.show.concise.code',
    'walkthroughActionShowFullCode': 'walkthrough.action.show.full.code',
    'walkthroughActivationHealthPoco': 'walkthrough.activation.health.poco',
    'walkthroughActivationHealthTitle': 'walkthrough.activation.health.title',
    'walkthroughActivationPreparePoco': 'walkthrough.activation.prepare.poco',
    'walkthroughActivationPrepareTitle': 'walkthrough.activation.prepare.title',
    'walkthroughActivationSelectedSoftwarePoco': 'walkthrough.activation.selected.software.poco',
    'walkthroughActivationSelectedSoftwareTitle': 'walkthrough.activation.selected.software.title',
    'walkthroughActivationSwitchPoco': 'walkthrough.activation.switch.poco',
    'walkthroughActivationSwitchTitle': 'walkthrough.activation.switch.title',
    'walkthroughAskPoco': 'walkthrough.ask.poco',
    'walkthroughBriefDivider': 'walkthrough.brief.divider',
    'walkthroughCaddyAddressChipHttps': 'walkthrough.caddy.address.chip.https',
    'walkthroughCaddyAddressChipIpAddress': 'walkthrough.caddy.address.chip.ip.address',
    'walkthroughCaddyAddressChipSslip': 'walkthrough.caddy.address.chip.sslip',
    'walkthroughCaddyAddressPoco': 'walkthrough.caddy.address.poco',
    'walkthroughCaddyAddressTitle': 'walkthrough.caddy.address.title',
    'walkthroughCaddyWebEntryChipCaddy': 'walkthrough.caddy.web.entry.chip.caddy',
    'walkthroughCaddyWebEntryChipPrivatePort': 'walkthrough.caddy.web.entry.chip.private.port',
    'walkthroughCaddyWebEntryPoco': 'walkthrough.caddy.web.entry.poco',
    'walkthroughCaddyWebEntryTitle': 'walkthrough.caddy.web.entry.title',
    'walkthroughDebianSetupStatusChipFailure': 'walkthrough.debian.setup.status.chip.failure',
    'walkthroughDebianSetupStatusChipStatus': 'walkthrough.debian.setup.status.chip.status',
    'walkthroughDebianSetupStatusPoco': 'walkthrough.debian.setup.status.poco',
    'walkthroughDebianSetupStatusTitle': 'walkthrough.debian.setup.status.title',
    'walkthroughHeader': 'walkthrough.header',
    'walkthroughLabel': 'walkthrough.label',
    'walkthroughNixosDockerPoco': 'walkthrough.nixos.docker.poco',
    'walkthroughNixosDockerRulesPoco': 'walkthrough.nixos.docker.rules.poco',
    'walkthroughNixosDockerRulesTitle': 'walkthrough.nixos.docker.rules.title',
    'walkthroughNixosDockerTitle': 'walkthrough.nixos.docker.title',
    'walkthroughNixosNetworkChipDockerRules': 'walkthrough.nixos.network.chip.docker.rules',
    'walkthroughNixosNetworkChipIpVersions': 'walkthrough.nixos.network.chip.ip.versions',
    'walkthroughNixosNetworkChipPorts': 'walkthrough.nixos.network.chip.ports',
    'walkthroughNixosNetworkPoco': 'walkthrough.nixos.network.poco',
    'walkthroughNixosNetworkTitle': 'walkthrough.nixos.network.title',
    'walkthroughNixosSshPoco': 'walkthrough.nixos.ssh.poco',
    'walkthroughNixosSshTitle': 'walkthrough.nixos.ssh.title',
    'walkthroughNixosStoragePoco': 'walkthrough.nixos.storage.poco',
    'walkthroughNixosStorageTitle': 'walkthrough.nixos.storage.title',
    'walkthroughProgress': 'walkthrough.progress',
    'walkthroughRuntimeSettingsChipLocalSettings': 'walkthrough.runtime.settings.chip.local.settings',
    'walkthroughRuntimeSettingsPoco': 'walkthrough.runtime.settings.poco',
    'walkthroughRuntimeSettingsTitle': 'walkthrough.runtime.settings.title',
    'walkthroughRuntimeVersionPoco': 'walkthrough.runtime.version.poco',
    'walkthroughRuntimeVersionTitle': 'walkthrough.runtime.version.title',
    'walkthroughServerKeyChipPrivate': 'walkthrough.server.key.chip.private',
    'walkthroughServerKeyChipPublic': 'walkthrough.server.key.chip.public',
    'walkthroughServerKeyChipSsh': 'walkthrough.server.key.chip.ssh',
    'walkthroughServerKeyPoco': 'walkthrough.server.key.poco',
    'walkthroughServerKeyTitle': 'walkthrough.server.key.title',
    'walkthroughServicesCogneeBadge': 'walkthrough.services.cognee.badge',
    'walkthroughServicesCogneePoco': 'walkthrough.services.cognee.poco',
    'walkthroughServicesCogneeTitle': 'walkthrough.services.cognee.title',
    'walkthroughServicesComposeChipDockerCompose': 'walkthrough.services.compose.chip.docker.compose',
    'walkthroughServicesComposeChipPrivateConnections': 'walkthrough.services.compose.chip.private.connections',
    'walkthroughServicesComposeChipSavedData': 'walkthrough.services.compose.chip.saved.data',
    'walkthroughServicesComposePoco': 'walkthrough.services.compose.poco',
    'walkthroughServicesComposeTitle': 'walkthrough.services.compose.title',
    'walkthroughServicesHarnessesChipAdd': 'walkthrough.services.harnesses.chip.add',
    'walkthroughServicesHarnessesChipHarness': 'walkthrough.services.harnesses.chip.harness',
    'walkthroughServicesHarnessesChipWorkspace': 'walkthrough.services.harnesses.chip.workspace',
    'walkthroughServicesHarnessesPoco': 'walkthrough.services.harnesses.poco',
    'walkthroughServicesHarnessesTitle': 'walkthrough.services.harnesses.title',
    'walkthroughServicesOllamaChipDownload': 'walkthrough.services.ollama.chip.download',
    'walkthroughServicesOllamaChipGpu': 'walkthrough.services.ollama.chip.gpu',
    'walkthroughServicesOllamaChipLocalModel': 'walkthrough.services.ollama.chip.local.model',
    'walkthroughServicesOllamaPoco': 'walkthrough.services.ollama.poco',
    'walkthroughServicesOllamaTitle': 'walkthrough.services.ollama.title',
    'walkthroughServicesPocketBaseChipKeeps': 'walkthrough.services.pocket.base.chip.keeps',
    'walkthroughServicesPocketBaseChipSignIn': 'walkthrough.services.pocket.base.chip.sign.in',
    'walkthroughServicesPocketBaseChipUpdates': 'walkthrough.services.pocket.base.chip.updates',
    'walkthroughServicesPocketBasePoco': 'walkthrough.services.pocket.base.poco',
    'walkthroughServicesPocketBaseTitle': 'walkthrough.services.pocket.base.title',
    'walkthroughServicesSqlPageChipContents': 'walkthrough.services.sql.page.chip.contents',
    'walkthroughServicesSqlPageChipStartOrder': 'walkthrough.services.sql.page.chip.start.order',
    'walkthroughServicesSqlPagePoco': 'walkthrough.services.sql.page.poco',
    'walkthroughServicesSqlPageTitle': 'walkthrough.services.sql.page.title',
    'walkthroughServicesToolsChipHarnessTools': 'walkthrough.services.tools.chip.harness.tools',
    'walkthroughServicesToolsChipMcp': 'walkthrough.services.tools.chip.mcp',
    'walkthroughServicesToolsChipProxy': 'walkthrough.services.tools.chip.proxy',
    'walkthroughServicesToolsPoco': 'walkthrough.services.tools.poco',
    'walkthroughServicesToolsTitle': 'walkthrough.services.tools.title',
    'walkthroughStartPocketCoderChipAddHarness': 'walkthrough.start.pocket.coder.chip.add.harness',
    'walkthroughStartPocketCoderChipWhatStarts': 'walkthrough.start.pocket.coder.chip.what.starts',
    'walkthroughStartPocketCoderPoco': 'walkthrough.start.pocket.coder.poco',
    'walkthroughStartPocketCoderTitle': 'walkthrough.start.pocket.coder.title',
    'walkthroughTransitionDeployment': 'walkthrough.transition.deployment',
    'walkthroughTransitionProvisioning': 'walkthrough.transition.provisioning',
    'walkthroughVerifiedVersionChipDownloadFailure': 'walkthrough.verified.version.chip.download.failure',
    'walkthroughVerifiedVersionChipUpdates': 'walkthrough.verified.version.chip.updates',
    'walkthroughVerifiedVersionChipVerification': 'walkthrough.verified.version.chip.verification',
    'walkthroughVerifiedVersionPoco': 'walkthrough.verified.version.poco',
    'walkthroughVerifiedVersionTitle': 'walkthrough.verified.version.title',
  };

  /// Maps dot-notation keys to ARB camelCase keys.
  static const dotToArbKey = <String, String>{
    'action.add': 'actionAdd',
    'action.add.new': 'actionAddNew',
    'action.authorize': 'actionAuthorize',
    'action.back': 'actionBack',
    'action.cancel': 'actionCancel',
    'action.change': 'actionChange',
    'action.close': 'actionClose',
    'action.configure': 'actionConfigure',
    'action.continue': 'actionContinue',
    'action.create': 'actionCreate',
    'action.deny': 'actionDeny',
    'action.refresh': 'actionRefresh',
    'action.reject': 'actionReject',
    'action.restore': 'actionRestore',
    'action.save': 'actionSave',
    'agent.config.default.badge': 'agentConfigDefaultBadge',
    'agent.config.delete': 'agentConfigDelete',
    'agent.config.delete.confirm.body': 'agentConfigDeleteConfirmBody',
    'agent.config.delete.confirm.title': 'agentConfigDeleteConfirmTitle',
    'agent.config.dialog.title': 'agentConfigDialogTitle',
    'agent.config.empty': 'agentConfigEmpty',
    'agent.config.error.prefix': 'agentConfigErrorPrefix',
    'agent.config.harness.model.label': 'agentConfigHarnessModelLabel',
    'agent.config.is.default.label': 'agentConfigIsDefaultLabel',
    'agent.config.mode.label': 'agentConfigModeLabel',
    'agent.config.name.label': 'agentConfigNameLabel',
    'agent.config.no.harness.models': 'agentConfigNoHarnessModels',
    'agent.config.no.modes': 'agentConfigNoModes',
    'agent.config.no.prompts': 'agentConfigNoPrompts',
    'agent.config.prompt.label': 'agentConfigPromptLabel',
    'agent.config.registry': 'agentConfigRegistry',
    'agent.config.select.harness.model': 'agentConfigSelectHarnessModel',
    'agent.config.select.mode': 'agentConfigSelectMode',
    'agent.config.select.prompt': 'agentConfigSelectPrompt',
    'agent.config.title': 'agentConfigTitle',
    'agent.default.tuned': 'agentDefaultTuned',
    'agent.description.label': 'agentDescriptionLabel',
    'agent.dialog.title': 'agentDialogTitle',
    'agent.models.label': 'agentModelsLabel',
    'agent.models.personas': 'agentModelsPersonas',
    'agent.name.label': 'agentNameLabel',
    'agent.none': 'agentNone',
    'agent.none.selected': 'agentNoneSelected',
    'agent.parameters.label': 'agentParametersLabel',
    'agent.prompts.label': 'agentPromptsLabel',
    'agent.registry.empty': 'agentRegistryEmpty',
    'agent.searching': 'agentSearching',
    'agent.select.to.configure': 'agentSelectToConfigure',
    'agent.title': 'agentTitle',
    'ai.error': 'aiError',
    'ai.fetch.failed': 'aiFetchFailed',
    'ai.save.failed': 'aiSaveFailed',
    'app.title': 'appTitle',
    'auth.error': 'authError',
    'auth.login.failed': 'authLoginFailed',
    'auth.not.authenticated': 'authNotAuthenticated',
    'auth.token.expired': 'authTokenExpired',
    'boot.checking.connection': 'bootCheckingConnection',
    'boot.connection.failed': 'bootConnectionFailed',
    'boot.load.error': 'bootLoadError',
    'boot.poco.intro': 'bootPocoIntro',
    'boot.systems.nominal': 'bootSystemsNominal',
    'boot.welcome.back': 'bootWelcomeBack',
    'brief.label': 'briefLabel',
    'chat.command.output': 'chatCommandOutput',
    'chat.commander.role': 'chatCommanderRole',
    'chat.created': 'chatCreated',
    'chat.decline': 'chatDecline',
    'chat.elicitation.request': 'chatElicitationRequest',
    'chat.error': 'chatError',
    'chat.fetch.failed': 'chatFetchFailed',
    'chat.files.action': 'chatFilesAction',
    'chat.list.archive': 'chatListArchive',
    'chat.list.delete': 'chatListDelete',
    'chat.list.error': 'chatListError',
    'chat.list.new.chat': 'chatListNewChat',
    'chat.list.no.messages': 'chatListNoMessages',
    'chat.list.timestamp.days.ago': 'chatListTimestampDaysAgo',
    'chat.list.timestamp.hours.ago': 'chatListTimestampHoursAgo',
    'chat.list.timestamp.minutes.ago': 'chatListTimestampMinutesAgo',
    'chat.list.timestamp.now': 'chatListTimestampNow',
    'chat.message.sent': 'chatMessageSent',
    'chat.model.default': 'chatModelDefault',
    'chat.model.label': 'chatModelLabel',
    'chat.model.per.chat': 'chatModelPerChat',
    'chat.new.capability.request': 'chatNewCapabilityRequest',
    'chat.no.fields.requested': 'chatNoFieldsRequested',
    'chat.not.found': 'chatNotFound',
    'chat.poco.role': 'chatPocoRole',
    'chat.select.model.title': 'chatSelectModelTitle',
    'chat.send.failed': 'chatSendFailed',
    'chat.send.tooltip': 'chatSendTooltip',
    'chat.session.action': 'chatSessionAction',
    'chat.session.title': 'chatSessionTitle',
    'chat.submit': 'chatSubmit',
    'chat.terminal.action': 'chatTerminalAction',
    'chat.thinking': 'chatThinking',
    'chat.thinking.live': 'chatThinkingLive',
    'chat.thinking.role': 'chatThinkingRole',
    'chat.thought': 'chatThought',
    'chat.use.global.default': 'chatUseGlobalDefault',
    'deploy.choose.provider': 'deployChooseProvider',
    'deploy.coming.soon': 'deployComingSoon',
    'deploy.pro.badge': 'deployProBadge',
    'deploy.select.provider': 'deploySelectProvider',
    'deploy.title': 'deployTitle',
    'deployment.action.abort': 'deploymentActionAbort',
    'deployment.action.back': 'deploymentActionBack',
    'deployment.action.deploy.instance': 'deploymentActionDeployInstance',
    'deployment.action.dismiss': 'deploymentActionDismiss',
    'deployment.action.login.now': 'deploymentActionLoginNow',
    'deployment.action.refresh': 'deploymentActionRefresh',
    'deployment.action.retry.scan': 'deploymentActionRetryScan',
    'deployment.action.update': 'deploymentActionUpdate',
    'deployment.admin.identity': 'deploymentAdminIdentity',
    'deployment.admin.password': 'deploymentAdminPassword',
    'deployment.backend': 'deploymentBackend',
    'deployment.cloud.region': 'deploymentCloudRegion',
    'deployment.coding.harnesses': 'deploymentCodingHarnesses',
    'deployment.connection.parameters': 'deploymentConnectionParameters',
    'deployment.copied.to.buffer': 'deploymentCopiedToBuffer',
    'deployment.copy.label': 'deploymentCopyLabel',
    'deployment.current.operation': 'deploymentCurrentOperation',
    'deployment.debian': 'deploymentDebian',
    'deployment.description.constructing': 'deploymentDescriptionConstructing',
    'deployment.description.failed': 'deploymentDescriptionFailed',
    'deployment.description.fetching': 'deploymentDescriptionFetching',
    'deployment.description.finishing': 'deploymentDescriptionFinishing',
    'deployment.description.initializing': 'deploymentDescriptionInitializing',
    'deployment.description.installing': 'deploymentDescriptionInstalling',
    'deployment.description.loading.images': 'deploymentDescriptionLoadingImages',
    'deployment.description.preparing.host': 'deploymentDescriptionPreparingHost',
    'deployment.description.ready': 'deploymentDescriptionReady',
    'deployment.description.securing': 'deploymentDescriptionSecuring',
    'deployment.description.starting': 'deploymentDescriptionStarting',
    'deployment.description.validating': 'deploymentDescriptionValidating',
    'deployment.distribution': 'deploymentDistribution',
    'deployment.error.code': 'deploymentErrorCode',
    'deployment.fault.detected': 'deploymentFaultDetected',
    'deployment.geo.grid': 'deploymentGeoGrid',
    'deployment.hardware.geography': 'deploymentHardwareGeography',
    'deployment.hardware.plan': 'deploymentHardwarePlan',
    'deployment.harness.selection.description': 'deploymentHarnessSelectionDescription',
    'deployment.https.endpoint': 'deploymentHttpsEndpoint',
    'deployment.initializing.hardware': 'deploymentInitializingHardware',
    'deployment.instance.manifest': 'deploymentInstanceManifest',
    'deployment.instance.plan': 'deploymentInstancePlan',
    'deployment.ip.address': 'deploymentIpAddress',
    'deployment.last.signal': 'deploymentLastSignal',
    'deployment.manifest.configuration': 'deploymentManifestConfiguration',
    'deployment.metadata.registry': 'deploymentMetadataRegistry',
    'deployment.monthly.price': 'deploymentMonthlyPrice',
    'deployment.network.ip': 'deploymentNetworkIp',
    'deployment.nixos': 'deploymentNixos',
    'deployment.operating.system': 'deploymentOperatingSystem',
    'deployment.provisioned': 'deploymentProvisioned',
    'deployment.region': 'deploymentRegion',
    'deployment.run.id': 'deploymentRunId',
    'deployment.scanning.regions': 'deploymentScanningRegions',
    'deployment.screen.title': 'deploymentScreenTitle',
    'deployment.secure': 'deploymentSecure',
    'deployment.security.notice': 'deploymentSecurityNotice',
    'deployment.source.commit': 'deploymentSourceCommit',
    'deployment.standard.linux': 'deploymentStandardLinux',
    'deployment.status.constructing': 'deploymentStatusConstructing',
    'deployment.status.failed': 'deploymentStatusFailed',
    'deployment.status.fetching': 'deploymentStatusFetching',
    'deployment.status.finishing': 'deploymentStatusFinishing',
    'deployment.status.initializing': 'deploymentStatusInitializing',
    'deployment.status.installing': 'deploymentStatusInstalling',
    'deployment.status.loading.images': 'deploymentStatusLoadingImages',
    'deployment.status.prefix': 'deploymentStatusPrefix',
    'deployment.status.preparing.host': 'deploymentStatusPreparingHost',
    'deployment.status.ready': 'deploymentStatusReady',
    'deployment.status.schema': 'deploymentStatusSchema',
    'deployment.status.securing': 'deploymentStatusSecuring',
    'deployment.status.starting': 'deploymentStatusStarting',
    'deployment.status.validating': 'deploymentStatusValidating',
    'deployment.sync.attempt': 'deploymentSyncAttempt',
    'deployment.system.parameters': 'deploymentSystemParameters',
    'deployment.ubuntu': 'deploymentUbuntu',
    'deployment.unknown': 'deploymentUnknown',
    'error.auth.failed': 'errorAuthFailed',
    'error.auth.unauthorized': 'errorAuthUnauthorized',
    'error.generic': 'errorGeneric',
    'error.network': 'errorNetwork',
    'error.timeout': 'errorTimeout',
    'errors.clear.all': 'errorsClearAll',
    'errors.copied': 'errorsCopied',
    'errors.copy': 'errorsCopy',
    'errors.copy.all': 'errorsCopyAll',
    'errors.empty': 'errorsEmpty',
    'errors.occurred': 'errorsOccurred',
    'errors.title': 'errorsTitle',
    'file.clear.action': 'fileClearAction',
    'file.dashboard.action': 'fileDashboardAction',
    'file.empty': 'fileEmpty',
    'file.fetching': 'fileFetching',
    'file.no.file.selected': 'fileNoFileSelected',
    'file.select.from.chat': 'fileSelectFromChat',
    'file.title': 'fileTitle',
    'files.cant.preview.type': 'filesCantPreviewType',
    'files.empty': 'filesEmpty',
    'files.title': 'filesTitle',
    'files.too.large.to.preview': 'filesTooLargeToPreview',
    'harness.auth.challenge.target.copied': 'harnessAuthChallengeTargetCopied',
    'home.error.prefix': 'homeErrorPrefix',
    'home.loading.chats': 'homeLoadingChats',
    'home.new.chat': 'homeNewChat',
    'home.no.chats': 'homeNoChats',
    'home.title': 'homeTitle',
    'llm.active.model.section': 'llmActiveModelSection',
    'llm.add.key': 'llmAddKey',
    'llm.add.key.hint': 'llmAddKeyHint',
    'llm.api.key.dialog.title': 'llmApiKeyDialogTitle',
    'llm.api.keys.section': 'llmApiKeysSection',
    'llm.connected': 'llmConnected',
    'llm.enter.credentials': 'llmEnterCredentials',
    'llm.global.default': 'llmGlobalDefault',
    'llm.loading.providers': 'llmLoadingProviders',
    'llm.models.available': 'llmModelsAvailable',
    'llm.models.button': 'llmModelsButton',
    'llm.no.key': 'llmNoKey',
    'llm.no.models': 'llmNoModels',
    'llm.no.providers': 'llmNoProviders',
    'llm.not.set': 'llmNotSet',
    'llm.provider.models.title': 'llmProviderModelsTitle',
    'llm.providers.section': 'llmProvidersSection',
    'llm.select': 'llmSelect',
    'llm.select.model.title': 'llmSelectModelTitle',
    'llm.title': 'llmTitle',
    'llm.update.key': 'llmUpdateKey',
    'mcp.active.capabilities': 'mcpActiveCapabilities',
    'mcp.add.config.optional': 'mcpAddConfigOptional',
    'mcp.add.dialog.title': 'mcpAddDialogTitle',
    'mcp.authorize.cap': 'mcpAuthorizeCap',
    'mcp.authorize.dialog.title': 'mcpAuthorizeDialogTitle',
    'mcp.capabilities.registry': 'mcpCapabilitiesRegistry',
    'mcp.connect.cap': 'mcpConnectCap',
    'mcp.edit.config': 'mcpEditConfig',
    'mcp.enter.secrets': 'mcpEnterSecrets',
    'mcp.image.label': 'mcpImageLabel',
    'mcp.image.optional.label': 'mcpImageOptionalLabel',
    'mcp.no.capabilities': 'mcpNoCapabilities',
    'mcp.no.config.required': 'mcpNoConfigRequired',
    'mcp.oauth.provider.not.configured.label': 'mcpOauthProviderNotConfiguredLabel',
    'mcp.oauth.provider.optional.label': 'mcpOauthProviderOptionalLabel',
    'mcp.oauth.required.label': 'mcpOauthRequiredLabel',
    'mcp.oauth.token.env.var.optional.label': 'mcpOauthTokenEnvVarOptionalLabel',
    'mcp.pending.approval': 'mcpPendingApproval',
    'mcp.purpose.label': 'mcpPurposeLabel',
    'mcp.required.config': 'mcpRequiredConfig',
    'mcp.retry.delivery.cap': 'mcpRetryDeliveryCap',
    'mcp.revoke': 'mcpRevoke',
    'mcp.server.name.label': 'mcpServerNameLabel',
    'mcp.title': 'mcpTitle',
    'mcp.update.config.dialog.title': 'mcpUpdateConfigDialogTitle',
    'monitor.agent.activity': 'monitorAgentActivity',
    'monitor.cost.label': 'monitorCostLabel',
    'monitor.fetching.telemetry': 'monitorFetchingTelemetry',
    'monitor.key.metrics': 'monitorKeyMetrics',
    'monitor.messages.label': 'monitorMessagesLabel',
    'monitor.no.data': 'monitorNoData',
    'monitor.system.health': 'monitorSystemHealth',
    'monitor.telemetry.unavailable': 'monitorTelemetryUnavailable',
    'monitor.title': 'monitorTitle',
    'monitor.token.usage': 'monitorTokenUsage',
    'monitor.tokens.label': 'monitorTokensLabel',
    'nav.chats': 'navChats',
    'nav.configure': 'navConfigure',
    'nav.monitor': 'navMonitor',
    'new.chat.cancel': 'newChatCancel',
    'new.chat.create': 'newChatCreate',
    'new.chat.cwd.field': 'newChatCwdField',
    'new.chat.cwd.hint': 'newChatCwdHint',
    'new.chat.harness.field': 'newChatHarnessField',
    'new.chat.model.field': 'newChatModelField',
    'new.chat.no.models.available': 'newChatNoModelsAvailable',
    'new.chat.select.harness': 'newChatSelectHarness',
    'new.chat.select.model': 'newChatSelectModel',
    'new.chat.title': 'newChatTitle',
    'new.chat.title.field': 'newChatTitleField',
    'new.chat.workspace.error.empty': 'newChatWorkspaceErrorEmpty',
    'new.chat.workspace.error.invalid': 'newChatWorkspaceErrorInvalid',
    'notification.settings.chat.reply.label': 'notificationSettingsChatReplyLabel',
    'notification.settings.schedule.label': 'notificationSettingsScheduleLabel',
    'notification.settings.screen.title': 'notificationSettingsScreenTitle',
    'notification.settings.task.complete.label': 'notificationSettingsTaskCompleteLabel',
    'notification.settings.task.error.label': 'notificationSettingsTaskErrorLabel',
    'notification.signal.received': 'notificationSignalReceived',
    'observability.backend': 'observabilityBackend',
    'observability.cost': 'observabilityCost',
    'observability.log.terminal': 'observabilityLogTerminal',
    'observability.msgs': 'observabilityMsgs',
    'observability.registry': 'observabilityRegistry',
    'observability.select.container': 'observabilitySelectContainer',
    'observability.title': 'observabilityTitle',
    'observability.tokens': 'observabilityTokens',
    'onboarding.access.denied': 'onboardingAccessDenied',
    'onboarding.account.login': 'onboardingAccountLogin',
    'onboarding.authenticating': 'onboardingAuthenticating',
    'onboarding.authorization.code': 'onboardingAuthorizationCode',
    'onboarding.authorization.code.hint': 'onboardingAuthorizationCodeHint',
    'onboarding.check.status': 'onboardingCheckStatus',
    'onboarding.choose.harness.body': 'onboardingChooseHarnessBody',
    'onboarding.choose.harness.title': 'onboardingChooseHarnessTitle',
    'onboarding.claude.account.login': 'onboardingClaudeAccountLogin',
    'onboarding.codex.account.login': 'onboardingCodexAccountLogin',
    'onboarding.connect.or.deploy': 'onboardingConnectOrDeploy',
    'onboarding.connected': 'onboardingConnected',
    'onboarding.create.server': 'onboardingCreateServer',
    'onboarding.deploy': 'onboardingDeploy',
    'onboarding.deploy.title': 'onboardingDeployTitle',
    'onboarding.docker.intro.action.start': 'onboardingDockerIntroActionStart',
    'onboarding.docker.intro.chip.component': 'onboardingDockerIntroChipComponent',
    'onboarding.docker.intro.chip.connections': 'onboardingDockerIntroChipConnections',
    'onboarding.docker.intro.chip.container': 'onboardingDockerIntroChipContainer',
    'onboarding.docker.intro.chip.saved.data': 'onboardingDockerIntroChipSavedData',
    'onboarding.docker.intro.eyebrow': 'onboardingDockerIntroEyebrow',
    'onboarding.docker.intro.poco': 'onboardingDockerIntroPoco',
    'onboarding.docker.intro.title': 'onboardingDockerIntroTitle',
    'onboarding.email': 'onboardingEmail',
    'onboarding.email.hint': 'onboardingEmailHint',
    'onboarding.email.hint.short': 'onboardingEmailHintShort',
    'onboarding.existing.server': 'onboardingExistingServer',
    'onboarding.failure.action.back.to.setup': 'onboardingFailureActionBackToSetup',
    'onboarding.failure.action.retry.connection': 'onboardingFailureActionRetryConnection',
    'onboarding.failure.action.technical.details': 'onboardingFailureActionTechnicalDetails',
    'onboarding.failure.action.view.server.details': 'onboardingFailureActionViewServerDetails',
    'onboarding.failure.connection.poco': 'onboardingFailureConnectionPoco',
    'onboarding.failure.create.poco': 'onboardingFailureCreatePoco',
    'onboarding.harness.login.title': 'onboardingHarnessLoginTitle',
    'onboarding.harness.not.found': 'onboardingHarnessNotFound',
    'onboarding.harness.poco': 'onboardingHarnessPoco',
    'onboarding.harness.title': 'onboardingHarnessTitle',
    'onboarding.home.server': 'onboardingHomeServer',
    'onboarding.identity.label': 'onboardingIdentityLabel',
    'onboarding.intent.chip.cloud.models': 'onboardingIntentChipCloudModels',
    'onboarding.intent.chip.local.models': 'onboardingIntentChipLocalModels',
    'onboarding.intent.poco': 'onboardingIntentPoco',
    'onboarding.login': 'onboardingLogin',
    'onboarding.no.server.chip.existing': 'onboardingNoServerChipExisting',
    'onboarding.no.server.chip.new': 'onboardingNoServerChipNew',
    'onboarding.no.server.looking.poco': 'onboardingNoServerLookingPoco',
    'onboarding.no.server.poco': 'onboardingNoServerPoco',
    'onboarding.open.authorization': 'onboardingOpenAuthorization',
    'onboarding.open.chat.failed': 'onboardingOpenChatFailed',
    'onboarding.orientation.action.continue': 'onboardingOrientationActionContinue',
    'onboarding.orientation.action.skip': 'onboardingOrientationActionSkip',
    'onboarding.orientation.title': 'onboardingOrientationTitle',
    'onboarding.os.debian.description': 'onboardingOsDebianDescription',
    'onboarding.os.debian.label': 'onboardingOsDebianLabel',
    'onboarding.os.nixos.description': 'onboardingOsNixosDescription',
    'onboarding.os.nixos.label': 'onboardingOsNixosLabel',
    'onboarding.os.poco': 'onboardingOsPoco',
    'onboarding.os.title': 'onboardingOsTitle',
    'onboarding.passphrase.label': 'onboardingPassphraseLabel',
    'onboarding.password': 'onboardingPassword',
    'onboarding.password.hint': 'onboardingPasswordHint',
    'onboarding.plan.poco': 'onboardingPlanPoco',
    'onboarding.plan.title': 'onboardingPlanTitle',
    'onboarding.pocketbase.admin.email': 'onboardingPocketbaseAdminEmail',
    'onboarding.pocketbase.admin.password': 'onboardingPocketbaseAdminPassword',
    'onboarding.poco.challenge.message': 'onboardingPocoChallengeMessage',
    'onboarding.poco.welcome': 'onboardingPocoWelcome',
    'onboarding.processing': 'onboardingProcessing',
    'onboarding.provider.authorization.action': 'onboardingProviderAuthorizationAction',
    'onboarding.provider.authorization.poco': 'onboardingProviderAuthorizationPoco',
    'onboarding.provider.authorization.title': 'onboardingProviderAuthorizationTitle',
    'onboarding.provider.chip.elestio.coming.soon': 'onboardingProviderChipElestioComingSoon',
    'onboarding.provider.chip.linode': 'onboardingProviderChipLinode',
    'onboarding.provider.poco': 'onboardingProviderPoco',
    'onboarding.provider.title': 'onboardingProviderTitle',
    'onboarding.provisioning.poco': 'onboardingProvisioningPoco',
    'onboarding.ready.action.login': 'onboardingReadyActionLogin',
    'onboarding.ready.poco': 'onboardingReadyPoco',
    'onboarding.region.consent.chip.choose.myself': 'onboardingRegionConsentChipChooseMyself',
    'onboarding.region.consent.chip.use.location': 'onboardingRegionConsentChipUseLocation',
    'onboarding.region.consent.poco': 'onboardingRegionConsentPoco',
    'onboarding.region.poco': 'onboardingRegionPoco',
    'onboarding.region.title': 'onboardingRegionTitle',
    'onboarding.required.fields': 'onboardingRequiredFields',
    'onboarding.review.action.provision': 'onboardingReviewActionProvision',
    'onboarding.review.poco': 'onboardingReviewPoco',
    'onboarding.review.title': 'onboardingReviewTitle',
    'onboarding.server.connecting': 'onboardingServerConnecting',
    'onboarding.server.login.title': 'onboardingServerLoginTitle',
    'onboarding.server.url': 'onboardingServerUrl',
    'onboarding.server.url.hint': 'onboardingServerUrlHint',
    'onboarding.setup.title': 'onboardingSetupTitle',
    'onboarding.sign.in.poco': 'onboardingSignInPoco',
    'onboarding.sign.in.title': 'onboardingSignInTitle',
    'onboarding.submit.code': 'onboardingSubmitCode',
    'onboarding.title': 'onboardingTitle',
    'onboarding.trial.chip.not.now': 'onboardingTrialChipNotNow',
    'onboarding.trial.chip.start': 'onboardingTrialChipStart',
    'onboarding.trial.poco': 'onboardingTrialPoco',
    'permission.error': 'permissionError',
    'permission.fetch.failed': 'permissionFetchFailed',
    'permission.patterns.label': 'permissionPatternsLabel',
    'permission.requesting.label': 'permissionRequestingLabel',
    'permission.signoff.title': 'permissionSignoffTitle',
    'permission.update.failed': 'permissionUpdateFailed',
    'pocket.coder.progress.active': 'pocketCoderProgressActive',
    'pocket.coder.progress.complete': 'pocketCoderProgressComplete',
    'pocket.coder.progress.deploy.pocket.coder': 'pocketCoderProgressDeployPocketCoder',
    'pocket.coder.progress.failed': 'pocketCoderProgressFailed',
    'pocket.coder.progress.initializing': 'pocketCoderProgressInitializing',
    'pocket.coder.progress.provision.server': 'pocketCoderProgressProvisionServer',
    'pocket.coder.progress.waiting': 'pocketCoderProgressWaiting',
    'poco.lesson.agent.explanation': 'pocoLessonAgentExplanation',
    'poco.lesson.agent.title': 'pocoLessonAgentTitle',
    'poco.lesson.compose.start.explanation': 'pocoLessonComposeStartExplanation',
    'poco.lesson.compose.start.title': 'pocoLessonComposeStartTitle',
    'poco.lesson.container.firewall.explanation': 'pocoLessonContainerFirewallExplanation',
    'poco.lesson.container.firewall.title': 'pocoLessonContainerFirewallTitle',
    'poco.lesson.dashboard.explanation': 'pocoLessonDashboardExplanation',
    'poco.lesson.dashboard.title': 'pocoLessonDashboardTitle',
    'poco.lesson.docker.explanation': 'pocoLessonDockerExplanation',
    'poco.lesson.docker.title': 'pocoLessonDockerTitle',
    'poco.lesson.harness.images.explanation': 'pocoLessonHarnessImagesExplanation',
    'poco.lesson.harness.images.title': 'pocoLessonHarnessImagesTitle',
    'poco.lesson.local.caddy.explanation': 'pocoLessonLocalCaddyExplanation',
    'poco.lesson.local.caddy.title': 'pocoLessonLocalCaddyTitle',
    'poco.lesson.local.model.explanation': 'pocoLessonLocalModelExplanation',
    'poco.lesson.local.model.title': 'pocoLessonLocalModelTitle',
    'poco.lesson.local.secrets.explanation': 'pocoLessonLocalSecretsExplanation',
    'poco.lesson.local.secrets.title': 'pocoLessonLocalSecretsTitle',
    'poco.lesson.mcp.sandbox.explanation': 'pocoLessonMcpSandboxExplanation',
    'poco.lesson.mcp.sandbox.title': 'pocoLessonMcpSandboxTitle',
    'poco.lesson.memory.explanation': 'pocoLessonMemoryExplanation',
    'poco.lesson.memory.title': 'pocoLessonMemoryTitle',
    'poco.lesson.networks.explanation': 'pocoLessonNetworksExplanation',
    'poco.lesson.networks.title': 'pocoLessonNetworksTitle',
    'poco.lesson.notifications.explanation': 'pocoLessonNotificationsExplanation',
    'poco.lesson.notifications.title': 'pocoLessonNotificationsTitle',
    'poco.lesson.owner.config.explanation': 'pocoLessonOwnerConfigExplanation',
    'poco.lesson.owner.config.title': 'pocoLessonOwnerConfigTitle',
    'poco.lesson.pocketbase.docker.access.explanation': 'pocoLessonPocketbaseDockerAccessExplanation',
    'poco.lesson.pocketbase.docker.access.title': 'pocoLessonPocketbaseDockerAccessTitle',
    'poco.lesson.pocketbase.explanation': 'pocoLessonPocketbaseExplanation',
    'poco.lesson.pocketbase.title': 'pocoLessonPocketbaseTitle',
    'poco.lesson.private.access.explanation': 'pocoLessonPrivateAccessExplanation',
    'poco.lesson.private.access.title': 'pocoLessonPrivateAccessTitle',
    'poco.lesson.public.firewall.explanation': 'pocoLessonPublicFirewallExplanation',
    'poco.lesson.public.firewall.title': 'pocoLessonPublicFirewallTitle',
    'poco.lesson.release.source.explanation': 'pocoLessonReleaseSourceExplanation',
    'poco.lesson.release.source.title': 'pocoLessonReleaseSourceTitle',
    'poco.lesson.ssh.explanation': 'pocoLessonSshExplanation',
    'poco.lesson.ssh.title': 'pocoLessonSshTitle',
    'poco.lesson.verified.images.explanation': 'pocoLessonVerifiedImagesExplanation',
    'poco.lesson.verified.images.title': 'pocoLessonVerifiedImagesTitle',
    'poco.lesson.volumes.explanation': 'pocoLessonVolumesExplanation',
    'poco.lesson.volumes.title': 'pocoLessonVolumesTitle',
    'poco.lesson.vps.storage.explanation': 'pocoLessonVpsStorageExplanation',
    'poco.lesson.vps.storage.title': 'pocoLessonVpsStorageTitle',
    'poco.provisioning.loading.source': 'pocoProvisioningLoadingSource',
    'poco.provisioning.next': 'pocoProvisioningNext',
    'poco.provisioning.previous': 'pocoProvisioningPrevious',
    'poco.provisioning.show.concise': 'pocoProvisioningShowConcise',
    'poco.provisioning.show.full': 'pocoProvisioningShowFull',
    'poco.provisioning.source.unavailable': 'pocoProvisioningSourceUnavailable',
    'poco.provisioning.tour.title': 'pocoProvisioningTourTitle',
    'poco.provisioning.waiting.for.source': 'pocoProvisioningWaitingForSource',
    'provider.screen.add.key': 'providerScreenAddKey',
    'provider.screen.add.key.body': 'providerScreenAddKeyBody',
    'provider.screen.add.key.title': 'providerScreenAddKeyTitle',
    'provider.screen.api.keys.section': 'providerScreenApiKeysSection',
    'provider.screen.default.badge': 'providerScreenDefaultBadge',
    'provider.screen.empty.hint': 'providerScreenEmptyHint',
    'provider.screen.error.prefix': 'providerScreenErrorPrefix',
    'provider.screen.harness.models.section': 'providerScreenHarnessModelsSection',
    'provider.screen.loading': 'providerScreenLoading',
    'provider.screen.no.api.keys': 'providerScreenNoApiKeys',
    'provider.screen.no.harness.models': 'providerScreenNoHarnessModels',
    'provider.screen.no.providers': 'providerScreenNoProviders',
    'provider.screen.select.provider': 'providerScreenSelectProvider',
    'provider.screen.title': 'providerScreenTitle',
    'provider.screen.update.key': 'providerScreenUpdateKey',
    'question.incoming.title': 'questionIncomingTitle',
    'question.poco.asking': 'questionPocoAsking',
    'question.send.reply': 'questionSendReply',
    'relay.activate': 'relayActivate',
    'relay.active': 'relayActive',
    'relay.checking.status': 'relayCheckingStatus',
    'relay.config.section': 'relayConfigSection',
    'relay.functional.overview.body': 'relayFunctionalOverviewBody',
    'relay.functional.overview.title': 'relayFunctionalOverviewTitle',
    'relay.ntfy.description': 'relayNtfyDescription',
    'relay.ntfy.title': 'relayNtfyTitle',
    'relay.permission.relay.label': 'relayPermissionRelayLabel',
    'relay.restore': 'relayRestore',
    'relay.subsystem': 'relaySubsystem',
    'relay.subsystems.nominal': 'relaySubsystemsNominal',
    'relay.title': 'relayTitle',
    'relay.unlimited.capacity': 'relayUnlimitedCapacity',
    'scheduler.add.button': 'schedulerAddButton',
    'scheduler.add.dialog.title': 'schedulerAddDialogTitle',
    'scheduler.cron.label': 'schedulerCronLabel',
    'scheduler.delete.button': 'schedulerDeleteButton',
    'scheduler.edit.button': 'schedulerEditButton',
    'scheduler.edit.dialog.title': 'schedulerEditDialogTitle',
    'scheduler.name.label': 'schedulerNameLabel',
    'scheduler.no.schedules': 'schedulerNoSchedules',
    'scheduler.pause.button': 'schedulerPauseButton',
    'scheduler.paused.badge': 'schedulerPausedBadge',
    'scheduler.prompt.label': 'schedulerPromptLabel',
    'scheduler.registry.title': 'schedulerRegistryTitle',
    'scheduler.resume.button': 'schedulerResumeButton',
    'scheduler.run.now.button': 'schedulerRunNowButton',
    'scheduler.running.badge': 'schedulerRunningBadge',
    'scheduler.save.button': 'schedulerSaveButton',
    'scheduler.title': 'schedulerTitle',
    'settings.account.section': 'settingsAccountSection',
    'settings.ai.agents.section': 'settingsAiAgentsSection',
    'settings.automation.section': 'settingsAutomationSection',
    'settings.governance.section': 'settingsGovernanceSection',
    'settings.logout.cancel': 'settingsLogoutCancel',
    'settings.logout.confirm': 'settingsLogoutConfirm',
    'settings.logout.confirm.body': 'settingsLogoutConfirmBody',
    'settings.logout.confirm.title': 'settingsLogoutConfirmTitle',
    'settings.observability.section': 'settingsObservabilitySection',
    'settings.security.section': 'settingsSecuritySection',
    'settings.system.section': 'settingsSystemSection',
    'settings.title': 'settingsTitle',
    'skills.add.button': 'skillsAddButton',
    'skills.add.dialog.title': 'skillsAddDialogTitle',
    'skills.content.label': 'skillsContentLabel',
    'skills.delete.button': 'skillsDeleteButton',
    'skills.description.label': 'skillsDescriptionLabel',
    'skills.edit.button': 'skillsEditButton',
    'skills.edit.dialog.title': 'skillsEditDialogTitle',
    'skills.global.label': 'skillsGlobalLabel',
    'skills.global.section': 'skillsGlobalSection',
    'skills.name.label': 'skillsNameLabel',
    'skills.no.eligible.config': 'skillsNoEligibleConfig',
    'skills.no.skills': 'skillsNoSkills',
    'skills.project.label': 'skillsProjectLabel',
    'skills.project.section': 'skillsProjectSection',
    'skills.registry.title': 'skillsRegistryTitle',
    'skills.save.button': 'skillsSaveButton',
    'skills.title': 'skillsTitle',
    'system.checks.diagnostics': 'systemChecksDiagnostics',
    'system.checks.empty': 'systemChecksEmpty',
    'system.checks.title': 'systemChecksTitle',
    'terminal.connecting': 'terminalConnecting',
    'terminal.connection.failed': 'terminalConnectionFailed',
    'terminal.connection.status': 'terminalConnectionStatus',
    'terminal.destination.path': 'terminalDestinationPath',
    'terminal.offline': 'terminalOffline',
    'terminal.online': 'terminalOnline',
    'terminal.reconnect': 'terminalReconnect',
    'terminal.retry': 'terminalRetry',
    'terminal.sftp.title': 'terminalSftpTitle',
    'terminal.ssh.link': 'terminalSshLink',
    'terminal.title': 'terminalTitle',
    'terminal.transfer': 'terminalTransfer',
    'terminal.upload': 'terminalUpload',
    'thoughts.waiting': 'thoughtsWaiting',
    'tool.permissions.action.label': 'toolPermissionsActionLabel',
    'tool.permissions.add': 'toolPermissionsAdd',
    'tool.permissions.add.rule.title': 'toolPermissionsAddRuleTitle',
    'tool.permissions.add.title': 'toolPermissionsAddTitle',
    'tool.permissions.allow.label': 'toolPermissionsAllowLabel',
    'tool.permissions.ask.label': 'toolPermissionsAskLabel',
    'tool.permissions.deny.label': 'toolPermissionsDenyLabel',
    'tool.permissions.empty': 'toolPermissionsEmpty',
    'tool.permissions.error': 'toolPermissionsError',
    'tool.permissions.fetch.failed': 'toolPermissionsFetchFailed',
    'tool.permissions.frame.title': 'toolPermissionsFrameTitle',
    'tool.permissions.loading': 'toolPermissionsLoading',
    'tool.permissions.no.rules': 'toolPermissionsNoRules',
    'tool.permissions.pattern.label': 'toolPermissionsPatternLabel',
    'tool.permissions.rules.registry': 'toolPermissionsRulesRegistry',
    'tool.permissions.scope.agent': 'toolPermissionsScopeAgent',
    'tool.permissions.scope.global': 'toolPermissionsScopeGlobal',
    'tool.permissions.screen.title': 'toolPermissionsScreenTitle',
    'tool.permissions.title': 'toolPermissionsTitle',
    'tool.permissions.tool.label': 'toolPermissionsToolLabel',
    'tool.permissions.tool.name.label': 'toolPermissionsToolNameLabel',
    'tool.permissions.update.failed': 'toolPermissionsUpdateFailed',
    'walkthrough.action.show.concise.code': 'walkthroughActionShowConciseCode',
    'walkthrough.action.show.full.code': 'walkthroughActionShowFullCode',
    'walkthrough.activation.health.poco': 'walkthroughActivationHealthPoco',
    'walkthrough.activation.health.title': 'walkthroughActivationHealthTitle',
    'walkthrough.activation.prepare.poco': 'walkthroughActivationPreparePoco',
    'walkthrough.activation.prepare.title': 'walkthroughActivationPrepareTitle',
    'walkthrough.activation.selected.software.poco': 'walkthroughActivationSelectedSoftwarePoco',
    'walkthrough.activation.selected.software.title': 'walkthroughActivationSelectedSoftwareTitle',
    'walkthrough.activation.switch.poco': 'walkthroughActivationSwitchPoco',
    'walkthrough.activation.switch.title': 'walkthroughActivationSwitchTitle',
    'walkthrough.ask.poco': 'walkthroughAskPoco',
    'walkthrough.brief.divider': 'walkthroughBriefDivider',
    'walkthrough.caddy.address.chip.https': 'walkthroughCaddyAddressChipHttps',
    'walkthrough.caddy.address.chip.ip.address': 'walkthroughCaddyAddressChipIpAddress',
    'walkthrough.caddy.address.chip.sslip': 'walkthroughCaddyAddressChipSslip',
    'walkthrough.caddy.address.poco': 'walkthroughCaddyAddressPoco',
    'walkthrough.caddy.address.title': 'walkthroughCaddyAddressTitle',
    'walkthrough.caddy.web.entry.chip.caddy': 'walkthroughCaddyWebEntryChipCaddy',
    'walkthrough.caddy.web.entry.chip.private.port': 'walkthroughCaddyWebEntryChipPrivatePort',
    'walkthrough.caddy.web.entry.poco': 'walkthroughCaddyWebEntryPoco',
    'walkthrough.caddy.web.entry.title': 'walkthroughCaddyWebEntryTitle',
    'walkthrough.debian.setup.status.chip.failure': 'walkthroughDebianSetupStatusChipFailure',
    'walkthrough.debian.setup.status.chip.status': 'walkthroughDebianSetupStatusChipStatus',
    'walkthrough.debian.setup.status.poco': 'walkthroughDebianSetupStatusPoco',
    'walkthrough.debian.setup.status.title': 'walkthroughDebianSetupStatusTitle',
    'walkthrough.header': 'walkthroughHeader',
    'walkthrough.label': 'walkthroughLabel',
    'walkthrough.nixos.docker.poco': 'walkthroughNixosDockerPoco',
    'walkthrough.nixos.docker.rules.poco': 'walkthroughNixosDockerRulesPoco',
    'walkthrough.nixos.docker.rules.title': 'walkthroughNixosDockerRulesTitle',
    'walkthrough.nixos.docker.title': 'walkthroughNixosDockerTitle',
    'walkthrough.nixos.network.chip.docker.rules': 'walkthroughNixosNetworkChipDockerRules',
    'walkthrough.nixos.network.chip.ip.versions': 'walkthroughNixosNetworkChipIpVersions',
    'walkthrough.nixos.network.chip.ports': 'walkthroughNixosNetworkChipPorts',
    'walkthrough.nixos.network.poco': 'walkthroughNixosNetworkPoco',
    'walkthrough.nixos.network.title': 'walkthroughNixosNetworkTitle',
    'walkthrough.nixos.ssh.poco': 'walkthroughNixosSshPoco',
    'walkthrough.nixos.ssh.title': 'walkthroughNixosSshTitle',
    'walkthrough.nixos.storage.poco': 'walkthroughNixosStoragePoco',
    'walkthrough.nixos.storage.title': 'walkthroughNixosStorageTitle',
    'walkthrough.progress': 'walkthroughProgress',
    'walkthrough.runtime.settings.chip.local.settings': 'walkthroughRuntimeSettingsChipLocalSettings',
    'walkthrough.runtime.settings.poco': 'walkthroughRuntimeSettingsPoco',
    'walkthrough.runtime.settings.title': 'walkthroughRuntimeSettingsTitle',
    'walkthrough.runtime.version.poco': 'walkthroughRuntimeVersionPoco',
    'walkthrough.runtime.version.title': 'walkthroughRuntimeVersionTitle',
    'walkthrough.server.key.chip.private': 'walkthroughServerKeyChipPrivate',
    'walkthrough.server.key.chip.public': 'walkthroughServerKeyChipPublic',
    'walkthrough.server.key.chip.ssh': 'walkthroughServerKeyChipSsh',
    'walkthrough.server.key.poco': 'walkthroughServerKeyPoco',
    'walkthrough.server.key.title': 'walkthroughServerKeyTitle',
    'walkthrough.services.cognee.badge': 'walkthroughServicesCogneeBadge',
    'walkthrough.services.cognee.poco': 'walkthroughServicesCogneePoco',
    'walkthrough.services.cognee.title': 'walkthroughServicesCogneeTitle',
    'walkthrough.services.compose.chip.docker.compose': 'walkthroughServicesComposeChipDockerCompose',
    'walkthrough.services.compose.chip.private.connections': 'walkthroughServicesComposeChipPrivateConnections',
    'walkthrough.services.compose.chip.saved.data': 'walkthroughServicesComposeChipSavedData',
    'walkthrough.services.compose.poco': 'walkthroughServicesComposePoco',
    'walkthrough.services.compose.title': 'walkthroughServicesComposeTitle',
    'walkthrough.services.harnesses.chip.add': 'walkthroughServicesHarnessesChipAdd',
    'walkthrough.services.harnesses.chip.harness': 'walkthroughServicesHarnessesChipHarness',
    'walkthrough.services.harnesses.chip.workspace': 'walkthroughServicesHarnessesChipWorkspace',
    'walkthrough.services.harnesses.poco': 'walkthroughServicesHarnessesPoco',
    'walkthrough.services.harnesses.title': 'walkthroughServicesHarnessesTitle',
    'walkthrough.services.ollama.chip.download': 'walkthroughServicesOllamaChipDownload',
    'walkthrough.services.ollama.chip.gpu': 'walkthroughServicesOllamaChipGpu',
    'walkthrough.services.ollama.chip.local.model': 'walkthroughServicesOllamaChipLocalModel',
    'walkthrough.services.ollama.poco': 'walkthroughServicesOllamaPoco',
    'walkthrough.services.ollama.title': 'walkthroughServicesOllamaTitle',
    'walkthrough.services.pocket.base.chip.keeps': 'walkthroughServicesPocketBaseChipKeeps',
    'walkthrough.services.pocket.base.chip.sign.in': 'walkthroughServicesPocketBaseChipSignIn',
    'walkthrough.services.pocket.base.chip.updates': 'walkthroughServicesPocketBaseChipUpdates',
    'walkthrough.services.pocket.base.poco': 'walkthroughServicesPocketBasePoco',
    'walkthrough.services.pocket.base.title': 'walkthroughServicesPocketBaseTitle',
    'walkthrough.services.sql.page.chip.contents': 'walkthroughServicesSqlPageChipContents',
    'walkthrough.services.sql.page.chip.start.order': 'walkthroughServicesSqlPageChipStartOrder',
    'walkthrough.services.sql.page.poco': 'walkthroughServicesSqlPagePoco',
    'walkthrough.services.sql.page.title': 'walkthroughServicesSqlPageTitle',
    'walkthrough.services.tools.chip.harness.tools': 'walkthroughServicesToolsChipHarnessTools',
    'walkthrough.services.tools.chip.mcp': 'walkthroughServicesToolsChipMcp',
    'walkthrough.services.tools.chip.proxy': 'walkthroughServicesToolsChipProxy',
    'walkthrough.services.tools.poco': 'walkthroughServicesToolsPoco',
    'walkthrough.services.tools.title': 'walkthroughServicesToolsTitle',
    'walkthrough.start.pocket.coder.chip.add.harness': 'walkthroughStartPocketCoderChipAddHarness',
    'walkthrough.start.pocket.coder.chip.what.starts': 'walkthroughStartPocketCoderChipWhatStarts',
    'walkthrough.start.pocket.coder.poco': 'walkthroughStartPocketCoderPoco',
    'walkthrough.start.pocket.coder.title': 'walkthroughStartPocketCoderTitle',
    'walkthrough.transition.deployment': 'walkthroughTransitionDeployment',
    'walkthrough.transition.provisioning': 'walkthroughTransitionProvisioning',
    'walkthrough.verified.version.chip.download.failure': 'walkthroughVerifiedVersionChipDownloadFailure',
    'walkthrough.verified.version.chip.updates': 'walkthroughVerifiedVersionChipUpdates',
    'walkthrough.verified.version.chip.verification': 'walkthroughVerifiedVersionChipVerification',
    'walkthrough.verified.version.poco': 'walkthroughVerifiedVersionPoco',
    'walkthrough.verified.version.title': 'walkthroughVerifiedVersionTitle',
  };
}

/// Type-safe constants for all l10n keys.
///
/// Usage:
/// ```dart
/// l10n.translate(L10nKeys.errorTimeout);
/// l10n.translate(...L10nKeys.fieldsCount(5));
/// ```
abstract class L10nKeys {
  static const actionAdd = 'action.add';
  static const actionAddNew = 'action.add.new';
  static const actionAuthorize = 'action.authorize';
  static const actionBack = 'action.back';
  static const actionCancel = 'action.cancel';
  static const actionChange = 'action.change';
  static const actionClose = 'action.close';
  static const actionConfigure = 'action.configure';
  static const actionContinue = 'action.continue';
  static const actionCreate = 'action.create';
  static const actionDeny = 'action.deny';
  static const actionRefresh = 'action.refresh';
  static const actionReject = 'action.reject';
  static const actionRestore = 'action.restore';
  static const actionSave = 'action.save';
  static const agentConfigDefaultBadge = 'agent.config.default.badge';
  static const agentConfigDelete = 'agent.config.delete';
  static (String, Map<String, dynamic>) agentConfigDeleteConfirmBody(String name) => ('agent.config.delete.confirm.body', {'name': name});
  static const agentConfigDeleteConfirmTitle = 'agent.config.delete.confirm.title';
  static (String, Map<String, dynamic>) agentConfigDialogTitle(String name) => ('agent.config.dialog.title', {'name': name});
  static const agentConfigEmpty = 'agent.config.empty';
  static (String, Map<String, dynamic>) agentConfigErrorPrefix(String error) => ('agent.config.error.prefix', {'error': error});
  static const agentConfigHarnessModelLabel = 'agent.config.harness.model.label';
  static const agentConfigIsDefaultLabel = 'agent.config.is.default.label';
  static const agentConfigModeLabel = 'agent.config.mode.label';
  static const agentConfigNameLabel = 'agent.config.name.label';
  static const agentConfigNoHarnessModels = 'agent.config.no.harness.models';
  static const agentConfigNoModes = 'agent.config.no.modes';
  static const agentConfigNoPrompts = 'agent.config.no.prompts';
  static const agentConfigPromptLabel = 'agent.config.prompt.label';
  static const agentConfigRegistry = 'agent.config.registry';
  static const agentConfigSelectHarnessModel = 'agent.config.select.harness.model';
  static const agentConfigSelectMode = 'agent.config.select.mode';
  static const agentConfigSelectPrompt = 'agent.config.select.prompt';
  static const agentConfigTitle = 'agent.config.title';
  static const agentDefaultTuned = 'agent.default.tuned';
  static const agentDescriptionLabel = 'agent.description.label';
  static (String, Map<String, dynamic>) agentDialogTitle(String name) => ('agent.dialog.title', {'name': name});
  static const agentModelsLabel = 'agent.models.label';
  static const agentModelsPersonas = 'agent.models.personas';
  static const agentNameLabel = 'agent.name.label';
  static const agentNone = 'agent.none';
  static const agentNoneSelected = 'agent.none.selected';
  static const agentParametersLabel = 'agent.parameters.label';
  static const agentPromptsLabel = 'agent.prompts.label';
  static const agentRegistryEmpty = 'agent.registry.empty';
  static const agentSearching = 'agent.searching';
  static const agentSelectToConfigure = 'agent.select.to.configure';
  static const agentTitle = 'agent.title';
  static const aiError = 'ai.error';
  static const aiFetchFailed = 'ai.fetch.failed';
  static const aiSaveFailed = 'ai.save.failed';
  static const appTitle = 'app.title';
  static const authError = 'auth.error';
  static const authLoginFailed = 'auth.login.failed';
  static const authNotAuthenticated = 'auth.not.authenticated';
  static const authTokenExpired = 'auth.token.expired';
  static const bootCheckingConnection = 'boot.checking.connection';
  static const bootConnectionFailed = 'boot.connection.failed';
  static const bootLoadError = 'boot.load.error';
  static const bootPocoIntro = 'boot.poco.intro';
  static const bootSystemsNominal = 'boot.systems.nominal';
  static const bootWelcomeBack = 'boot.welcome.back';
  static (String, Map<String, dynamic>) briefLabel(int current, int total) => ('brief.label', {'current': current, 'total': total});
  static const chatCommandOutput = 'chat.command.output';
  static const chatCommanderRole = 'chat.commander.role';
  static const chatCreated = 'chat.created';
  static const chatDecline = 'chat.decline';
  static const chatElicitationRequest = 'chat.elicitation.request';
  static const chatError = 'chat.error';
  static const chatFetchFailed = 'chat.fetch.failed';
  static const chatFilesAction = 'chat.files.action';
  static const chatListArchive = 'chat.list.archive';
  static const chatListDelete = 'chat.list.delete';
  static const chatListError = 'chat.list.error';
  static const chatListNewChat = 'chat.list.new.chat';
  static const chatListNoMessages = 'chat.list.no.messages';
  static (String, Map<String, dynamic>) chatListTimestampDaysAgo(int count) => ('chat.list.timestamp.days.ago', {'count': count});
  static (String, Map<String, dynamic>) chatListTimestampHoursAgo(int count) => ('chat.list.timestamp.hours.ago', {'count': count});
  static (String, Map<String, dynamic>) chatListTimestampMinutesAgo(int count) => ('chat.list.timestamp.minutes.ago', {'count': count});
  static const chatListTimestampNow = 'chat.list.timestamp.now';
  static const chatMessageSent = 'chat.message.sent';
  static const chatModelDefault = 'chat.model.default';
  static const chatModelLabel = 'chat.model.label';
  static const chatModelPerChat = 'chat.model.per.chat';
  static const chatNewCapabilityRequest = 'chat.new.capability.request';
  static const chatNoFieldsRequested = 'chat.no.fields.requested';
  static const chatNotFound = 'chat.not.found';
  static const chatPocoRole = 'chat.poco.role';
  static const chatSelectModelTitle = 'chat.select.model.title';
  static const chatSendFailed = 'chat.send.failed';
  static const chatSendTooltip = 'chat.send.tooltip';
  static const chatSessionAction = 'chat.session.action';
  static const chatSessionTitle = 'chat.session.title';
  static const chatSubmit = 'chat.submit';
  static const chatTerminalAction = 'chat.terminal.action';
  static const chatThinking = 'chat.thinking';
  static const chatThinkingLive = 'chat.thinking.live';
  static const chatThinkingRole = 'chat.thinking.role';
  static const chatThought = 'chat.thought';
  static const chatUseGlobalDefault = 'chat.use.global.default';
  static const deployChooseProvider = 'deploy.choose.provider';
  static const deployComingSoon = 'deploy.coming.soon';
  static const deployProBadge = 'deploy.pro.badge';
  static const deploySelectProvider = 'deploy.select.provider';
  static const deployTitle = 'deploy.title';
  static const deploymentActionAbort = 'deployment.action.abort';
  static const deploymentActionBack = 'deployment.action.back';
  static const deploymentActionDeployInstance = 'deployment.action.deploy.instance';
  static const deploymentActionDismiss = 'deployment.action.dismiss';
  static const deploymentActionLoginNow = 'deployment.action.login.now';
  static const deploymentActionRefresh = 'deployment.action.refresh';
  static const deploymentActionRetryScan = 'deployment.action.retry.scan';
  static const deploymentActionUpdate = 'deployment.action.update';
  static const deploymentAdminIdentity = 'deployment.admin.identity';
  static const deploymentAdminPassword = 'deployment.admin.password';
  static const deploymentBackend = 'deployment.backend';
  static const deploymentCloudRegion = 'deployment.cloud.region';
  static const deploymentCodingHarnesses = 'deployment.coding.harnesses';
  static const deploymentConnectionParameters = 'deployment.connection.parameters';
  static (String, Map<String, dynamic>) deploymentCopiedToBuffer(String label) => ('deployment.copied.to.buffer', {'label': label});
  static const deploymentCopyLabel = 'deployment.copy.label';
  static const deploymentCurrentOperation = 'deployment.current.operation';
  static const deploymentDebian = 'deployment.debian';
  static const deploymentDescriptionConstructing = 'deployment.description.constructing';
  static const deploymentDescriptionFailed = 'deployment.description.failed';
  static const deploymentDescriptionFetching = 'deployment.description.fetching';
  static const deploymentDescriptionFinishing = 'deployment.description.finishing';
  static const deploymentDescriptionInitializing = 'deployment.description.initializing';
  static const deploymentDescriptionInstalling = 'deployment.description.installing';
  static const deploymentDescriptionLoadingImages = 'deployment.description.loading.images';
  static const deploymentDescriptionPreparingHost = 'deployment.description.preparing.host';
  static const deploymentDescriptionReady = 'deployment.description.ready';
  static const deploymentDescriptionSecuring = 'deployment.description.securing';
  static const deploymentDescriptionStarting = 'deployment.description.starting';
  static const deploymentDescriptionValidating = 'deployment.description.validating';
  static const deploymentDistribution = 'deployment.distribution';
  static const deploymentErrorCode = 'deployment.error.code';
  static (String, Map<String, dynamic>) deploymentFaultDetected(String error) => ('deployment.fault.detected', {'error': error});
  static const deploymentGeoGrid = 'deployment.geo.grid';
  static const deploymentHardwareGeography = 'deployment.hardware.geography';
  static const deploymentHardwarePlan = 'deployment.hardware.plan';
  static const deploymentHarnessSelectionDescription = 'deployment.harness.selection.description';
  static const deploymentHttpsEndpoint = 'deployment.https.endpoint';
  static const deploymentInitializingHardware = 'deployment.initializing.hardware';
  static const deploymentInstanceManifest = 'deployment.instance.manifest';
  static const deploymentInstancePlan = 'deployment.instance.plan';
  static const deploymentIpAddress = 'deployment.ip.address';
  static const deploymentLastSignal = 'deployment.last.signal';
  static const deploymentManifestConfiguration = 'deployment.manifest.configuration';
  static const deploymentMetadataRegistry = 'deployment.metadata.registry';
  static (String, Map<String, dynamic>) deploymentMonthlyPrice(String price) => ('deployment.monthly.price', {'price': price});
  static const deploymentNetworkIp = 'deployment.network.ip';
  static const deploymentNixos = 'deployment.nixos';
  static const deploymentOperatingSystem = 'deployment.operating.system';
  static const deploymentProvisioned = 'deployment.provisioned';
  static const deploymentRegion = 'deployment.region';
  static const deploymentRunId = 'deployment.run.id';
  static const deploymentScanningRegions = 'deployment.scanning.regions';
  static const deploymentScreenTitle = 'deployment.screen.title';
  static const deploymentSecure = 'deployment.secure';
  static const deploymentSecurityNotice = 'deployment.security.notice';
  static const deploymentSourceCommit = 'deployment.source.commit';
  static const deploymentStandardLinux = 'deployment.standard.linux';
  static const deploymentStatusConstructing = 'deployment.status.constructing';
  static const deploymentStatusFailed = 'deployment.status.failed';
  static const deploymentStatusFetching = 'deployment.status.fetching';
  static const deploymentStatusFinishing = 'deployment.status.finishing';
  static const deploymentStatusInitializing = 'deployment.status.initializing';
  static const deploymentStatusInstalling = 'deployment.status.installing';
  static const deploymentStatusLoadingImages = 'deployment.status.loading.images';
  static (String, Map<String, dynamic>) deploymentStatusPrefix(String status) => ('deployment.status.prefix', {'status': status});
  static const deploymentStatusPreparingHost = 'deployment.status.preparing.host';
  static const deploymentStatusReady = 'deployment.status.ready';
  static const deploymentStatusSchema = 'deployment.status.schema';
  static const deploymentStatusSecuring = 'deployment.status.securing';
  static const deploymentStatusStarting = 'deployment.status.starting';
  static const deploymentStatusValidating = 'deployment.status.validating';
  static (String, Map<String, dynamic>) deploymentSyncAttempt(int attempt) => ('deployment.sync.attempt', {'attempt': attempt});
  static const deploymentSystemParameters = 'deployment.system.parameters';
  static const deploymentUbuntu = 'deployment.ubuntu';
  static const deploymentUnknown = 'deployment.unknown';
  static const errorAuthFailed = 'error.auth.failed';
  static const errorAuthUnauthorized = 'error.auth.unauthorized';
  static const errorGeneric = 'error.generic';
  static const errorNetwork = 'error.network';
  static const errorTimeout = 'error.timeout';
  static const errorsClearAll = 'errors.clear.all';
  static const errorsCopied = 'errors.copied';
  static const errorsCopy = 'errors.copy';
  static const errorsCopyAll = 'errors.copy.all';
  static const errorsEmpty = 'errors.empty';
  static (String, Map<String, dynamic>) errorsOccurred(int count) => ('errors.occurred', {'count': count});
  static const errorsTitle = 'errors.title';
  static const fileClearAction = 'file.clear.action';
  static const fileDashboardAction = 'file.dashboard.action';
  static const fileEmpty = 'file.empty';
  static const fileFetching = 'file.fetching';
  static const fileNoFileSelected = 'file.no.file.selected';
  static const fileSelectFromChat = 'file.select.from.chat';
  static const fileTitle = 'file.title';
  static const filesCantPreviewType = 'files.cant.preview.type';
  static const filesEmpty = 'files.empty';
  static const filesTitle = 'files.title';
  static const filesTooLargeToPreview = 'files.too.large.to.preview';
  static const harnessAuthChallengeTargetCopied = 'harness.auth.challenge.target.copied';
  static (String, Map<String, dynamic>) homeErrorPrefix(String error) => ('home.error.prefix', {'error': error});
  static const homeLoadingChats = 'home.loading.chats';
  static const homeNewChat = 'home.new.chat';
  static const homeNoChats = 'home.no.chats';
  static const homeTitle = 'home.title';
  static const llmActiveModelSection = 'llm.active.model.section';
  static const llmAddKey = 'llm.add.key';
  static const llmAddKeyHint = 'llm.add.key.hint';
  static (String, Map<String, dynamic>) llmApiKeyDialogTitle(String provider) => ('llm.api.key.dialog.title', {'provider': provider});
  static const llmApiKeysSection = 'llm.api.keys.section';
  static const llmConnected = 'llm.connected';
  static (String, Map<String, dynamic>) llmEnterCredentials(String provider) => ('llm.enter.credentials', {'provider': provider});
  static const llmGlobalDefault = 'llm.global.default';
  static const llmLoadingProviders = 'llm.loading.providers';
  static (String, Map<String, dynamic>) llmModelsAvailable(int count) => ('llm.models.available', {'count': count});
  static const llmModelsButton = 'llm.models.button';
  static const llmNoKey = 'llm.no.key';
  static const llmNoModels = 'llm.no.models';
  static const llmNoProviders = 'llm.no.providers';
  static const llmNotSet = 'llm.not.set';
  static (String, Map<String, dynamic>) llmProviderModelsTitle(String provider) => ('llm.provider.models.title', {'provider': provider});
  static const llmProvidersSection = 'llm.providers.section';
  static const llmSelect = 'llm.select';
  static const llmSelectModelTitle = 'llm.select.model.title';
  static const llmTitle = 'llm.title';
  static const llmUpdateKey = 'llm.update.key';
  static const mcpActiveCapabilities = 'mcp.active.capabilities';
  static const mcpAddConfigOptional = 'mcp.add.config.optional';
  static const mcpAddDialogTitle = 'mcp.add.dialog.title';
  static const mcpAuthorizeCap = 'mcp.authorize.cap';
  static (String, Map<String, dynamic>) mcpAuthorizeDialogTitle(String name) => ('mcp.authorize.dialog.title', {'name': name});
  static const mcpCapabilitiesRegistry = 'mcp.capabilities.registry';
  static const mcpConnectCap = 'mcp.connect.cap';
  static const mcpEditConfig = 'mcp.edit.config';
  static const mcpEnterSecrets = 'mcp.enter.secrets';
  static (String, Map<String, dynamic>) mcpImageLabel(String image) => ('mcp.image.label', {'image': image});
  static const mcpImageOptionalLabel = 'mcp.image.optional.label';
  static const mcpNoCapabilities = 'mcp.no.capabilities';
  static const mcpNoConfigRequired = 'mcp.no.config.required';
  static (String, Map<String, dynamic>) mcpOauthProviderNotConfiguredLabel(String provider) => ('mcp.oauth.provider.not.configured.label', {'provider': provider});
  static const mcpOauthProviderOptionalLabel = 'mcp.oauth.provider.optional.label';
  static (String, Map<String, dynamic>) mcpOauthRequiredLabel(String provider) => ('mcp.oauth.required.label', {'provider': provider});
  static const mcpOauthTokenEnvVarOptionalLabel = 'mcp.oauth.token.env.var.optional.label';
  static const mcpPendingApproval = 'mcp.pending.approval';
  static (String, Map<String, dynamic>) mcpPurposeLabel(String reason) => ('mcp.purpose.label', {'reason': reason});
  static const mcpRequiredConfig = 'mcp.required.config';
  static const mcpRetryDeliveryCap = 'mcp.retry.delivery.cap';
  static const mcpRevoke = 'mcp.revoke';
  static const mcpServerNameLabel = 'mcp.server.name.label';
  static const mcpTitle = 'mcp.title';
  static (String, Map<String, dynamic>) mcpUpdateConfigDialogTitle(String name) => ('mcp.update.config.dialog.title', {'name': name});
  static const monitorAgentActivity = 'monitor.agent.activity';
  static const monitorCostLabel = 'monitor.cost.label';
  static const monitorFetchingTelemetry = 'monitor.fetching.telemetry';
  static const monitorKeyMetrics = 'monitor.key.metrics';
  static const monitorMessagesLabel = 'monitor.messages.label';
  static const monitorNoData = 'monitor.no.data';
  static const monitorSystemHealth = 'monitor.system.health';
  static const monitorTelemetryUnavailable = 'monitor.telemetry.unavailable';
  static const monitorTitle = 'monitor.title';
  static const monitorTokenUsage = 'monitor.token.usage';
  static const monitorTokensLabel = 'monitor.tokens.label';
  static const navChats = 'nav.chats';
  static const navConfigure = 'nav.configure';
  static const navMonitor = 'nav.monitor';
  static const newChatCancel = 'new.chat.cancel';
  static const newChatCreate = 'new.chat.create';
  static const newChatCwdField = 'new.chat.cwd.field';
  static const newChatCwdHint = 'new.chat.cwd.hint';
  static const newChatHarnessField = 'new.chat.harness.field';
  static const newChatModelField = 'new.chat.model.field';
  static const newChatNoModelsAvailable = 'new.chat.no.models.available';
  static const newChatSelectHarness = 'new.chat.select.harness';
  static const newChatSelectModel = 'new.chat.select.model';
  static const newChatTitle = 'new.chat.title';
  static const newChatTitleField = 'new.chat.title.field';
  static const newChatWorkspaceErrorEmpty = 'new.chat.workspace.error.empty';
  static const newChatWorkspaceErrorInvalid = 'new.chat.workspace.error.invalid';
  static const notificationSettingsChatReplyLabel = 'notification.settings.chat.reply.label';
  static const notificationSettingsScheduleLabel = 'notification.settings.schedule.label';
  static const notificationSettingsScreenTitle = 'notification.settings.screen.title';
  static const notificationSettingsTaskCompleteLabel = 'notification.settings.task.complete.label';
  static const notificationSettingsTaskErrorLabel = 'notification.settings.task.error.label';
  static (String, Map<String, dynamic>) notificationSignalReceived(String title) => ('notification.signal.received', {'title': title});
  static const observabilityBackend = 'observability.backend';
  static const observabilityCost = 'observability.cost';
  static const observabilityLogTerminal = 'observability.log.terminal';
  static const observabilityMsgs = 'observability.msgs';
  static const observabilityRegistry = 'observability.registry';
  static const observabilitySelectContainer = 'observability.select.container';
  static const observabilityTitle = 'observability.title';
  static const observabilityTokens = 'observability.tokens';
  static const onboardingAccessDenied = 'onboarding.access.denied';
  static const onboardingAccountLogin = 'onboarding.account.login';
  static const onboardingAuthenticating = 'onboarding.authenticating';
  static const onboardingAuthorizationCode = 'onboarding.authorization.code';
  static const onboardingAuthorizationCodeHint = 'onboarding.authorization.code.hint';
  static const onboardingCheckStatus = 'onboarding.check.status';
  static const onboardingChooseHarnessBody = 'onboarding.choose.harness.body';
  static const onboardingChooseHarnessTitle = 'onboarding.choose.harness.title';
  static const onboardingClaudeAccountLogin = 'onboarding.claude.account.login';
  static const onboardingCodexAccountLogin = 'onboarding.codex.account.login';
  static const onboardingConnectOrDeploy = 'onboarding.connect.or.deploy';
  static const onboardingConnected = 'onboarding.connected';
  static const onboardingCreateServer = 'onboarding.create.server';
  static const onboardingDeploy = 'onboarding.deploy';
  static const onboardingDeployTitle = 'onboarding.deploy.title';
  static const onboardingDockerIntroActionStart = 'onboarding.docker.intro.action.start';
  static const onboardingDockerIntroChipComponent = 'onboarding.docker.intro.chip.component';
  static const onboardingDockerIntroChipConnections = 'onboarding.docker.intro.chip.connections';
  static const onboardingDockerIntroChipContainer = 'onboarding.docker.intro.chip.container';
  static const onboardingDockerIntroChipSavedData = 'onboarding.docker.intro.chip.saved.data';
  static const onboardingDockerIntroEyebrow = 'onboarding.docker.intro.eyebrow';
  static const onboardingDockerIntroPoco = 'onboarding.docker.intro.poco';
  static const onboardingDockerIntroTitle = 'onboarding.docker.intro.title';
  static const onboardingEmail = 'onboarding.email';
  static const onboardingEmailHint = 'onboarding.email.hint';
  static const onboardingEmailHintShort = 'onboarding.email.hint.short';
  static const onboardingExistingServer = 'onboarding.existing.server';
  static const onboardingFailureActionBackToSetup = 'onboarding.failure.action.back.to.setup';
  static const onboardingFailureActionRetryConnection = 'onboarding.failure.action.retry.connection';
  static const onboardingFailureActionTechnicalDetails = 'onboarding.failure.action.technical.details';
  static const onboardingFailureActionViewServerDetails = 'onboarding.failure.action.view.server.details';
  static (String, Map<String, dynamic>) onboardingFailureConnectionPoco(String providerName) => ('onboarding.failure.connection.poco', {'providerName': providerName});
  static const onboardingFailureCreatePoco = 'onboarding.failure.create.poco';
  static (String, Map<String, dynamic>) onboardingHarnessLoginTitle(String provider) => ('onboarding.harness.login.title', {'provider': provider});
  static const onboardingHarnessNotFound = 'onboarding.harness.not.found';
  static const onboardingHarnessPoco = 'onboarding.harness.poco';
  static const onboardingHarnessTitle = 'onboarding.harness.title';
  static const onboardingHomeServer = 'onboarding.home.server';
  static const onboardingIdentityLabel = 'onboarding.identity.label';
  static const onboardingIntentChipCloudModels = 'onboarding.intent.chip.cloud.models';
  static const onboardingIntentChipLocalModels = 'onboarding.intent.chip.local.models';
  static const onboardingIntentPoco = 'onboarding.intent.poco';
  static const onboardingLogin = 'onboarding.login';
  static const onboardingNoServerChipExisting = 'onboarding.no.server.chip.existing';
  static const onboardingNoServerChipNew = 'onboarding.no.server.chip.new';
  static const onboardingNoServerLookingPoco = 'onboarding.no.server.looking.poco';
  static const onboardingNoServerPoco = 'onboarding.no.server.poco';
  static const onboardingOpenAuthorization = 'onboarding.open.authorization';
  static (String, Map<String, dynamic>) onboardingOpenChatFailed(String error) => ('onboarding.open.chat.failed', {'error': error});
  static const onboardingOrientationActionContinue = 'onboarding.orientation.action.continue';
  static const onboardingOrientationActionSkip = 'onboarding.orientation.action.skip';
  static const onboardingOrientationTitle = 'onboarding.orientation.title';
  static (String, Map<String, dynamic>) onboardingOsDebianDescription(int minutes) => ('onboarding.os.debian.description', {'minutes': minutes});
  static const onboardingOsDebianLabel = 'onboarding.os.debian.label';
  static (String, Map<String, dynamic>) onboardingOsNixosDescription(int minutes) => ('onboarding.os.nixos.description', {'minutes': minutes});
  static const onboardingOsNixosLabel = 'onboarding.os.nixos.label';
  static const onboardingOsPoco = 'onboarding.os.poco';
  static const onboardingOsTitle = 'onboarding.os.title';
  static const onboardingPassphraseLabel = 'onboarding.passphrase.label';
  static const onboardingPassword = 'onboarding.password';
  static const onboardingPasswordHint = 'onboarding.password.hint';
  static (String, Map<String, dynamic>) onboardingPlanPoco(String providerName) => ('onboarding.plan.poco', {'providerName': providerName});
  static const onboardingPlanTitle = 'onboarding.plan.title';
  static const onboardingPocketbaseAdminEmail = 'onboarding.pocketbase.admin.email';
  static const onboardingPocketbaseAdminPassword = 'onboarding.pocketbase.admin.password';
  static const onboardingPocoChallengeMessage = 'onboarding.poco.challenge.message';
  static const onboardingPocoWelcome = 'onboarding.poco.welcome';
  static const onboardingProcessing = 'onboarding.processing';
  static (String, Map<String, dynamic>) onboardingProviderAuthorizationAction(String providerName) => ('onboarding.provider.authorization.action', {'providerName': providerName});
  static const onboardingProviderAuthorizationPoco = 'onboarding.provider.authorization.poco';
  static const onboardingProviderAuthorizationTitle = 'onboarding.provider.authorization.title';
  static const onboardingProviderChipElestioComingSoon = 'onboarding.provider.chip.elestio.coming.soon';
  static const onboardingProviderChipLinode = 'onboarding.provider.chip.linode';
  static const onboardingProviderPoco = 'onboarding.provider.poco';
  static const onboardingProviderTitle = 'onboarding.provider.title';
  static const onboardingProvisioningPoco = 'onboarding.provisioning.poco';
  static const onboardingReadyActionLogin = 'onboarding.ready.action.login';
  static const onboardingReadyPoco = 'onboarding.ready.poco';
  static const onboardingRegionConsentChipChooseMyself = 'onboarding.region.consent.chip.choose.myself';
  static const onboardingRegionConsentChipUseLocation = 'onboarding.region.consent.chip.use.location';
  static const onboardingRegionConsentPoco = 'onboarding.region.consent.poco';
  static const onboardingRegionPoco = 'onboarding.region.poco';
  static const onboardingRegionTitle = 'onboarding.region.title';
  static const onboardingRequiredFields = 'onboarding.required.fields';
  static const onboardingReviewActionProvision = 'onboarding.review.action.provision';
  static (String, Map<String, dynamic>) onboardingReviewPoco(String providerName) => ('onboarding.review.poco', {'providerName': providerName});
  static const onboardingReviewTitle = 'onboarding.review.title';
  static const onboardingServerConnecting = 'onboarding.server.connecting';
  static const onboardingServerLoginTitle = 'onboarding.server.login.title';
  static const onboardingServerUrl = 'onboarding.server.url';
  static const onboardingServerUrlHint = 'onboarding.server.url.hint';
  static const onboardingSetupTitle = 'onboarding.setup.title';
  static const onboardingSignInPoco = 'onboarding.sign.in.poco';
  static const onboardingSignInTitle = 'onboarding.sign.in.title';
  static const onboardingSubmitCode = 'onboarding.submit.code';
  static const onboardingTitle = 'onboarding.title';
  static const onboardingTrialChipNotNow = 'onboarding.trial.chip.not.now';
  static const onboardingTrialChipStart = 'onboarding.trial.chip.start';
  static (String, Map<String, dynamic>) onboardingTrialPoco(String trialDuration) => ('onboarding.trial.poco', {'trialDuration': trialDuration});
  static const permissionError = 'permission.error';
  static const permissionFetchFailed = 'permission.fetch.failed';
  static const permissionPatternsLabel = 'permission.patterns.label';
  static (String, Map<String, dynamic>) permissionRequestingLabel(String source) => ('permission.requesting.label', {'source': source});
  static const permissionSignoffTitle = 'permission.signoff.title';
  static const permissionUpdateFailed = 'permission.update.failed';
  static const pocketCoderProgressActive = 'pocket.coder.progress.active';
  static const pocketCoderProgressComplete = 'pocket.coder.progress.complete';
  static const pocketCoderProgressDeployPocketCoder = 'pocket.coder.progress.deploy.pocket.coder';
  static const pocketCoderProgressFailed = 'pocket.coder.progress.failed';
  static const pocketCoderProgressInitializing = 'pocket.coder.progress.initializing';
  static const pocketCoderProgressProvisionServer = 'pocket.coder.progress.provision.server';
  static const pocketCoderProgressWaiting = 'pocket.coder.progress.waiting';
  static const pocoLessonAgentExplanation = 'poco.lesson.agent.explanation';
  static const pocoLessonAgentTitle = 'poco.lesson.agent.title';
  static const pocoLessonComposeStartExplanation = 'poco.lesson.compose.start.explanation';
  static const pocoLessonComposeStartTitle = 'poco.lesson.compose.start.title';
  static const pocoLessonContainerFirewallExplanation = 'poco.lesson.container.firewall.explanation';
  static const pocoLessonContainerFirewallTitle = 'poco.lesson.container.firewall.title';
  static const pocoLessonDashboardExplanation = 'poco.lesson.dashboard.explanation';
  static const pocoLessonDashboardTitle = 'poco.lesson.dashboard.title';
  static const pocoLessonDockerExplanation = 'poco.lesson.docker.explanation';
  static const pocoLessonDockerTitle = 'poco.lesson.docker.title';
  static const pocoLessonHarnessImagesExplanation = 'poco.lesson.harness.images.explanation';
  static const pocoLessonHarnessImagesTitle = 'poco.lesson.harness.images.title';
  static const pocoLessonLocalCaddyExplanation = 'poco.lesson.local.caddy.explanation';
  static const pocoLessonLocalCaddyTitle = 'poco.lesson.local.caddy.title';
  static const pocoLessonLocalModelExplanation = 'poco.lesson.local.model.explanation';
  static const pocoLessonLocalModelTitle = 'poco.lesson.local.model.title';
  static const pocoLessonLocalSecretsExplanation = 'poco.lesson.local.secrets.explanation';
  static const pocoLessonLocalSecretsTitle = 'poco.lesson.local.secrets.title';
  static const pocoLessonMcpSandboxExplanation = 'poco.lesson.mcp.sandbox.explanation';
  static const pocoLessonMcpSandboxTitle = 'poco.lesson.mcp.sandbox.title';
  static const pocoLessonMemoryExplanation = 'poco.lesson.memory.explanation';
  static const pocoLessonMemoryTitle = 'poco.lesson.memory.title';
  static const pocoLessonNetworksExplanation = 'poco.lesson.networks.explanation';
  static const pocoLessonNetworksTitle = 'poco.lesson.networks.title';
  static const pocoLessonNotificationsExplanation = 'poco.lesson.notifications.explanation';
  static const pocoLessonNotificationsTitle = 'poco.lesson.notifications.title';
  static const pocoLessonOwnerConfigExplanation = 'poco.lesson.owner.config.explanation';
  static const pocoLessonOwnerConfigTitle = 'poco.lesson.owner.config.title';
  static const pocoLessonPocketbaseDockerAccessExplanation = 'poco.lesson.pocketbase.docker.access.explanation';
  static const pocoLessonPocketbaseDockerAccessTitle = 'poco.lesson.pocketbase.docker.access.title';
  static const pocoLessonPocketbaseExplanation = 'poco.lesson.pocketbase.explanation';
  static const pocoLessonPocketbaseTitle = 'poco.lesson.pocketbase.title';
  static const pocoLessonPrivateAccessExplanation = 'poco.lesson.private.access.explanation';
  static const pocoLessonPrivateAccessTitle = 'poco.lesson.private.access.title';
  static const pocoLessonPublicFirewallExplanation = 'poco.lesson.public.firewall.explanation';
  static const pocoLessonPublicFirewallTitle = 'poco.lesson.public.firewall.title';
  static const pocoLessonReleaseSourceExplanation = 'poco.lesson.release.source.explanation';
  static const pocoLessonReleaseSourceTitle = 'poco.lesson.release.source.title';
  static const pocoLessonSshExplanation = 'poco.lesson.ssh.explanation';
  static const pocoLessonSshTitle = 'poco.lesson.ssh.title';
  static const pocoLessonVerifiedImagesExplanation = 'poco.lesson.verified.images.explanation';
  static const pocoLessonVerifiedImagesTitle = 'poco.lesson.verified.images.title';
  static const pocoLessonVolumesExplanation = 'poco.lesson.volumes.explanation';
  static const pocoLessonVolumesTitle = 'poco.lesson.volumes.title';
  static const pocoLessonVpsStorageExplanation = 'poco.lesson.vps.storage.explanation';
  static const pocoLessonVpsStorageTitle = 'poco.lesson.vps.storage.title';
  static const pocoProvisioningLoadingSource = 'poco.provisioning.loading.source';
  static const pocoProvisioningNext = 'poco.provisioning.next';
  static const pocoProvisioningPrevious = 'poco.provisioning.previous';
  static const pocoProvisioningShowConcise = 'poco.provisioning.show.concise';
  static const pocoProvisioningShowFull = 'poco.provisioning.show.full';
  static const pocoProvisioningSourceUnavailable = 'poco.provisioning.source.unavailable';
  static const pocoProvisioningTourTitle = 'poco.provisioning.tour.title';
  static const pocoProvisioningWaitingForSource = 'poco.provisioning.waiting.for.source';
  static const providerScreenAddKey = 'provider.screen.add.key';
  static (String, Map<String, dynamic>) providerScreenAddKeyBody(String provider) => ('provider.screen.add.key.body', {'provider': provider});
  static (String, Map<String, dynamic>) providerScreenAddKeyTitle(String provider) => ('provider.screen.add.key.title', {'provider': provider});
  static const providerScreenApiKeysSection = 'provider.screen.api.keys.section';
  static const providerScreenDefaultBadge = 'provider.screen.default.badge';
  static const providerScreenEmptyHint = 'provider.screen.empty.hint';
  static (String, Map<String, dynamic>) providerScreenErrorPrefix(String error) => ('provider.screen.error.prefix', {'error': error});
  static const providerScreenHarnessModelsSection = 'provider.screen.harness.models.section';
  static const providerScreenLoading = 'provider.screen.loading';
  static const providerScreenNoApiKeys = 'provider.screen.no.api.keys';
  static const providerScreenNoHarnessModels = 'provider.screen.no.harness.models';
  static const providerScreenNoProviders = 'provider.screen.no.providers';
  static const providerScreenSelectProvider = 'provider.screen.select.provider';
  static const providerScreenTitle = 'provider.screen.title';
  static const providerScreenUpdateKey = 'provider.screen.update.key';
  static const questionIncomingTitle = 'question.incoming.title';
  static const questionPocoAsking = 'question.poco.asking';
  static const questionSendReply = 'question.send.reply';
  static const relayActivate = 'relay.activate';
  static const relayActive = 'relay.active';
  static const relayCheckingStatus = 'relay.checking.status';
  static const relayConfigSection = 'relay.config.section';
  static const relayFunctionalOverviewBody = 'relay.functional.overview.body';
  static const relayFunctionalOverviewTitle = 'relay.functional.overview.title';
  static const relayNtfyDescription = 'relay.ntfy.description';
  static const relayNtfyTitle = 'relay.ntfy.title';
  static const relayPermissionRelayLabel = 'relay.permission.relay.label';
  static const relayRestore = 'relay.restore';
  static const relaySubsystem = 'relay.subsystem';
  static const relaySubsystemsNominal = 'relay.subsystems.nominal';
  static const relayTitle = 'relay.title';
  static const relayUnlimitedCapacity = 'relay.unlimited.capacity';
  static const schedulerAddButton = 'scheduler.add.button';
  static const schedulerAddDialogTitle = 'scheduler.add.dialog.title';
  static const schedulerCronLabel = 'scheduler.cron.label';
  static const schedulerDeleteButton = 'scheduler.delete.button';
  static const schedulerEditButton = 'scheduler.edit.button';
  static (String, Map<String, dynamic>) schedulerEditDialogTitle(String name) => ('scheduler.edit.dialog.title', {'name': name});
  static const schedulerNameLabel = 'scheduler.name.label';
  static const schedulerNoSchedules = 'scheduler.no.schedules';
  static const schedulerPauseButton = 'scheduler.pause.button';
  static const schedulerPausedBadge = 'scheduler.paused.badge';
  static const schedulerPromptLabel = 'scheduler.prompt.label';
  static const schedulerRegistryTitle = 'scheduler.registry.title';
  static const schedulerResumeButton = 'scheduler.resume.button';
  static const schedulerRunNowButton = 'scheduler.run.now.button';
  static const schedulerRunningBadge = 'scheduler.running.badge';
  static const schedulerSaveButton = 'scheduler.save.button';
  static const schedulerTitle = 'scheduler.title';
  static const settingsAccountSection = 'settings.account.section';
  static const settingsAiAgentsSection = 'settings.ai.agents.section';
  static const settingsAutomationSection = 'settings.automation.section';
  static const settingsGovernanceSection = 'settings.governance.section';
  static const settingsLogoutCancel = 'settings.logout.cancel';
  static const settingsLogoutConfirm = 'settings.logout.confirm';
  static const settingsLogoutConfirmBody = 'settings.logout.confirm.body';
  static const settingsLogoutConfirmTitle = 'settings.logout.confirm.title';
  static const settingsObservabilitySection = 'settings.observability.section';
  static const settingsSecuritySection = 'settings.security.section';
  static const settingsSystemSection = 'settings.system.section';
  static const settingsTitle = 'settings.title';
  static const skillsAddButton = 'skills.add.button';
  static const skillsAddDialogTitle = 'skills.add.dialog.title';
  static const skillsContentLabel = 'skills.content.label';
  static const skillsDeleteButton = 'skills.delete.button';
  static const skillsDescriptionLabel = 'skills.description.label';
  static const skillsEditButton = 'skills.edit.button';
  static (String, Map<String, dynamic>) skillsEditDialogTitle(String name) => ('skills.edit.dialog.title', {'name': name});
  static const skillsGlobalLabel = 'skills.global.label';
  static const skillsGlobalSection = 'skills.global.section';
  static const skillsNameLabel = 'skills.name.label';
  static const skillsNoEligibleConfig = 'skills.no.eligible.config';
  static const skillsNoSkills = 'skills.no.skills';
  static const skillsProjectLabel = 'skills.project.label';
  static const skillsProjectSection = 'skills.project.section';
  static const skillsRegistryTitle = 'skills.registry.title';
  static const skillsSaveButton = 'skills.save.button';
  static const skillsTitle = 'skills.title';
  static const systemChecksDiagnostics = 'system.checks.diagnostics';
  static const systemChecksEmpty = 'system.checks.empty';
  static const systemChecksTitle = 'system.checks.title';
  static const terminalConnecting = 'terminal.connecting';
  static const terminalConnectionFailed = 'terminal.connection.failed';
  static const terminalConnectionStatus = 'terminal.connection.status';
  static const terminalDestinationPath = 'terminal.destination.path';
  static const terminalOffline = 'terminal.offline';
  static const terminalOnline = 'terminal.online';
  static const terminalReconnect = 'terminal.reconnect';
  static const terminalRetry = 'terminal.retry';
  static const terminalSftpTitle = 'terminal.sftp.title';
  static (String, Map<String, dynamic>) terminalSshLink(String host, String port) => ('terminal.ssh.link', {'host': host, 'port': port});
  static const terminalTitle = 'terminal.title';
  static const terminalTransfer = 'terminal.transfer';
  static const terminalUpload = 'terminal.upload';
  static const thoughtsWaiting = 'thoughts.waiting';
  static const toolPermissionsActionLabel = 'tool.permissions.action.label';
  static const toolPermissionsAdd = 'tool.permissions.add';
  static const toolPermissionsAddRuleTitle = 'tool.permissions.add.rule.title';
  static const toolPermissionsAddTitle = 'tool.permissions.add.title';
  static const toolPermissionsAllowLabel = 'tool.permissions.allow.label';
  static const toolPermissionsAskLabel = 'tool.permissions.ask.label';
  static const toolPermissionsDenyLabel = 'tool.permissions.deny.label';
  static const toolPermissionsEmpty = 'tool.permissions.empty';
  static const toolPermissionsError = 'tool.permissions.error';
  static const toolPermissionsFetchFailed = 'tool.permissions.fetch.failed';
  static const toolPermissionsFrameTitle = 'tool.permissions.frame.title';
  static const toolPermissionsLoading = 'tool.permissions.loading';
  static const toolPermissionsNoRules = 'tool.permissions.no.rules';
  static const toolPermissionsPatternLabel = 'tool.permissions.pattern.label';
  static const toolPermissionsRulesRegistry = 'tool.permissions.rules.registry';
  static const toolPermissionsScopeAgent = 'tool.permissions.scope.agent';
  static const toolPermissionsScopeGlobal = 'tool.permissions.scope.global';
  static const toolPermissionsScreenTitle = 'tool.permissions.screen.title';
  static const toolPermissionsTitle = 'tool.permissions.title';
  static const toolPermissionsToolLabel = 'tool.permissions.tool.label';
  static const toolPermissionsToolNameLabel = 'tool.permissions.tool.name.label';
  static const toolPermissionsUpdateFailed = 'tool.permissions.update.failed';
  static const walkthroughActionShowConciseCode = 'walkthrough.action.show.concise.code';
  static const walkthroughActionShowFullCode = 'walkthrough.action.show.full.code';
  static const walkthroughActivationHealthPoco = 'walkthrough.activation.health.poco';
  static const walkthroughActivationHealthTitle = 'walkthrough.activation.health.title';
  static const walkthroughActivationPreparePoco = 'walkthrough.activation.prepare.poco';
  static const walkthroughActivationPrepareTitle = 'walkthrough.activation.prepare.title';
  static const walkthroughActivationSelectedSoftwarePoco = 'walkthrough.activation.selected.software.poco';
  static const walkthroughActivationSelectedSoftwareTitle = 'walkthrough.activation.selected.software.title';
  static const walkthroughActivationSwitchPoco = 'walkthrough.activation.switch.poco';
  static const walkthroughActivationSwitchTitle = 'walkthrough.activation.switch.title';
  static const walkthroughAskPoco = 'walkthrough.ask.poco';
  static const walkthroughBriefDivider = 'walkthrough.brief.divider';
  static const walkthroughCaddyAddressChipHttps = 'walkthrough.caddy.address.chip.https';
  static const walkthroughCaddyAddressChipIpAddress = 'walkthrough.caddy.address.chip.ip.address';
  static const walkthroughCaddyAddressChipSslip = 'walkthrough.caddy.address.chip.sslip';
  static const walkthroughCaddyAddressPoco = 'walkthrough.caddy.address.poco';
  static const walkthroughCaddyAddressTitle = 'walkthrough.caddy.address.title';
  static const walkthroughCaddyWebEntryChipCaddy = 'walkthrough.caddy.web.entry.chip.caddy';
  static const walkthroughCaddyWebEntryChipPrivatePort = 'walkthrough.caddy.web.entry.chip.private.port';
  static const walkthroughCaddyWebEntryPoco = 'walkthrough.caddy.web.entry.poco';
  static const walkthroughCaddyWebEntryTitle = 'walkthrough.caddy.web.entry.title';
  static const walkthroughDebianSetupStatusChipFailure = 'walkthrough.debian.setup.status.chip.failure';
  static const walkthroughDebianSetupStatusChipStatus = 'walkthrough.debian.setup.status.chip.status';
  static const walkthroughDebianSetupStatusPoco = 'walkthrough.debian.setup.status.poco';
  static const walkthroughDebianSetupStatusTitle = 'walkthrough.debian.setup.status.title';
  static (String, Map<String, dynamic>) walkthroughHeader(String os, int current, int total) => ('walkthrough.header', {'os': os, 'current': current, 'total': total});
  static (String, Map<String, dynamic>) walkthroughLabel(int current, int total) => ('walkthrough.label', {'current': current, 'total': total});
  static const walkthroughNixosDockerPoco = 'walkthrough.nixos.docker.poco';
  static const walkthroughNixosDockerRulesPoco = 'walkthrough.nixos.docker.rules.poco';
  static const walkthroughNixosDockerRulesTitle = 'walkthrough.nixos.docker.rules.title';
  static const walkthroughNixosDockerTitle = 'walkthrough.nixos.docker.title';
  static const walkthroughNixosNetworkChipDockerRules = 'walkthrough.nixos.network.chip.docker.rules';
  static const walkthroughNixosNetworkChipIpVersions = 'walkthrough.nixos.network.chip.ip.versions';
  static const walkthroughNixosNetworkChipPorts = 'walkthrough.nixos.network.chip.ports';
  static const walkthroughNixosNetworkPoco = 'walkthrough.nixos.network.poco';
  static const walkthroughNixosNetworkTitle = 'walkthrough.nixos.network.title';
  static const walkthroughNixosSshPoco = 'walkthrough.nixos.ssh.poco';
  static const walkthroughNixosSshTitle = 'walkthrough.nixos.ssh.title';
  static const walkthroughNixosStoragePoco = 'walkthrough.nixos.storage.poco';
  static const walkthroughNixosStorageTitle = 'walkthrough.nixos.storage.title';
  static (String, Map<String, dynamic>) walkthroughProgress(int current, int total, String brief) => ('walkthrough.progress', {'current': current, 'total': total, 'brief': brief});
  static const walkthroughRuntimeSettingsChipLocalSettings = 'walkthrough.runtime.settings.chip.local.settings';
  static const walkthroughRuntimeSettingsPoco = 'walkthrough.runtime.settings.poco';
  static const walkthroughRuntimeSettingsTitle = 'walkthrough.runtime.settings.title';
  static const walkthroughRuntimeVersionPoco = 'walkthrough.runtime.version.poco';
  static const walkthroughRuntimeVersionTitle = 'walkthrough.runtime.version.title';
  static const walkthroughServerKeyChipPrivate = 'walkthrough.server.key.chip.private';
  static const walkthroughServerKeyChipPublic = 'walkthrough.server.key.chip.public';
  static const walkthroughServerKeyChipSsh = 'walkthrough.server.key.chip.ssh';
  static const walkthroughServerKeyPoco = 'walkthrough.server.key.poco';
  static const walkthroughServerKeyTitle = 'walkthrough.server.key.title';
  static const walkthroughServicesCogneeBadge = 'walkthrough.services.cognee.badge';
  static const walkthroughServicesCogneePoco = 'walkthrough.services.cognee.poco';
  static const walkthroughServicesCogneeTitle = 'walkthrough.services.cognee.title';
  static const walkthroughServicesComposeChipDockerCompose = 'walkthrough.services.compose.chip.docker.compose';
  static const walkthroughServicesComposeChipPrivateConnections = 'walkthrough.services.compose.chip.private.connections';
  static const walkthroughServicesComposeChipSavedData = 'walkthrough.services.compose.chip.saved.data';
  static const walkthroughServicesComposePoco = 'walkthrough.services.compose.poco';
  static const walkthroughServicesComposeTitle = 'walkthrough.services.compose.title';
  static const walkthroughServicesHarnessesChipAdd = 'walkthrough.services.harnesses.chip.add';
  static const walkthroughServicesHarnessesChipHarness = 'walkthrough.services.harnesses.chip.harness';
  static const walkthroughServicesHarnessesChipWorkspace = 'walkthrough.services.harnesses.chip.workspace';
  static (String, Map<String, dynamic>) walkthroughServicesHarnessesPoco(String selectedHarnesses) => ('walkthrough.services.harnesses.poco', {'selectedHarnesses': selectedHarnesses});
  static const walkthroughServicesHarnessesTitle = 'walkthrough.services.harnesses.title';
  static const walkthroughServicesOllamaChipDownload = 'walkthrough.services.ollama.chip.download';
  static const walkthroughServicesOllamaChipGpu = 'walkthrough.services.ollama.chip.gpu';
  static const walkthroughServicesOllamaChipLocalModel = 'walkthrough.services.ollama.chip.local.model';
  static const walkthroughServicesOllamaPoco = 'walkthrough.services.ollama.poco';
  static const walkthroughServicesOllamaTitle = 'walkthrough.services.ollama.title';
  static const walkthroughServicesPocketBaseChipKeeps = 'walkthrough.services.pocket.base.chip.keeps';
  static const walkthroughServicesPocketBaseChipSignIn = 'walkthrough.services.pocket.base.chip.sign.in';
  static const walkthroughServicesPocketBaseChipUpdates = 'walkthrough.services.pocket.base.chip.updates';
  static const walkthroughServicesPocketBasePoco = 'walkthrough.services.pocket.base.poco';
  static const walkthroughServicesPocketBaseTitle = 'walkthrough.services.pocket.base.title';
  static const walkthroughServicesSqlPageChipContents = 'walkthrough.services.sql.page.chip.contents';
  static const walkthroughServicesSqlPageChipStartOrder = 'walkthrough.services.sql.page.chip.start.order';
  static const walkthroughServicesSqlPagePoco = 'walkthrough.services.sql.page.poco';
  static const walkthroughServicesSqlPageTitle = 'walkthrough.services.sql.page.title';
  static const walkthroughServicesToolsChipHarnessTools = 'walkthrough.services.tools.chip.harness.tools';
  static const walkthroughServicesToolsChipMcp = 'walkthrough.services.tools.chip.mcp';
  static const walkthroughServicesToolsChipProxy = 'walkthrough.services.tools.chip.proxy';
  static const walkthroughServicesToolsPoco = 'walkthrough.services.tools.poco';
  static const walkthroughServicesToolsTitle = 'walkthrough.services.tools.title';
  static const walkthroughStartPocketCoderChipAddHarness = 'walkthrough.start.pocket.coder.chip.add.harness';
  static const walkthroughStartPocketCoderChipWhatStarts = 'walkthrough.start.pocket.coder.chip.what.starts';
  static const walkthroughStartPocketCoderPoco = 'walkthrough.start.pocket.coder.poco';
  static const walkthroughStartPocketCoderTitle = 'walkthrough.start.pocket.coder.title';
  static const walkthroughTransitionDeployment = 'walkthrough.transition.deployment';
  static const walkthroughTransitionProvisioning = 'walkthrough.transition.provisioning';
  static const walkthroughVerifiedVersionChipDownloadFailure = 'walkthrough.verified.version.chip.download.failure';
  static const walkthroughVerifiedVersionChipUpdates = 'walkthrough.verified.version.chip.updates';
  static const walkthroughVerifiedVersionChipVerification = 'walkthrough.verified.version.chip.verification';
  static const walkthroughVerifiedVersionPoco = 'walkthrough.verified.version.poco';
  static const walkthroughVerifiedVersionTitle = 'walkthrough.verified.version.title';
}
