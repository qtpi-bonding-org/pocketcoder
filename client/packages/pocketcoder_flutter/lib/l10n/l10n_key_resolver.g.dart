// GENERATED CODE - DO NOT MODIFY BY HAND
// Generator: l10n_key_resolver

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
      'action.dismiss' => _l10n.actionDismiss,
      'action.refresh' => _l10n.actionRefresh,
      'action.reject' => _l10n.actionReject,
      'action.restore' => _l10n.actionRestore,
      'action.save' => _l10n.actionSave,
      'action.skip' => _l10n.actionSkip,
      'agent.config.default.badge' => _l10n.agentConfigDefaultBadge,
      'agent.config.delete' => _l10n.agentConfigDelete,
      'agent.config.delete.confirm.title' => _l10n.agentConfigDeleteConfirmTitle,
      'agent.config.empty' => _l10n.agentConfigEmpty,
      'agent.config.is.default.label' => _l10n.agentConfigIsDefaultLabel,
      'agent.config.label' => _l10n.agentConfigLabel,
      'agent.config.mode.label' => _l10n.agentConfigModeLabel,
      'agent.config.name.label' => _l10n.agentConfigNameLabel,
      'agent.config.no.modes' => _l10n.agentConfigNoModes,
      'agent.config.no.prompts' => _l10n.agentConfigNoPrompts,
      'agent.config.prompt.label' => _l10n.agentConfigPromptLabel,
      'agent.config.registry' => _l10n.agentConfigRegistry,
      'agent.config.select.mode' => _l10n.agentConfigSelectMode,
      'agent.config.select.prompt' => _l10n.agentConfigSelectPrompt,
      'agent.config.title' => _l10n.agentConfigTitle,
      'agent.default.tuned' => _l10n.agentDefaultTuned,
      'agent.description.label' => _l10n.agentDescriptionLabel,
      'agent.mode.label' => _l10n.agentModeLabel,
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
      'billing.error' => _l10n.billingError,
      'billing.restore.failed' => _l10n.billingRestoreFailed,
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
      'chat.monitor.action' => _l10n.chatMonitorAction,
      'chat.new.capability.request' => _l10n.chatNewCapabilityRequest,
      'chat.no.fields.requested' => _l10n.chatNoFieldsRequested,
      'chat.not.found' => _l10n.chatNotFound,
      'chat.poco.role' => _l10n.chatPocoRole,
      'chat.run.outcome.cancelled.body' => _l10n.chatRunOutcomeCancelledBody,
      'chat.run.outcome.cancelled.title' => _l10n.chatRunOutcomeCancelledTitle,
      'chat.run.outcome.failed.body' => _l10n.chatRunOutcomeFailedBody,
      'chat.run.outcome.failed.title' => _l10n.chatRunOutcomeFailedTitle,
      'chat.run.outcome.interrupted.body' => _l10n.chatRunOutcomeInterruptedBody,
      'chat.run.outcome.interrupted.title' => _l10n.chatRunOutcomeInterruptedTitle,
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
      'chat.tool.call.fallback' => _l10n.chatToolCallFallback,
      'chat.use.global.default' => _l10n.chatUseGlobalDefault,
      'choose.provider.coming.soon' => _l10n.chooseProviderComingSoon,
      'choose.provider.pro.badge' => _l10n.chooseProviderProBadge,
      'choose.provider.title' => _l10n.chooseProviderTitle,
      'credential.connection.api.key' => _l10n.credentialConnectionApiKey,
      'credential.connection.cancel' => _l10n.credentialConnectionCancel,
      'credential.connection.copy' => _l10n.credentialConnectionCopy,
      'credential.connection.enter.code' => _l10n.credentialConnectionEnterCode,
      'credential.connection.open.authorization.page' => _l10n.credentialConnectionOpenAuthorizationPage,
      'credential.connection.open.failed' => _l10n.credentialConnectionOpenFailed,
      'credential.connection.paste.code' => _l10n.credentialConnectionPasteCode,
      'credential.connection.retry' => _l10n.credentialConnectionRetry,
      'credential.connection.submit' => _l10n.credentialConnectionSubmit,
      'deploy.choose.provider' => _l10n.deployChooseProvider,
      'deploy.select.provider' => _l10n.deploySelectProvider,
      'deployment.action.back' => _l10n.deploymentActionBack,
      'deployment.action.deploy.instance' => _l10n.deploymentActionDeployInstance,
      'deployment.action.dismiss' => _l10n.deploymentActionDismiss,
      'deployment.action.initialize' => _l10n.deploymentActionInitialize,
      'deployment.action.refresh' => _l10n.deploymentActionRefresh,
      'deployment.action.update' => _l10n.deploymentActionUpdate,
      'deployment.backend' => _l10n.deploymentBackend,
      'deployment.cleanup.failed' => _l10n.deploymentCleanupFailed,
      'deployment.cleanup.not.needed' => _l10n.deploymentCleanupNotNeeded,
      'deployment.cleanup.pending' => _l10n.deploymentCleanupPending,
      'deployment.cleanup.succeeded' => _l10n.deploymentCleanupSucceeded,
      'deployment.coding.agents.title' => _l10n.deploymentCodingAgentsTitle,
      'deployment.coding.harnesses' => _l10n.deploymentCodingHarnesses,
      'deployment.debian' => _l10n.deploymentDebian,
      'deployment.debian.description' => _l10n.deploymentDebianDescription,
      'deployment.default.agent' => _l10n.deploymentDefaultAgent,
      'deployment.description.configuring.operating.system' => _l10n.deploymentDescriptionConfiguringOperatingSystem,
      'deployment.description.constructing' => _l10n.deploymentDescriptionConstructing,
      'deployment.description.failed' => _l10n.deploymentDescriptionFailed,
      'deployment.description.fetching' => _l10n.deploymentDescriptionFetching,
      'deployment.description.finishing' => _l10n.deploymentDescriptionFinishing,
      'deployment.description.loading.images' => _l10n.deploymentDescriptionLoadingImages,
      'deployment.description.preparing.operating.system' => _l10n.deploymentDescriptionPreparingOperatingSystem,
      'deployment.description.ready' => _l10n.deploymentDescriptionReady,
      'deployment.description.securing' => _l10n.deploymentDescriptionSecuring,
      'deployment.description.starting' => _l10n.deploymentDescriptionStarting,
      'deployment.description.tls.failed' => _l10n.deploymentDescriptionTlsFailed,
      'deployment.description.tls.rate.limited' => _l10n.deploymentDescriptionTlsRateLimited,
      'deployment.description.tls.ready' => _l10n.deploymentDescriptionTlsReady,
      'deployment.description.tls.zero.ssl' => _l10n.deploymentDescriptionTlsZeroSsl,
      'deployment.description.validating' => _l10n.deploymentDescriptionValidating,
      'deployment.discard.attempt.body' => _l10n.deploymentDiscardAttemptBody,
      'deployment.discard.attempt.cancel' => _l10n.deploymentDiscardAttemptCancel,
      'deployment.discard.attempt.check.link' => _l10n.deploymentDiscardAttemptCheckLink,
      'deployment.discard.attempt.confirm' => _l10n.deploymentDiscardAttemptConfirm,
      'deployment.discard.attempt.confirm.checkbox' => _l10n.deploymentDiscardAttemptConfirmCheckbox,
      'deployment.discard.attempt.title' => _l10n.deploymentDiscardAttemptTitle,
      'deployment.disconnect.action' => _l10n.deploymentDisconnectAction,
      'deployment.disconnect.cancel' => _l10n.deploymentDisconnectCancel,
      'deployment.disconnect.confirm' => _l10n.deploymentDisconnectConfirm,
      'deployment.disconnect.confirmation.body' => _l10n.deploymentDisconnectConfirmationBody,
      'deployment.disconnect.confirmation.title' => _l10n.deploymentDisconnectConfirmationTitle,
      'deployment.distribution' => _l10n.deploymentDistribution,
      'deployment.fault.deployment.instance.not.found' => _l10n.deploymentFaultDeploymentInstanceNotFound,
      'deployment.gpu.badge' => _l10n.deploymentGpuBadge,
      'deployment.hardware.geography' => _l10n.deploymentHardwareGeography,
      'deployment.harness.poco' => _l10n.deploymentHarnessPoco,
      'deployment.harness.selection.description' => _l10n.deploymentHarnessSelectionDescription,
      'deployment.initializing.hardware' => _l10n.deploymentInitializingHardware,
      'deployment.instance.plan' => _l10n.deploymentInstancePlan,
      'deployment.linux.poco' => _l10n.deploymentLinuxPoco,
      'deployment.linux.system.title' => _l10n.deploymentLinuxSystemTitle,
      'deployment.manifest.configuration' => _l10n.deploymentManifestConfiguration,
      'deployment.minimum' => _l10n.deploymentMinimum,
      'deployment.nixos' => _l10n.deploymentNixos,
      'deployment.nixos.description' => _l10n.deploymentNixosDescription,
      'deployment.no.suitable.plans' => _l10n.deploymentNoSuitablePlans,
      'deployment.operating.system' => _l10n.deploymentOperatingSystem,
      'deployment.provider.linode' => _l10n.deploymentProviderLinode,
      'deployment.provisioned' => _l10n.deploymentProvisioned,
      'deployment.provisioning.summary' => _l10n.deploymentProvisioningSummary,
      'deployment.recommended' => _l10n.deploymentRecommended,
      'deployment.region' => _l10n.deploymentRegion,
      'deployment.region.poco' => _l10n.deploymentRegionPoco,
      'deployment.reset.action' => _l10n.deploymentResetAction,
      'deployment.reset.also.clear.o.auth' => _l10n.deploymentResetAlsoClearOAuth,
      'deployment.reset.cancel' => _l10n.deploymentResetCancel,
      'deployment.reset.complete' => _l10n.deploymentResetComplete,
      'deployment.reset.confirm' => _l10n.deploymentResetConfirm,
      'deployment.reset.confirmation.body' => _l10n.deploymentResetConfirmationBody,
      'deployment.reset.confirmation.title' => _l10n.deploymentResetConfirmationTitle,
      'deployment.reset.confirmation.warn.cloud' => _l10n.deploymentResetConfirmationWarnCloud,
      'deployment.review.poco' => _l10n.deploymentReviewPoco,
      'deployment.review.title' => _l10n.deploymentReviewTitle,
      'deployment.run.local.model' => _l10n.deploymentRunLocalModel,
      'deployment.scanning.regions' => _l10n.deploymentScanningRegions,
      'deployment.server.provider' => _l10n.deploymentServerProvider,
      'deployment.server.region.title' => _l10n.deploymentServerRegionTitle,
      'deployment.server.size.title' => _l10n.deploymentServerSizeTitle,
      'deployment.setup.type.title' => _l10n.deploymentSetupTypeTitle,
      'deployment.standard.linux' => _l10n.deploymentStandardLinux,
      'deployment.status.configuring.operating.system' => _l10n.deploymentStatusConfiguringOperatingSystem,
      'deployment.status.constructing' => _l10n.deploymentStatusConstructing,
      'deployment.status.failed' => _l10n.deploymentStatusFailed,
      'deployment.status.fetching' => _l10n.deploymentStatusFetching,
      'deployment.status.finishing' => _l10n.deploymentStatusFinishing,
      'deployment.status.loading.images' => _l10n.deploymentStatusLoadingImages,
      'deployment.status.preparing.operating.system' => _l10n.deploymentStatusPreparingOperatingSystem,
      'deployment.status.ready' => _l10n.deploymentStatusReady,
      'deployment.status.securing' => _l10n.deploymentStatusSecuring,
      'deployment.status.starting' => _l10n.deploymentStatusStarting,
      'deployment.status.tls.failed' => _l10n.deploymentStatusTlsFailed,
      'deployment.status.tls.rate.limited' => _l10n.deploymentStatusTlsRateLimited,
      'deployment.status.tls.ready' => _l10n.deploymentStatusTlsReady,
      'deployment.status.tls.zero.ssl' => _l10n.deploymentStatusTlsZeroSsl,
      'deployment.status.validating' => _l10n.deploymentStatusValidating,
      'deployment.step.boot.final' => _l10n.deploymentStepBootFinal,
      'deployment.step.boot.installer' => _l10n.deploymentStepBootInstaller,
      'deployment.step.bootstrap.complete' => _l10n.deploymentStepBootstrapComplete,
      'deployment.step.compose.up' => _l10n.deploymentStepComposeUp,
      'deployment.step.configuring.operating.system' => _l10n.deploymentStepConfiguringOperatingSystem,
      'deployment.step.create.final.config' => _l10n.deploymentStepCreateFinalConfig,
      'deployment.step.create.installer.config' => _l10n.deploymentStepCreateInstallerConfig,
      'deployment.step.create.installer.disk' => _l10n.deploymentStepCreateInstallerDisk,
      'deployment.step.create.instance' => _l10n.deploymentStepCreateInstance,
      'deployment.step.create.target.disk' => _l10n.deploymentStepCreateTargetDisk,
      'deployment.step.enable.watchdog' => _l10n.deploymentStepEnableWatchdog,
      'deployment.step.fetching.release' => _l10n.deploymentStepFetchingRelease,
      'deployment.step.final.instance.fetch' => _l10n.deploymentStepFinalInstanceFetch,
      'deployment.step.loading.images' => _l10n.deploymentStepLoadingImages,
      'deployment.step.plan.lookup' => _l10n.deploymentStepPlanLookup,
      'deployment.step.pre.boot.shutdown' => _l10n.deploymentStepPreBootShutdown,
      'deployment.step.ready' => _l10n.deploymentStepReady,
      'deployment.step.remove.installer.resources' => _l10n.deploymentStepRemoveInstallerResources,
      'deployment.step.wait.installer.completion' => _l10n.deploymentStepWaitInstallerCompletion,
      'deployment.step.wait.installer.disk.ready' => _l10n.deploymentStepWaitInstallerDiskReady,
      'deployment.step.wait.target.disk.ready' => _l10n.deploymentStepWaitTargetDiskReady,
      'deployment.step.waiting.for.connection' => _l10n.deploymentStepWaitingForConnection,
      'deployment.system.parameters' => _l10n.deploymentSystemParameters,
      'deployment.ubuntu' => _l10n.deploymentUbuntu,
      'deployment.use.cloud.models' => _l10n.deploymentUseCloudModels,
      'deployment.workload.cloud.reply' => _l10n.deploymentWorkloadCloudReply,
      'deployment.workload.local.reply' => _l10n.deploymentWorkloadLocalReply,
      'deployment.workload.poco' => _l10n.deploymentWorkloadPoco,
      'error.auth.failed' => _l10n.errorAuthFailed,
      'error.auth.unauthorized' => _l10n.errorAuthUnauthorized,
      'error.could.not.open.browser' => _l10n.errorCouldNotOpenBrowser,
      'error.generic' => _l10n.errorGeneric,
      'error.network' => _l10n.errorNetwork,
      'error.timeout' => _l10n.errorTimeout,
      'errors.clear.all' => _l10n.errorsClearAll,
      'errors.copied' => _l10n.errorsCopied,
      'errors.copy' => _l10n.errorsCopy,
      'errors.copy.all' => _l10n.errorsCopyAll,
      'errors.empty' => _l10n.errorsEmpty,
      'errors.report.on.github' => _l10n.errorsReportOnGithub,
      'errors.title' => _l10n.errorsTitle,
      'external.auth.cancel' => _l10n.externalAuthCancel,
      'external.auth.retry' => _l10n.externalAuthRetry,
      'external.auth.title' => _l10n.externalAuthTitle,
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
      'foss.server.setup.connected' => _l10n.fossServerSetupConnected,
      'foss.server.setup.generate.key' => _l10n.fossServerSetupGenerateKey,
      'foss.server.setup.host.label' => _l10n.fossServerSetupHostLabel,
      'foss.server.setup.intro' => _l10n.fossServerSetupIntro,
      'foss.server.setup.public.key.label' => _l10n.fossServerSetupPublicKeyLabel,
      'foss.server.setup.test.and.save' => _l10n.fossServerSetupTestAndSave,
      'foss.server.setup.title' => _l10n.fossServerSetupTitle,
      'harness.auth.account.login' => _l10n.harnessAuthAccountLogin,
      'harness.auth.api.key' => _l10n.harnessAuthApiKey,
      'harness.auth.cancel' => _l10n.harnessAuthCancel,
      'harness.auth.challenge' => _l10n.harnessAuthChallenge,
      'harness.auth.challenge.details.copied' => _l10n.harnessAuthChallengeDetailsCopied,
      'harness.auth.challenge.target.copied' => _l10n.harnessAuthChallengeTargetCopied,
      'harness.auth.choose.provider.key' => _l10n.harnessAuthChooseProviderKey,
      'harness.auth.connections' => _l10n.harnessAuthConnections,
      'harness.auth.copy' => _l10n.harnessAuthCopy,
      'harness.auth.disconnect' => _l10n.harnessAuthDisconnect,
      'harness.auth.empty' => _l10n.harnessAuthEmpty,
      'harness.auth.loading' => _l10n.harnessAuthLoading,
      'harness.auth.no.api.key.body' => _l10n.harnessAuthNoApiKeyBody,
      'harness.auth.no.api.key.title' => _l10n.harnessAuthNoApiKeyTitle,
      'harness.auth.none' => _l10n.harnessAuthNone,
      'harness.auth.one.time.code' => _l10n.harnessAuthOneTimeCode,
      'harness.auth.paste.code' => _l10n.harnessAuthPasteCode,
      'harness.auth.personal' => _l10n.harnessAuthPersonal,
      'harness.auth.poll' => _l10n.harnessAuthPoll,
      'harness.auth.refresh' => _l10n.harnessAuthRefresh,
      'harness.auth.shared' => _l10n.harnessAuthShared,
      'harness.auth.submit' => _l10n.harnessAuthSubmit,
      'harness.auth.unavailable' => _l10n.harnessAuthUnavailable,
      'harness.auth.visibility.body' => _l10n.harnessAuthVisibilityBody,
      'harness.auth.visibility.title' => _l10n.harnessAuthVisibilityTitle,
      'home.loading.chats' => _l10n.homeLoadingChats,
      'home.new.chat' => _l10n.homeNewChat,
      'home.no.chats' => _l10n.homeNoChats,
      'home.title' => _l10n.homeTitle,
      'initialization.action.abort' => _l10n.initializationActionAbort,
      'initialization.action.login' => _l10n.initializationActionLogin,
      'initialization.action.retry' => _l10n.initializationActionRetry,
      'initialization.admin.identity' => _l10n.initializationAdminIdentity,
      'initialization.admin.password' => _l10n.initializationAdminPassword,
      'initialization.cloud.region' => _l10n.initializationCloudRegion,
      'initialization.connection.parameters' => _l10n.initializationConnectionParameters,
      'initialization.current.operation' => _l10n.initializationCurrentOperation,
      'initialization.description.initializing' => _l10n.initializationDescriptionInitializing,
      'initialization.error.code' => _l10n.initializationErrorCode,
      'initialization.failed' => _l10n.initializationFailed,
      'initialization.fault.authentication.expired' => _l10n.initializationFaultAuthenticationExpired,
      'initialization.fault.generic' => _l10n.initializationFaultGeneric,
      'initialization.fault.provision.interrupted.no.resource' => _l10n.initializationFaultProvisionInterruptedNoResource,
      'initialization.fault.provision.resource.not.found' => _l10n.initializationFaultProvisionResourceNotFound,
      'initialization.fault.provision.resource.still.exists' => _l10n.initializationFaultProvisionResourceStillExists,
      'initialization.fault.resource.already.exists' => _l10n.initializationFaultResourceAlreadyExists,
      'initialization.geo.grid' => _l10n.initializationGeoGrid,
      'initialization.hardware.plan' => _l10n.initializationHardwarePlan,
      'initialization.https.endpoint' => _l10n.initializationHttpsEndpoint,
      'initialization.in.progress' => _l10n.initializationInProgress,
      'initialization.instance.id' => _l10n.initializationInstanceId,
      'initialization.instance.manifest' => _l10n.initializationInstanceManifest,
      'initialization.ip.address' => _l10n.initializationIpAddress,
      'initialization.last.signal' => _l10n.initializationLastSignal,
      'initialization.metadata.registry' => _l10n.initializationMetadataRegistry,
      'initialization.network.ip' => _l10n.initializationNetworkIp,
      'initialization.retry.attempt' => _l10n.initializationRetryAttempt,
      'initialization.run.id' => _l10n.initializationRunId,
      'initialization.screen.title' => _l10n.initializationScreenTitle,
      'initialization.secure' => _l10n.initializationSecure,
      'initialization.security.notice' => _l10n.initializationSecurityNotice,
      'initialization.source.commit' => _l10n.initializationSourceCommit,
      'initialization.status.initializing' => _l10n.initializationStatusInitializing,
      'initialization.status.schema' => _l10n.initializationStatusSchema,
      'initialization.technical.details.toggle' => _l10n.initializationTechnicalDetailsToggle,
      'initialization.unknown' => _l10n.initializationUnknown,
      'instance.verification.back.action' => _l10n.instanceVerificationBackAction,
      'instance.verification.body' => _l10n.instanceVerificationBody,
      'instance.verification.check.action' => _l10n.instanceVerificationCheckAction,
      'instance.verification.check.failed.message' => _l10n.instanceVerificationCheckFailedMessage,
      'instance.verification.reset.action' => _l10n.instanceVerificationResetAction,
      'instance.verification.reset.cancel' => _l10n.instanceVerificationResetCancel,
      'instance.verification.reset.confirm' => _l10n.instanceVerificationResetConfirm,
      'instance.verification.reset.confirmation.body' => _l10n.instanceVerificationResetConfirmationBody,
      'instance.verification.reset.confirmation.title' => _l10n.instanceVerificationResetConfirmationTitle,
      'instance.verification.title' => _l10n.instanceVerificationTitle,
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
      'mcp.add.new' => _l10n.mcpAddNew,
      'mcp.authorize' => _l10n.mcpAuthorize,
      'mcp.authorize.cap' => _l10n.mcpAuthorizeCap,
      'mcp.capabilities.registry' => _l10n.mcpCapabilitiesRegistry,
      'mcp.connect.cap' => _l10n.mcpConnectCap,
      'mcp.deny' => _l10n.mcpDeny,
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
      'monitor.telemetry.unavailable' => _l10n.monitorTelemetryUnavailable,
      'monitor.title' => _l10n.monitorTitle,
      'nav.chats' => _l10n.navChats,
      'nav.configure' => _l10n.navConfigure,
      'nav.manage' => _l10n.navManage,
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
      'notification.settings.enable.device' => _l10n.notificationSettingsEnableDevice,
      'notification.settings.poco' => _l10n.notificationSettingsPoco,
      'notification.settings.schedule.label' => _l10n.notificationSettingsScheduleLabel,
      'notification.settings.screen.title' => _l10n.notificationSettingsScreenTitle,
      'notification.settings.task.complete.label' => _l10n.notificationSettingsTaskCompleteLabel,
      'notification.settings.task.error.label' => _l10n.notificationSettingsTaskErrorLabel,
      'observability.log.terminal' => _l10n.observabilityLogTerminal,
      'observability.registry' => _l10n.observabilityRegistry,
      'observability.select.container' => _l10n.observabilitySelectContainer,
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
      'onboarding.harness.account.visibility.body' => _l10n.onboardingHarnessAccountVisibilityBody,
      'onboarding.harness.account.visibility.cancel' => _l10n.onboardingHarnessAccountVisibilityCancel,
      'onboarding.harness.account.visibility.personal' => _l10n.onboardingHarnessAccountVisibilityPersonal,
      'onboarding.harness.account.visibility.shared' => _l10n.onboardingHarnessAccountVisibilityShared,
      'onboarding.harness.account.visibility.title' => _l10n.onboardingHarnessAccountVisibilityTitle,
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
      'onboarding.open.chat.failed' => _l10n.onboardingOpenChatFailed,
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
      'onboarding.password.too.short' => _l10n.onboardingPasswordTooShort,
      'onboarding.plan.title' => _l10n.onboardingPlanTitle,
      'onboarding.pocketbase.admin.email' => _l10n.onboardingPocketbaseAdminEmail,
      'onboarding.pocketbase.admin.password' => _l10n.onboardingPocketbaseAdminPassword,
      'onboarding.poco.challenge.message' => _l10n.onboardingPocoChallengeMessage,
      'onboarding.poco.welcome' => _l10n.onboardingPocoWelcome,
      'onboarding.processing' => _l10n.onboardingProcessing,
      'onboarding.provider.authorization.action' => _l10n.onboardingProviderAuthorizationAction,
      'onboarding.provider.authorization.cancelled' => _l10n.onboardingProviderAuthorizationCancelled,
      'onboarding.provider.authorization.error' => _l10n.onboardingProviderAuthorizationError,
      'onboarding.provider.authorization.failed' => _l10n.onboardingProviderAuthorizationFailed,
      'onboarding.provider.authorization.poco' => _l10n.onboardingProviderAuthorizationPoco,
      'onboarding.provider.authorization.title' => _l10n.onboardingProviderAuthorizationTitle,
      'onboarding.provider.authorization.waiting' => _l10n.onboardingProviderAuthorizationWaiting,
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
      'onboarding.self.host.action.connect' => _l10n.onboardingSelfHostActionConnect,
      'onboarding.self.host.action.guide' => _l10n.onboardingSelfHostActionGuide,
      'onboarding.self.host.poco' => _l10n.onboardingSelfHostPoco,
      'onboarding.self.host.requirement.access' => _l10n.onboardingSelfHostRequirementAccess,
      'onboarding.self.host.requirement.docker' => _l10n.onboardingSelfHostRequirementDocker,
      'onboarding.self.host.requirement.server' => _l10n.onboardingSelfHostRequirementServer,
      'onboarding.self.host.requirements.title' => _l10n.onboardingSelfHostRequirementsTitle,
      'onboarding.self.host.title' => _l10n.onboardingSelfHostTitle,
      'onboarding.server.connecting' => _l10n.onboardingServerConnecting,
      'onboarding.server.credentials.poco' => _l10n.onboardingServerCredentialsPoco,
      'onboarding.server.credentials.title' => _l10n.onboardingServerCredentialsTitle,
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
      'onboarding.welcome.action.guided' => _l10n.onboardingWelcomeActionGuided,
      'onboarding.welcome.action.self.host' => _l10n.onboardingWelcomeActionSelfHost,
      'onboarding.welcome.poco' => _l10n.onboardingWelcomePoco,
      'onboarding.welcome.title' => _l10n.onboardingWelcomeTitle,
      'permission.error' => _l10n.permissionError,
      'permission.fetch.failed' => _l10n.permissionFetchFailed,
      'permission.patterns.label' => _l10n.permissionPatternsLabel,
      'permission.requested.fallback' => _l10n.permissionRequestedFallback,
      'permission.signoff.title' => _l10n.permissionSignoffTitle,
      'permission.update.failed' => _l10n.permissionUpdateFailed,
      'pocket.coder.progress.active' => _l10n.pocketCoderProgressActive,
      'pocket.coder.progress.complete' => _l10n.pocketCoderProgressComplete,
      'pocket.coder.progress.deploy.pocket.coder' => _l10n.pocketCoderProgressDeployPocketCoder,
      'pocket.coder.progress.failed' => _l10n.pocketCoderProgressFailed,
      'pocket.coder.progress.initializing' => _l10n.pocketCoderProgressInitializing,
      'pocket.coder.progress.provision.server' => _l10n.pocketCoderProgressProvisionServer,
      'pocket.coder.progress.waiting' => _l10n.pocketCoderProgressWaiting,
      'pocket.coder.update.available' => _l10n.pocketCoderUpdateAvailable,
      'pocket.coder.update.available.status' => _l10n.pocketCoderUpdateAvailableStatus,
      'pocket.coder.update.check.again' => _l10n.pocketCoderUpdateCheckAgain,
      'pocket.coder.update.checking' => _l10n.pocketCoderUpdateChecking,
      'pocket.coder.update.command' => _l10n.pocketCoderUpdateCommand,
      'pocket.coder.update.confirm.upgrade' => _l10n.pocketCoderUpdateConfirmUpgrade,
      'pocket.coder.update.critical.status' => _l10n.pocketCoderUpdateCriticalStatus,
      'pocket.coder.update.current' => _l10n.pocketCoderUpdateCurrent,
      'pocket.coder.update.current.status' => _l10n.pocketCoderUpdateCurrentStatus,
      'pocket.coder.update.download' => _l10n.pocketCoderUpdateDownload,
      'pocket.coder.update.no.deployment' => _l10n.pocketCoderUpdateNoDeployment,
      'pocket.coder.update.output' => _l10n.pocketCoderUpdateOutput,
      'pocket.coder.update.required.disk' => _l10n.pocketCoderUpdateRequiredDisk,
      'pocket.coder.update.review.data.change' => _l10n.pocketCoderUpdateReviewDataChange,
      'pocket.coder.update.rollback.warning' => _l10n.pocketCoderUpdateRollbackWarning,
      'pocket.coder.update.stderr' => _l10n.pocketCoderUpdateStderr,
      'pocket.coder.update.succeeded' => _l10n.pocketCoderUpdateSucceeded,
      'pocket.coder.update.unknown.status' => _l10n.pocketCoderUpdateUnknownStatus,
      'pocket.coder.update.upgrade' => _l10n.pocketCoderUpdateUpgrade,
      'pocket.coder.update.working' => _l10n.pocketCoderUpdateWorking,
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
      'poco.provisioning.failed' => _l10n.pocoProvisioningFailed,
      'poco.provisioning.loading.source' => _l10n.pocoProvisioningLoadingSource,
      'poco.provisioning.next' => _l10n.pocoProvisioningNext,
      'poco.provisioning.previous' => _l10n.pocoProvisioningPrevious,
      'poco.provisioning.show.concise' => _l10n.pocoProvisioningShowConcise,
      'poco.provisioning.show.full' => _l10n.pocoProvisioningShowFull,
      'poco.provisioning.source.unavailable' => _l10n.pocoProvisioningSourceUnavailable,
      'poco.provisioning.tour.title' => _l10n.pocoProvisioningTourTitle,
      'poco.provisioning.waiting.for.source' => _l10n.pocoProvisioningWaitingForSource,
      'pro.active' => _l10n.proActive,
      'pro.active.body' => _l10n.proActiveBody,
      'pro.benefit.live.monitoring' => _l10n.proBenefitLiveMonitoring,
      'pro.benefit.push.notifications' => _l10n.proBenefitPushNotifications,
      'pro.benefit.server.setup' => _l10n.proBenefitServerSetup,
      'pro.checking.status' => _l10n.proCheckingStatus,
      'pro.configure.self.hosted.push' => _l10n.proConfigureSelfHostedPush,
      'pro.feature.console' => _l10n.proFeatureConsole,
      'pro.feature.deploy' => _l10n.proFeatureDeploy,
      'pro.feature.push' => _l10n.proFeaturePush,
      'pro.feature.ready' => _l10n.proFeatureReady,
      'pro.manage.subscription' => _l10n.proManageSubscription,
      'pro.plan.title' => _l10n.proPlanTitle,
      'pro.privacy.policy.link' => _l10n.proPrivacyPolicyLink,
      'pro.restore' => _l10n.proRestore,
      'pro.self.hosted.push.body' => _l10n.proSelfHostedPushBody,
      'pro.self.hosted.push.title' => _l10n.proSelfHostedPushTitle,
      'pro.settings.label' => _l10n.proSettingsLabel,
      'pro.settings.status' => _l10n.proSettingsStatus,
      'pro.subscribe' => _l10n.proSubscribe,
      'pro.summary' => _l10n.proSummary,
      'pro.terms.of.service.link' => _l10n.proTermsOfServiceLink,
      'pro.title' => _l10n.proTitle,
      'pro.trial.lapse.explainer' => _l10n.proTrialLapseExplainer,
      'pro.trial.no.payment.info' => _l10n.proTrialNoPaymentInfo,
      'pro.unavailable' => _l10n.proUnavailable,
      'pro.unavailable.body' => _l10n.proUnavailableBody,
      'pro.unlock.command' => _l10n.proUnlockCommand,
      'provider.reauthentication.required' => _l10n.providerReauthenticationRequired,
      'provider.screen.add.key' => _l10n.providerScreenAddKey,
      'provider.screen.api.keys.section' => _l10n.providerScreenApiKeysSection,
      'provider.screen.default.badge' => _l10n.providerScreenDefaultBadge,
      'provider.screen.empty.hint' => _l10n.providerScreenEmptyHint,
      'provider.screen.harness.models.section' => _l10n.providerScreenHarnessModelsSection,
      'provider.screen.loading' => _l10n.providerScreenLoading,
      'provider.screen.no.api.keys' => _l10n.providerScreenNoApiKeys,
      'provider.screen.no.harness.models' => _l10n.providerScreenNoHarnessModels,
      'provider.screen.no.providers' => _l10n.providerScreenNoProviders,
      'provider.screen.search.hint' => _l10n.providerScreenSearchHint,
      'provider.screen.search.label' => _l10n.providerScreenSearchLabel,
      'provider.screen.search.no.matches' => _l10n.providerScreenSearchNoMatches,
      'provider.screen.select.provider' => _l10n.providerScreenSelectProvider,
      'provider.screen.title' => _l10n.providerScreenTitle,
      'provider.screen.update.key' => _l10n.providerScreenUpdateKey,
      'question.incoming.title' => _l10n.questionIncomingTitle,
      'question.poco.asking' => _l10n.questionPocoAsking,
      'question.send.reply' => _l10n.questionSendReply,
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
      'server.control.action.restart' => _l10n.serverControlActionRestart,
      'server.control.action.restore' => _l10n.serverControlActionRestore,
      'server.control.action.save' => _l10n.serverControlActionSave,
      'server.control.action.update' => _l10n.serverControlActionUpdate,
      'server.control.admin.identity' => _l10n.serverControlAdminIdentity,
      'server.control.admin.password' => _l10n.serverControlAdminPassword,
      'server.control.confirm.cancel' => _l10n.serverControlConfirmCancel,
      'server.control.confirm.confirm' => _l10n.serverControlConfirmConfirm,
      'server.control.confirm.restore.body' => _l10n.serverControlConfirmRestoreBody,
      'server.control.confirm.restore.title' => _l10n.serverControlConfirmRestoreTitle,
      'server.control.confirm.title' => _l10n.serverControlConfirmTitle,
      'server.control.connection.details' => _l10n.serverControlConnectionDetails,
      'server.control.copied' => _l10n.serverControlCopied,
      'server.control.copy' => _l10n.serverControlCopy,
      'server.control.group.data' => _l10n.serverControlGroupData,
      'server.control.group.nix.os' => _l10n.serverControlGroupNixOs,
      'server.control.group.pocket.coder' => _l10n.serverControlGroupPocketCoder,
      'server.control.hide' => _l10n.serverControlHide,
      'server.control.https.endpoint' => _l10n.serverControlHttpsEndpoint,
      'server.control.ip.address' => _l10n.serverControlIpAddress,
      'server.control.local.auth.reason' => _l10n.serverControlLocalAuthReason,
      'server.control.operation.restart.nix.os' => _l10n.serverControlOperationRestartNixOs,
      'server.control.operation.restart.pocket.coder' => _l10n.serverControlOperationRestartPocketCoder,
      'server.control.operation.restore.backup' => _l10n.serverControlOperationRestoreBackup,
      'server.control.operation.save.backup' => _l10n.serverControlOperationSaveBackup,
      'server.control.operation.update.nix.os' => _l10n.serverControlOperationUpdateNixOs,
      'server.control.operation.update.pocket.coder' => _l10n.serverControlOperationUpdatePocketCoder,
      'server.control.private.key.label' => _l10n.serverControlPrivateKeyLabel,
      'server.control.provider.console' => _l10n.serverControlProviderConsole,
      'server.control.provider.console.unavailable' => _l10n.serverControlProviderConsoleUnavailable,
      'server.control.public.key.label' => _l10n.serverControlPublicKeyLabel,
      'server.control.release.checking' => _l10n.serverControlReleaseChecking,
      'server.control.show' => _l10n.serverControlShow,
      'server.control.title' => _l10n.serverControlTitle,
      'settings.account.section' => _l10n.settingsAccountSection,
      'settings.ai.agents.section' => _l10n.settingsAiAgentsSection,
      'settings.delete.pro.data.cancel' => _l10n.settingsDeleteProDataCancel,
      'settings.delete.pro.data.confirm' => _l10n.settingsDeleteProDataConfirm,
      'settings.delete.pro.data.confirm.body' => _l10n.settingsDeleteProDataConfirmBody,
      'settings.delete.pro.data.confirm.title' => _l10n.settingsDeleteProDataConfirmTitle,
      'settings.delete.pro.data.label' => _l10n.settingsDeleteProDataLabel,
      'settings.factory.reset.cancel' => _l10n.settingsFactoryResetCancel,
      'settings.factory.reset.confirm' => _l10n.settingsFactoryResetConfirm,
      'settings.factory.reset.confirm.body' => _l10n.settingsFactoryResetConfirmBody,
      'settings.factory.reset.confirm.title' => _l10n.settingsFactoryResetConfirmTitle,
      'settings.logout.cancel' => _l10n.settingsLogoutCancel,
      'settings.logout.confirm' => _l10n.settingsLogoutConfirm,
      'settings.logout.confirm.body' => _l10n.settingsLogoutConfirmBody,
      'settings.logout.confirm.title' => _l10n.settingsLogoutConfirmTitle,
      'settings.report.ai.content.label' => _l10n.settingsReportAiContentLabel,
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
      'walkthrough.action.skip' => _l10n.walkthroughActionSkip,
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
      'credential.connection.expires.at' => _l10n.credentialConnectionExpiresAt(args?['expiresAt'] as DateTime? ?? DateTime.now()),
      'deployment.discard.attempt.resource.id' => _l10n.deploymentDiscardAttemptResourceId(args?['resourceId'] as String? ?? ''),
      'deployment.memory.gb' => _l10n.deploymentMemoryGb(args?['value'] as int? ?? 0),
      'deployment.memory.mb' => _l10n.deploymentMemoryMb(args?['value'] as int? ?? 0),
      'deployment.monthly.price' => _l10n.deploymentMonthlyPrice(args?['price'] as String? ?? ''),
      'deployment.plan.poco' => _l10n.deploymentPlanPoco(args?['minimumMemory'] as String? ?? ''),
      'deployment.plan.specs' => _l10n.deploymentPlanSpecs(args?['vcpus'] as int? ?? 0, args?['memory'] as String? ?? '', args?['diskGb'] as int? ?? 0),
      'errors.occurred' => _l10n.errorsOccurred(args?['count'] as int? ?? 0),
      'external.auth.connecting' => _l10n.externalAuthConnecting(args?['label'] as String? ?? ''),
      'harness.auth.account' => _l10n.harnessAuthAccount(args?['account'] as String? ?? '', args?['visibility'] as String? ?? ''),
      'harness.auth.attempt' => _l10n.harnessAuthAttempt(args?['id'] as String? ?? ''),
      'harness.auth.details' => _l10n.harnessAuthDetails(args?['details'] as String? ?? ''),
      'harness.auth.mode' => _l10n.harnessAuthMode(args?['mode'] as String? ?? ''),
      'harness.auth.provider.key.missing' => _l10n.harnessAuthProviderKeyMissing(args?['harness'] as String? ?? ''),
      'harness.auth.status' => _l10n.harnessAuthStatus(args?['status'] as String? ?? ''),
      'home.error.prefix' => _l10n.homeErrorPrefix(args?['error'] as String? ?? ''),
      'initialization.copied.to.buffer' => _l10n.initializationCopiedToBuffer(args?['label'] as String? ?? ''),
      'initialization.copy.label' => _l10n.initializationCopyLabel(args?['label'] as String? ?? ''),
      'initialization.fault.detected' => _l10n.initializationFaultDetected(args?['error'] as String? ?? ''),
      'initialization.fault.max.retries.exceeded' => _l10n.initializationFaultMaxRetriesExceeded(args?['maxAttempts'] as String? ?? ''),
      'initialization.ready' => _l10n.initializationReady(args?['ipAddress'] as String? ?? ''),
      'initialization.status.prefix' => _l10n.initializationStatusPrefix(args?['status'] as String? ?? ''),
      'initialization.sync.attempt' => _l10n.initializationSyncAttempt(args?['attempt'] as String? ?? ''),
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
      'onboarding.harness.account.login' => _l10n.onboardingHarnessAccountLogin(args?['harness'] as String? ?? ''),
      'onboarding.harness.login.title' => _l10n.onboardingHarnessLoginTitle(args?['provider'] as String? ?? ''),
      'onboarding.os.debian.description' => _l10n.onboardingOsDebianDescription(args?['minutes'] as int? ?? 0),
      'onboarding.os.nixos.description' => _l10n.onboardingOsNixosDescription(args?['minutes'] as int? ?? 0),
      'onboarding.plan.poco' => _l10n.onboardingPlanPoco(args?['providerName'] as String? ?? ''),
      'onboarding.review.poco' => _l10n.onboardingReviewPoco(args?['providerName'] as String? ?? ''),
      'onboarding.trial.poco' => _l10n.onboardingTrialPoco(args?['trialDuration'] as int? ?? 0),
      'permission.requesting.label' => _l10n.permissionRequestingLabel(args?['source'] as String? ?? ''),
      'pocket.coder.update.data.boundary' => _l10n.pocketCoderUpdateDataBoundary(args?['currentVersion'] as int? ?? 0, args?['availableVersion'] as int? ?? 0),
      'pocket.coder.update.failed' => _l10n.pocketCoderUpdateFailed(args?['exitCode'] as int? ?? 0),
      'pro.price' => _l10n.proPrice(args?['price'] as String? ?? ''),
      'pro.price.after.trial' => _l10n.proPriceAfterTrial(args?['price'] as String? ?? ''),
      'pro.price.per.month' => _l10n.proPricePerMonth(args?['price'] as String? ?? ''),
      'pro.price.per.week' => _l10n.proPricePerWeek(args?['price'] as String? ?? ''),
      'pro.price.per.year' => _l10n.proPricePerYear(args?['price'] as String? ?? ''),
      'pro.start.trial' => _l10n.proStartTrial(args?['days'] as int? ?? 0),
      'pro.terms' => _l10n.proTerms(args?['price'] as String? ?? ''),
      'pro.trial.duration' => _l10n.proTrialDuration(args?['days'] as int? ?? 0),
      'pro.trial.terms' => _l10n.proTrialTerms(args?['days'] as int? ?? 0, args?['price'] as String? ?? ''),
      'provider.screen.add.key.body' => _l10n.providerScreenAddKeyBody(args?['provider'] as String? ?? ''),
      'provider.screen.add.key.title' => _l10n.providerScreenAddKeyTitle(args?['provider'] as String? ?? ''),
      'provider.screen.browse.all.models' => _l10n.providerScreenBrowseAllModels(args?['count'] as int? ?? 0),
      'provider.screen.error.prefix' => _l10n.providerScreenErrorPrefix(args?['error'] as String? ?? ''),
      'provider.screen.harness.model.count' => _l10n.providerScreenHarnessModelCount(args?['count'] as int? ?? 0),
      'scheduler.edit.dialog.title' => _l10n.schedulerEditDialogTitle(args?['name'] as String? ?? ''),
      'server.control.confirm.body' => _l10n.serverControlConfirmBody(args?['operation'] as String? ?? ''),
      'server.control.release.available' => _l10n.serverControlReleaseAvailable(args?['version'] as String? ?? ''),
      'server.control.release.contracts' => _l10n.serverControlReleaseContracts(args?['app'] as String? ?? '', args?['server'] as String? ?? '', args?['deployment'] as String? ?? ''),
      'server.control.release.current' => _l10n.serverControlReleaseCurrent(args?['version'] as String? ?? ''),
      'server.control.release.nixos' => _l10n.serverControlReleaseNixos(args?['version'] as String? ?? ''),
      'server.control.release.status' => _l10n.serverControlReleaseStatus(args?['status'] as String? ?? ''),
      'skills.edit.dialog.title' => _l10n.skillsEditDialogTitle(args?['name'] as String? ?? ''),
      'terminal.ssh.link' => _l10n.terminalSshLink(args?['host'] as String? ?? '', args?['port'] as String? ?? ''),
      'walkthrough.header' => _l10n.walkthroughHeader(args?['os'] as String? ?? '', args?['current'] as int? ?? 0, args?['total'] as int? ?? 0),
      'walkthrough.label' => _l10n.walkthroughLabel(args?['current'] as int? ?? 0, args?['total'] as int? ?? 0),
      'walkthrough.progress' => _l10n.walkthroughProgress(args?['current'] as int? ?? 0, args?['total'] as int? ?? 0, args?['brief'] as String? ?? ''),
      'walkthrough.services.harnesses.poco' => _l10n.walkthroughServicesHarnessesPoco(args?['selectedHarnesses'] as String? ?? ''),

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
    'action.dismiss',
    'action.refresh',
    'action.reject',
    'action.restore',
    'action.save',
    'action.skip',
    'agent.config.default.badge',
    'agent.config.delete',
    'agent.config.delete.confirm.body',
    'agent.config.delete.confirm.title',
    'agent.config.dialog.title',
    'agent.config.empty',
    'agent.config.error.prefix',
    'agent.config.is.default.label',
    'agent.config.label',
    'agent.config.mode.label',
    'agent.config.name.label',
    'agent.config.no.modes',
    'agent.config.no.prompts',
    'agent.config.prompt.label',
    'agent.config.registry',
    'agent.config.select.mode',
    'agent.config.select.prompt',
    'agent.config.title',
    'agent.default.tuned',
    'agent.description.label',
    'agent.dialog.title',
    'agent.mode.label',
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
    'billing.error',
    'billing.restore.failed',
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
    'chat.monitor.action',
    'chat.new.capability.request',
    'chat.no.fields.requested',
    'chat.not.found',
    'chat.poco.role',
    'chat.run.outcome.cancelled.body',
    'chat.run.outcome.cancelled.title',
    'chat.run.outcome.failed.body',
    'chat.run.outcome.failed.title',
    'chat.run.outcome.interrupted.body',
    'chat.run.outcome.interrupted.title',
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
    'chat.tool.call.fallback',
    'chat.use.global.default',
    'choose.provider.coming.soon',
    'choose.provider.pro.badge',
    'choose.provider.title',
    'credential.connection.api.key',
    'credential.connection.cancel',
    'credential.connection.copy',
    'credential.connection.enter.code',
    'credential.connection.expires.at',
    'credential.connection.open.authorization.page',
    'credential.connection.open.failed',
    'credential.connection.paste.code',
    'credential.connection.retry',
    'credential.connection.submit',
    'deploy.choose.provider',
    'deploy.select.provider',
    'deployment.action.back',
    'deployment.action.deploy.instance',
    'deployment.action.dismiss',
    'deployment.action.initialize',
    'deployment.action.refresh',
    'deployment.action.update',
    'deployment.backend',
    'deployment.cleanup.failed',
    'deployment.cleanup.not.needed',
    'deployment.cleanup.pending',
    'deployment.cleanup.succeeded',
    'deployment.coding.agents.title',
    'deployment.coding.harnesses',
    'deployment.debian',
    'deployment.debian.description',
    'deployment.default.agent',
    'deployment.description.configuring.operating.system',
    'deployment.description.constructing',
    'deployment.description.failed',
    'deployment.description.fetching',
    'deployment.description.finishing',
    'deployment.description.loading.images',
    'deployment.description.preparing.operating.system',
    'deployment.description.ready',
    'deployment.description.securing',
    'deployment.description.starting',
    'deployment.description.tls.failed',
    'deployment.description.tls.rate.limited',
    'deployment.description.tls.ready',
    'deployment.description.tls.zero.ssl',
    'deployment.description.validating',
    'deployment.discard.attempt.body',
    'deployment.discard.attempt.cancel',
    'deployment.discard.attempt.check.link',
    'deployment.discard.attempt.confirm',
    'deployment.discard.attempt.confirm.checkbox',
    'deployment.discard.attempt.resource.id',
    'deployment.discard.attempt.title',
    'deployment.disconnect.action',
    'deployment.disconnect.cancel',
    'deployment.disconnect.confirm',
    'deployment.disconnect.confirmation.body',
    'deployment.disconnect.confirmation.title',
    'deployment.distribution',
    'deployment.fault.deployment.instance.not.found',
    'deployment.gpu.badge',
    'deployment.hardware.geography',
    'deployment.harness.poco',
    'deployment.harness.selection.description',
    'deployment.initializing.hardware',
    'deployment.instance.plan',
    'deployment.linux.poco',
    'deployment.linux.system.title',
    'deployment.manifest.configuration',
    'deployment.memory.gb',
    'deployment.memory.mb',
    'deployment.minimum',
    'deployment.monthly.price',
    'deployment.nixos',
    'deployment.nixos.description',
    'deployment.no.suitable.plans',
    'deployment.operating.system',
    'deployment.plan.poco',
    'deployment.plan.specs',
    'deployment.provider.linode',
    'deployment.provisioned',
    'deployment.provisioning.summary',
    'deployment.recommended',
    'deployment.region',
    'deployment.region.poco',
    'deployment.reset.action',
    'deployment.reset.also.clear.o.auth',
    'deployment.reset.cancel',
    'deployment.reset.complete',
    'deployment.reset.confirm',
    'deployment.reset.confirmation.body',
    'deployment.reset.confirmation.title',
    'deployment.reset.confirmation.warn.cloud',
    'deployment.review.poco',
    'deployment.review.title',
    'deployment.run.local.model',
    'deployment.scanning.regions',
    'deployment.server.provider',
    'deployment.server.region.title',
    'deployment.server.size.title',
    'deployment.setup.type.title',
    'deployment.standard.linux',
    'deployment.status.configuring.operating.system',
    'deployment.status.constructing',
    'deployment.status.failed',
    'deployment.status.fetching',
    'deployment.status.finishing',
    'deployment.status.loading.images',
    'deployment.status.preparing.operating.system',
    'deployment.status.ready',
    'deployment.status.securing',
    'deployment.status.starting',
    'deployment.status.tls.failed',
    'deployment.status.tls.rate.limited',
    'deployment.status.tls.ready',
    'deployment.status.tls.zero.ssl',
    'deployment.status.validating',
    'deployment.step.boot.final',
    'deployment.step.boot.installer',
    'deployment.step.bootstrap.complete',
    'deployment.step.compose.up',
    'deployment.step.configuring.operating.system',
    'deployment.step.create.final.config',
    'deployment.step.create.installer.config',
    'deployment.step.create.installer.disk',
    'deployment.step.create.instance',
    'deployment.step.create.target.disk',
    'deployment.step.enable.watchdog',
    'deployment.step.fetching.release',
    'deployment.step.final.instance.fetch',
    'deployment.step.loading.images',
    'deployment.step.plan.lookup',
    'deployment.step.pre.boot.shutdown',
    'deployment.step.ready',
    'deployment.step.remove.installer.resources',
    'deployment.step.wait.installer.completion',
    'deployment.step.wait.installer.disk.ready',
    'deployment.step.wait.target.disk.ready',
    'deployment.step.waiting.for.connection',
    'deployment.system.parameters',
    'deployment.ubuntu',
    'deployment.use.cloud.models',
    'deployment.workload.cloud.reply',
    'deployment.workload.local.reply',
    'deployment.workload.poco',
    'error.auth.failed',
    'error.auth.unauthorized',
    'error.could.not.open.browser',
    'error.generic',
    'error.network',
    'error.timeout',
    'errors.clear.all',
    'errors.copied',
    'errors.copy',
    'errors.copy.all',
    'errors.empty',
    'errors.occurred',
    'errors.report.on.github',
    'errors.title',
    'external.auth.cancel',
    'external.auth.connecting',
    'external.auth.retry',
    'external.auth.title',
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
    'foss.server.setup.connected',
    'foss.server.setup.generate.key',
    'foss.server.setup.host.label',
    'foss.server.setup.intro',
    'foss.server.setup.public.key.label',
    'foss.server.setup.test.and.save',
    'foss.server.setup.title',
    'harness.auth.account',
    'harness.auth.account.login',
    'harness.auth.api.key',
    'harness.auth.attempt',
    'harness.auth.cancel',
    'harness.auth.challenge',
    'harness.auth.challenge.details.copied',
    'harness.auth.challenge.target.copied',
    'harness.auth.choose.provider.key',
    'harness.auth.connections',
    'harness.auth.copy',
    'harness.auth.details',
    'harness.auth.disconnect',
    'harness.auth.empty',
    'harness.auth.loading',
    'harness.auth.mode',
    'harness.auth.no.api.key.body',
    'harness.auth.no.api.key.title',
    'harness.auth.none',
    'harness.auth.one.time.code',
    'harness.auth.paste.code',
    'harness.auth.personal',
    'harness.auth.poll',
    'harness.auth.provider.key.missing',
    'harness.auth.refresh',
    'harness.auth.shared',
    'harness.auth.status',
    'harness.auth.submit',
    'harness.auth.unavailable',
    'harness.auth.visibility.body',
    'harness.auth.visibility.title',
    'home.error.prefix',
    'home.loading.chats',
    'home.new.chat',
    'home.no.chats',
    'home.title',
    'initialization.action.abort',
    'initialization.action.login',
    'initialization.action.retry',
    'initialization.admin.identity',
    'initialization.admin.password',
    'initialization.cloud.region',
    'initialization.connection.parameters',
    'initialization.copied.to.buffer',
    'initialization.copy.label',
    'initialization.current.operation',
    'initialization.description.initializing',
    'initialization.error.code',
    'initialization.failed',
    'initialization.fault.authentication.expired',
    'initialization.fault.detected',
    'initialization.fault.generic',
    'initialization.fault.max.retries.exceeded',
    'initialization.fault.provision.interrupted.no.resource',
    'initialization.fault.provision.resource.not.found',
    'initialization.fault.provision.resource.still.exists',
    'initialization.fault.resource.already.exists',
    'initialization.geo.grid',
    'initialization.hardware.plan',
    'initialization.https.endpoint',
    'initialization.in.progress',
    'initialization.instance.id',
    'initialization.instance.manifest',
    'initialization.ip.address',
    'initialization.last.signal',
    'initialization.metadata.registry',
    'initialization.network.ip',
    'initialization.ready',
    'initialization.retry.attempt',
    'initialization.run.id',
    'initialization.screen.title',
    'initialization.secure',
    'initialization.security.notice',
    'initialization.source.commit',
    'initialization.status.initializing',
    'initialization.status.prefix',
    'initialization.status.schema',
    'initialization.sync.attempt',
    'initialization.technical.details.toggle',
    'initialization.unknown',
    'instance.verification.back.action',
    'instance.verification.body',
    'instance.verification.check.action',
    'instance.verification.check.failed.message',
    'instance.verification.reset.action',
    'instance.verification.reset.cancel',
    'instance.verification.reset.confirm',
    'instance.verification.reset.confirmation.body',
    'instance.verification.reset.confirmation.title',
    'instance.verification.title',
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
    'mcp.add.new',
    'mcp.authorize',
    'mcp.authorize.cap',
    'mcp.authorize.dialog.title',
    'mcp.capabilities.registry',
    'mcp.connect.cap',
    'mcp.deny',
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
    'monitor.telemetry.unavailable',
    'monitor.title',
    'nav.chats',
    'nav.configure',
    'nav.manage',
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
    'notification.settings.enable.device',
    'notification.settings.poco',
    'notification.settings.schedule.label',
    'notification.settings.screen.title',
    'notification.settings.task.complete.label',
    'notification.settings.task.error.label',
    'notification.signal.received',
    'observability.log.terminal',
    'observability.registry',
    'observability.select.container',
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
    'onboarding.harness.account.login',
    'onboarding.harness.account.visibility.body',
    'onboarding.harness.account.visibility.cancel',
    'onboarding.harness.account.visibility.personal',
    'onboarding.harness.account.visibility.shared',
    'onboarding.harness.account.visibility.title',
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
    'onboarding.password.too.short',
    'onboarding.plan.poco',
    'onboarding.plan.title',
    'onboarding.pocketbase.admin.email',
    'onboarding.pocketbase.admin.password',
    'onboarding.poco.challenge.message',
    'onboarding.poco.welcome',
    'onboarding.processing',
    'onboarding.provider.authorization.action',
    'onboarding.provider.authorization.cancelled',
    'onboarding.provider.authorization.error',
    'onboarding.provider.authorization.failed',
    'onboarding.provider.authorization.poco',
    'onboarding.provider.authorization.title',
    'onboarding.provider.authorization.waiting',
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
    'onboarding.self.host.action.connect',
    'onboarding.self.host.action.guide',
    'onboarding.self.host.poco',
    'onboarding.self.host.requirement.access',
    'onboarding.self.host.requirement.docker',
    'onboarding.self.host.requirement.server',
    'onboarding.self.host.requirements.title',
    'onboarding.self.host.title',
    'onboarding.server.connecting',
    'onboarding.server.credentials.poco',
    'onboarding.server.credentials.title',
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
    'onboarding.welcome.action.guided',
    'onboarding.welcome.action.self.host',
    'onboarding.welcome.poco',
    'onboarding.welcome.title',
    'permission.error',
    'permission.fetch.failed',
    'permission.patterns.label',
    'permission.requested.fallback',
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
    'pocket.coder.update.available',
    'pocket.coder.update.available.status',
    'pocket.coder.update.check.again',
    'pocket.coder.update.checking',
    'pocket.coder.update.command',
    'pocket.coder.update.confirm.upgrade',
    'pocket.coder.update.critical.status',
    'pocket.coder.update.current',
    'pocket.coder.update.current.status',
    'pocket.coder.update.data.boundary',
    'pocket.coder.update.download',
    'pocket.coder.update.failed',
    'pocket.coder.update.no.deployment',
    'pocket.coder.update.output',
    'pocket.coder.update.required.disk',
    'pocket.coder.update.review.data.change',
    'pocket.coder.update.rollback.warning',
    'pocket.coder.update.stderr',
    'pocket.coder.update.succeeded',
    'pocket.coder.update.unknown.status',
    'pocket.coder.update.upgrade',
    'pocket.coder.update.working',
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
    'poco.provisioning.failed',
    'poco.provisioning.loading.source',
    'poco.provisioning.next',
    'poco.provisioning.previous',
    'poco.provisioning.show.concise',
    'poco.provisioning.show.full',
    'poco.provisioning.source.unavailable',
    'poco.provisioning.tour.title',
    'poco.provisioning.waiting.for.source',
    'pro.active',
    'pro.active.body',
    'pro.benefit.live.monitoring',
    'pro.benefit.push.notifications',
    'pro.benefit.server.setup',
    'pro.checking.status',
    'pro.configure.self.hosted.push',
    'pro.feature.console',
    'pro.feature.deploy',
    'pro.feature.push',
    'pro.feature.ready',
    'pro.manage.subscription',
    'pro.plan.title',
    'pro.price',
    'pro.price.after.trial',
    'pro.price.per.month',
    'pro.price.per.week',
    'pro.price.per.year',
    'pro.privacy.policy.link',
    'pro.restore',
    'pro.self.hosted.push.body',
    'pro.self.hosted.push.title',
    'pro.settings.label',
    'pro.settings.status',
    'pro.start.trial',
    'pro.subscribe',
    'pro.summary',
    'pro.terms',
    'pro.terms.of.service.link',
    'pro.title',
    'pro.trial.duration',
    'pro.trial.lapse.explainer',
    'pro.trial.no.payment.info',
    'pro.trial.terms',
    'pro.unavailable',
    'pro.unavailable.body',
    'pro.unlock.command',
    'provider.reauthentication.required',
    'provider.screen.add.key',
    'provider.screen.add.key.body',
    'provider.screen.add.key.title',
    'provider.screen.api.keys.section',
    'provider.screen.browse.all.models',
    'provider.screen.default.badge',
    'provider.screen.empty.hint',
    'provider.screen.error.prefix',
    'provider.screen.harness.model.count',
    'provider.screen.harness.models.section',
    'provider.screen.loading',
    'provider.screen.no.api.keys',
    'provider.screen.no.harness.models',
    'provider.screen.no.providers',
    'provider.screen.search.hint',
    'provider.screen.search.label',
    'provider.screen.search.no.matches',
    'provider.screen.select.provider',
    'provider.screen.title',
    'provider.screen.update.key',
    'question.incoming.title',
    'question.poco.asking',
    'question.send.reply',
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
    'server.control.action.restart',
    'server.control.action.restore',
    'server.control.action.save',
    'server.control.action.update',
    'server.control.admin.identity',
    'server.control.admin.password',
    'server.control.confirm.body',
    'server.control.confirm.cancel',
    'server.control.confirm.confirm',
    'server.control.confirm.restore.body',
    'server.control.confirm.restore.title',
    'server.control.confirm.title',
    'server.control.connection.details',
    'server.control.copied',
    'server.control.copy',
    'server.control.group.data',
    'server.control.group.nix.os',
    'server.control.group.pocket.coder',
    'server.control.hide',
    'server.control.https.endpoint',
    'server.control.ip.address',
    'server.control.local.auth.reason',
    'server.control.operation.restart.nix.os',
    'server.control.operation.restart.pocket.coder',
    'server.control.operation.restore.backup',
    'server.control.operation.save.backup',
    'server.control.operation.update.nix.os',
    'server.control.operation.update.pocket.coder',
    'server.control.private.key.label',
    'server.control.provider.console',
    'server.control.provider.console.unavailable',
    'server.control.public.key.label',
    'server.control.release.available',
    'server.control.release.checking',
    'server.control.release.contracts',
    'server.control.release.current',
    'server.control.release.nixos',
    'server.control.release.status',
    'server.control.show',
    'server.control.title',
    'settings.account.section',
    'settings.ai.agents.section',
    'settings.delete.pro.data.cancel',
    'settings.delete.pro.data.confirm',
    'settings.delete.pro.data.confirm.body',
    'settings.delete.pro.data.confirm.title',
    'settings.delete.pro.data.label',
    'settings.factory.reset.cancel',
    'settings.factory.reset.confirm',
    'settings.factory.reset.confirm.body',
    'settings.factory.reset.confirm.title',
    'settings.logout.cancel',
    'settings.logout.confirm',
    'settings.logout.confirm.body',
    'settings.logout.confirm.title',
    'settings.report.ai.content.label',
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
    'walkthrough.action.skip',
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
    'actionDismiss': 'action.dismiss',
    'actionRefresh': 'action.refresh',
    'actionReject': 'action.reject',
    'actionRestore': 'action.restore',
    'actionSave': 'action.save',
    'actionSkip': 'action.skip',
    'agentConfigDefaultBadge': 'agent.config.default.badge',
    'agentConfigDelete': 'agent.config.delete',
    'agentConfigDeleteConfirmBody': 'agent.config.delete.confirm.body',
    'agentConfigDeleteConfirmTitle': 'agent.config.delete.confirm.title',
    'agentConfigDialogTitle': 'agent.config.dialog.title',
    'agentConfigEmpty': 'agent.config.empty',
    'agentConfigErrorPrefix': 'agent.config.error.prefix',
    'agentConfigIsDefaultLabel': 'agent.config.is.default.label',
    'agentConfigLabel': 'agent.config.label',
    'agentConfigModeLabel': 'agent.config.mode.label',
    'agentConfigNameLabel': 'agent.config.name.label',
    'agentConfigNoModes': 'agent.config.no.modes',
    'agentConfigNoPrompts': 'agent.config.no.prompts',
    'agentConfigPromptLabel': 'agent.config.prompt.label',
    'agentConfigRegistry': 'agent.config.registry',
    'agentConfigSelectMode': 'agent.config.select.mode',
    'agentConfigSelectPrompt': 'agent.config.select.prompt',
    'agentConfigTitle': 'agent.config.title',
    'agentDefaultTuned': 'agent.default.tuned',
    'agentDescriptionLabel': 'agent.description.label',
    'agentDialogTitle': 'agent.dialog.title',
    'agentModeLabel': 'agent.mode.label',
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
    'billingError': 'billing.error',
    'billingRestoreFailed': 'billing.restore.failed',
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
    'chatMonitorAction': 'chat.monitor.action',
    'chatNewCapabilityRequest': 'chat.new.capability.request',
    'chatNoFieldsRequested': 'chat.no.fields.requested',
    'chatNotFound': 'chat.not.found',
    'chatPocoRole': 'chat.poco.role',
    'chatRunOutcomeCancelledBody': 'chat.run.outcome.cancelled.body',
    'chatRunOutcomeCancelledTitle': 'chat.run.outcome.cancelled.title',
    'chatRunOutcomeFailedBody': 'chat.run.outcome.failed.body',
    'chatRunOutcomeFailedTitle': 'chat.run.outcome.failed.title',
    'chatRunOutcomeInterruptedBody': 'chat.run.outcome.interrupted.body',
    'chatRunOutcomeInterruptedTitle': 'chat.run.outcome.interrupted.title',
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
    'chatToolCallFallback': 'chat.tool.call.fallback',
    'chatUseGlobalDefault': 'chat.use.global.default',
    'chooseProviderComingSoon': 'choose.provider.coming.soon',
    'chooseProviderProBadge': 'choose.provider.pro.badge',
    'chooseProviderTitle': 'choose.provider.title',
    'credentialConnectionApiKey': 'credential.connection.api.key',
    'credentialConnectionCancel': 'credential.connection.cancel',
    'credentialConnectionCopy': 'credential.connection.copy',
    'credentialConnectionEnterCode': 'credential.connection.enter.code',
    'credentialConnectionExpiresAt': 'credential.connection.expires.at',
    'credentialConnectionOpenAuthorizationPage': 'credential.connection.open.authorization.page',
    'credentialConnectionOpenFailed': 'credential.connection.open.failed',
    'credentialConnectionPasteCode': 'credential.connection.paste.code',
    'credentialConnectionRetry': 'credential.connection.retry',
    'credentialConnectionSubmit': 'credential.connection.submit',
    'deployChooseProvider': 'deploy.choose.provider',
    'deploySelectProvider': 'deploy.select.provider',
    'deploymentActionBack': 'deployment.action.back',
    'deploymentActionDeployInstance': 'deployment.action.deploy.instance',
    'deploymentActionDismiss': 'deployment.action.dismiss',
    'deploymentActionInitialize': 'deployment.action.initialize',
    'deploymentActionRefresh': 'deployment.action.refresh',
    'deploymentActionUpdate': 'deployment.action.update',
    'deploymentBackend': 'deployment.backend',
    'deploymentCleanupFailed': 'deployment.cleanup.failed',
    'deploymentCleanupNotNeeded': 'deployment.cleanup.not.needed',
    'deploymentCleanupPending': 'deployment.cleanup.pending',
    'deploymentCleanupSucceeded': 'deployment.cleanup.succeeded',
    'deploymentCodingAgentsTitle': 'deployment.coding.agents.title',
    'deploymentCodingHarnesses': 'deployment.coding.harnesses',
    'deploymentDebian': 'deployment.debian',
    'deploymentDebianDescription': 'deployment.debian.description',
    'deploymentDefaultAgent': 'deployment.default.agent',
    'deploymentDescriptionConfiguringOperatingSystem': 'deployment.description.configuring.operating.system',
    'deploymentDescriptionConstructing': 'deployment.description.constructing',
    'deploymentDescriptionFailed': 'deployment.description.failed',
    'deploymentDescriptionFetching': 'deployment.description.fetching',
    'deploymentDescriptionFinishing': 'deployment.description.finishing',
    'deploymentDescriptionLoadingImages': 'deployment.description.loading.images',
    'deploymentDescriptionPreparingOperatingSystem': 'deployment.description.preparing.operating.system',
    'deploymentDescriptionReady': 'deployment.description.ready',
    'deploymentDescriptionSecuring': 'deployment.description.securing',
    'deploymentDescriptionStarting': 'deployment.description.starting',
    'deploymentDescriptionTlsFailed': 'deployment.description.tls.failed',
    'deploymentDescriptionTlsRateLimited': 'deployment.description.tls.rate.limited',
    'deploymentDescriptionTlsReady': 'deployment.description.tls.ready',
    'deploymentDescriptionTlsZeroSsl': 'deployment.description.tls.zero.ssl',
    'deploymentDescriptionValidating': 'deployment.description.validating',
    'deploymentDiscardAttemptBody': 'deployment.discard.attempt.body',
    'deploymentDiscardAttemptCancel': 'deployment.discard.attempt.cancel',
    'deploymentDiscardAttemptCheckLink': 'deployment.discard.attempt.check.link',
    'deploymentDiscardAttemptConfirm': 'deployment.discard.attempt.confirm',
    'deploymentDiscardAttemptConfirmCheckbox': 'deployment.discard.attempt.confirm.checkbox',
    'deploymentDiscardAttemptResourceId': 'deployment.discard.attempt.resource.id',
    'deploymentDiscardAttemptTitle': 'deployment.discard.attempt.title',
    'deploymentDisconnectAction': 'deployment.disconnect.action',
    'deploymentDisconnectCancel': 'deployment.disconnect.cancel',
    'deploymentDisconnectConfirm': 'deployment.disconnect.confirm',
    'deploymentDisconnectConfirmationBody': 'deployment.disconnect.confirmation.body',
    'deploymentDisconnectConfirmationTitle': 'deployment.disconnect.confirmation.title',
    'deploymentDistribution': 'deployment.distribution',
    'deploymentFaultDeploymentInstanceNotFound': 'deployment.fault.deployment.instance.not.found',
    'deploymentGpuBadge': 'deployment.gpu.badge',
    'deploymentHardwareGeography': 'deployment.hardware.geography',
    'deploymentHarnessPoco': 'deployment.harness.poco',
    'deploymentHarnessSelectionDescription': 'deployment.harness.selection.description',
    'deploymentInitializingHardware': 'deployment.initializing.hardware',
    'deploymentInstancePlan': 'deployment.instance.plan',
    'deploymentLinuxPoco': 'deployment.linux.poco',
    'deploymentLinuxSystemTitle': 'deployment.linux.system.title',
    'deploymentManifestConfiguration': 'deployment.manifest.configuration',
    'deploymentMemoryGb': 'deployment.memory.gb',
    'deploymentMemoryMb': 'deployment.memory.mb',
    'deploymentMinimum': 'deployment.minimum',
    'deploymentMonthlyPrice': 'deployment.monthly.price',
    'deploymentNixos': 'deployment.nixos',
    'deploymentNixosDescription': 'deployment.nixos.description',
    'deploymentNoSuitablePlans': 'deployment.no.suitable.plans',
    'deploymentOperatingSystem': 'deployment.operating.system',
    'deploymentPlanPoco': 'deployment.plan.poco',
    'deploymentPlanSpecs': 'deployment.plan.specs',
    'deploymentProviderLinode': 'deployment.provider.linode',
    'deploymentProvisioned': 'deployment.provisioned',
    'deploymentProvisioningSummary': 'deployment.provisioning.summary',
    'deploymentRecommended': 'deployment.recommended',
    'deploymentRegion': 'deployment.region',
    'deploymentRegionPoco': 'deployment.region.poco',
    'deploymentResetAction': 'deployment.reset.action',
    'deploymentResetAlsoClearOAuth': 'deployment.reset.also.clear.o.auth',
    'deploymentResetCancel': 'deployment.reset.cancel',
    'deploymentResetComplete': 'deployment.reset.complete',
    'deploymentResetConfirm': 'deployment.reset.confirm',
    'deploymentResetConfirmationBody': 'deployment.reset.confirmation.body',
    'deploymentResetConfirmationTitle': 'deployment.reset.confirmation.title',
    'deploymentResetConfirmationWarnCloud': 'deployment.reset.confirmation.warn.cloud',
    'deploymentReviewPoco': 'deployment.review.poco',
    'deploymentReviewTitle': 'deployment.review.title',
    'deploymentRunLocalModel': 'deployment.run.local.model',
    'deploymentScanningRegions': 'deployment.scanning.regions',
    'deploymentServerProvider': 'deployment.server.provider',
    'deploymentServerRegionTitle': 'deployment.server.region.title',
    'deploymentServerSizeTitle': 'deployment.server.size.title',
    'deploymentSetupTypeTitle': 'deployment.setup.type.title',
    'deploymentStandardLinux': 'deployment.standard.linux',
    'deploymentStatusConfiguringOperatingSystem': 'deployment.status.configuring.operating.system',
    'deploymentStatusConstructing': 'deployment.status.constructing',
    'deploymentStatusFailed': 'deployment.status.failed',
    'deploymentStatusFetching': 'deployment.status.fetching',
    'deploymentStatusFinishing': 'deployment.status.finishing',
    'deploymentStatusLoadingImages': 'deployment.status.loading.images',
    'deploymentStatusPreparingOperatingSystem': 'deployment.status.preparing.operating.system',
    'deploymentStatusReady': 'deployment.status.ready',
    'deploymentStatusSecuring': 'deployment.status.securing',
    'deploymentStatusStarting': 'deployment.status.starting',
    'deploymentStatusTlsFailed': 'deployment.status.tls.failed',
    'deploymentStatusTlsRateLimited': 'deployment.status.tls.rate.limited',
    'deploymentStatusTlsReady': 'deployment.status.tls.ready',
    'deploymentStatusTlsZeroSsl': 'deployment.status.tls.zero.ssl',
    'deploymentStatusValidating': 'deployment.status.validating',
    'deploymentStepBootFinal': 'deployment.step.boot.final',
    'deploymentStepBootInstaller': 'deployment.step.boot.installer',
    'deploymentStepBootstrapComplete': 'deployment.step.bootstrap.complete',
    'deploymentStepComposeUp': 'deployment.step.compose.up',
    'deploymentStepConfiguringOperatingSystem': 'deployment.step.configuring.operating.system',
    'deploymentStepCreateFinalConfig': 'deployment.step.create.final.config',
    'deploymentStepCreateInstallerConfig': 'deployment.step.create.installer.config',
    'deploymentStepCreateInstallerDisk': 'deployment.step.create.installer.disk',
    'deploymentStepCreateInstance': 'deployment.step.create.instance',
    'deploymentStepCreateTargetDisk': 'deployment.step.create.target.disk',
    'deploymentStepEnableWatchdog': 'deployment.step.enable.watchdog',
    'deploymentStepFetchingRelease': 'deployment.step.fetching.release',
    'deploymentStepFinalInstanceFetch': 'deployment.step.final.instance.fetch',
    'deploymentStepLoadingImages': 'deployment.step.loading.images',
    'deploymentStepPlanLookup': 'deployment.step.plan.lookup',
    'deploymentStepPreBootShutdown': 'deployment.step.pre.boot.shutdown',
    'deploymentStepReady': 'deployment.step.ready',
    'deploymentStepRemoveInstallerResources': 'deployment.step.remove.installer.resources',
    'deploymentStepWaitInstallerCompletion': 'deployment.step.wait.installer.completion',
    'deploymentStepWaitInstallerDiskReady': 'deployment.step.wait.installer.disk.ready',
    'deploymentStepWaitTargetDiskReady': 'deployment.step.wait.target.disk.ready',
    'deploymentStepWaitingForConnection': 'deployment.step.waiting.for.connection',
    'deploymentSystemParameters': 'deployment.system.parameters',
    'deploymentUbuntu': 'deployment.ubuntu',
    'deploymentUseCloudModels': 'deployment.use.cloud.models',
    'deploymentWorkloadCloudReply': 'deployment.workload.cloud.reply',
    'deploymentWorkloadLocalReply': 'deployment.workload.local.reply',
    'deploymentWorkloadPoco': 'deployment.workload.poco',
    'errorAuthFailed': 'error.auth.failed',
    'errorAuthUnauthorized': 'error.auth.unauthorized',
    'errorCouldNotOpenBrowser': 'error.could.not.open.browser',
    'errorGeneric': 'error.generic',
    'errorNetwork': 'error.network',
    'errorTimeout': 'error.timeout',
    'errorsClearAll': 'errors.clear.all',
    'errorsCopied': 'errors.copied',
    'errorsCopy': 'errors.copy',
    'errorsCopyAll': 'errors.copy.all',
    'errorsEmpty': 'errors.empty',
    'errorsOccurred': 'errors.occurred',
    'errorsReportOnGithub': 'errors.report.on.github',
    'errorsTitle': 'errors.title',
    'externalAuthCancel': 'external.auth.cancel',
    'externalAuthConnecting': 'external.auth.connecting',
    'externalAuthRetry': 'external.auth.retry',
    'externalAuthTitle': 'external.auth.title',
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
    'fossServerSetupConnected': 'foss.server.setup.connected',
    'fossServerSetupGenerateKey': 'foss.server.setup.generate.key',
    'fossServerSetupHostLabel': 'foss.server.setup.host.label',
    'fossServerSetupIntro': 'foss.server.setup.intro',
    'fossServerSetupPublicKeyLabel': 'foss.server.setup.public.key.label',
    'fossServerSetupTestAndSave': 'foss.server.setup.test.and.save',
    'fossServerSetupTitle': 'foss.server.setup.title',
    'harnessAuthAccount': 'harness.auth.account',
    'harnessAuthAccountLogin': 'harness.auth.account.login',
    'harnessAuthApiKey': 'harness.auth.api.key',
    'harnessAuthAttempt': 'harness.auth.attempt',
    'harnessAuthCancel': 'harness.auth.cancel',
    'harnessAuthChallenge': 'harness.auth.challenge',
    'harnessAuthChallengeDetailsCopied': 'harness.auth.challenge.details.copied',
    'harnessAuthChallengeTargetCopied': 'harness.auth.challenge.target.copied',
    'harnessAuthChooseProviderKey': 'harness.auth.choose.provider.key',
    'harnessAuthConnections': 'harness.auth.connections',
    'harnessAuthCopy': 'harness.auth.copy',
    'harnessAuthDetails': 'harness.auth.details',
    'harnessAuthDisconnect': 'harness.auth.disconnect',
    'harnessAuthEmpty': 'harness.auth.empty',
    'harnessAuthLoading': 'harness.auth.loading',
    'harnessAuthMode': 'harness.auth.mode',
    'harnessAuthNoApiKeyBody': 'harness.auth.no.api.key.body',
    'harnessAuthNoApiKeyTitle': 'harness.auth.no.api.key.title',
    'harnessAuthNone': 'harness.auth.none',
    'harnessAuthOneTimeCode': 'harness.auth.one.time.code',
    'harnessAuthPasteCode': 'harness.auth.paste.code',
    'harnessAuthPersonal': 'harness.auth.personal',
    'harnessAuthPoll': 'harness.auth.poll',
    'harnessAuthProviderKeyMissing': 'harness.auth.provider.key.missing',
    'harnessAuthRefresh': 'harness.auth.refresh',
    'harnessAuthShared': 'harness.auth.shared',
    'harnessAuthStatus': 'harness.auth.status',
    'harnessAuthSubmit': 'harness.auth.submit',
    'harnessAuthUnavailable': 'harness.auth.unavailable',
    'harnessAuthVisibilityBody': 'harness.auth.visibility.body',
    'harnessAuthVisibilityTitle': 'harness.auth.visibility.title',
    'homeErrorPrefix': 'home.error.prefix',
    'homeLoadingChats': 'home.loading.chats',
    'homeNewChat': 'home.new.chat',
    'homeNoChats': 'home.no.chats',
    'homeTitle': 'home.title',
    'initializationActionAbort': 'initialization.action.abort',
    'initializationActionLogin': 'initialization.action.login',
    'initializationActionRetry': 'initialization.action.retry',
    'initializationAdminIdentity': 'initialization.admin.identity',
    'initializationAdminPassword': 'initialization.admin.password',
    'initializationCloudRegion': 'initialization.cloud.region',
    'initializationConnectionParameters': 'initialization.connection.parameters',
    'initializationCopiedToBuffer': 'initialization.copied.to.buffer',
    'initializationCopyLabel': 'initialization.copy.label',
    'initializationCurrentOperation': 'initialization.current.operation',
    'initializationDescriptionInitializing': 'initialization.description.initializing',
    'initializationErrorCode': 'initialization.error.code',
    'initializationFailed': 'initialization.failed',
    'initializationFaultAuthenticationExpired': 'initialization.fault.authentication.expired',
    'initializationFaultDetected': 'initialization.fault.detected',
    'initializationFaultGeneric': 'initialization.fault.generic',
    'initializationFaultMaxRetriesExceeded': 'initialization.fault.max.retries.exceeded',
    'initializationFaultProvisionInterruptedNoResource': 'initialization.fault.provision.interrupted.no.resource',
    'initializationFaultProvisionResourceNotFound': 'initialization.fault.provision.resource.not.found',
    'initializationFaultProvisionResourceStillExists': 'initialization.fault.provision.resource.still.exists',
    'initializationFaultResourceAlreadyExists': 'initialization.fault.resource.already.exists',
    'initializationGeoGrid': 'initialization.geo.grid',
    'initializationHardwarePlan': 'initialization.hardware.plan',
    'initializationHttpsEndpoint': 'initialization.https.endpoint',
    'initializationInProgress': 'initialization.in.progress',
    'initializationInstanceId': 'initialization.instance.id',
    'initializationInstanceManifest': 'initialization.instance.manifest',
    'initializationIpAddress': 'initialization.ip.address',
    'initializationLastSignal': 'initialization.last.signal',
    'initializationMetadataRegistry': 'initialization.metadata.registry',
    'initializationNetworkIp': 'initialization.network.ip',
    'initializationReady': 'initialization.ready',
    'initializationRetryAttempt': 'initialization.retry.attempt',
    'initializationRunId': 'initialization.run.id',
    'initializationScreenTitle': 'initialization.screen.title',
    'initializationSecure': 'initialization.secure',
    'initializationSecurityNotice': 'initialization.security.notice',
    'initializationSourceCommit': 'initialization.source.commit',
    'initializationStatusInitializing': 'initialization.status.initializing',
    'initializationStatusPrefix': 'initialization.status.prefix',
    'initializationStatusSchema': 'initialization.status.schema',
    'initializationSyncAttempt': 'initialization.sync.attempt',
    'initializationTechnicalDetailsToggle': 'initialization.technical.details.toggle',
    'initializationUnknown': 'initialization.unknown',
    'instanceVerificationBackAction': 'instance.verification.back.action',
    'instanceVerificationBody': 'instance.verification.body',
    'instanceVerificationCheckAction': 'instance.verification.check.action',
    'instanceVerificationCheckFailedMessage': 'instance.verification.check.failed.message',
    'instanceVerificationResetAction': 'instance.verification.reset.action',
    'instanceVerificationResetCancel': 'instance.verification.reset.cancel',
    'instanceVerificationResetConfirm': 'instance.verification.reset.confirm',
    'instanceVerificationResetConfirmationBody': 'instance.verification.reset.confirmation.body',
    'instanceVerificationResetConfirmationTitle': 'instance.verification.reset.confirmation.title',
    'instanceVerificationTitle': 'instance.verification.title',
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
    'mcpAddNew': 'mcp.add.new',
    'mcpAuthorize': 'mcp.authorize',
    'mcpAuthorizeCap': 'mcp.authorize.cap',
    'mcpAuthorizeDialogTitle': 'mcp.authorize.dialog.title',
    'mcpCapabilitiesRegistry': 'mcp.capabilities.registry',
    'mcpConnectCap': 'mcp.connect.cap',
    'mcpDeny': 'mcp.deny',
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
    'monitorTelemetryUnavailable': 'monitor.telemetry.unavailable',
    'monitorTitle': 'monitor.title',
    'navChats': 'nav.chats',
    'navConfigure': 'nav.configure',
    'navManage': 'nav.manage',
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
    'notificationSettingsEnableDevice': 'notification.settings.enable.device',
    'notificationSettingsPoco': 'notification.settings.poco',
    'notificationSettingsScheduleLabel': 'notification.settings.schedule.label',
    'notificationSettingsScreenTitle': 'notification.settings.screen.title',
    'notificationSettingsTaskCompleteLabel': 'notification.settings.task.complete.label',
    'notificationSettingsTaskErrorLabel': 'notification.settings.task.error.label',
    'notificationSignalReceived': 'notification.signal.received',
    'observabilityLogTerminal': 'observability.log.terminal',
    'observabilityRegistry': 'observability.registry',
    'observabilitySelectContainer': 'observability.select.container',
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
    'onboardingHarnessAccountLogin': 'onboarding.harness.account.login',
    'onboardingHarnessAccountVisibilityBody': 'onboarding.harness.account.visibility.body',
    'onboardingHarnessAccountVisibilityCancel': 'onboarding.harness.account.visibility.cancel',
    'onboardingHarnessAccountVisibilityPersonal': 'onboarding.harness.account.visibility.personal',
    'onboardingHarnessAccountVisibilityShared': 'onboarding.harness.account.visibility.shared',
    'onboardingHarnessAccountVisibilityTitle': 'onboarding.harness.account.visibility.title',
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
    'onboardingPasswordTooShort': 'onboarding.password.too.short',
    'onboardingPlanPoco': 'onboarding.plan.poco',
    'onboardingPlanTitle': 'onboarding.plan.title',
    'onboardingPocketbaseAdminEmail': 'onboarding.pocketbase.admin.email',
    'onboardingPocketbaseAdminPassword': 'onboarding.pocketbase.admin.password',
    'onboardingPocoChallengeMessage': 'onboarding.poco.challenge.message',
    'onboardingPocoWelcome': 'onboarding.poco.welcome',
    'onboardingProcessing': 'onboarding.processing',
    'onboardingProviderAuthorizationAction': 'onboarding.provider.authorization.action',
    'onboardingProviderAuthorizationCancelled': 'onboarding.provider.authorization.cancelled',
    'onboardingProviderAuthorizationError': 'onboarding.provider.authorization.error',
    'onboardingProviderAuthorizationFailed': 'onboarding.provider.authorization.failed',
    'onboardingProviderAuthorizationPoco': 'onboarding.provider.authorization.poco',
    'onboardingProviderAuthorizationTitle': 'onboarding.provider.authorization.title',
    'onboardingProviderAuthorizationWaiting': 'onboarding.provider.authorization.waiting',
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
    'onboardingSelfHostActionConnect': 'onboarding.self.host.action.connect',
    'onboardingSelfHostActionGuide': 'onboarding.self.host.action.guide',
    'onboardingSelfHostPoco': 'onboarding.self.host.poco',
    'onboardingSelfHostRequirementAccess': 'onboarding.self.host.requirement.access',
    'onboardingSelfHostRequirementDocker': 'onboarding.self.host.requirement.docker',
    'onboardingSelfHostRequirementServer': 'onboarding.self.host.requirement.server',
    'onboardingSelfHostRequirementsTitle': 'onboarding.self.host.requirements.title',
    'onboardingSelfHostTitle': 'onboarding.self.host.title',
    'onboardingServerConnecting': 'onboarding.server.connecting',
    'onboardingServerCredentialsPoco': 'onboarding.server.credentials.poco',
    'onboardingServerCredentialsTitle': 'onboarding.server.credentials.title',
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
    'onboardingWelcomeActionGuided': 'onboarding.welcome.action.guided',
    'onboardingWelcomeActionSelfHost': 'onboarding.welcome.action.self.host',
    'onboardingWelcomePoco': 'onboarding.welcome.poco',
    'onboardingWelcomeTitle': 'onboarding.welcome.title',
    'permissionError': 'permission.error',
    'permissionFetchFailed': 'permission.fetch.failed',
    'permissionPatternsLabel': 'permission.patterns.label',
    'permissionRequestedFallback': 'permission.requested.fallback',
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
    'pocketCoderUpdateAvailable': 'pocket.coder.update.available',
    'pocketCoderUpdateAvailableStatus': 'pocket.coder.update.available.status',
    'pocketCoderUpdateCheckAgain': 'pocket.coder.update.check.again',
    'pocketCoderUpdateChecking': 'pocket.coder.update.checking',
    'pocketCoderUpdateCommand': 'pocket.coder.update.command',
    'pocketCoderUpdateConfirmUpgrade': 'pocket.coder.update.confirm.upgrade',
    'pocketCoderUpdateCriticalStatus': 'pocket.coder.update.critical.status',
    'pocketCoderUpdateCurrent': 'pocket.coder.update.current',
    'pocketCoderUpdateCurrentStatus': 'pocket.coder.update.current.status',
    'pocketCoderUpdateDataBoundary': 'pocket.coder.update.data.boundary',
    'pocketCoderUpdateDownload': 'pocket.coder.update.download',
    'pocketCoderUpdateFailed': 'pocket.coder.update.failed',
    'pocketCoderUpdateNoDeployment': 'pocket.coder.update.no.deployment',
    'pocketCoderUpdateOutput': 'pocket.coder.update.output',
    'pocketCoderUpdateRequiredDisk': 'pocket.coder.update.required.disk',
    'pocketCoderUpdateReviewDataChange': 'pocket.coder.update.review.data.change',
    'pocketCoderUpdateRollbackWarning': 'pocket.coder.update.rollback.warning',
    'pocketCoderUpdateStderr': 'pocket.coder.update.stderr',
    'pocketCoderUpdateSucceeded': 'pocket.coder.update.succeeded',
    'pocketCoderUpdateUnknownStatus': 'pocket.coder.update.unknown.status',
    'pocketCoderUpdateUpgrade': 'pocket.coder.update.upgrade',
    'pocketCoderUpdateWorking': 'pocket.coder.update.working',
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
    'pocoProvisioningFailed': 'poco.provisioning.failed',
    'pocoProvisioningLoadingSource': 'poco.provisioning.loading.source',
    'pocoProvisioningNext': 'poco.provisioning.next',
    'pocoProvisioningPrevious': 'poco.provisioning.previous',
    'pocoProvisioningShowConcise': 'poco.provisioning.show.concise',
    'pocoProvisioningShowFull': 'poco.provisioning.show.full',
    'pocoProvisioningSourceUnavailable': 'poco.provisioning.source.unavailable',
    'pocoProvisioningTourTitle': 'poco.provisioning.tour.title',
    'pocoProvisioningWaitingForSource': 'poco.provisioning.waiting.for.source',
    'proActive': 'pro.active',
    'proActiveBody': 'pro.active.body',
    'proBenefitLiveMonitoring': 'pro.benefit.live.monitoring',
    'proBenefitPushNotifications': 'pro.benefit.push.notifications',
    'proBenefitServerSetup': 'pro.benefit.server.setup',
    'proCheckingStatus': 'pro.checking.status',
    'proConfigureSelfHostedPush': 'pro.configure.self.hosted.push',
    'proFeatureConsole': 'pro.feature.console',
    'proFeatureDeploy': 'pro.feature.deploy',
    'proFeaturePush': 'pro.feature.push',
    'proFeatureReady': 'pro.feature.ready',
    'proManageSubscription': 'pro.manage.subscription',
    'proPlanTitle': 'pro.plan.title',
    'proPrice': 'pro.price',
    'proPriceAfterTrial': 'pro.price.after.trial',
    'proPricePerMonth': 'pro.price.per.month',
    'proPricePerWeek': 'pro.price.per.week',
    'proPricePerYear': 'pro.price.per.year',
    'proPrivacyPolicyLink': 'pro.privacy.policy.link',
    'proRestore': 'pro.restore',
    'proSelfHostedPushBody': 'pro.self.hosted.push.body',
    'proSelfHostedPushTitle': 'pro.self.hosted.push.title',
    'proSettingsLabel': 'pro.settings.label',
    'proSettingsStatus': 'pro.settings.status',
    'proStartTrial': 'pro.start.trial',
    'proSubscribe': 'pro.subscribe',
    'proSummary': 'pro.summary',
    'proTerms': 'pro.terms',
    'proTermsOfServiceLink': 'pro.terms.of.service.link',
    'proTitle': 'pro.title',
    'proTrialDuration': 'pro.trial.duration',
    'proTrialLapseExplainer': 'pro.trial.lapse.explainer',
    'proTrialNoPaymentInfo': 'pro.trial.no.payment.info',
    'proTrialTerms': 'pro.trial.terms',
    'proUnavailable': 'pro.unavailable',
    'proUnavailableBody': 'pro.unavailable.body',
    'proUnlockCommand': 'pro.unlock.command',
    'providerReauthenticationRequired': 'provider.reauthentication.required',
    'providerScreenAddKey': 'provider.screen.add.key',
    'providerScreenAddKeyBody': 'provider.screen.add.key.body',
    'providerScreenAddKeyTitle': 'provider.screen.add.key.title',
    'providerScreenApiKeysSection': 'provider.screen.api.keys.section',
    'providerScreenBrowseAllModels': 'provider.screen.browse.all.models',
    'providerScreenDefaultBadge': 'provider.screen.default.badge',
    'providerScreenEmptyHint': 'provider.screen.empty.hint',
    'providerScreenErrorPrefix': 'provider.screen.error.prefix',
    'providerScreenHarnessModelCount': 'provider.screen.harness.model.count',
    'providerScreenHarnessModelsSection': 'provider.screen.harness.models.section',
    'providerScreenLoading': 'provider.screen.loading',
    'providerScreenNoApiKeys': 'provider.screen.no.api.keys',
    'providerScreenNoHarnessModels': 'provider.screen.no.harness.models',
    'providerScreenNoProviders': 'provider.screen.no.providers',
    'providerScreenSearchHint': 'provider.screen.search.hint',
    'providerScreenSearchLabel': 'provider.screen.search.label',
    'providerScreenSearchNoMatches': 'provider.screen.search.no.matches',
    'providerScreenSelectProvider': 'provider.screen.select.provider',
    'providerScreenTitle': 'provider.screen.title',
    'providerScreenUpdateKey': 'provider.screen.update.key',
    'questionIncomingTitle': 'question.incoming.title',
    'questionPocoAsking': 'question.poco.asking',
    'questionSendReply': 'question.send.reply',
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
    'serverControlActionRestart': 'server.control.action.restart',
    'serverControlActionRestore': 'server.control.action.restore',
    'serverControlActionSave': 'server.control.action.save',
    'serverControlActionUpdate': 'server.control.action.update',
    'serverControlAdminIdentity': 'server.control.admin.identity',
    'serverControlAdminPassword': 'server.control.admin.password',
    'serverControlConfirmBody': 'server.control.confirm.body',
    'serverControlConfirmCancel': 'server.control.confirm.cancel',
    'serverControlConfirmConfirm': 'server.control.confirm.confirm',
    'serverControlConfirmRestoreBody': 'server.control.confirm.restore.body',
    'serverControlConfirmRestoreTitle': 'server.control.confirm.restore.title',
    'serverControlConfirmTitle': 'server.control.confirm.title',
    'serverControlConnectionDetails': 'server.control.connection.details',
    'serverControlCopied': 'server.control.copied',
    'serverControlCopy': 'server.control.copy',
    'serverControlGroupData': 'server.control.group.data',
    'serverControlGroupNixOs': 'server.control.group.nix.os',
    'serverControlGroupPocketCoder': 'server.control.group.pocket.coder',
    'serverControlHide': 'server.control.hide',
    'serverControlHttpsEndpoint': 'server.control.https.endpoint',
    'serverControlIpAddress': 'server.control.ip.address',
    'serverControlLocalAuthReason': 'server.control.local.auth.reason',
    'serverControlOperationRestartNixOs': 'server.control.operation.restart.nix.os',
    'serverControlOperationRestartPocketCoder': 'server.control.operation.restart.pocket.coder',
    'serverControlOperationRestoreBackup': 'server.control.operation.restore.backup',
    'serverControlOperationSaveBackup': 'server.control.operation.save.backup',
    'serverControlOperationUpdateNixOs': 'server.control.operation.update.nix.os',
    'serverControlOperationUpdatePocketCoder': 'server.control.operation.update.pocket.coder',
    'serverControlPrivateKeyLabel': 'server.control.private.key.label',
    'serverControlProviderConsole': 'server.control.provider.console',
    'serverControlProviderConsoleUnavailable': 'server.control.provider.console.unavailable',
    'serverControlPublicKeyLabel': 'server.control.public.key.label',
    'serverControlReleaseAvailable': 'server.control.release.available',
    'serverControlReleaseChecking': 'server.control.release.checking',
    'serverControlReleaseContracts': 'server.control.release.contracts',
    'serverControlReleaseCurrent': 'server.control.release.current',
    'serverControlReleaseNixos': 'server.control.release.nixos',
    'serverControlReleaseStatus': 'server.control.release.status',
    'serverControlShow': 'server.control.show',
    'serverControlTitle': 'server.control.title',
    'settingsAccountSection': 'settings.account.section',
    'settingsAiAgentsSection': 'settings.ai.agents.section',
    'settingsDeleteProDataCancel': 'settings.delete.pro.data.cancel',
    'settingsDeleteProDataConfirm': 'settings.delete.pro.data.confirm',
    'settingsDeleteProDataConfirmBody': 'settings.delete.pro.data.confirm.body',
    'settingsDeleteProDataConfirmTitle': 'settings.delete.pro.data.confirm.title',
    'settingsDeleteProDataLabel': 'settings.delete.pro.data.label',
    'settingsFactoryResetCancel': 'settings.factory.reset.cancel',
    'settingsFactoryResetConfirm': 'settings.factory.reset.confirm',
    'settingsFactoryResetConfirmBody': 'settings.factory.reset.confirm.body',
    'settingsFactoryResetConfirmTitle': 'settings.factory.reset.confirm.title',
    'settingsLogoutCancel': 'settings.logout.cancel',
    'settingsLogoutConfirm': 'settings.logout.confirm',
    'settingsLogoutConfirmBody': 'settings.logout.confirm.body',
    'settingsLogoutConfirmTitle': 'settings.logout.confirm.title',
    'settingsReportAiContentLabel': 'settings.report.ai.content.label',
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
    'walkthroughActionSkip': 'walkthrough.action.skip',
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
    'action.dismiss': 'actionDismiss',
    'action.refresh': 'actionRefresh',
    'action.reject': 'actionReject',
    'action.restore': 'actionRestore',
    'action.save': 'actionSave',
    'action.skip': 'actionSkip',
    'agent.config.default.badge': 'agentConfigDefaultBadge',
    'agent.config.delete': 'agentConfigDelete',
    'agent.config.delete.confirm.body': 'agentConfigDeleteConfirmBody',
    'agent.config.delete.confirm.title': 'agentConfigDeleteConfirmTitle',
    'agent.config.dialog.title': 'agentConfigDialogTitle',
    'agent.config.empty': 'agentConfigEmpty',
    'agent.config.error.prefix': 'agentConfigErrorPrefix',
    'agent.config.is.default.label': 'agentConfigIsDefaultLabel',
    'agent.config.label': 'agentConfigLabel',
    'agent.config.mode.label': 'agentConfigModeLabel',
    'agent.config.name.label': 'agentConfigNameLabel',
    'agent.config.no.modes': 'agentConfigNoModes',
    'agent.config.no.prompts': 'agentConfigNoPrompts',
    'agent.config.prompt.label': 'agentConfigPromptLabel',
    'agent.config.registry': 'agentConfigRegistry',
    'agent.config.select.mode': 'agentConfigSelectMode',
    'agent.config.select.prompt': 'agentConfigSelectPrompt',
    'agent.config.title': 'agentConfigTitle',
    'agent.default.tuned': 'agentDefaultTuned',
    'agent.description.label': 'agentDescriptionLabel',
    'agent.dialog.title': 'agentDialogTitle',
    'agent.mode.label': 'agentModeLabel',
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
    'billing.error': 'billingError',
    'billing.restore.failed': 'billingRestoreFailed',
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
    'chat.monitor.action': 'chatMonitorAction',
    'chat.new.capability.request': 'chatNewCapabilityRequest',
    'chat.no.fields.requested': 'chatNoFieldsRequested',
    'chat.not.found': 'chatNotFound',
    'chat.poco.role': 'chatPocoRole',
    'chat.run.outcome.cancelled.body': 'chatRunOutcomeCancelledBody',
    'chat.run.outcome.cancelled.title': 'chatRunOutcomeCancelledTitle',
    'chat.run.outcome.failed.body': 'chatRunOutcomeFailedBody',
    'chat.run.outcome.failed.title': 'chatRunOutcomeFailedTitle',
    'chat.run.outcome.interrupted.body': 'chatRunOutcomeInterruptedBody',
    'chat.run.outcome.interrupted.title': 'chatRunOutcomeInterruptedTitle',
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
    'chat.tool.call.fallback': 'chatToolCallFallback',
    'chat.use.global.default': 'chatUseGlobalDefault',
    'choose.provider.coming.soon': 'chooseProviderComingSoon',
    'choose.provider.pro.badge': 'chooseProviderProBadge',
    'choose.provider.title': 'chooseProviderTitle',
    'credential.connection.api.key': 'credentialConnectionApiKey',
    'credential.connection.cancel': 'credentialConnectionCancel',
    'credential.connection.copy': 'credentialConnectionCopy',
    'credential.connection.enter.code': 'credentialConnectionEnterCode',
    'credential.connection.expires.at': 'credentialConnectionExpiresAt',
    'credential.connection.open.authorization.page': 'credentialConnectionOpenAuthorizationPage',
    'credential.connection.open.failed': 'credentialConnectionOpenFailed',
    'credential.connection.paste.code': 'credentialConnectionPasteCode',
    'credential.connection.retry': 'credentialConnectionRetry',
    'credential.connection.submit': 'credentialConnectionSubmit',
    'deploy.choose.provider': 'deployChooseProvider',
    'deploy.select.provider': 'deploySelectProvider',
    'deployment.action.back': 'deploymentActionBack',
    'deployment.action.deploy.instance': 'deploymentActionDeployInstance',
    'deployment.action.dismiss': 'deploymentActionDismiss',
    'deployment.action.initialize': 'deploymentActionInitialize',
    'deployment.action.refresh': 'deploymentActionRefresh',
    'deployment.action.update': 'deploymentActionUpdate',
    'deployment.backend': 'deploymentBackend',
    'deployment.cleanup.failed': 'deploymentCleanupFailed',
    'deployment.cleanup.not.needed': 'deploymentCleanupNotNeeded',
    'deployment.cleanup.pending': 'deploymentCleanupPending',
    'deployment.cleanup.succeeded': 'deploymentCleanupSucceeded',
    'deployment.coding.agents.title': 'deploymentCodingAgentsTitle',
    'deployment.coding.harnesses': 'deploymentCodingHarnesses',
    'deployment.debian': 'deploymentDebian',
    'deployment.debian.description': 'deploymentDebianDescription',
    'deployment.default.agent': 'deploymentDefaultAgent',
    'deployment.description.configuring.operating.system': 'deploymentDescriptionConfiguringOperatingSystem',
    'deployment.description.constructing': 'deploymentDescriptionConstructing',
    'deployment.description.failed': 'deploymentDescriptionFailed',
    'deployment.description.fetching': 'deploymentDescriptionFetching',
    'deployment.description.finishing': 'deploymentDescriptionFinishing',
    'deployment.description.loading.images': 'deploymentDescriptionLoadingImages',
    'deployment.description.preparing.operating.system': 'deploymentDescriptionPreparingOperatingSystem',
    'deployment.description.ready': 'deploymentDescriptionReady',
    'deployment.description.securing': 'deploymentDescriptionSecuring',
    'deployment.description.starting': 'deploymentDescriptionStarting',
    'deployment.description.tls.failed': 'deploymentDescriptionTlsFailed',
    'deployment.description.tls.rate.limited': 'deploymentDescriptionTlsRateLimited',
    'deployment.description.tls.ready': 'deploymentDescriptionTlsReady',
    'deployment.description.tls.zero.ssl': 'deploymentDescriptionTlsZeroSsl',
    'deployment.description.validating': 'deploymentDescriptionValidating',
    'deployment.discard.attempt.body': 'deploymentDiscardAttemptBody',
    'deployment.discard.attempt.cancel': 'deploymentDiscardAttemptCancel',
    'deployment.discard.attempt.check.link': 'deploymentDiscardAttemptCheckLink',
    'deployment.discard.attempt.confirm': 'deploymentDiscardAttemptConfirm',
    'deployment.discard.attempt.confirm.checkbox': 'deploymentDiscardAttemptConfirmCheckbox',
    'deployment.discard.attempt.resource.id': 'deploymentDiscardAttemptResourceId',
    'deployment.discard.attempt.title': 'deploymentDiscardAttemptTitle',
    'deployment.disconnect.action': 'deploymentDisconnectAction',
    'deployment.disconnect.cancel': 'deploymentDisconnectCancel',
    'deployment.disconnect.confirm': 'deploymentDisconnectConfirm',
    'deployment.disconnect.confirmation.body': 'deploymentDisconnectConfirmationBody',
    'deployment.disconnect.confirmation.title': 'deploymentDisconnectConfirmationTitle',
    'deployment.distribution': 'deploymentDistribution',
    'deployment.fault.deployment.instance.not.found': 'deploymentFaultDeploymentInstanceNotFound',
    'deployment.gpu.badge': 'deploymentGpuBadge',
    'deployment.hardware.geography': 'deploymentHardwareGeography',
    'deployment.harness.poco': 'deploymentHarnessPoco',
    'deployment.harness.selection.description': 'deploymentHarnessSelectionDescription',
    'deployment.initializing.hardware': 'deploymentInitializingHardware',
    'deployment.instance.plan': 'deploymentInstancePlan',
    'deployment.linux.poco': 'deploymentLinuxPoco',
    'deployment.linux.system.title': 'deploymentLinuxSystemTitle',
    'deployment.manifest.configuration': 'deploymentManifestConfiguration',
    'deployment.memory.gb': 'deploymentMemoryGb',
    'deployment.memory.mb': 'deploymentMemoryMb',
    'deployment.minimum': 'deploymentMinimum',
    'deployment.monthly.price': 'deploymentMonthlyPrice',
    'deployment.nixos': 'deploymentNixos',
    'deployment.nixos.description': 'deploymentNixosDescription',
    'deployment.no.suitable.plans': 'deploymentNoSuitablePlans',
    'deployment.operating.system': 'deploymentOperatingSystem',
    'deployment.plan.poco': 'deploymentPlanPoco',
    'deployment.plan.specs': 'deploymentPlanSpecs',
    'deployment.provider.linode': 'deploymentProviderLinode',
    'deployment.provisioned': 'deploymentProvisioned',
    'deployment.provisioning.summary': 'deploymentProvisioningSummary',
    'deployment.recommended': 'deploymentRecommended',
    'deployment.region': 'deploymentRegion',
    'deployment.region.poco': 'deploymentRegionPoco',
    'deployment.reset.action': 'deploymentResetAction',
    'deployment.reset.also.clear.o.auth': 'deploymentResetAlsoClearOAuth',
    'deployment.reset.cancel': 'deploymentResetCancel',
    'deployment.reset.complete': 'deploymentResetComplete',
    'deployment.reset.confirm': 'deploymentResetConfirm',
    'deployment.reset.confirmation.body': 'deploymentResetConfirmationBody',
    'deployment.reset.confirmation.title': 'deploymentResetConfirmationTitle',
    'deployment.reset.confirmation.warn.cloud': 'deploymentResetConfirmationWarnCloud',
    'deployment.review.poco': 'deploymentReviewPoco',
    'deployment.review.title': 'deploymentReviewTitle',
    'deployment.run.local.model': 'deploymentRunLocalModel',
    'deployment.scanning.regions': 'deploymentScanningRegions',
    'deployment.server.provider': 'deploymentServerProvider',
    'deployment.server.region.title': 'deploymentServerRegionTitle',
    'deployment.server.size.title': 'deploymentServerSizeTitle',
    'deployment.setup.type.title': 'deploymentSetupTypeTitle',
    'deployment.standard.linux': 'deploymentStandardLinux',
    'deployment.status.configuring.operating.system': 'deploymentStatusConfiguringOperatingSystem',
    'deployment.status.constructing': 'deploymentStatusConstructing',
    'deployment.status.failed': 'deploymentStatusFailed',
    'deployment.status.fetching': 'deploymentStatusFetching',
    'deployment.status.finishing': 'deploymentStatusFinishing',
    'deployment.status.loading.images': 'deploymentStatusLoadingImages',
    'deployment.status.preparing.operating.system': 'deploymentStatusPreparingOperatingSystem',
    'deployment.status.ready': 'deploymentStatusReady',
    'deployment.status.securing': 'deploymentStatusSecuring',
    'deployment.status.starting': 'deploymentStatusStarting',
    'deployment.status.tls.failed': 'deploymentStatusTlsFailed',
    'deployment.status.tls.rate.limited': 'deploymentStatusTlsRateLimited',
    'deployment.status.tls.ready': 'deploymentStatusTlsReady',
    'deployment.status.tls.zero.ssl': 'deploymentStatusTlsZeroSsl',
    'deployment.status.validating': 'deploymentStatusValidating',
    'deployment.step.boot.final': 'deploymentStepBootFinal',
    'deployment.step.boot.installer': 'deploymentStepBootInstaller',
    'deployment.step.bootstrap.complete': 'deploymentStepBootstrapComplete',
    'deployment.step.compose.up': 'deploymentStepComposeUp',
    'deployment.step.configuring.operating.system': 'deploymentStepConfiguringOperatingSystem',
    'deployment.step.create.final.config': 'deploymentStepCreateFinalConfig',
    'deployment.step.create.installer.config': 'deploymentStepCreateInstallerConfig',
    'deployment.step.create.installer.disk': 'deploymentStepCreateInstallerDisk',
    'deployment.step.create.instance': 'deploymentStepCreateInstance',
    'deployment.step.create.target.disk': 'deploymentStepCreateTargetDisk',
    'deployment.step.enable.watchdog': 'deploymentStepEnableWatchdog',
    'deployment.step.fetching.release': 'deploymentStepFetchingRelease',
    'deployment.step.final.instance.fetch': 'deploymentStepFinalInstanceFetch',
    'deployment.step.loading.images': 'deploymentStepLoadingImages',
    'deployment.step.plan.lookup': 'deploymentStepPlanLookup',
    'deployment.step.pre.boot.shutdown': 'deploymentStepPreBootShutdown',
    'deployment.step.ready': 'deploymentStepReady',
    'deployment.step.remove.installer.resources': 'deploymentStepRemoveInstallerResources',
    'deployment.step.wait.installer.completion': 'deploymentStepWaitInstallerCompletion',
    'deployment.step.wait.installer.disk.ready': 'deploymentStepWaitInstallerDiskReady',
    'deployment.step.wait.target.disk.ready': 'deploymentStepWaitTargetDiskReady',
    'deployment.step.waiting.for.connection': 'deploymentStepWaitingForConnection',
    'deployment.system.parameters': 'deploymentSystemParameters',
    'deployment.ubuntu': 'deploymentUbuntu',
    'deployment.use.cloud.models': 'deploymentUseCloudModels',
    'deployment.workload.cloud.reply': 'deploymentWorkloadCloudReply',
    'deployment.workload.local.reply': 'deploymentWorkloadLocalReply',
    'deployment.workload.poco': 'deploymentWorkloadPoco',
    'error.auth.failed': 'errorAuthFailed',
    'error.auth.unauthorized': 'errorAuthUnauthorized',
    'error.could.not.open.browser': 'errorCouldNotOpenBrowser',
    'error.generic': 'errorGeneric',
    'error.network': 'errorNetwork',
    'error.timeout': 'errorTimeout',
    'errors.clear.all': 'errorsClearAll',
    'errors.copied': 'errorsCopied',
    'errors.copy': 'errorsCopy',
    'errors.copy.all': 'errorsCopyAll',
    'errors.empty': 'errorsEmpty',
    'errors.occurred': 'errorsOccurred',
    'errors.report.on.github': 'errorsReportOnGithub',
    'errors.title': 'errorsTitle',
    'external.auth.cancel': 'externalAuthCancel',
    'external.auth.connecting': 'externalAuthConnecting',
    'external.auth.retry': 'externalAuthRetry',
    'external.auth.title': 'externalAuthTitle',
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
    'foss.server.setup.connected': 'fossServerSetupConnected',
    'foss.server.setup.generate.key': 'fossServerSetupGenerateKey',
    'foss.server.setup.host.label': 'fossServerSetupHostLabel',
    'foss.server.setup.intro': 'fossServerSetupIntro',
    'foss.server.setup.public.key.label': 'fossServerSetupPublicKeyLabel',
    'foss.server.setup.test.and.save': 'fossServerSetupTestAndSave',
    'foss.server.setup.title': 'fossServerSetupTitle',
    'harness.auth.account': 'harnessAuthAccount',
    'harness.auth.account.login': 'harnessAuthAccountLogin',
    'harness.auth.api.key': 'harnessAuthApiKey',
    'harness.auth.attempt': 'harnessAuthAttempt',
    'harness.auth.cancel': 'harnessAuthCancel',
    'harness.auth.challenge': 'harnessAuthChallenge',
    'harness.auth.challenge.details.copied': 'harnessAuthChallengeDetailsCopied',
    'harness.auth.challenge.target.copied': 'harnessAuthChallengeTargetCopied',
    'harness.auth.choose.provider.key': 'harnessAuthChooseProviderKey',
    'harness.auth.connections': 'harnessAuthConnections',
    'harness.auth.copy': 'harnessAuthCopy',
    'harness.auth.details': 'harnessAuthDetails',
    'harness.auth.disconnect': 'harnessAuthDisconnect',
    'harness.auth.empty': 'harnessAuthEmpty',
    'harness.auth.loading': 'harnessAuthLoading',
    'harness.auth.mode': 'harnessAuthMode',
    'harness.auth.no.api.key.body': 'harnessAuthNoApiKeyBody',
    'harness.auth.no.api.key.title': 'harnessAuthNoApiKeyTitle',
    'harness.auth.none': 'harnessAuthNone',
    'harness.auth.one.time.code': 'harnessAuthOneTimeCode',
    'harness.auth.paste.code': 'harnessAuthPasteCode',
    'harness.auth.personal': 'harnessAuthPersonal',
    'harness.auth.poll': 'harnessAuthPoll',
    'harness.auth.provider.key.missing': 'harnessAuthProviderKeyMissing',
    'harness.auth.refresh': 'harnessAuthRefresh',
    'harness.auth.shared': 'harnessAuthShared',
    'harness.auth.status': 'harnessAuthStatus',
    'harness.auth.submit': 'harnessAuthSubmit',
    'harness.auth.unavailable': 'harnessAuthUnavailable',
    'harness.auth.visibility.body': 'harnessAuthVisibilityBody',
    'harness.auth.visibility.title': 'harnessAuthVisibilityTitle',
    'home.error.prefix': 'homeErrorPrefix',
    'home.loading.chats': 'homeLoadingChats',
    'home.new.chat': 'homeNewChat',
    'home.no.chats': 'homeNoChats',
    'home.title': 'homeTitle',
    'initialization.action.abort': 'initializationActionAbort',
    'initialization.action.login': 'initializationActionLogin',
    'initialization.action.retry': 'initializationActionRetry',
    'initialization.admin.identity': 'initializationAdminIdentity',
    'initialization.admin.password': 'initializationAdminPassword',
    'initialization.cloud.region': 'initializationCloudRegion',
    'initialization.connection.parameters': 'initializationConnectionParameters',
    'initialization.copied.to.buffer': 'initializationCopiedToBuffer',
    'initialization.copy.label': 'initializationCopyLabel',
    'initialization.current.operation': 'initializationCurrentOperation',
    'initialization.description.initializing': 'initializationDescriptionInitializing',
    'initialization.error.code': 'initializationErrorCode',
    'initialization.failed': 'initializationFailed',
    'initialization.fault.authentication.expired': 'initializationFaultAuthenticationExpired',
    'initialization.fault.detected': 'initializationFaultDetected',
    'initialization.fault.generic': 'initializationFaultGeneric',
    'initialization.fault.max.retries.exceeded': 'initializationFaultMaxRetriesExceeded',
    'initialization.fault.provision.interrupted.no.resource': 'initializationFaultProvisionInterruptedNoResource',
    'initialization.fault.provision.resource.not.found': 'initializationFaultProvisionResourceNotFound',
    'initialization.fault.provision.resource.still.exists': 'initializationFaultProvisionResourceStillExists',
    'initialization.fault.resource.already.exists': 'initializationFaultResourceAlreadyExists',
    'initialization.geo.grid': 'initializationGeoGrid',
    'initialization.hardware.plan': 'initializationHardwarePlan',
    'initialization.https.endpoint': 'initializationHttpsEndpoint',
    'initialization.in.progress': 'initializationInProgress',
    'initialization.instance.id': 'initializationInstanceId',
    'initialization.instance.manifest': 'initializationInstanceManifest',
    'initialization.ip.address': 'initializationIpAddress',
    'initialization.last.signal': 'initializationLastSignal',
    'initialization.metadata.registry': 'initializationMetadataRegistry',
    'initialization.network.ip': 'initializationNetworkIp',
    'initialization.ready': 'initializationReady',
    'initialization.retry.attempt': 'initializationRetryAttempt',
    'initialization.run.id': 'initializationRunId',
    'initialization.screen.title': 'initializationScreenTitle',
    'initialization.secure': 'initializationSecure',
    'initialization.security.notice': 'initializationSecurityNotice',
    'initialization.source.commit': 'initializationSourceCommit',
    'initialization.status.initializing': 'initializationStatusInitializing',
    'initialization.status.prefix': 'initializationStatusPrefix',
    'initialization.status.schema': 'initializationStatusSchema',
    'initialization.sync.attempt': 'initializationSyncAttempt',
    'initialization.technical.details.toggle': 'initializationTechnicalDetailsToggle',
    'initialization.unknown': 'initializationUnknown',
    'instance.verification.back.action': 'instanceVerificationBackAction',
    'instance.verification.body': 'instanceVerificationBody',
    'instance.verification.check.action': 'instanceVerificationCheckAction',
    'instance.verification.check.failed.message': 'instanceVerificationCheckFailedMessage',
    'instance.verification.reset.action': 'instanceVerificationResetAction',
    'instance.verification.reset.cancel': 'instanceVerificationResetCancel',
    'instance.verification.reset.confirm': 'instanceVerificationResetConfirm',
    'instance.verification.reset.confirmation.body': 'instanceVerificationResetConfirmationBody',
    'instance.verification.reset.confirmation.title': 'instanceVerificationResetConfirmationTitle',
    'instance.verification.title': 'instanceVerificationTitle',
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
    'mcp.add.new': 'mcpAddNew',
    'mcp.authorize': 'mcpAuthorize',
    'mcp.authorize.cap': 'mcpAuthorizeCap',
    'mcp.authorize.dialog.title': 'mcpAuthorizeDialogTitle',
    'mcp.capabilities.registry': 'mcpCapabilitiesRegistry',
    'mcp.connect.cap': 'mcpConnectCap',
    'mcp.deny': 'mcpDeny',
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
    'monitor.telemetry.unavailable': 'monitorTelemetryUnavailable',
    'monitor.title': 'monitorTitle',
    'nav.chats': 'navChats',
    'nav.configure': 'navConfigure',
    'nav.manage': 'navManage',
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
    'notification.settings.enable.device': 'notificationSettingsEnableDevice',
    'notification.settings.poco': 'notificationSettingsPoco',
    'notification.settings.schedule.label': 'notificationSettingsScheduleLabel',
    'notification.settings.screen.title': 'notificationSettingsScreenTitle',
    'notification.settings.task.complete.label': 'notificationSettingsTaskCompleteLabel',
    'notification.settings.task.error.label': 'notificationSettingsTaskErrorLabel',
    'notification.signal.received': 'notificationSignalReceived',
    'observability.log.terminal': 'observabilityLogTerminal',
    'observability.registry': 'observabilityRegistry',
    'observability.select.container': 'observabilitySelectContainer',
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
    'onboarding.harness.account.login': 'onboardingHarnessAccountLogin',
    'onboarding.harness.account.visibility.body': 'onboardingHarnessAccountVisibilityBody',
    'onboarding.harness.account.visibility.cancel': 'onboardingHarnessAccountVisibilityCancel',
    'onboarding.harness.account.visibility.personal': 'onboardingHarnessAccountVisibilityPersonal',
    'onboarding.harness.account.visibility.shared': 'onboardingHarnessAccountVisibilityShared',
    'onboarding.harness.account.visibility.title': 'onboardingHarnessAccountVisibilityTitle',
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
    'onboarding.password.too.short': 'onboardingPasswordTooShort',
    'onboarding.plan.poco': 'onboardingPlanPoco',
    'onboarding.plan.title': 'onboardingPlanTitle',
    'onboarding.pocketbase.admin.email': 'onboardingPocketbaseAdminEmail',
    'onboarding.pocketbase.admin.password': 'onboardingPocketbaseAdminPassword',
    'onboarding.poco.challenge.message': 'onboardingPocoChallengeMessage',
    'onboarding.poco.welcome': 'onboardingPocoWelcome',
    'onboarding.processing': 'onboardingProcessing',
    'onboarding.provider.authorization.action': 'onboardingProviderAuthorizationAction',
    'onboarding.provider.authorization.cancelled': 'onboardingProviderAuthorizationCancelled',
    'onboarding.provider.authorization.error': 'onboardingProviderAuthorizationError',
    'onboarding.provider.authorization.failed': 'onboardingProviderAuthorizationFailed',
    'onboarding.provider.authorization.poco': 'onboardingProviderAuthorizationPoco',
    'onboarding.provider.authorization.title': 'onboardingProviderAuthorizationTitle',
    'onboarding.provider.authorization.waiting': 'onboardingProviderAuthorizationWaiting',
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
    'onboarding.self.host.action.connect': 'onboardingSelfHostActionConnect',
    'onboarding.self.host.action.guide': 'onboardingSelfHostActionGuide',
    'onboarding.self.host.poco': 'onboardingSelfHostPoco',
    'onboarding.self.host.requirement.access': 'onboardingSelfHostRequirementAccess',
    'onboarding.self.host.requirement.docker': 'onboardingSelfHostRequirementDocker',
    'onboarding.self.host.requirement.server': 'onboardingSelfHostRequirementServer',
    'onboarding.self.host.requirements.title': 'onboardingSelfHostRequirementsTitle',
    'onboarding.self.host.title': 'onboardingSelfHostTitle',
    'onboarding.server.connecting': 'onboardingServerConnecting',
    'onboarding.server.credentials.poco': 'onboardingServerCredentialsPoco',
    'onboarding.server.credentials.title': 'onboardingServerCredentialsTitle',
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
    'onboarding.welcome.action.guided': 'onboardingWelcomeActionGuided',
    'onboarding.welcome.action.self.host': 'onboardingWelcomeActionSelfHost',
    'onboarding.welcome.poco': 'onboardingWelcomePoco',
    'onboarding.welcome.title': 'onboardingWelcomeTitle',
    'permission.error': 'permissionError',
    'permission.fetch.failed': 'permissionFetchFailed',
    'permission.patterns.label': 'permissionPatternsLabel',
    'permission.requested.fallback': 'permissionRequestedFallback',
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
    'pocket.coder.update.available': 'pocketCoderUpdateAvailable',
    'pocket.coder.update.available.status': 'pocketCoderUpdateAvailableStatus',
    'pocket.coder.update.check.again': 'pocketCoderUpdateCheckAgain',
    'pocket.coder.update.checking': 'pocketCoderUpdateChecking',
    'pocket.coder.update.command': 'pocketCoderUpdateCommand',
    'pocket.coder.update.confirm.upgrade': 'pocketCoderUpdateConfirmUpgrade',
    'pocket.coder.update.critical.status': 'pocketCoderUpdateCriticalStatus',
    'pocket.coder.update.current': 'pocketCoderUpdateCurrent',
    'pocket.coder.update.current.status': 'pocketCoderUpdateCurrentStatus',
    'pocket.coder.update.data.boundary': 'pocketCoderUpdateDataBoundary',
    'pocket.coder.update.download': 'pocketCoderUpdateDownload',
    'pocket.coder.update.failed': 'pocketCoderUpdateFailed',
    'pocket.coder.update.no.deployment': 'pocketCoderUpdateNoDeployment',
    'pocket.coder.update.output': 'pocketCoderUpdateOutput',
    'pocket.coder.update.required.disk': 'pocketCoderUpdateRequiredDisk',
    'pocket.coder.update.review.data.change': 'pocketCoderUpdateReviewDataChange',
    'pocket.coder.update.rollback.warning': 'pocketCoderUpdateRollbackWarning',
    'pocket.coder.update.stderr': 'pocketCoderUpdateStderr',
    'pocket.coder.update.succeeded': 'pocketCoderUpdateSucceeded',
    'pocket.coder.update.unknown.status': 'pocketCoderUpdateUnknownStatus',
    'pocket.coder.update.upgrade': 'pocketCoderUpdateUpgrade',
    'pocket.coder.update.working': 'pocketCoderUpdateWorking',
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
    'poco.provisioning.failed': 'pocoProvisioningFailed',
    'poco.provisioning.loading.source': 'pocoProvisioningLoadingSource',
    'poco.provisioning.next': 'pocoProvisioningNext',
    'poco.provisioning.previous': 'pocoProvisioningPrevious',
    'poco.provisioning.show.concise': 'pocoProvisioningShowConcise',
    'poco.provisioning.show.full': 'pocoProvisioningShowFull',
    'poco.provisioning.source.unavailable': 'pocoProvisioningSourceUnavailable',
    'poco.provisioning.tour.title': 'pocoProvisioningTourTitle',
    'poco.provisioning.waiting.for.source': 'pocoProvisioningWaitingForSource',
    'pro.active': 'proActive',
    'pro.active.body': 'proActiveBody',
    'pro.benefit.live.monitoring': 'proBenefitLiveMonitoring',
    'pro.benefit.push.notifications': 'proBenefitPushNotifications',
    'pro.benefit.server.setup': 'proBenefitServerSetup',
    'pro.checking.status': 'proCheckingStatus',
    'pro.configure.self.hosted.push': 'proConfigureSelfHostedPush',
    'pro.feature.console': 'proFeatureConsole',
    'pro.feature.deploy': 'proFeatureDeploy',
    'pro.feature.push': 'proFeaturePush',
    'pro.feature.ready': 'proFeatureReady',
    'pro.manage.subscription': 'proManageSubscription',
    'pro.plan.title': 'proPlanTitle',
    'pro.price': 'proPrice',
    'pro.price.after.trial': 'proPriceAfterTrial',
    'pro.price.per.month': 'proPricePerMonth',
    'pro.price.per.week': 'proPricePerWeek',
    'pro.price.per.year': 'proPricePerYear',
    'pro.privacy.policy.link': 'proPrivacyPolicyLink',
    'pro.restore': 'proRestore',
    'pro.self.hosted.push.body': 'proSelfHostedPushBody',
    'pro.self.hosted.push.title': 'proSelfHostedPushTitle',
    'pro.settings.label': 'proSettingsLabel',
    'pro.settings.status': 'proSettingsStatus',
    'pro.start.trial': 'proStartTrial',
    'pro.subscribe': 'proSubscribe',
    'pro.summary': 'proSummary',
    'pro.terms': 'proTerms',
    'pro.terms.of.service.link': 'proTermsOfServiceLink',
    'pro.title': 'proTitle',
    'pro.trial.duration': 'proTrialDuration',
    'pro.trial.lapse.explainer': 'proTrialLapseExplainer',
    'pro.trial.no.payment.info': 'proTrialNoPaymentInfo',
    'pro.trial.terms': 'proTrialTerms',
    'pro.unavailable': 'proUnavailable',
    'pro.unavailable.body': 'proUnavailableBody',
    'pro.unlock.command': 'proUnlockCommand',
    'provider.reauthentication.required': 'providerReauthenticationRequired',
    'provider.screen.add.key': 'providerScreenAddKey',
    'provider.screen.add.key.body': 'providerScreenAddKeyBody',
    'provider.screen.add.key.title': 'providerScreenAddKeyTitle',
    'provider.screen.api.keys.section': 'providerScreenApiKeysSection',
    'provider.screen.browse.all.models': 'providerScreenBrowseAllModels',
    'provider.screen.default.badge': 'providerScreenDefaultBadge',
    'provider.screen.empty.hint': 'providerScreenEmptyHint',
    'provider.screen.error.prefix': 'providerScreenErrorPrefix',
    'provider.screen.harness.model.count': 'providerScreenHarnessModelCount',
    'provider.screen.harness.models.section': 'providerScreenHarnessModelsSection',
    'provider.screen.loading': 'providerScreenLoading',
    'provider.screen.no.api.keys': 'providerScreenNoApiKeys',
    'provider.screen.no.harness.models': 'providerScreenNoHarnessModels',
    'provider.screen.no.providers': 'providerScreenNoProviders',
    'provider.screen.search.hint': 'providerScreenSearchHint',
    'provider.screen.search.label': 'providerScreenSearchLabel',
    'provider.screen.search.no.matches': 'providerScreenSearchNoMatches',
    'provider.screen.select.provider': 'providerScreenSelectProvider',
    'provider.screen.title': 'providerScreenTitle',
    'provider.screen.update.key': 'providerScreenUpdateKey',
    'question.incoming.title': 'questionIncomingTitle',
    'question.poco.asking': 'questionPocoAsking',
    'question.send.reply': 'questionSendReply',
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
    'server.control.action.restart': 'serverControlActionRestart',
    'server.control.action.restore': 'serverControlActionRestore',
    'server.control.action.save': 'serverControlActionSave',
    'server.control.action.update': 'serverControlActionUpdate',
    'server.control.admin.identity': 'serverControlAdminIdentity',
    'server.control.admin.password': 'serverControlAdminPassword',
    'server.control.confirm.body': 'serverControlConfirmBody',
    'server.control.confirm.cancel': 'serverControlConfirmCancel',
    'server.control.confirm.confirm': 'serverControlConfirmConfirm',
    'server.control.confirm.restore.body': 'serverControlConfirmRestoreBody',
    'server.control.confirm.restore.title': 'serverControlConfirmRestoreTitle',
    'server.control.confirm.title': 'serverControlConfirmTitle',
    'server.control.connection.details': 'serverControlConnectionDetails',
    'server.control.copied': 'serverControlCopied',
    'server.control.copy': 'serverControlCopy',
    'server.control.group.data': 'serverControlGroupData',
    'server.control.group.nix.os': 'serverControlGroupNixOs',
    'server.control.group.pocket.coder': 'serverControlGroupPocketCoder',
    'server.control.hide': 'serverControlHide',
    'server.control.https.endpoint': 'serverControlHttpsEndpoint',
    'server.control.ip.address': 'serverControlIpAddress',
    'server.control.local.auth.reason': 'serverControlLocalAuthReason',
    'server.control.operation.restart.nix.os': 'serverControlOperationRestartNixOs',
    'server.control.operation.restart.pocket.coder': 'serverControlOperationRestartPocketCoder',
    'server.control.operation.restore.backup': 'serverControlOperationRestoreBackup',
    'server.control.operation.save.backup': 'serverControlOperationSaveBackup',
    'server.control.operation.update.nix.os': 'serverControlOperationUpdateNixOs',
    'server.control.operation.update.pocket.coder': 'serverControlOperationUpdatePocketCoder',
    'server.control.private.key.label': 'serverControlPrivateKeyLabel',
    'server.control.provider.console': 'serverControlProviderConsole',
    'server.control.provider.console.unavailable': 'serverControlProviderConsoleUnavailable',
    'server.control.public.key.label': 'serverControlPublicKeyLabel',
    'server.control.release.available': 'serverControlReleaseAvailable',
    'server.control.release.checking': 'serverControlReleaseChecking',
    'server.control.release.contracts': 'serverControlReleaseContracts',
    'server.control.release.current': 'serverControlReleaseCurrent',
    'server.control.release.nixos': 'serverControlReleaseNixos',
    'server.control.release.status': 'serverControlReleaseStatus',
    'server.control.show': 'serverControlShow',
    'server.control.title': 'serverControlTitle',
    'settings.account.section': 'settingsAccountSection',
    'settings.ai.agents.section': 'settingsAiAgentsSection',
    'settings.delete.pro.data.cancel': 'settingsDeleteProDataCancel',
    'settings.delete.pro.data.confirm': 'settingsDeleteProDataConfirm',
    'settings.delete.pro.data.confirm.body': 'settingsDeleteProDataConfirmBody',
    'settings.delete.pro.data.confirm.title': 'settingsDeleteProDataConfirmTitle',
    'settings.delete.pro.data.label': 'settingsDeleteProDataLabel',
    'settings.factory.reset.cancel': 'settingsFactoryResetCancel',
    'settings.factory.reset.confirm': 'settingsFactoryResetConfirm',
    'settings.factory.reset.confirm.body': 'settingsFactoryResetConfirmBody',
    'settings.factory.reset.confirm.title': 'settingsFactoryResetConfirmTitle',
    'settings.logout.cancel': 'settingsLogoutCancel',
    'settings.logout.confirm': 'settingsLogoutConfirm',
    'settings.logout.confirm.body': 'settingsLogoutConfirmBody',
    'settings.logout.confirm.title': 'settingsLogoutConfirmTitle',
    'settings.report.ai.content.label': 'settingsReportAiContentLabel',
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
    'walkthrough.action.skip': 'walkthroughActionSkip',
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
  static const actionDismiss = 'action.dismiss';
  static const actionRefresh = 'action.refresh';
  static const actionReject = 'action.reject';
  static const actionRestore = 'action.restore';
  static const actionSave = 'action.save';
  static const actionSkip = 'action.skip';
  static const agentConfigDefaultBadge = 'agent.config.default.badge';
  static const agentConfigDelete = 'agent.config.delete';
  static (String, Map<String, dynamic>) agentConfigDeleteConfirmBody(String name) => ('agent.config.delete.confirm.body', {'name': name});
  static const agentConfigDeleteConfirmTitle = 'agent.config.delete.confirm.title';
  static (String, Map<String, dynamic>) agentConfigDialogTitle(String name) => ('agent.config.dialog.title', {'name': name});
  static const agentConfigEmpty = 'agent.config.empty';
  static (String, Map<String, dynamic>) agentConfigErrorPrefix(String error) => ('agent.config.error.prefix', {'error': error});
  static const agentConfigIsDefaultLabel = 'agent.config.is.default.label';
  static const agentConfigLabel = 'agent.config.label';
  static const agentConfigModeLabel = 'agent.config.mode.label';
  static const agentConfigNameLabel = 'agent.config.name.label';
  static const agentConfigNoModes = 'agent.config.no.modes';
  static const agentConfigNoPrompts = 'agent.config.no.prompts';
  static const agentConfigPromptLabel = 'agent.config.prompt.label';
  static const agentConfigRegistry = 'agent.config.registry';
  static const agentConfigSelectMode = 'agent.config.select.mode';
  static const agentConfigSelectPrompt = 'agent.config.select.prompt';
  static const agentConfigTitle = 'agent.config.title';
  static const agentDefaultTuned = 'agent.default.tuned';
  static const agentDescriptionLabel = 'agent.description.label';
  static (String, Map<String, dynamic>) agentDialogTitle(String name) => ('agent.dialog.title', {'name': name});
  static const agentModeLabel = 'agent.mode.label';
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
  static const billingError = 'billing.error';
  static const billingRestoreFailed = 'billing.restore.failed';
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
  static const chatMonitorAction = 'chat.monitor.action';
  static const chatNewCapabilityRequest = 'chat.new.capability.request';
  static const chatNoFieldsRequested = 'chat.no.fields.requested';
  static const chatNotFound = 'chat.not.found';
  static const chatPocoRole = 'chat.poco.role';
  static const chatRunOutcomeCancelledBody = 'chat.run.outcome.cancelled.body';
  static const chatRunOutcomeCancelledTitle = 'chat.run.outcome.cancelled.title';
  static const chatRunOutcomeFailedBody = 'chat.run.outcome.failed.body';
  static const chatRunOutcomeFailedTitle = 'chat.run.outcome.failed.title';
  static const chatRunOutcomeInterruptedBody = 'chat.run.outcome.interrupted.body';
  static const chatRunOutcomeInterruptedTitle = 'chat.run.outcome.interrupted.title';
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
  static const chatToolCallFallback = 'chat.tool.call.fallback';
  static const chatUseGlobalDefault = 'chat.use.global.default';
  static const chooseProviderComingSoon = 'choose.provider.coming.soon';
  static const chooseProviderProBadge = 'choose.provider.pro.badge';
  static const chooseProviderTitle = 'choose.provider.title';
  static const credentialConnectionApiKey = 'credential.connection.api.key';
  static const credentialConnectionCancel = 'credential.connection.cancel';
  static const credentialConnectionCopy = 'credential.connection.copy';
  static const credentialConnectionEnterCode = 'credential.connection.enter.code';
  static (String, Map<String, dynamic>) credentialConnectionExpiresAt(DateTime expiresAt) => ('credential.connection.expires.at', {'expiresAt': expiresAt});
  static const credentialConnectionOpenAuthorizationPage = 'credential.connection.open.authorization.page';
  static const credentialConnectionOpenFailed = 'credential.connection.open.failed';
  static const credentialConnectionPasteCode = 'credential.connection.paste.code';
  static const credentialConnectionRetry = 'credential.connection.retry';
  static const credentialConnectionSubmit = 'credential.connection.submit';
  static const deployChooseProvider = 'deploy.choose.provider';
  static const deploySelectProvider = 'deploy.select.provider';
  static const deploymentActionBack = 'deployment.action.back';
  static const deploymentActionDeployInstance = 'deployment.action.deploy.instance';
  static const deploymentActionDismiss = 'deployment.action.dismiss';
  static const deploymentActionInitialize = 'deployment.action.initialize';
  static const deploymentActionRefresh = 'deployment.action.refresh';
  static const deploymentActionUpdate = 'deployment.action.update';
  static const deploymentBackend = 'deployment.backend';
  static const deploymentCleanupFailed = 'deployment.cleanup.failed';
  static const deploymentCleanupNotNeeded = 'deployment.cleanup.not.needed';
  static const deploymentCleanupPending = 'deployment.cleanup.pending';
  static const deploymentCleanupSucceeded = 'deployment.cleanup.succeeded';
  static const deploymentCodingAgentsTitle = 'deployment.coding.agents.title';
  static const deploymentCodingHarnesses = 'deployment.coding.harnesses';
  static const deploymentDebian = 'deployment.debian';
  static const deploymentDebianDescription = 'deployment.debian.description';
  static const deploymentDefaultAgent = 'deployment.default.agent';
  static const deploymentDescriptionConfiguringOperatingSystem = 'deployment.description.configuring.operating.system';
  static const deploymentDescriptionConstructing = 'deployment.description.constructing';
  static const deploymentDescriptionFailed = 'deployment.description.failed';
  static const deploymentDescriptionFetching = 'deployment.description.fetching';
  static const deploymentDescriptionFinishing = 'deployment.description.finishing';
  static const deploymentDescriptionLoadingImages = 'deployment.description.loading.images';
  static const deploymentDescriptionPreparingOperatingSystem = 'deployment.description.preparing.operating.system';
  static const deploymentDescriptionReady = 'deployment.description.ready';
  static const deploymentDescriptionSecuring = 'deployment.description.securing';
  static const deploymentDescriptionStarting = 'deployment.description.starting';
  static const deploymentDescriptionTlsFailed = 'deployment.description.tls.failed';
  static const deploymentDescriptionTlsRateLimited = 'deployment.description.tls.rate.limited';
  static const deploymentDescriptionTlsReady = 'deployment.description.tls.ready';
  static const deploymentDescriptionTlsZeroSsl = 'deployment.description.tls.zero.ssl';
  static const deploymentDescriptionValidating = 'deployment.description.validating';
  static const deploymentDiscardAttemptBody = 'deployment.discard.attempt.body';
  static const deploymentDiscardAttemptCancel = 'deployment.discard.attempt.cancel';
  static const deploymentDiscardAttemptCheckLink = 'deployment.discard.attempt.check.link';
  static const deploymentDiscardAttemptConfirm = 'deployment.discard.attempt.confirm';
  static const deploymentDiscardAttemptConfirmCheckbox = 'deployment.discard.attempt.confirm.checkbox';
  static (String, Map<String, dynamic>) deploymentDiscardAttemptResourceId(String resourceId) => ('deployment.discard.attempt.resource.id', {'resourceId': resourceId});
  static const deploymentDiscardAttemptTitle = 'deployment.discard.attempt.title';
  static const deploymentDisconnectAction = 'deployment.disconnect.action';
  static const deploymentDisconnectCancel = 'deployment.disconnect.cancel';
  static const deploymentDisconnectConfirm = 'deployment.disconnect.confirm';
  static const deploymentDisconnectConfirmationBody = 'deployment.disconnect.confirmation.body';
  static const deploymentDisconnectConfirmationTitle = 'deployment.disconnect.confirmation.title';
  static const deploymentDistribution = 'deployment.distribution';
  static const deploymentFaultDeploymentInstanceNotFound = 'deployment.fault.deployment.instance.not.found';
  static const deploymentGpuBadge = 'deployment.gpu.badge';
  static const deploymentHardwareGeography = 'deployment.hardware.geography';
  static const deploymentHarnessPoco = 'deployment.harness.poco';
  static const deploymentHarnessSelectionDescription = 'deployment.harness.selection.description';
  static const deploymentInitializingHardware = 'deployment.initializing.hardware';
  static const deploymentInstancePlan = 'deployment.instance.plan';
  static const deploymentLinuxPoco = 'deployment.linux.poco';
  static const deploymentLinuxSystemTitle = 'deployment.linux.system.title';
  static const deploymentManifestConfiguration = 'deployment.manifest.configuration';
  static (String, Map<String, dynamic>) deploymentMemoryGb(int value) => ('deployment.memory.gb', {'value': value});
  static (String, Map<String, dynamic>) deploymentMemoryMb(int value) => ('deployment.memory.mb', {'value': value});
  static const deploymentMinimum = 'deployment.minimum';
  static (String, Map<String, dynamic>) deploymentMonthlyPrice(String price) => ('deployment.monthly.price', {'price': price});
  static const deploymentNixos = 'deployment.nixos';
  static const deploymentNixosDescription = 'deployment.nixos.description';
  static const deploymentNoSuitablePlans = 'deployment.no.suitable.plans';
  static const deploymentOperatingSystem = 'deployment.operating.system';
  static (String, Map<String, dynamic>) deploymentPlanPoco(String minimumMemory) => ('deployment.plan.poco', {'minimumMemory': minimumMemory});
  static (String, Map<String, dynamic>) deploymentPlanSpecs(int vcpus, String memory, int diskGb) => ('deployment.plan.specs', {'vcpus': vcpus, 'memory': memory, 'diskGb': diskGb});
  static const deploymentProviderLinode = 'deployment.provider.linode';
  static const deploymentProvisioned = 'deployment.provisioned';
  static const deploymentProvisioningSummary = 'deployment.provisioning.summary';
  static const deploymentRecommended = 'deployment.recommended';
  static const deploymentRegion = 'deployment.region';
  static const deploymentRegionPoco = 'deployment.region.poco';
  static const deploymentResetAction = 'deployment.reset.action';
  static const deploymentResetAlsoClearOAuth = 'deployment.reset.also.clear.o.auth';
  static const deploymentResetCancel = 'deployment.reset.cancel';
  static const deploymentResetComplete = 'deployment.reset.complete';
  static const deploymentResetConfirm = 'deployment.reset.confirm';
  static const deploymentResetConfirmationBody = 'deployment.reset.confirmation.body';
  static const deploymentResetConfirmationTitle = 'deployment.reset.confirmation.title';
  static const deploymentResetConfirmationWarnCloud = 'deployment.reset.confirmation.warn.cloud';
  static const deploymentReviewPoco = 'deployment.review.poco';
  static const deploymentReviewTitle = 'deployment.review.title';
  static const deploymentRunLocalModel = 'deployment.run.local.model';
  static const deploymentScanningRegions = 'deployment.scanning.regions';
  static const deploymentServerProvider = 'deployment.server.provider';
  static const deploymentServerRegionTitle = 'deployment.server.region.title';
  static const deploymentServerSizeTitle = 'deployment.server.size.title';
  static const deploymentSetupTypeTitle = 'deployment.setup.type.title';
  static const deploymentStandardLinux = 'deployment.standard.linux';
  static const deploymentStatusConfiguringOperatingSystem = 'deployment.status.configuring.operating.system';
  static const deploymentStatusConstructing = 'deployment.status.constructing';
  static const deploymentStatusFailed = 'deployment.status.failed';
  static const deploymentStatusFetching = 'deployment.status.fetching';
  static const deploymentStatusFinishing = 'deployment.status.finishing';
  static const deploymentStatusLoadingImages = 'deployment.status.loading.images';
  static const deploymentStatusPreparingOperatingSystem = 'deployment.status.preparing.operating.system';
  static const deploymentStatusReady = 'deployment.status.ready';
  static const deploymentStatusSecuring = 'deployment.status.securing';
  static const deploymentStatusStarting = 'deployment.status.starting';
  static const deploymentStatusTlsFailed = 'deployment.status.tls.failed';
  static const deploymentStatusTlsRateLimited = 'deployment.status.tls.rate.limited';
  static const deploymentStatusTlsReady = 'deployment.status.tls.ready';
  static const deploymentStatusTlsZeroSsl = 'deployment.status.tls.zero.ssl';
  static const deploymentStatusValidating = 'deployment.status.validating';
  static const deploymentStepBootFinal = 'deployment.step.boot.final';
  static const deploymentStepBootInstaller = 'deployment.step.boot.installer';
  static const deploymentStepBootstrapComplete = 'deployment.step.bootstrap.complete';
  static const deploymentStepComposeUp = 'deployment.step.compose.up';
  static const deploymentStepConfiguringOperatingSystem = 'deployment.step.configuring.operating.system';
  static const deploymentStepCreateFinalConfig = 'deployment.step.create.final.config';
  static const deploymentStepCreateInstallerConfig = 'deployment.step.create.installer.config';
  static const deploymentStepCreateInstallerDisk = 'deployment.step.create.installer.disk';
  static const deploymentStepCreateInstance = 'deployment.step.create.instance';
  static const deploymentStepCreateTargetDisk = 'deployment.step.create.target.disk';
  static const deploymentStepEnableWatchdog = 'deployment.step.enable.watchdog';
  static const deploymentStepFetchingRelease = 'deployment.step.fetching.release';
  static const deploymentStepFinalInstanceFetch = 'deployment.step.final.instance.fetch';
  static const deploymentStepLoadingImages = 'deployment.step.loading.images';
  static const deploymentStepPlanLookup = 'deployment.step.plan.lookup';
  static const deploymentStepPreBootShutdown = 'deployment.step.pre.boot.shutdown';
  static const deploymentStepReady = 'deployment.step.ready';
  static const deploymentStepRemoveInstallerResources = 'deployment.step.remove.installer.resources';
  static const deploymentStepWaitInstallerCompletion = 'deployment.step.wait.installer.completion';
  static const deploymentStepWaitInstallerDiskReady = 'deployment.step.wait.installer.disk.ready';
  static const deploymentStepWaitTargetDiskReady = 'deployment.step.wait.target.disk.ready';
  static const deploymentStepWaitingForConnection = 'deployment.step.waiting.for.connection';
  static const deploymentSystemParameters = 'deployment.system.parameters';
  static const deploymentUbuntu = 'deployment.ubuntu';
  static const deploymentUseCloudModels = 'deployment.use.cloud.models';
  static const deploymentWorkloadCloudReply = 'deployment.workload.cloud.reply';
  static const deploymentWorkloadLocalReply = 'deployment.workload.local.reply';
  static const deploymentWorkloadPoco = 'deployment.workload.poco';
  static const errorAuthFailed = 'error.auth.failed';
  static const errorAuthUnauthorized = 'error.auth.unauthorized';
  static const errorCouldNotOpenBrowser = 'error.could.not.open.browser';
  static const errorGeneric = 'error.generic';
  static const errorNetwork = 'error.network';
  static const errorTimeout = 'error.timeout';
  static const errorsClearAll = 'errors.clear.all';
  static const errorsCopied = 'errors.copied';
  static const errorsCopy = 'errors.copy';
  static const errorsCopyAll = 'errors.copy.all';
  static const errorsEmpty = 'errors.empty';
  static (String, Map<String, dynamic>) errorsOccurred(int count) => ('errors.occurred', {'count': count});
  static const errorsReportOnGithub = 'errors.report.on.github';
  static const errorsTitle = 'errors.title';
  static const externalAuthCancel = 'external.auth.cancel';
  static (String, Map<String, dynamic>) externalAuthConnecting(String label) => ('external.auth.connecting', {'label': label});
  static const externalAuthRetry = 'external.auth.retry';
  static const externalAuthTitle = 'external.auth.title';
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
  static const fossServerSetupConnected = 'foss.server.setup.connected';
  static const fossServerSetupGenerateKey = 'foss.server.setup.generate.key';
  static const fossServerSetupHostLabel = 'foss.server.setup.host.label';
  static const fossServerSetupIntro = 'foss.server.setup.intro';
  static const fossServerSetupPublicKeyLabel = 'foss.server.setup.public.key.label';
  static const fossServerSetupTestAndSave = 'foss.server.setup.test.and.save';
  static const fossServerSetupTitle = 'foss.server.setup.title';
  static (String, Map<String, dynamic>) harnessAuthAccount(String account, String visibility) => ('harness.auth.account', {'account': account, 'visibility': visibility});
  static const harnessAuthAccountLogin = 'harness.auth.account.login';
  static const harnessAuthApiKey = 'harness.auth.api.key';
  static (String, Map<String, dynamic>) harnessAuthAttempt(String id) => ('harness.auth.attempt', {'id': id});
  static const harnessAuthCancel = 'harness.auth.cancel';
  static const harnessAuthChallenge = 'harness.auth.challenge';
  static const harnessAuthChallengeDetailsCopied = 'harness.auth.challenge.details.copied';
  static const harnessAuthChallengeTargetCopied = 'harness.auth.challenge.target.copied';
  static const harnessAuthChooseProviderKey = 'harness.auth.choose.provider.key';
  static const harnessAuthConnections = 'harness.auth.connections';
  static const harnessAuthCopy = 'harness.auth.copy';
  static (String, Map<String, dynamic>) harnessAuthDetails(String details) => ('harness.auth.details', {'details': details});
  static const harnessAuthDisconnect = 'harness.auth.disconnect';
  static const harnessAuthEmpty = 'harness.auth.empty';
  static const harnessAuthLoading = 'harness.auth.loading';
  static (String, Map<String, dynamic>) harnessAuthMode(String mode) => ('harness.auth.mode', {'mode': mode});
  static const harnessAuthNoApiKeyBody = 'harness.auth.no.api.key.body';
  static const harnessAuthNoApiKeyTitle = 'harness.auth.no.api.key.title';
  static const harnessAuthNone = 'harness.auth.none';
  static const harnessAuthOneTimeCode = 'harness.auth.one.time.code';
  static const harnessAuthPasteCode = 'harness.auth.paste.code';
  static const harnessAuthPersonal = 'harness.auth.personal';
  static const harnessAuthPoll = 'harness.auth.poll';
  static (String, Map<String, dynamic>) harnessAuthProviderKeyMissing(String harness) => ('harness.auth.provider.key.missing', {'harness': harness});
  static const harnessAuthRefresh = 'harness.auth.refresh';
  static const harnessAuthShared = 'harness.auth.shared';
  static (String, Map<String, dynamic>) harnessAuthStatus(String status) => ('harness.auth.status', {'status': status});
  static const harnessAuthSubmit = 'harness.auth.submit';
  static const harnessAuthUnavailable = 'harness.auth.unavailable';
  static const harnessAuthVisibilityBody = 'harness.auth.visibility.body';
  static const harnessAuthVisibilityTitle = 'harness.auth.visibility.title';
  static (String, Map<String, dynamic>) homeErrorPrefix(String error) => ('home.error.prefix', {'error': error});
  static const homeLoadingChats = 'home.loading.chats';
  static const homeNewChat = 'home.new.chat';
  static const homeNoChats = 'home.no.chats';
  static const homeTitle = 'home.title';
  static const initializationActionAbort = 'initialization.action.abort';
  static const initializationActionLogin = 'initialization.action.login';
  static const initializationActionRetry = 'initialization.action.retry';
  static const initializationAdminIdentity = 'initialization.admin.identity';
  static const initializationAdminPassword = 'initialization.admin.password';
  static const initializationCloudRegion = 'initialization.cloud.region';
  static const initializationConnectionParameters = 'initialization.connection.parameters';
  static (String, Map<String, dynamic>) initializationCopiedToBuffer(String label) => ('initialization.copied.to.buffer', {'label': label});
  static (String, Map<String, dynamic>) initializationCopyLabel(String label) => ('initialization.copy.label', {'label': label});
  static const initializationCurrentOperation = 'initialization.current.operation';
  static const initializationDescriptionInitializing = 'initialization.description.initializing';
  static const initializationErrorCode = 'initialization.error.code';
  static const initializationFailed = 'initialization.failed';
  static const initializationFaultAuthenticationExpired = 'initialization.fault.authentication.expired';
  static (String, Map<String, dynamic>) initializationFaultDetected(String error) => ('initialization.fault.detected', {'error': error});
  static const initializationFaultGeneric = 'initialization.fault.generic';
  static (String, Map<String, dynamic>) initializationFaultMaxRetriesExceeded(String maxAttempts) => ('initialization.fault.max.retries.exceeded', {'maxAttempts': maxAttempts});
  static const initializationFaultProvisionInterruptedNoResource = 'initialization.fault.provision.interrupted.no.resource';
  static const initializationFaultProvisionResourceNotFound = 'initialization.fault.provision.resource.not.found';
  static const initializationFaultProvisionResourceStillExists = 'initialization.fault.provision.resource.still.exists';
  static const initializationFaultResourceAlreadyExists = 'initialization.fault.resource.already.exists';
  static const initializationGeoGrid = 'initialization.geo.grid';
  static const initializationHardwarePlan = 'initialization.hardware.plan';
  static const initializationHttpsEndpoint = 'initialization.https.endpoint';
  static const initializationInProgress = 'initialization.in.progress';
  static const initializationInstanceId = 'initialization.instance.id';
  static const initializationInstanceManifest = 'initialization.instance.manifest';
  static const initializationIpAddress = 'initialization.ip.address';
  static const initializationLastSignal = 'initialization.last.signal';
  static const initializationMetadataRegistry = 'initialization.metadata.registry';
  static const initializationNetworkIp = 'initialization.network.ip';
  static (String, Map<String, dynamic>) initializationReady(String ipAddress) => ('initialization.ready', {'ipAddress': ipAddress});
  static const initializationRetryAttempt = 'initialization.retry.attempt';
  static const initializationRunId = 'initialization.run.id';
  static const initializationScreenTitle = 'initialization.screen.title';
  static const initializationSecure = 'initialization.secure';
  static const initializationSecurityNotice = 'initialization.security.notice';
  static const initializationSourceCommit = 'initialization.source.commit';
  static const initializationStatusInitializing = 'initialization.status.initializing';
  static (String, Map<String, dynamic>) initializationStatusPrefix(String status) => ('initialization.status.prefix', {'status': status});
  static const initializationStatusSchema = 'initialization.status.schema';
  static (String, Map<String, dynamic>) initializationSyncAttempt(String attempt) => ('initialization.sync.attempt', {'attempt': attempt});
  static const initializationTechnicalDetailsToggle = 'initialization.technical.details.toggle';
  static const initializationUnknown = 'initialization.unknown';
  static const instanceVerificationBackAction = 'instance.verification.back.action';
  static const instanceVerificationBody = 'instance.verification.body';
  static const instanceVerificationCheckAction = 'instance.verification.check.action';
  static const instanceVerificationCheckFailedMessage = 'instance.verification.check.failed.message';
  static const instanceVerificationResetAction = 'instance.verification.reset.action';
  static const instanceVerificationResetCancel = 'instance.verification.reset.cancel';
  static const instanceVerificationResetConfirm = 'instance.verification.reset.confirm';
  static const instanceVerificationResetConfirmationBody = 'instance.verification.reset.confirmation.body';
  static const instanceVerificationResetConfirmationTitle = 'instance.verification.reset.confirmation.title';
  static const instanceVerificationTitle = 'instance.verification.title';
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
  static const mcpAddNew = 'mcp.add.new';
  static const mcpAuthorize = 'mcp.authorize';
  static const mcpAuthorizeCap = 'mcp.authorize.cap';
  static (String, Map<String, dynamic>) mcpAuthorizeDialogTitle(String name) => ('mcp.authorize.dialog.title', {'name': name});
  static const mcpCapabilitiesRegistry = 'mcp.capabilities.registry';
  static const mcpConnectCap = 'mcp.connect.cap';
  static const mcpDeny = 'mcp.deny';
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
  static const monitorTelemetryUnavailable = 'monitor.telemetry.unavailable';
  static const monitorTitle = 'monitor.title';
  static const navChats = 'nav.chats';
  static const navConfigure = 'nav.configure';
  static const navManage = 'nav.manage';
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
  static const notificationSettingsEnableDevice = 'notification.settings.enable.device';
  static const notificationSettingsPoco = 'notification.settings.poco';
  static const notificationSettingsScheduleLabel = 'notification.settings.schedule.label';
  static const notificationSettingsScreenTitle = 'notification.settings.screen.title';
  static const notificationSettingsTaskCompleteLabel = 'notification.settings.task.complete.label';
  static const notificationSettingsTaskErrorLabel = 'notification.settings.task.error.label';
  static (String, Map<String, dynamic>) notificationSignalReceived(String title) => ('notification.signal.received', {'title': title});
  static const observabilityLogTerminal = 'observability.log.terminal';
  static const observabilityRegistry = 'observability.registry';
  static const observabilitySelectContainer = 'observability.select.container';
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
  static (String, Map<String, dynamic>) onboardingHarnessAccountLogin(String harness) => ('onboarding.harness.account.login', {'harness': harness});
  static const onboardingHarnessAccountVisibilityBody = 'onboarding.harness.account.visibility.body';
  static const onboardingHarnessAccountVisibilityCancel = 'onboarding.harness.account.visibility.cancel';
  static const onboardingHarnessAccountVisibilityPersonal = 'onboarding.harness.account.visibility.personal';
  static const onboardingHarnessAccountVisibilityShared = 'onboarding.harness.account.visibility.shared';
  static const onboardingHarnessAccountVisibilityTitle = 'onboarding.harness.account.visibility.title';
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
  static const onboardingOpenChatFailed = 'onboarding.open.chat.failed';
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
  static const onboardingPasswordTooShort = 'onboarding.password.too.short';
  static (String, Map<String, dynamic>) onboardingPlanPoco(String providerName) => ('onboarding.plan.poco', {'providerName': providerName});
  static const onboardingPlanTitle = 'onboarding.plan.title';
  static const onboardingPocketbaseAdminEmail = 'onboarding.pocketbase.admin.email';
  static const onboardingPocketbaseAdminPassword = 'onboarding.pocketbase.admin.password';
  static const onboardingPocoChallengeMessage = 'onboarding.poco.challenge.message';
  static const onboardingPocoWelcome = 'onboarding.poco.welcome';
  static const onboardingProcessing = 'onboarding.processing';
  static const onboardingProviderAuthorizationAction = 'onboarding.provider.authorization.action';
  static const onboardingProviderAuthorizationCancelled = 'onboarding.provider.authorization.cancelled';
  static const onboardingProviderAuthorizationError = 'onboarding.provider.authorization.error';
  static const onboardingProviderAuthorizationFailed = 'onboarding.provider.authorization.failed';
  static const onboardingProviderAuthorizationPoco = 'onboarding.provider.authorization.poco';
  static const onboardingProviderAuthorizationTitle = 'onboarding.provider.authorization.title';
  static const onboardingProviderAuthorizationWaiting = 'onboarding.provider.authorization.waiting';
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
  static const onboardingSelfHostActionConnect = 'onboarding.self.host.action.connect';
  static const onboardingSelfHostActionGuide = 'onboarding.self.host.action.guide';
  static const onboardingSelfHostPoco = 'onboarding.self.host.poco';
  static const onboardingSelfHostRequirementAccess = 'onboarding.self.host.requirement.access';
  static const onboardingSelfHostRequirementDocker = 'onboarding.self.host.requirement.docker';
  static const onboardingSelfHostRequirementServer = 'onboarding.self.host.requirement.server';
  static const onboardingSelfHostRequirementsTitle = 'onboarding.self.host.requirements.title';
  static const onboardingSelfHostTitle = 'onboarding.self.host.title';
  static const onboardingServerConnecting = 'onboarding.server.connecting';
  static const onboardingServerCredentialsPoco = 'onboarding.server.credentials.poco';
  static const onboardingServerCredentialsTitle = 'onboarding.server.credentials.title';
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
  static (String, Map<String, dynamic>) onboardingTrialPoco(int trialDuration) => ('onboarding.trial.poco', {'trialDuration': trialDuration});
  static const onboardingWelcomeActionGuided = 'onboarding.welcome.action.guided';
  static const onboardingWelcomeActionSelfHost = 'onboarding.welcome.action.self.host';
  static const onboardingWelcomePoco = 'onboarding.welcome.poco';
  static const onboardingWelcomeTitle = 'onboarding.welcome.title';
  static const permissionError = 'permission.error';
  static const permissionFetchFailed = 'permission.fetch.failed';
  static const permissionPatternsLabel = 'permission.patterns.label';
  static const permissionRequestedFallback = 'permission.requested.fallback';
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
  static const pocketCoderUpdateAvailable = 'pocket.coder.update.available';
  static const pocketCoderUpdateAvailableStatus = 'pocket.coder.update.available.status';
  static const pocketCoderUpdateCheckAgain = 'pocket.coder.update.check.again';
  static const pocketCoderUpdateChecking = 'pocket.coder.update.checking';
  static const pocketCoderUpdateCommand = 'pocket.coder.update.command';
  static const pocketCoderUpdateConfirmUpgrade = 'pocket.coder.update.confirm.upgrade';
  static const pocketCoderUpdateCriticalStatus = 'pocket.coder.update.critical.status';
  static const pocketCoderUpdateCurrent = 'pocket.coder.update.current';
  static const pocketCoderUpdateCurrentStatus = 'pocket.coder.update.current.status';
  static (String, Map<String, dynamic>) pocketCoderUpdateDataBoundary(int currentVersion, int availableVersion) => ('pocket.coder.update.data.boundary', {'currentVersion': currentVersion, 'availableVersion': availableVersion});
  static const pocketCoderUpdateDownload = 'pocket.coder.update.download';
  static (String, Map<String, dynamic>) pocketCoderUpdateFailed(int exitCode) => ('pocket.coder.update.failed', {'exitCode': exitCode});
  static const pocketCoderUpdateNoDeployment = 'pocket.coder.update.no.deployment';
  static const pocketCoderUpdateOutput = 'pocket.coder.update.output';
  static const pocketCoderUpdateRequiredDisk = 'pocket.coder.update.required.disk';
  static const pocketCoderUpdateReviewDataChange = 'pocket.coder.update.review.data.change';
  static const pocketCoderUpdateRollbackWarning = 'pocket.coder.update.rollback.warning';
  static const pocketCoderUpdateStderr = 'pocket.coder.update.stderr';
  static const pocketCoderUpdateSucceeded = 'pocket.coder.update.succeeded';
  static const pocketCoderUpdateUnknownStatus = 'pocket.coder.update.unknown.status';
  static const pocketCoderUpdateUpgrade = 'pocket.coder.update.upgrade';
  static const pocketCoderUpdateWorking = 'pocket.coder.update.working';
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
  static const pocoProvisioningFailed = 'poco.provisioning.failed';
  static const pocoProvisioningLoadingSource = 'poco.provisioning.loading.source';
  static const pocoProvisioningNext = 'poco.provisioning.next';
  static const pocoProvisioningPrevious = 'poco.provisioning.previous';
  static const pocoProvisioningShowConcise = 'poco.provisioning.show.concise';
  static const pocoProvisioningShowFull = 'poco.provisioning.show.full';
  static const pocoProvisioningSourceUnavailable = 'poco.provisioning.source.unavailable';
  static const pocoProvisioningTourTitle = 'poco.provisioning.tour.title';
  static const pocoProvisioningWaitingForSource = 'poco.provisioning.waiting.for.source';
  static const proActive = 'pro.active';
  static const proActiveBody = 'pro.active.body';
  static const proBenefitLiveMonitoring = 'pro.benefit.live.monitoring';
  static const proBenefitPushNotifications = 'pro.benefit.push.notifications';
  static const proBenefitServerSetup = 'pro.benefit.server.setup';
  static const proCheckingStatus = 'pro.checking.status';
  static const proConfigureSelfHostedPush = 'pro.configure.self.hosted.push';
  static const proFeatureConsole = 'pro.feature.console';
  static const proFeatureDeploy = 'pro.feature.deploy';
  static const proFeaturePush = 'pro.feature.push';
  static const proFeatureReady = 'pro.feature.ready';
  static const proManageSubscription = 'pro.manage.subscription';
  static const proPlanTitle = 'pro.plan.title';
  static (String, Map<String, dynamic>) proPrice(String price) => ('pro.price', {'price': price});
  static (String, Map<String, dynamic>) proPriceAfterTrial(String price) => ('pro.price.after.trial', {'price': price});
  static (String, Map<String, dynamic>) proPricePerMonth(String price) => ('pro.price.per.month', {'price': price});
  static (String, Map<String, dynamic>) proPricePerWeek(String price) => ('pro.price.per.week', {'price': price});
  static (String, Map<String, dynamic>) proPricePerYear(String price) => ('pro.price.per.year', {'price': price});
  static const proPrivacyPolicyLink = 'pro.privacy.policy.link';
  static const proRestore = 'pro.restore';
  static const proSelfHostedPushBody = 'pro.self.hosted.push.body';
  static const proSelfHostedPushTitle = 'pro.self.hosted.push.title';
  static const proSettingsLabel = 'pro.settings.label';
  static const proSettingsStatus = 'pro.settings.status';
  static (String, Map<String, dynamic>) proStartTrial(int days) => ('pro.start.trial', {'days': days});
  static const proSubscribe = 'pro.subscribe';
  static const proSummary = 'pro.summary';
  static (String, Map<String, dynamic>) proTerms(String price) => ('pro.terms', {'price': price});
  static const proTermsOfServiceLink = 'pro.terms.of.service.link';
  static const proTitle = 'pro.title';
  static (String, Map<String, dynamic>) proTrialDuration(int days) => ('pro.trial.duration', {'days': days});
  static const proTrialLapseExplainer = 'pro.trial.lapse.explainer';
  static const proTrialNoPaymentInfo = 'pro.trial.no.payment.info';
  static (String, Map<String, dynamic>) proTrialTerms(int days, String price) => ('pro.trial.terms', {'days': days, 'price': price});
  static const proUnavailable = 'pro.unavailable';
  static const proUnavailableBody = 'pro.unavailable.body';
  static const proUnlockCommand = 'pro.unlock.command';
  static const providerReauthenticationRequired = 'provider.reauthentication.required';
  static const providerScreenAddKey = 'provider.screen.add.key';
  static (String, Map<String, dynamic>) providerScreenAddKeyBody(String provider) => ('provider.screen.add.key.body', {'provider': provider});
  static (String, Map<String, dynamic>) providerScreenAddKeyTitle(String provider) => ('provider.screen.add.key.title', {'provider': provider});
  static const providerScreenApiKeysSection = 'provider.screen.api.keys.section';
  static (String, Map<String, dynamic>) providerScreenBrowseAllModels(int count) => ('provider.screen.browse.all.models', {'count': count});
  static const providerScreenDefaultBadge = 'provider.screen.default.badge';
  static const providerScreenEmptyHint = 'provider.screen.empty.hint';
  static (String, Map<String, dynamic>) providerScreenErrorPrefix(String error) => ('provider.screen.error.prefix', {'error': error});
  static (String, Map<String, dynamic>) providerScreenHarnessModelCount(int count) => ('provider.screen.harness.model.count', {'count': count});
  static const providerScreenHarnessModelsSection = 'provider.screen.harness.models.section';
  static const providerScreenLoading = 'provider.screen.loading';
  static const providerScreenNoApiKeys = 'provider.screen.no.api.keys';
  static const providerScreenNoHarnessModels = 'provider.screen.no.harness.models';
  static const providerScreenNoProviders = 'provider.screen.no.providers';
  static const providerScreenSearchHint = 'provider.screen.search.hint';
  static const providerScreenSearchLabel = 'provider.screen.search.label';
  static const providerScreenSearchNoMatches = 'provider.screen.search.no.matches';
  static const providerScreenSelectProvider = 'provider.screen.select.provider';
  static const providerScreenTitle = 'provider.screen.title';
  static const providerScreenUpdateKey = 'provider.screen.update.key';
  static const questionIncomingTitle = 'question.incoming.title';
  static const questionPocoAsking = 'question.poco.asking';
  static const questionSendReply = 'question.send.reply';
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
  static const serverControlActionRestart = 'server.control.action.restart';
  static const serverControlActionRestore = 'server.control.action.restore';
  static const serverControlActionSave = 'server.control.action.save';
  static const serverControlActionUpdate = 'server.control.action.update';
  static const serverControlAdminIdentity = 'server.control.admin.identity';
  static const serverControlAdminPassword = 'server.control.admin.password';
  static (String, Map<String, dynamic>) serverControlConfirmBody(String operation) => ('server.control.confirm.body', {'operation': operation});
  static const serverControlConfirmCancel = 'server.control.confirm.cancel';
  static const serverControlConfirmConfirm = 'server.control.confirm.confirm';
  static const serverControlConfirmRestoreBody = 'server.control.confirm.restore.body';
  static const serverControlConfirmRestoreTitle = 'server.control.confirm.restore.title';
  static const serverControlConfirmTitle = 'server.control.confirm.title';
  static const serverControlConnectionDetails = 'server.control.connection.details';
  static const serverControlCopied = 'server.control.copied';
  static const serverControlCopy = 'server.control.copy';
  static const serverControlGroupData = 'server.control.group.data';
  static const serverControlGroupNixOs = 'server.control.group.nix.os';
  static const serverControlGroupPocketCoder = 'server.control.group.pocket.coder';
  static const serverControlHide = 'server.control.hide';
  static const serverControlHttpsEndpoint = 'server.control.https.endpoint';
  static const serverControlIpAddress = 'server.control.ip.address';
  static const serverControlLocalAuthReason = 'server.control.local.auth.reason';
  static const serverControlOperationRestartNixOs = 'server.control.operation.restart.nix.os';
  static const serverControlOperationRestartPocketCoder = 'server.control.operation.restart.pocket.coder';
  static const serverControlOperationRestoreBackup = 'server.control.operation.restore.backup';
  static const serverControlOperationSaveBackup = 'server.control.operation.save.backup';
  static const serverControlOperationUpdateNixOs = 'server.control.operation.update.nix.os';
  static const serverControlOperationUpdatePocketCoder = 'server.control.operation.update.pocket.coder';
  static const serverControlPrivateKeyLabel = 'server.control.private.key.label';
  static const serverControlProviderConsole = 'server.control.provider.console';
  static const serverControlProviderConsoleUnavailable = 'server.control.provider.console.unavailable';
  static const serverControlPublicKeyLabel = 'server.control.public.key.label';
  static (String, Map<String, dynamic>) serverControlReleaseAvailable(String version) => ('server.control.release.available', {'version': version});
  static const serverControlReleaseChecking = 'server.control.release.checking';
  static (String, Map<String, dynamic>) serverControlReleaseContracts(String app, String server, String deployment) => ('server.control.release.contracts', {'app': app, 'server': server, 'deployment': deployment});
  static (String, Map<String, dynamic>) serverControlReleaseCurrent(String version) => ('server.control.release.current', {'version': version});
  static (String, Map<String, dynamic>) serverControlReleaseNixos(String version) => ('server.control.release.nixos', {'version': version});
  static (String, Map<String, dynamic>) serverControlReleaseStatus(String status) => ('server.control.release.status', {'status': status});
  static const serverControlShow = 'server.control.show';
  static const serverControlTitle = 'server.control.title';
  static const settingsAccountSection = 'settings.account.section';
  static const settingsAiAgentsSection = 'settings.ai.agents.section';
  static const settingsDeleteProDataCancel = 'settings.delete.pro.data.cancel';
  static const settingsDeleteProDataConfirm = 'settings.delete.pro.data.confirm';
  static const settingsDeleteProDataConfirmBody = 'settings.delete.pro.data.confirm.body';
  static const settingsDeleteProDataConfirmTitle = 'settings.delete.pro.data.confirm.title';
  static const settingsDeleteProDataLabel = 'settings.delete.pro.data.label';
  static const settingsFactoryResetCancel = 'settings.factory.reset.cancel';
  static const settingsFactoryResetConfirm = 'settings.factory.reset.confirm';
  static const settingsFactoryResetConfirmBody = 'settings.factory.reset.confirm.body';
  static const settingsFactoryResetConfirmTitle = 'settings.factory.reset.confirm.title';
  static const settingsLogoutCancel = 'settings.logout.cancel';
  static const settingsLogoutConfirm = 'settings.logout.confirm';
  static const settingsLogoutConfirmBody = 'settings.logout.confirm.body';
  static const settingsLogoutConfirmTitle = 'settings.logout.confirm.title';
  static const settingsReportAiContentLabel = 'settings.report.ai.content.label';
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
  static const walkthroughActionSkip = 'walkthrough.action.skip';
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
