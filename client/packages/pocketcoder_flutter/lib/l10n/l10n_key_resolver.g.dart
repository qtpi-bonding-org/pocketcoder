// GENERATED CODE - DO NOT MODIFY BY HAND
// Generator: l10n_key_resolver
// Generated at: 2026-08-09T10:17:21.281644

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
    return switch (key) {
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
      'chat.created' => _l10n.chatCreated,
      'chat.error' => _l10n.chatError,
      'chat.fetch.failed' => _l10n.chatFetchFailed,
      'chat.files.action' => _l10n.chatFilesAction,
      'chat.list.archive' => _l10n.chatListArchive,
      'chat.list.delete' => _l10n.chatListDelete,
      'chat.list.error' => _l10n.chatListError,
      'chat.list.new.chat' => _l10n.chatListNewChat,
      'chat.list.no.messages' => _l10n.chatListNoMessages,
      'chat.message.sent' => _l10n.chatMessageSent,
      'chat.model.default' => _l10n.chatModelDefault,
      'chat.model.label' => _l10n.chatModelLabel,
      'chat.model.per.chat' => _l10n.chatModelPerChat,
      'chat.new.capability.request' => _l10n.chatNewCapabilityRequest,
      'chat.not.found' => _l10n.chatNotFound,
      'chat.select.model.title' => _l10n.chatSelectModelTitle,
      'chat.send.failed' => _l10n.chatSendFailed,
      'chat.session.title' => _l10n.chatSessionTitle,
      'chat.terminal.action' => _l10n.chatTerminalAction,
      'chat.thinking' => _l10n.chatThinking,
      'chat.thinking.live' => _l10n.chatThinkingLive,
      'chat.thought' => _l10n.chatThought,
      'chat.use.global.default' => _l10n.chatUseGlobalDefault,
      'deploy.choose.provider' => _l10n.deployChooseProvider,
      'deploy.pro.badge' => _l10n.deployProBadge,
      'deploy.select.provider' => _l10n.deploySelectProvider,
      'deploy.title' => _l10n.deployTitle,
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
      'onboarding.email' => _l10n.onboardingEmail,
      'onboarding.email.hint' => _l10n.onboardingEmailHint,
      'onboarding.email.hint.short' => _l10n.onboardingEmailHintShort,
      'onboarding.existing.server' => _l10n.onboardingExistingServer,
      'onboarding.harness.not.found' => _l10n.onboardingHarnessNotFound,
      'onboarding.home.server' => _l10n.onboardingHomeServer,
      'onboarding.identity.label' => _l10n.onboardingIdentityLabel,
      'onboarding.login' => _l10n.onboardingLogin,
      'onboarding.open.authorization' => _l10n.onboardingOpenAuthorization,
      'onboarding.passphrase.label' => _l10n.onboardingPassphraseLabel,
      'onboarding.password' => _l10n.onboardingPassword,
      'onboarding.password.hint' => _l10n.onboardingPasswordHint,
      'onboarding.pocketbase.admin.email' => _l10n.onboardingPocketbaseAdminEmail,
      'onboarding.pocketbase.admin.password' => _l10n.onboardingPocketbaseAdminPassword,
      'onboarding.poco.challenge.message' => _l10n.onboardingPocoChallengeMessage,
      'onboarding.poco.welcome' => _l10n.onboardingPocoWelcome,
      'onboarding.processing' => _l10n.onboardingProcessing,
      'onboarding.required.fields' => _l10n.onboardingRequiredFields,
      'onboarding.server.connecting' => _l10n.onboardingServerConnecting,
      'onboarding.server.login.title' => _l10n.onboardingServerLoginTitle,
      'onboarding.server.url' => _l10n.onboardingServerUrl,
      'onboarding.server.url.hint' => _l10n.onboardingServerUrlHint,
      'onboarding.setup.title' => _l10n.onboardingSetupTitle,
      'onboarding.submit.code' => _l10n.onboardingSubmitCode,
      'onboarding.title' => _l10n.onboardingTitle,
      'permission.error' => _l10n.permissionError,
      'permission.fetch.failed' => _l10n.permissionFetchFailed,
      'permission.patterns.label' => _l10n.permissionPatternsLabel,
      'permission.signoff.title' => _l10n.permissionSignoffTitle,
      'permission.update.failed' => _l10n.permissionUpdateFailed,
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

      // Parameterized keys
      'agent.config.delete.confirm.body' => _l10n.agentConfigDeleteConfirmBody(args?['name'] as String? ?? ''),
      'agent.config.dialog.title' => _l10n.agentConfigDialogTitle(args?['name'] as String? ?? ''),
      'agent.config.error.prefix' => _l10n.agentConfigErrorPrefix(args?['error'] as String? ?? ''),
      'agent.dialog.title' => _l10n.agentDialogTitle(args?['name'] as String? ?? ''),
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
      'onboarding.harness.login.title' => _l10n.onboardingHarnessLoginTitle(args?['provider'] as String? ?? ''),
      'onboarding.open.chat.failed' => _l10n.onboardingOpenChatFailed(args?['error'] as String? ?? ''),
      'permission.requesting.label' => _l10n.permissionRequestingLabel(args?['source'] as String? ?? ''),
      'provider.screen.add.key.body' => _l10n.providerScreenAddKeyBody(args?['provider'] as String? ?? ''),
      'provider.screen.add.key.title' => _l10n.providerScreenAddKeyTitle(args?['provider'] as String? ?? ''),
      'provider.screen.error.prefix' => _l10n.providerScreenErrorPrefix(args?['error'] as String? ?? ''),
      'scheduler.edit.dialog.title' => _l10n.schedulerEditDialogTitle(args?['name'] as String? ?? ''),
      'skills.edit.dialog.title' => _l10n.skillsEditDialogTitle(args?['name'] as String? ?? ''),
      'terminal.ssh.link' => _l10n.terminalSshLink(args?['host'] as String? ?? '', args?['port'] as String? ?? ''),

      _ => null,
    };
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
    'chat.created',
    'chat.error',
    'chat.fetch.failed',
    'chat.files.action',
    'chat.list.archive',
    'chat.list.delete',
    'chat.list.error',
    'chat.list.new.chat',
    'chat.list.no.messages',
    'chat.message.sent',
    'chat.model.default',
    'chat.model.label',
    'chat.model.per.chat',
    'chat.new.capability.request',
    'chat.not.found',
    'chat.select.model.title',
    'chat.send.failed',
    'chat.session.title',
    'chat.terminal.action',
    'chat.thinking',
    'chat.thinking.live',
    'chat.thought',
    'chat.use.global.default',
    'deploy.choose.provider',
    'deploy.pro.badge',
    'deploy.select.provider',
    'deploy.title',
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
    'onboarding.email',
    'onboarding.email.hint',
    'onboarding.email.hint.short',
    'onboarding.existing.server',
    'onboarding.harness.login.title',
    'onboarding.harness.not.found',
    'onboarding.home.server',
    'onboarding.identity.label',
    'onboarding.login',
    'onboarding.open.authorization',
    'onboarding.open.chat.failed',
    'onboarding.passphrase.label',
    'onboarding.password',
    'onboarding.password.hint',
    'onboarding.pocketbase.admin.email',
    'onboarding.pocketbase.admin.password',
    'onboarding.poco.challenge.message',
    'onboarding.poco.welcome',
    'onboarding.processing',
    'onboarding.required.fields',
    'onboarding.server.connecting',
    'onboarding.server.login.title',
    'onboarding.server.url',
    'onboarding.server.url.hint',
    'onboarding.setup.title',
    'onboarding.submit.code',
    'onboarding.title',
    'permission.error',
    'permission.fetch.failed',
    'permission.patterns.label',
    'permission.requesting.label',
    'permission.signoff.title',
    'permission.update.failed',
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
    'chatCreated': 'chat.created',
    'chatError': 'chat.error',
    'chatFetchFailed': 'chat.fetch.failed',
    'chatFilesAction': 'chat.files.action',
    'chatListArchive': 'chat.list.archive',
    'chatListDelete': 'chat.list.delete',
    'chatListError': 'chat.list.error',
    'chatListNewChat': 'chat.list.new.chat',
    'chatListNoMessages': 'chat.list.no.messages',
    'chatMessageSent': 'chat.message.sent',
    'chatModelDefault': 'chat.model.default',
    'chatModelLabel': 'chat.model.label',
    'chatModelPerChat': 'chat.model.per.chat',
    'chatNewCapabilityRequest': 'chat.new.capability.request',
    'chatNotFound': 'chat.not.found',
    'chatSelectModelTitle': 'chat.select.model.title',
    'chatSendFailed': 'chat.send.failed',
    'chatSessionTitle': 'chat.session.title',
    'chatTerminalAction': 'chat.terminal.action',
    'chatThinking': 'chat.thinking',
    'chatThinkingLive': 'chat.thinking.live',
    'chatThought': 'chat.thought',
    'chatUseGlobalDefault': 'chat.use.global.default',
    'deployChooseProvider': 'deploy.choose.provider',
    'deployProBadge': 'deploy.pro.badge',
    'deploySelectProvider': 'deploy.select.provider',
    'deployTitle': 'deploy.title',
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
    'onboardingEmail': 'onboarding.email',
    'onboardingEmailHint': 'onboarding.email.hint',
    'onboardingEmailHintShort': 'onboarding.email.hint.short',
    'onboardingExistingServer': 'onboarding.existing.server',
    'onboardingHarnessLoginTitle': 'onboarding.harness.login.title',
    'onboardingHarnessNotFound': 'onboarding.harness.not.found',
    'onboardingHomeServer': 'onboarding.home.server',
    'onboardingIdentityLabel': 'onboarding.identity.label',
    'onboardingLogin': 'onboarding.login',
    'onboardingOpenAuthorization': 'onboarding.open.authorization',
    'onboardingOpenChatFailed': 'onboarding.open.chat.failed',
    'onboardingPassphraseLabel': 'onboarding.passphrase.label',
    'onboardingPassword': 'onboarding.password',
    'onboardingPasswordHint': 'onboarding.password.hint',
    'onboardingPocketbaseAdminEmail': 'onboarding.pocketbase.admin.email',
    'onboardingPocketbaseAdminPassword': 'onboarding.pocketbase.admin.password',
    'onboardingPocoChallengeMessage': 'onboarding.poco.challenge.message',
    'onboardingPocoWelcome': 'onboarding.poco.welcome',
    'onboardingProcessing': 'onboarding.processing',
    'onboardingRequiredFields': 'onboarding.required.fields',
    'onboardingServerConnecting': 'onboarding.server.connecting',
    'onboardingServerLoginTitle': 'onboarding.server.login.title',
    'onboardingServerUrl': 'onboarding.server.url',
    'onboardingServerUrlHint': 'onboarding.server.url.hint',
    'onboardingSetupTitle': 'onboarding.setup.title',
    'onboardingSubmitCode': 'onboarding.submit.code',
    'onboardingTitle': 'onboarding.title',
    'permissionError': 'permission.error',
    'permissionFetchFailed': 'permission.fetch.failed',
    'permissionPatternsLabel': 'permission.patterns.label',
    'permissionRequestingLabel': 'permission.requesting.label',
    'permissionSignoffTitle': 'permission.signoff.title',
    'permissionUpdateFailed': 'permission.update.failed',
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
    'chat.created': 'chatCreated',
    'chat.error': 'chatError',
    'chat.fetch.failed': 'chatFetchFailed',
    'chat.files.action': 'chatFilesAction',
    'chat.list.archive': 'chatListArchive',
    'chat.list.delete': 'chatListDelete',
    'chat.list.error': 'chatListError',
    'chat.list.new.chat': 'chatListNewChat',
    'chat.list.no.messages': 'chatListNoMessages',
    'chat.message.sent': 'chatMessageSent',
    'chat.model.default': 'chatModelDefault',
    'chat.model.label': 'chatModelLabel',
    'chat.model.per.chat': 'chatModelPerChat',
    'chat.new.capability.request': 'chatNewCapabilityRequest',
    'chat.not.found': 'chatNotFound',
    'chat.select.model.title': 'chatSelectModelTitle',
    'chat.send.failed': 'chatSendFailed',
    'chat.session.title': 'chatSessionTitle',
    'chat.terminal.action': 'chatTerminalAction',
    'chat.thinking': 'chatThinking',
    'chat.thinking.live': 'chatThinkingLive',
    'chat.thought': 'chatThought',
    'chat.use.global.default': 'chatUseGlobalDefault',
    'deploy.choose.provider': 'deployChooseProvider',
    'deploy.pro.badge': 'deployProBadge',
    'deploy.select.provider': 'deploySelectProvider',
    'deploy.title': 'deployTitle',
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
    'onboarding.email': 'onboardingEmail',
    'onboarding.email.hint': 'onboardingEmailHint',
    'onboarding.email.hint.short': 'onboardingEmailHintShort',
    'onboarding.existing.server': 'onboardingExistingServer',
    'onboarding.harness.login.title': 'onboardingHarnessLoginTitle',
    'onboarding.harness.not.found': 'onboardingHarnessNotFound',
    'onboarding.home.server': 'onboardingHomeServer',
    'onboarding.identity.label': 'onboardingIdentityLabel',
    'onboarding.login': 'onboardingLogin',
    'onboarding.open.authorization': 'onboardingOpenAuthorization',
    'onboarding.open.chat.failed': 'onboardingOpenChatFailed',
    'onboarding.passphrase.label': 'onboardingPassphraseLabel',
    'onboarding.password': 'onboardingPassword',
    'onboarding.password.hint': 'onboardingPasswordHint',
    'onboarding.pocketbase.admin.email': 'onboardingPocketbaseAdminEmail',
    'onboarding.pocketbase.admin.password': 'onboardingPocketbaseAdminPassword',
    'onboarding.poco.challenge.message': 'onboardingPocoChallengeMessage',
    'onboarding.poco.welcome': 'onboardingPocoWelcome',
    'onboarding.processing': 'onboardingProcessing',
    'onboarding.required.fields': 'onboardingRequiredFields',
    'onboarding.server.connecting': 'onboardingServerConnecting',
    'onboarding.server.login.title': 'onboardingServerLoginTitle',
    'onboarding.server.url': 'onboardingServerUrl',
    'onboarding.server.url.hint': 'onboardingServerUrlHint',
    'onboarding.setup.title': 'onboardingSetupTitle',
    'onboarding.submit.code': 'onboardingSubmitCode',
    'onboarding.title': 'onboardingTitle',
    'permission.error': 'permissionError',
    'permission.fetch.failed': 'permissionFetchFailed',
    'permission.patterns.label': 'permissionPatternsLabel',
    'permission.requesting.label': 'permissionRequestingLabel',
    'permission.signoff.title': 'permissionSignoffTitle',
    'permission.update.failed': 'permissionUpdateFailed',
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
  static const chatCreated = 'chat.created';
  static const chatError = 'chat.error';
  static const chatFetchFailed = 'chat.fetch.failed';
  static const chatFilesAction = 'chat.files.action';
  static const chatListArchive = 'chat.list.archive';
  static const chatListDelete = 'chat.list.delete';
  static const chatListError = 'chat.list.error';
  static const chatListNewChat = 'chat.list.new.chat';
  static const chatListNoMessages = 'chat.list.no.messages';
  static const chatMessageSent = 'chat.message.sent';
  static const chatModelDefault = 'chat.model.default';
  static const chatModelLabel = 'chat.model.label';
  static const chatModelPerChat = 'chat.model.per.chat';
  static const chatNewCapabilityRequest = 'chat.new.capability.request';
  static const chatNotFound = 'chat.not.found';
  static const chatSelectModelTitle = 'chat.select.model.title';
  static const chatSendFailed = 'chat.send.failed';
  static const chatSessionTitle = 'chat.session.title';
  static const chatTerminalAction = 'chat.terminal.action';
  static const chatThinking = 'chat.thinking';
  static const chatThinkingLive = 'chat.thinking.live';
  static const chatThought = 'chat.thought';
  static const chatUseGlobalDefault = 'chat.use.global.default';
  static const deployChooseProvider = 'deploy.choose.provider';
  static const deployProBadge = 'deploy.pro.badge';
  static const deploySelectProvider = 'deploy.select.provider';
  static const deployTitle = 'deploy.title';
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
  static const onboardingEmail = 'onboarding.email';
  static const onboardingEmailHint = 'onboarding.email.hint';
  static const onboardingEmailHintShort = 'onboarding.email.hint.short';
  static const onboardingExistingServer = 'onboarding.existing.server';
  static (String, Map<String, dynamic>) onboardingHarnessLoginTitle(String provider) => ('onboarding.harness.login.title', {'provider': provider});
  static const onboardingHarnessNotFound = 'onboarding.harness.not.found';
  static const onboardingHomeServer = 'onboarding.home.server';
  static const onboardingIdentityLabel = 'onboarding.identity.label';
  static const onboardingLogin = 'onboarding.login';
  static const onboardingOpenAuthorization = 'onboarding.open.authorization';
  static (String, Map<String, dynamic>) onboardingOpenChatFailed(String error) => ('onboarding.open.chat.failed', {'error': error});
  static const onboardingPassphraseLabel = 'onboarding.passphrase.label';
  static const onboardingPassword = 'onboarding.password';
  static const onboardingPasswordHint = 'onboarding.password.hint';
  static const onboardingPocketbaseAdminEmail = 'onboarding.pocketbase.admin.email';
  static const onboardingPocketbaseAdminPassword = 'onboarding.pocketbase.admin.password';
  static const onboardingPocoChallengeMessage = 'onboarding.poco.challenge.message';
  static const onboardingPocoWelcome = 'onboarding.poco.welcome';
  static const onboardingProcessing = 'onboarding.processing';
  static const onboardingRequiredFields = 'onboarding.required.fields';
  static const onboardingServerConnecting = 'onboarding.server.connecting';
  static const onboardingServerLoginTitle = 'onboarding.server.login.title';
  static const onboardingServerUrl = 'onboarding.server.url';
  static const onboardingServerUrlHint = 'onboarding.server.url.hint';
  static const onboardingSetupTitle = 'onboarding.setup.title';
  static const onboardingSubmitCode = 'onboarding.submit.code';
  static const onboardingTitle = 'onboarding.title';
  static const permissionError = 'permission.error';
  static const permissionFetchFailed = 'permission.fetch.failed';
  static const permissionPatternsLabel = 'permission.patterns.label';
  static (String, Map<String, dynamic>) permissionRequestingLabel(String source) => ('permission.requesting.label', {'source': source});
  static const permissionSignoffTitle = 'permission.signoff.title';
  static const permissionUpdateFailed = 'permission.update.failed';
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
}
