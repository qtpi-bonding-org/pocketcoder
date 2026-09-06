// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PocketCoder';

  @override
  String get errorNetwork => 'Network error occurred';

  @override
  String get errorTimeout => 'Operation timed out';

  @override
  String get errorAuthUnauthorized => 'Unauthorized access';

  @override
  String get errorAuthFailed => 'Authentication failed';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorCouldNotOpenBrowser =>
      'Could not open the browser. Please try again.';

  @override
  String get errorCouldNotOpenMailApp =>
      'Could not open a mail app. Please try again.';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authNotAuthenticated => 'Please log in';

  @override
  String get authTokenExpired => 'Session expired, please log in again';

  @override
  String get authError => 'Authentication error';

  @override
  String get providerReauthenticationRequired =>
      'Your provider needs to be reauthenticated. Your saved login was kept.';

  @override
  String get chatFetchFailed => 'Unable to load chats';

  @override
  String get chatSendFailed => 'Failed to send message';

  @override
  String get chatNotFound => 'Chat not found';

  @override
  String get chatError => 'Chat error';

  @override
  String get chatListError => 'Unable to load chats';

  @override
  String get chatMessageSent => 'Message sent';

  @override
  String get chatCreated => 'Chat created';

  @override
  String get permissionFetchFailed => 'Unable to load permissions';

  @override
  String get permissionUpdateFailed => 'Failed to update permission';

  @override
  String get permissionError => 'Permission error';

  @override
  String get aiFetchFailed => 'Unable to load AI resources';

  @override
  String get aiSaveFailed => 'Failed to save AI configuration';

  @override
  String get aiError => 'AI error';

  @override
  String get toolPermissionsFetchFailed => 'Unable to load tool permissions';

  @override
  String get toolPermissionsUpdateFailed => 'Failed to update tool permissions';

  @override
  String get toolPermissionsError => 'Tool permissions error';

  @override
  String get billingRestoreFailed =>
      'Couldn\'t restore your purchases. Check your connection and try again.';

  @override
  String get billingError => 'Billing error';

  @override
  String get actionCancel => 'cancel';

  @override
  String get actionSave => 'save';

  @override
  String get actionClose => 'close';

  @override
  String get actionDeny => 'deny';

  @override
  String get actionAuthorize => 'authorize';

  @override
  String get actionRefresh => 'refresh';

  @override
  String get actionBack => 'back';

  @override
  String get actionSkip => 'skip';

  @override
  String get actionContinue => 'next';

  @override
  String get actionChange => 'change';

  @override
  String get actionCreate => 'create';

  @override
  String get actionAddNew => 'add new';

  @override
  String get actionRestore => 'restore';

  @override
  String get actionConfigure => 'configure';

  @override
  String get actionReject => 'reject';

  @override
  String get externalAuthTitle => 'external authentication';

  @override
  String externalAuthConnecting(String label) {
    return 'Connecting to $label...';
  }

  @override
  String get externalAuthRetry => 'retry';

  @override
  String get externalAuthCancel => 'cancel';

  @override
  String get bootLoadError =>
      'SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS\n[!] CHECK_ASSET_MANIFEST';

  @override
  String get bootPocoIntro =>
      'Hi! I\'m Poco, your Private Operations Coding Officer representing the PocketCoder Initiative.';

  @override
  String get bootCheckingConnection => 'Checking secure connection...';

  @override
  String get bootWelcomeBack => 'Welcome back.';

  @override
  String get bootSystemsNominal => 'Systems nominal. I\'m ready.';

  @override
  String get bootConnectionFailed =>
      'Connection failed. I\'ll take you back to the setup screen so we can check the server settings.';

  @override
  String get bootNoiseHeartbeat => '[sys] heartbeat: ok';

  @override
  String get bootNoiseKeepalive => '[net] keepalive sent';

  @override
  String get bootNoiseGcMinor => '[mem] gc_minor completed';

  @override
  String get bootNoiseContextSwitch => '[proc] context_switch: 1241';

  @override
  String get bootNoiseReasoningEngine => '[agent] reasoning_engine: idle';

  @override
  String get onboardingTitle => 'identification unlock';

  @override
  String get onboardingPocoChallengeMessage =>
      'Who goes there? Identify yourself and provide the secret passphrase.';

  @override
  String get onboardingPocoWelcome =>
      'Identity verified! Welcome home. I knew it was you—just had to make sure the Cloud wasn\'t spoofing your signature.';

  @override
  String get onboardingAccessDenied => 'Access denied.';

  @override
  String get onboardingProcessing => 'Processing...';

  @override
  String get onboardingLogin => 'connect';

  @override
  String get onboardingDeploy => 'deploy';

  @override
  String get onboardingHomeServer => 'home server';

  @override
  String get onboardingIdentityLabel => 'identity';

  @override
  String get onboardingEmailHint => 'enter email';

  @override
  String get onboardingPassphraseLabel => 'passphrase';

  @override
  String get onboardingPasswordHint => 'enter password';

  @override
  String get onboardingAuthenticating => 'authenticating';

  @override
  String get onboardingSetupTitle => 'PocketCoder setup';

  @override
  String get onboardingConnectOrDeploy =>
      'Are you already part of the PocketCoder initiative?';

  @override
  String get onboardingExistingServer => 'use an existing PocketBase server';

  @override
  String get onboardingCreateServer => 'create a new server';

  @override
  String get onboardingServerLoginTitle => 'server login';

  @override
  String get onboardingServerUrl => 'server URL';

  @override
  String get onboardingServerUrlHint => 'https://server.example.com';

  @override
  String get onboardingEmail => 'email';

  @override
  String get onboardingEmailHintShort => 'admin@example.com';

  @override
  String get onboardingPassword => 'password';

  @override
  String get onboardingServerConnecting => 'Connecting...';

  @override
  String get onboardingRequiredFields => 'enter all required fields';

  @override
  String get onboardingChooseHarnessTitle => 'choose your harness';

  @override
  String get onboardingChooseHarnessBody =>
      'Choose the account-based agent to connect.';

  @override
  String get onboardingChooseHarnessLoadingProviders =>
      'Loading provider connections…';

  @override
  String get onboardingHarnessProvidersLoading => 'Loading harness providers…';

  @override
  String get onboardingHarnessNotFound => 'harness not found';

  @override
  String get onboardingClaudeAccountLogin => 'Claude account login';

  @override
  String get onboardingCodexAccountLogin => 'ChatGPT account login';

  @override
  String onboardingHarnessAccountLogin(String harness) {
    return '$harness account login';
  }

  @override
  String onboardingHarnessLoginTitle(String provider) {
    return '$provider login';
  }

  @override
  String get onboardingHarnessAccountVisibilityTitle =>
      'Who uses this harness account?';

  @override
  String get onboardingHarnessAccountVisibilityBody =>
      'Shared reuses this login across profiles on this server. Personal keeps a separate login for this profile.';

  @override
  String get onboardingHarnessAccountVisibilityPersonal => 'Personal';

  @override
  String get onboardingHarnessAccountVisibilityShared => 'Shared';

  @override
  String get onboardingHarnessAccountVisibilityCancel => 'Cancel';

  @override
  String get onboardingConnected => 'connected';

  @override
  String get onboardingAccountLogin => 'account login';

  @override
  String get onboardingAuthorizationCode => 'authorization code';

  @override
  String get onboardingAuthorizationCodeHint => 'paste code';

  @override
  String get onboardingSubmitCode => 'submit code';

  @override
  String get onboardingOpenAuthorization => 'open authorization';

  @override
  String get onboardingCheckStatus => 'check status';

  @override
  String get onboardingOpenChatFailed =>
      'Could not open a new chat. Please try again.';

  @override
  String get onboardingServerCredentialsTitle => 'server credentials';

  @override
  String get onboardingPocketbaseAdminEmail => 'PocketCoder admin email';

  @override
  String get onboardingPocketbaseAdminPassword => 'PocketCoder admin password';

  @override
  String get homeTitle => 'chats';

  @override
  String get homeLoadingChats => 'loading chats';

  @override
  String homeErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get homeNewChat => 'new chat';

  @override
  String get homeNoChats => 'No active chats found.';

  @override
  String get chatSessionTitle => 'chat session';

  @override
  String get chatTerminalAction => 'terminal';

  @override
  String get chatListNewChat => 'new';

  @override
  String get chatListNoMessages => 'No messages yet';

  @override
  String get newChatTitle => 'New Chat';

  @override
  String get newChatTitleField => 'Title';

  @override
  String get newChatHarnessField => 'Harness';

  @override
  String get newChatModelField => 'Model';

  @override
  String get newChatCwdField => 'Working directory';

  @override
  String get newChatCwdHint => '/workspace';

  @override
  String get newChatCreate => 'create';

  @override
  String get newChatCancel => 'cancel';

  @override
  String get newChatSelectHarness => 'select harness';

  @override
  String get newChatSelectModel => 'select model';

  @override
  String get newChatNoModelsAvailable => 'No models available for this harness';

  @override
  String get chatPickerSearchLabel => 'search';

  @override
  String get chatPickerSearchHint => 'Filter options';

  @override
  String get chatPickerNoMatches => 'no matching options';

  @override
  String get newChatWorkspaceErrorEmpty => 'Path cannot be empty';

  @override
  String get newChatWorkspaceErrorInvalid =>
      'Path must be /workspace or a subdirectory of it';

  @override
  String get chatListArchive => 'archive';

  @override
  String get chatListDelete => 'delete';

  @override
  String chatListActionsBody(String title) {
    return 'archive hides \"$title\" from this list. delete removes it permanently.';
  }

  @override
  String get chatListTimestampNow => 'now';

  @override
  String chatListTimestampMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String chatListTimestampHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String chatListTimestampDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get chatFilesAction => 'files';

  @override
  String get chatNewCapabilityRequest => '[!] new capability request received';

  @override
  String get chatThinking => 'thinking';

  @override
  String get chatThinkingLive => 'Thinking...';

  @override
  String get chatThought => 'thought';

  @override
  String get chatAwaitingHarnessStart =>
      'Starting the harness -- this can take a minute or two on a fresh container.';

  @override
  String get chatWorkingThroughRequest => 'Working through the request.';

  @override
  String get chatCommandOutput => 'output';

  @override
  String get chatToolCallFallback => 'Tool call';

  @override
  String get chatSessionAction => 'session';

  @override
  String get chatMonitorAction => 'watch';

  @override
  String get chatSendTooltip => 'Send';

  @override
  String get chatCommanderRole => 'commander';

  @override
  String get chatThinkingRole => 'thinking';

  @override
  String get chatPocoRole => 'Poco';

  @override
  String get chatElicitationRequest => 'elicitation request';

  @override
  String get chatElicitationFormLabel => 'form';

  @override
  String get chatCommanderPrompt => 'commander@pc \$ ';

  @override
  String get chatComposerPrompt => 'commander@pc \$';

  @override
  String get chatPocoPrompt => '[poco] ';

  @override
  String get chatPickerFieldIndicator => '[v]';

  @override
  String get chatDecline => 'decline';

  @override
  String get chatSubmit => 'submit';

  @override
  String get chatNoFieldsRequested => '(no fields requested)';

  @override
  String get chatRunOutcomeInterruptedTitle => 'run interrupted';

  @override
  String get chatRunOutcomeInterruptedBody =>
      'The connection ended before the run finished.';

  @override
  String get chatRunOutcomeCancelledTitle => 'run stopped';

  @override
  String get chatRunOutcomeCancelledBody => 'The run was stopped.';

  @override
  String get chatRunOutcomeFailedTitle => 'run failed';

  @override
  String get chatRunOutcomeFailedBody =>
      'Something went wrong while running this request.';

  @override
  String get filesTitle => 'files';

  @override
  String get filesEmpty => 'no files';

  @override
  String get filesTooLargeToPreview => 'file too large to preview';

  @override
  String get filesCantPreviewType => 'can\'t preview this file type';

  @override
  String get chatModelLabel => 'model:';

  @override
  String get chatModelDefault => 'default';

  @override
  String get chatModelPerChat => '[chat]';

  @override
  String get chatSelectModelTitle => 'select model';

  @override
  String get chatUseGlobalDefault => 'use global default';

  @override
  String get llmTitle => 'llm management';

  @override
  String get llmLoadingProviders => 'loading providers';

  @override
  String get llmActiveModelSection => 'active model';

  @override
  String get llmProvidersSection => 'providers';

  @override
  String get llmApiKeysSection => 'API keys';

  @override
  String get llmGlobalDefault => 'global default';

  @override
  String get llmNotSet => 'not set';

  @override
  String get llmAddKeyHint => 'add an API key to enable model selection';

  @override
  String get llmNoProviders => 'no providers available';

  @override
  String get llmConnected => '[ connected ]';

  @override
  String get llmNoKey => '[ no key ]';

  @override
  String llmModelsAvailable(int count) {
    return '$count model(s) available';
  }

  @override
  String get llmUpdateKey => 'update key';

  @override
  String get llmAddKey => 'add key';

  @override
  String get llmModelsButton => 'models';

  @override
  String llmApiKeyDialogTitle(String provider) {
    return 'API key: $provider';
  }

  @override
  String llmEnterCredentials(String provider) {
    return 'Enter credentials for $provider:';
  }

  @override
  String get llmSelectModelTitle => 'select model';

  @override
  String llmProviderModelsTitle(String provider) {
    return '$provider models';
  }

  @override
  String get llmNoModels => 'no models listed';

  @override
  String get llmSelect => '[ select ]';

  @override
  String get mcpTitle => 'MCP management';

  @override
  String get mcpCapabilitiesRegistry => 'capabilities registry';

  @override
  String get mcpPendingApproval => 'pending approval';

  @override
  String get mcpActiveCapabilities => 'active capabilities';

  @override
  String get mcpNoCapabilities => 'no capabilities registered';

  @override
  String mcpImageLabel(String image) {
    return 'image: $image';
  }

  @override
  String mcpPurposeLabel(String reason) {
    return 'purpose: $reason';
  }

  @override
  String get mcpRequiredConfig => 'required config:';

  @override
  String get mcpAuthorizeCap => 'authorize capability';

  @override
  String get mcpEditConfig => 'edit configuration';

  @override
  String get mcpRevoke => 'revoke';

  @override
  String mcpAuthorizeDialogTitle(String name) {
    return 'authorize: $name';
  }

  @override
  String mcpUpdateConfigDialogTitle(String name) {
    return 'update config: $name';
  }

  @override
  String get mcpNoConfigRequired => 'No configuration required.';

  @override
  String get mcpEnterSecrets => 'Enter required secrets:';

  @override
  String get mcpAddDialogTitle => 'add MCP server';

  @override
  String get mcpServerNameLabel => 'server name';

  @override
  String get mcpImageOptionalLabel => 'image (optional)';

  @override
  String get mcpAddConfigOptional =>
      'Optional config (leave blank if none needed)';

  @override
  String get mcpConnectCap => 'connect';

  @override
  String get mcpRetryDeliveryCap => 'retry delivery';

  @override
  String mcpOauthRequiredLabel(String provider) {
    return 'requires OAuth: $provider';
  }

  @override
  String get mcpOauthProviderOptionalLabel => 'OAuth provider (optional)';

  @override
  String get mcpOauthTokenEnvVarOptionalLabel =>
      'OAuth token env var (optional)';

  @override
  String mcpOauthProviderNotConfiguredLabel(String provider) {
    return '$provider not yet configured';
  }

  @override
  String get mcpAddNew => 'add new';

  @override
  String get mcpDeny => 'deny';

  @override
  String get mcpAuthorize => 'authorize';

  @override
  String get actionAdd => 'add';

  @override
  String get toolPermissionsScreenTitle => 'tool permissions';

  @override
  String get toolPermissionsRulesRegistry => 'permission rules';

  @override
  String get toolPermissionsNoRules => 'no rules configured';

  @override
  String get toolPermissionsAddRuleTitle => 'add permission rule';

  @override
  String get toolPermissionsToolNameLabel => 'tool name';

  @override
  String get toolPermissionsAllowLabel => 'allow';

  @override
  String get toolPermissionsAskLabel => 'ask';

  @override
  String get toolPermissionsDenyLabel => 'deny';

  @override
  String get toolPermissionsAddRuleButton => 'add rule';

  @override
  String get notificationSettingsScreenTitle => 'notifications';

  @override
  String get notificationSettingsChatReplyLabel => 'chat replies';

  @override
  String get notificationSettingsScheduleLabel => 'scheduled tasks';

  @override
  String get notificationSettingsTaskCompleteLabel => 'task complete';

  @override
  String get notificationSettingsTaskErrorLabel => 'task errors';

  @override
  String get notificationSettingsPoco =>
      'I can notify you when an agent needs approval or finishes a task, even when PocketCoder is not open. Your phone will ask for permission before I enable alerts on this device.';

  @override
  String get notificationSettingsEnableDevice => 'enable on this device';

  @override
  String get skillsTitle => 'skills';

  @override
  String get skillsRegistryTitle => 'skills registry';

  @override
  String get skillsGlobalSection => 'global';

  @override
  String get skillsProjectSection => 'project';

  @override
  String get skillsNoSkills => 'no skills configured';

  @override
  String get skillsAddButton => 'add skill';

  @override
  String get skillsEditButton => 'edit';

  @override
  String get skillsDeleteButton => 'delete';

  @override
  String get skillsSaveButton => 'save';

  @override
  String get skillsNameLabel => 'name';

  @override
  String get skillsDescriptionLabel => 'description';

  @override
  String get skillsContentLabel => 'content';

  @override
  String get skillsGlobalLabel => 'global';

  @override
  String get skillsProjectLabel => 'project';

  @override
  String get skillsAddDialogTitle => 'add skill';

  @override
  String skillsEditDialogTitle(String name) {
    return 'edit: $name';
  }

  @override
  String get skillsNoEligibleConfig =>
      'No agent config has a workspace folder configured.';

  @override
  String get skillsBuiltInLabel => 'built-in';

  @override
  String get schedulerTitle => 'scheduler';

  @override
  String get schedulerRegistryTitle => 'scheduled tasks';

  @override
  String get schedulerNoSchedules => 'no schedules configured';

  @override
  String get schedulerAddButton => 'add schedule';

  @override
  String get schedulerEditButton => 'edit';

  @override
  String get schedulerDeleteButton => 'delete';

  @override
  String get schedulerSaveButton => 'save';

  @override
  String get schedulerPauseButton => 'pause';

  @override
  String get schedulerResumeButton => 'resume';

  @override
  String get schedulerRunNowButton => 'run now';

  @override
  String get schedulerNameLabel => 'name';

  @override
  String get schedulerCronLabel => 'cron expression';

  @override
  String get schedulerPromptLabel => 'prompt';

  @override
  String get schedulerAddDialogTitle => 'add schedule';

  @override
  String schedulerEditDialogTitle(String name) {
    return 'edit: $name';
  }

  @override
  String get schedulerPausedBadge => 'paused';

  @override
  String get schedulerRunningBadge => 'running';

  @override
  String get settingsTitle => 'configure';

  @override
  String get settingsAiAgentsSection => 'agents & access';

  @override
  String get settingsReportAiContentLabel => 'report AI content';

  @override
  String get settingsSystemSection => 'system';

  @override
  String get settingsAccountSection => 'account';

  @override
  String get settingsMenuLlmManagement => 'llm management';

  @override
  String get settingsMenuAgentRegistry => 'agent registry';

  @override
  String get settingsMenuMcpManagement => 'MCP management';

  @override
  String get settingsMenuSkills => 'skills';

  @override
  String get settingsMenuToolPermissions => 'tool permissions';

  @override
  String get settingsMenuHarnessConnections => 'harness connections';

  @override
  String get settingsMenuSystemChecks => 'system checks';

  @override
  String get settingsMenuPocketMemory => 'pocket memory';

  @override
  String get settingsMenuPocketbase => 'PocketBase';

  @override
  String get settingsMenuScheduler => 'scheduler';

  @override
  String get settingsMenuNotifications => 'notifications';

  @override
  String get settingsMenuLogout => 'logout';

  @override
  String get settingsMenuReset => 'reset';

  @override
  String get settingsMenuHapticFeedback => 'haptic feedback';

  @override
  String get settingsLogoutConfirmTitle => 'sign out';

  @override
  String get settingsLogoutConfirmBody =>
      'This will end your current session. You will need to log in again to continue.';

  @override
  String get settingsLogoutCancel => 'cancel';

  @override
  String get settingsLogoutConfirm => 'sign out';

  @override
  String get settingsFactoryResetConfirmTitle => 'reset';

  @override
  String get settingsFactoryResetConfirmBody =>
      'This clears the saved session and local deployment state so you can connect to another instance. It does not delete your cloud server.';

  @override
  String get settingsFactoryResetCancel => 'cancel';

  @override
  String get settingsFactoryResetConfirm => 'reset';

  @override
  String get settingsDeleteProDataLabel => 'delete PocketCoder Pro data';

  @override
  String get settingsDeleteProDataConfirmTitle => 'delete pro data';

  @override
  String get settingsDeleteProDataConfirmBody =>
      'This removes your subscription and notification records from PocketCoder Pro\'s systems. Your server and everything on it are unaffected -- use your own SSH access if you want to wipe that too.';

  @override
  String get settingsDeleteProDataCancel => 'cancel';

  @override
  String get settingsDeleteProDataConfirm => 'delete';

  @override
  String get agentTitle => 'agent registry';

  @override
  String get agentModelsPersonas => 'models & personas';

  @override
  String get agentSearching => 'Searching...';

  @override
  String get agentRegistryEmpty => 'Registry empty.';

  @override
  String get agentSelectToConfigure => 'select agent to configure';

  @override
  String agentDialogTitle(String name) {
    return 'agent: $name';
  }

  @override
  String get agentNameLabel => 'name';

  @override
  String get agentDescriptionLabel => 'description';

  @override
  String get agentPromptsLabel => 'prompts';

  @override
  String get agentModelsLabel => 'models';

  @override
  String get agentParametersLabel => 'parameters';

  @override
  String get agentNone => 'none';

  @override
  String get agentNoneSelected => 'none selected';

  @override
  String get agentDefaultTuned => 'default [tuned]';

  @override
  String get agentPlanPanelBadge => '[plan]';

  @override
  String get agentPlanPanelLabel => 'plan';

  @override
  String get agentConfigTitle => 'agent configuration';

  @override
  String get agentConfigRegistry => 'agent configs';

  @override
  String get agentConfigEmpty => 'no agent configs yet';

  @override
  String agentConfigDialogTitle(String name) {
    return 'agent config: $name';
  }

  @override
  String get agentConfigNameLabel => 'name';

  @override
  String get agentConfigPromptLabel => 'system prompt';

  @override
  String get agentConfigModeLabel => 'mode';

  @override
  String get agentConfigIsDefaultLabel => 'is default';

  @override
  String get agentConfigNoPrompts => 'no prompts available';

  @override
  String get agentConfigNoModes => 'no modes available';

  @override
  String get agentConfigSelectPrompt => 'select prompt';

  @override
  String get agentConfigSelectMode => 'select mode';

  @override
  String get agentConfigDelete => 'delete';

  @override
  String get agentConfigDeleteConfirmTitle => 'Delete config?';

  @override
  String agentConfigDeleteConfirmBody(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get agentConfigDefaultBadge => '[ default ]';

  @override
  String agentConfigErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get providerScreenTitle => 'provider management';

  @override
  String get providerScreenLoading => 'loading providers';

  @override
  String get providerScreenHarnessModelsSection => 'harness models';

  @override
  String get providerScreenApiKeysSection => 'API keys';

  @override
  String get providerScreenNoHarnessModels => 'no harness models listed';

  @override
  String providerScreenHarnessModelCount(int count) {
    return '$count models';
  }

  @override
  String providerScreenBrowseAllModels(int count) {
    return 'browse all $count models';
  }

  @override
  String get providerScreenNoApiKeys => 'no API keys configured';

  @override
  String get providerScreenEmptyHint => 'no harness models or API keys yet';

  @override
  String get providerScreenAddKey => 'add key';

  @override
  String get providerScreenUpdateKey => 'update key';

  @override
  String providerScreenAddKeyTitle(String provider) {
    return 'API key: $provider';
  }

  @override
  String providerScreenAddKeyBody(String provider) {
    return 'Enter credentials for $provider:';
  }

  @override
  String get providerScreenSelectProvider => 'select provider';

  @override
  String get providerScreenNoProviders => 'no providers available';

  @override
  String get providerScreenSearchLabel => 'search';

  @override
  String get providerScreenSearchHint => 'Filter providers';

  @override
  String get providerScreenSearchNoMatches => 'no matching providers';

  @override
  String get providerScreenDefaultBadge => '[ default ]';

  @override
  String providerScreenErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get providerScreenApiKeyLabel => 'API key';

  @override
  String get providerScreenApiKeyLeaveBlankHint =>
      'Leave blank to keep the existing key';

  @override
  String get providerScreenApiKeyNotSet => '(not set)';

  @override
  String get providerScreenApiKeyStoredSecurely =>
      'Existing key is stored securely; enter a new key to replace it.';

  @override
  String get providerScreenProviderLabel => 'provider';

  @override
  String get providerScreenDeleteKeyAction => 'delete';

  @override
  String get toolPermissionsTitle => 'gatekeeper configuration';

  @override
  String get toolPermissionsFrameTitle => 'tool permissions';

  @override
  String get toolPermissionsLoading => 'loading permissions';

  @override
  String get toolPermissionsEmpty => 'No permissions defined.';

  @override
  String get toolPermissionsAdd => 'add permission';

  @override
  String get toolPermissionsScopeAgent => 'agent';

  @override
  String get toolPermissionsScopeGlobal => 'global';

  @override
  String get toolPermissionsAddTitle => 'add tool permission';

  @override
  String get toolPermissionsToolLabel => 'TOOL (e.g. bash, edit, cao_*)';

  @override
  String get toolPermissionsPatternLabel => 'PATTERN (e.g. *, git *, rm *)';

  @override
  String get toolPermissionsActionLabel => 'action:';

  @override
  String get terminalTitle => 'terminal mirror';

  @override
  String get terminalTransfer => 'transfer';

  @override
  String get terminalReconnect => 'reconnect';

  @override
  String get terminalConnecting => 'establishing SSH link';

  @override
  String get terminalConnectionFailed => 'connection failed';

  @override
  String get terminalRetry => 'retry connection';

  @override
  String get terminalSftpTitle => 'SFTP transfer';

  @override
  String get terminalDestinationPath => 'destination path';

  @override
  String get terminalUpload => 'upload';

  @override
  String get terminalConnectionStatus => 'connection_status';

  @override
  String terminalSshLink(String host, String port) {
    return 'SSH link: $host:$port';
  }

  @override
  String get terminalOnline => 'online';

  @override
  String get terminalOffline => 'offline';

  @override
  String get monitorTitle => 'monitor';

  @override
  String get monitorTelemetryUnavailable => 'telemetry unavailable';

  @override
  String get fileTitle => 'source output manifest';

  @override
  String get fileDashboardAction => 'dashboard';

  @override
  String get fileClearAction => 'clear';

  @override
  String get fileNoFileSelected => 'No file selected.';

  @override
  String get fileSelectFromChat => '>> select from chat to view';

  @override
  String get fileFetching => 'Fetching data...';

  @override
  String get fileEmpty => 'empty file';

  @override
  String get systemChecksTitle => 'system checks';

  @override
  String get systemChecksDiagnostics => 'system diagnostics';

  @override
  String get systemChecksEmpty => 'no diagnostics available';

  @override
  String get observabilityRegistry => 'registry';

  @override
  String get observabilityLogTerminal => 'system log terminal';

  @override
  String get observabilitySelectContainer =>
      '>> select container for log stream';

  @override
  String get proTitle => 'PocketCoder Pro';

  @override
  String get proPlanTitle => 'unlock all systems';

  @override
  String get proCheckingStatus => 'Checking pro status...';

  @override
  String get proUnlockCommand => '\$ unlock --all';

  @override
  String get proSummary =>
      'One subscription. Every PocketCoder Pro capability.';

  @override
  String get proFeatureReady => '[OK]';

  @override
  String get proFeatureDeploy => 'provision and deploy PocketCoder servers';

  @override
  String get proFeaturePush => 'receive hosted agent notifications';

  @override
  String get proFeatureConsole => 'use pro console controls as they ship';

  @override
  String proTrialDuration(int days) {
    return '$days days free';
  }

  @override
  String get proTrialNoPaymentInfo =>
      'Starts a free week. No payment info is collected now.';

  @override
  String get proTrialLapseExplainer =>
      'If you do not keep pro, only hosted push notifications stop. Your server keeps running.';

  @override
  String proPrice(String price) {
    return '$price';
  }

  @override
  String proPriceAfterTrial(String price) {
    return 'then $price';
  }

  @override
  String proPricePerWeek(String price) {
    return '$price / week';
  }

  @override
  String proPricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String proPricePerYear(String price) {
    return '$price / year';
  }

  @override
  String proStartTrial(int days) {
    return 'start $days-day free trial';
  }

  @override
  String get proSubscribe => 'unlock PocketCoder Pro';

  @override
  String get proContinueSetup => 'continue setup';

  @override
  String get proRestore => 'restore purchases';

  @override
  String get proManageSubscription => 'manage subscription';

  @override
  String proTerms(String price) {
    return 'Subscription renews at $price Until cancelled. Manage or cancel in your app store account.';
  }

  @override
  String proTrialTerms(int days, String price) {
    return 'Free for $days Days, then $price Until cancelled. Manage or cancel in your app store account.';
  }

  @override
  String get proTermsOfServiceLink => 'terms of service';

  @override
  String get proPrivacyPolicyLink => 'privacy policy';

  @override
  String get proBenefitServerSetup =>
      'one-tap server setup -- no manual VPS configuration';

  @override
  String get proBenefitPushNotifications =>
      'push notifications for agent activity -- approvals, task completion';

  @override
  String get proBenefitLiveMonitoring => 'live agent monitoring';

  @override
  String get proActive => '> entitlement: active';

  @override
  String get proActiveBody =>
      'PocketCoder Pro is active. Deployment and hosted notifications are unlocked.';

  @override
  String get proUnavailable => '> offering: unavailable';

  @override
  String get proUnavailableBody =>
      'The app store could not return the PocketCoder Pro subscription. Check your connection or restore an existing purchase.';

  @override
  String get proSelfHostedPushTitle => 'self-hosted notifications';

  @override
  String get proSelfHostedPushBody =>
      'You can connect your own Ntfy or UnifiedPush distributor without PocketCoder Pro.';

  @override
  String get proConfigureSelfHostedPush => 'configure self-hosted push';

  @override
  String get proSettingsLabel => 'PocketCoder Pro';

  @override
  String get proSettingsStatus => '[status]';

  @override
  String get chooseProviderTitle => 'choose provider';

  @override
  String get deploySelectProvider => 'select provider';

  @override
  String get deployChooseProvider => 'choose where to deploy your instance';

  @override
  String get chooseProviderProBadge => 'pro';

  @override
  String get chooseProviderComingSoon => 'coming soon';

  @override
  String get pocketCoderProgressProvisionServer => 'provision server';

  @override
  String get pocketCoderProgressDeployPocketCoder => 'deploy PocketCoder';

  @override
  String get pocketCoderProgressWaiting => 'waiting';

  @override
  String get pocketCoderProgressActive => 'active';

  @override
  String get pocketCoderProgressComplete => 'done';

  @override
  String get pocketCoderProgressFailed => 'FAILED';

  @override
  String get pocketCoderProgressInitializing => 'initializing';

  @override
  String get deploymentStepCreateInstance => 'Creating server';

  @override
  String get deploymentStepPlanLookup => 'Looking up plan details';

  @override
  String get deploymentStepCreateInstallerDisk => 'Preparing installer disk';

  @override
  String get deploymentStepWaitInstallerDiskReady =>
      'Waiting for installer disk';

  @override
  String get deploymentStepCreateTargetDisk => 'Preparing target disk';

  @override
  String get deploymentStepWaitTargetDiskReady => 'Waiting for target disk';

  @override
  String get deploymentStepCreateInstallerConfig =>
      'Configuring installer boot';

  @override
  String get deploymentStepBootInstaller => 'Booting installer';

  @override
  String get deploymentStepWaitInstallerCompletion =>
      'Installing operating system';

  @override
  String get deploymentStepRemoveInstallerResources => 'Cleaning up installer';

  @override
  String get deploymentStepCreateFinalConfig => 'Configuring server boot';

  @override
  String get deploymentStepPreBootShutdown => 'Restarting server';

  @override
  String get deploymentStepBootFinal => 'Booting server';

  @override
  String get deploymentStepFinalInstanceFetch => 'Confirming server is up';

  @override
  String get deploymentStepEnableWatchdog => 'Re-enabling server monitoring';

  @override
  String get deploymentStepWaitingForConnection => 'Connecting to server';

  @override
  String get deploymentStepConfiguringOperatingSystem =>
      'Configuring operating system';

  @override
  String get deploymentStepFetchingRelease => 'Fetching PocketCoder release';

  @override
  String get deploymentStepLoadingImages => 'Loading container images';

  @override
  String get deploymentStepComposeUp => 'Starting services';

  @override
  String get deploymentStepBootstrapComplete => 'Finishing setup';

  @override
  String get deploymentStepReady => 'Ready';

  @override
  String get initializationScreenTitle => 'initializing server';

  @override
  String get initializationActionAbort => 'abort';

  @override
  String get initializationActionRetry => 'retry';

  @override
  String get initializationUnknown => 'unknown';

  @override
  String get initializationTechnicalDetailsToggle => 'technical details';

  @override
  String get initializationNetworkIp => 'network IP';

  @override
  String get initializationGeoGrid => 'geo grid';

  @override
  String initializationFaultDetected(Object error) {
    return 'fault detected: $error';
  }

  @override
  String get initializationFaultGeneric =>
      'Setup could not continue. Return and try again.';

  @override
  String get initializationFaultProvisionInterruptedNoResource =>
      'Provisioning was interrupted before a provider resource was recorded. Return to configuration to retry or reset local initialization state.';

  @override
  String get initializationFaultProvisionResourceStillExists =>
      'Provisioning was interrupted after a provider resource was created. The resource still exists and was not recreated automatically. Use cleanup or resume from the provider account before trying again.';

  @override
  String get initializationFaultProvisionResourceNotFound =>
      'The tracked provider resource is no longer found in your account. It may have been deleted outside the app. Use Reset Deployment State to clear local state, or re-deploy from configuration.';

  @override
  String get deploymentFaultDeploymentInstanceNotFound =>
      'The tracked deployment instance is no longer found in your provider account. It may have been deleted outside the app. Use Reset Deployment State to clear local state, or re-deploy from configuration.';

  @override
  String get initializationFaultResourceAlreadyExists =>
      'A provider resource already exists. Retrying provisioning could create a duplicate billable resource. Use Reset/Cleanup/Resume instead.';

  @override
  String get initializationFaultAuthenticationExpired =>
      'Your Linode connection has expired or was revoked. Reconnect your account, then restart the initialization.';

  @override
  String initializationFaultMaxRetriesExceeded(Object maxAttempts) {
    return 'Max retry attempts ($maxAttempts) exceeded.';
  }

  @override
  String get initializationFailed =>
      'Setup could not continue. Return and try again.';

  @override
  String initializationReady(Object ipAddress) {
    return 'Server ready at $ipAddress.';
  }

  @override
  String get initializationInProgress => 'Server setup started.';

  @override
  String get deploymentStatusValidating => 'validating configuration';

  @override
  String get deploymentStatusConstructing => 'constructing instance';

  @override
  String get deploymentStatusPreparingOperatingSystem => 'preparing OS';

  @override
  String get deploymentStatusSecuring => 'securing connection';

  @override
  String get deploymentStatusTlsReady => 'connection secured';

  @override
  String get deploymentStatusTlsZeroSsl => 'using backup certificate authority';

  @override
  String get deploymentStatusTlsRateLimited =>
      'certificate authority rate limited';

  @override
  String get deploymentStatusTlsFailed => 'certificate issuance failed';

  @override
  String get deploymentStatusConfiguringOperatingSystem => 'configuring OS';

  @override
  String get deploymentStatusFetching => 'fetching release';

  @override
  String get deploymentStatusLoadingImages => 'loading images';

  @override
  String get deploymentStatusStarting => 'starting services';

  @override
  String get deploymentStatusFinishing => 'finishing up';

  @override
  String get deploymentStatusReady => 'handshake successful';

  @override
  String get deploymentStatusFailed => 'deployment aborted';

  @override
  String get initializationStatusInitializing => 'initializing stack';

  @override
  String get deploymentDescriptionValidating =>
      'Checking the provisioning configuration.';

  @override
  String get deploymentDescriptionConstructing =>
      'Allocating hardware resources on cloud grid.';

  @override
  String get deploymentDescriptionPreparingOperatingSystem =>
      'Preparing the operating system.';

  @override
  String get deploymentDescriptionSecuring =>
      'Waiting for the native reverse proxy.';

  @override
  String get deploymentDescriptionTlsReady =>
      'A browser-trusted certificate is active.';

  @override
  String get deploymentDescriptionTlsZeroSsl =>
      'Issued via the backup authority after the primary was unavailable.';

  @override
  String get deploymentDescriptionTlsRateLimited =>
      'Retrying automatically with a backup certificate authority.';

  @override
  String get deploymentDescriptionTlsFailed =>
      'The reverse proxy could not obtain a certificate.';

  @override
  String get deploymentDescriptionConfiguringOperatingSystem =>
      'Preparing native services and dependencies.';

  @override
  String get deploymentDescriptionFetching => 'Fetching the immutable release.';

  @override
  String get deploymentDescriptionLoadingImages =>
      'Loading the verified image bundle.';

  @override
  String get deploymentDescriptionStarting => 'Starting application services.';

  @override
  String get deploymentDescriptionFinishing => 'Finishing deployment.';

  @override
  String get deploymentDescriptionReady => 'The server is fully operational.';

  @override
  String get deploymentDescriptionFailed =>
      'Setup stopped before completion. No later step will continue.';

  @override
  String get initializationDescriptionInitializing =>
      'Preparing initialization manifest.';

  @override
  String initializationStatusPrefix(Object status) {
    return 'status: $status';
  }

  @override
  String get initializationSecure => '[secure]';

  @override
  String get initializationConnectionParameters => 'connection parameters';

  @override
  String get initializationMetadataRegistry => 'metadata registry';

  @override
  String get initializationActionLogin => 'login';

  @override
  String get deploymentActionRefresh => 'refresh';

  @override
  String get deploymentActionUpdate => 'update';

  @override
  String get deploymentActionDismiss => 'dismiss';

  @override
  String get initializationInstanceManifest => 'instance manifest';

  @override
  String get initializationIpAddress => 'IP address';

  @override
  String get initializationHttpsEndpoint => 'HTTPS endpoint';

  @override
  String get initializationAdminIdentity => 'admin identity';

  @override
  String get initializationAdminPassword => 'admin password';

  @override
  String get initializationNotAvailable => 'n/a';

  @override
  String get initializationCopyAction => 'copy';

  @override
  String get initializationHideAction => 'hide';

  @override
  String get initializationShowAction => 'show';

  @override
  String get deploymentProvisioned => 'provisioned';

  @override
  String get initializationCloudRegion => 'cloud region';

  @override
  String get initializationHardwarePlan => 'hardware plan';

  @override
  String get initializationSecurityNotice =>
      'Security notice: credentials are stored in local secure enclave. Passphrase retains encryption at rest.';

  @override
  String initializationCopiedToBuffer(Object label) {
    return '$label copied to buffer';
  }

  @override
  String initializationCopyLabel(Object label) {
    return 'copy $label';
  }

  @override
  String get deploymentManifestConfiguration => 'manifest configuration';

  @override
  String get deploymentActionBack => 'back';

  @override
  String get deploymentActionDeployInstance => 'deploy instance';

  @override
  String get deploymentActionInitialize => 'initialize';

  @override
  String get deploymentSystemParameters => 'system parameters';

  @override
  String get deploymentHardwareGeography => 'hardware & geography';

  @override
  String get deploymentInitializingHardware => 'Initializing HW registry...';

  @override
  String get deploymentScanningRegions => 'Scanning global regions...';

  @override
  String get deploymentCodingHarnesses => 'coding harnesses';

  @override
  String get deploymentHarnessSelectionDescription =>
      'Choose what is downloaded onto your VPS. Goose is ready by default; you can select more than one.';

  @override
  String get deploymentOperatingSystem => 'operating system';

  @override
  String get deploymentInstancePlan => 'instance plan';

  @override
  String deploymentMonthlyPrice(String price) {
    return '$price/mo';
  }

  @override
  String get deploymentRegion => 'deployment region';

  @override
  String get deploymentBackend => 'backend';

  @override
  String get deploymentDistribution => 'distribution';

  @override
  String get deploymentNixos => 'NixOS';

  @override
  String get deploymentStandardLinux => 'Standard Linux';

  @override
  String get deploymentDebian => 'Debian';

  @override
  String get deploymentUbuntu => 'Ubuntu';

  @override
  String get deploymentSetupTypeTitle => 'choose your setup';

  @override
  String get deploymentServerSizeTitle => 'choose your server size';

  @override
  String get deploymentServerRegionTitle => 'choose your server region';

  @override
  String get deploymentCodingAgentsTitle => 'choose coding agents';

  @override
  String get deploymentLinuxSystemTitle => 'Linux system';

  @override
  String get deploymentReviewTitle => 'review your server';

  @override
  String get deploymentWorkloadPoco =>
      'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.';

  @override
  String get deploymentWorkloadCloudReply =>
      'Cloud models run inference through your online AI account. Your server mainly needs room for PocketCoder, your agents, and your projects.\n\nI\'ll show the minimum server size I recommend. You can choose a larger one.';

  @override
  String get deploymentWorkloadLocalReply =>
      'A local model runs on your own server through Ollama. It needs more computing power, and is usually faster with a GPU.\n\nI\'ll show the minimum server size I recommend. You can choose a larger one.';

  @override
  String get deploymentUseCloudModels => 'use cloud models';

  @override
  String get deploymentRunLocalModel => 'run a local model';

  @override
  String deploymentPlanPoco(String minimumMemory) {
    return 'The $minimumMemory option is the minimum for remote models. Choose it or go larger for builds, tests, and updates.';
  }

  @override
  String get deploymentRegionPoco =>
      'Choose where your server will live. A nearby region will usually respond faster, but you can use any available Linode region.';

  @override
  String get deploymentHarnessPoco =>
      'Now choose which coding agents to have ready on your server.\n\nThis installs their software. You\'ll connect any required accounts after your server is ready.';

  @override
  String get deploymentLinuxPoco =>
      'PocketCoder deploys on NixOS -- chosen for reproducible, deterministic builds.';

  @override
  String get deploymentReviewPoco =>
      'Your server is ready to be provisioned.\n\nPocketCoder will create it in your Linode account, then install the coding agents you selected. Linode will bill you directly for the server.';

  @override
  String get deploymentNoSuitablePlans =>
      'No suitable server sizes are available for this setup.';

  @override
  String get deploymentMinimum => 'minimum';

  @override
  String get deploymentRecommended => 'recommended';

  @override
  String get deploymentGpuBadge => 'GPU';

  @override
  String get deploymentDefaultAgent => 'ready by default';

  @override
  String deploymentPlanSpecs(int vcpus, String memory, int diskGb) {
    return '$vcpus CPU · $memory RAM · $diskGb GB disk';
  }

  @override
  String deploymentMemoryGb(int value) {
    return '$value GB';
  }

  @override
  String deploymentMemoryMb(int value) {
    return '$value MB';
  }

  @override
  String get deploymentNixosDescription =>
      'A repeatable server setup that is easier to recreate and roll back if a system change goes wrong.';

  @override
  String get deploymentDebianDescription =>
      'A Debian server configured with setup scripts. Faster to set up.';

  @override
  String get deploymentProvisioningSummary => 'provisioning summary';

  @override
  String get deploymentServerProvider => 'server provider';

  @override
  String get deploymentProviderLinode => 'Linode';

  @override
  String get deploymentProviderFake => 'fake';

  @override
  String get deploymentConfigNotReadyError =>
      'Deployment is not ready yet — configuration is still loading.';

  @override
  String deploymentAdminPasswordTooShort(int minLength) {
    return 'The admin password must be at least $minLength characters.';
  }

  @override
  String walkthroughLabel(int current, int total) {
    return 'walkthrough $current/$total';
  }

  @override
  String briefLabel(int current, int total) {
    return 'brief $current/$total';
  }

  @override
  String get walkthroughAskPoco => 'ask Poco';

  @override
  String get walkthroughActionSkip => 'skip';

  @override
  String get walkthroughBriefDivider => 'brief';

  @override
  String get walkthroughTransitionProvisioning =>
      'Let\'s follow this next part of the server setup together.';

  @override
  String get walkthroughTransitionDeployment =>
      'Now we\'ll follow the verified release onto the host.';

  @override
  String initializationSyncAttempt(Object attempt) {
    return 'sync attempt: $attempt';
  }

  @override
  String get initializationCurrentOperation => 'current operation';

  @override
  String get initializationSourceCommit => 'source commit';

  @override
  String get initializationRunId => 'initialization run';

  @override
  String get initializationStatusSchema => 'status schema';

  @override
  String get initializationLastSignal => 'last server signal';

  @override
  String get initializationErrorCode => 'server error code';

  @override
  String get pocoProvisioningTourTitle => 'Poco walkthrough';

  @override
  String get pocoProvisioningWaitingForSource =>
      'I am waiting for your VPS to report its exact source commit. Once it does, I can show you the code actually being installed.';

  @override
  String get pocoProvisioningLoadingSource =>
      'I found the exact release commit. I am fetching its public provisioning code so we can inspect it together.';

  @override
  String get pocoProvisioningSourceUnavailable =>
      'The deployment is still running, but I could not load its annotated source right now. This lesson is optional and never blocks your VPS.';

  @override
  String get pocoProvisioningFailed =>
      'The setup stopped, so I stopped the walkthrough too. Go back to review the configuration, then we can try again.';

  @override
  String get pocoProvisioningPrevious => 'previous';

  @override
  String get pocoProvisioningNext => 'next';

  @override
  String get pocoProvisioningShowFull => 'show full snippet';

  @override
  String get pocoProvisioningShowConcise => 'show preview';

  @override
  String get pocoLessonVpsStorageTitle => 'Your VPS disk';

  @override
  String get pocoLessonVpsStorageExplanation =>
      'The release image is only the starting shape of the server. This tells NixOS to expand its filesystem so PocketCoder can use the full disk you rented.';

  @override
  String get pocoLessonPublicFirewallTitle => 'The public firewall';

  @override
  String get pocoLessonPublicFirewallExplanation =>
      'A firewall is a guest list for network traffic. This VPS exposes only SSH and web traffic; everything else is refused by default.';

  @override
  String get pocoLessonContainerFirewallTitle => 'The container firewall';

  @override
  String get pocoLessonContainerFirewallExplanation =>
      'Docker has its own traffic path, so the host firewall alone is not enough. These rules apply the same boundaries to containers and block access to cloud metadata credentials.';

  @override
  String get pocoLessonSshTitle => 'Key-only administration';

  @override
  String get pocoLessonSshExplanation =>
      'SSH is the emergency and administration door to your VPS. PocketCoder disables password login, requires your cryptographic key, and temporarily bans repeated guessing attempts.';

  @override
  String get pocoLessonDockerTitle => 'Getting the OS ready';

  @override
  String get pocoLessonDockerExplanation =>
      'NixOS enables the Docker engine that will run every PocketCoder component. The VPS then receives its owner settings once, stores them in a protected file, installs your SSH key, and removes the temporary copy used during first boot.';

  @override
  String get pocoLessonOwnerConfigTitle => 'Receiving your configuration';

  @override
  String get pocoLessonOwnerConfigExplanation =>
      'Your VPS receives its owner settings once, stores them in a protected file, installs your SSH key, and removes the temporary copy used during first boot.';

  @override
  String get pocoLessonLocalSecretsTitle => 'Host-local secrets';

  @override
  String get pocoLessonLocalSecretsExplanation =>
      'Internal services need private handshake secrets. The VPS creates random values locally instead of sending those secrets through the app or committing them to GitHub.';

  @override
  String get pocoLessonReleaseSourceTitle => 'Activating the verified release';

  @override
  String get pocoLessonReleaseSourceExplanation =>
      'The server checks out the exact release commit, verifies every container image\'s signature, prepares fresh internal secrets, and starts the stack — writing a completion marker only once a real health check succeeds.';

  @override
  String get pocoLessonVerifiedImagesTitle => 'Verified container images';

  @override
  String get pocoLessonVerifiedImagesExplanation =>
      'The VPS downloads prebuilt container images and checks their SHA-256 fingerprint before loading them. A missing, incomplete, or modified bundle stops deployment instead of silently building something different.';

  @override
  String get pocoLessonComposeStartTitle => 'Starting the stack';

  @override
  String get pocoLessonComposeStartExplanation =>
      'Docker Compose starts the verified images in the background without rebuilding them. PocketCoder then writes a completion marker, while the app independently waits for a real health response.';

  @override
  String get pocoLessonPocketbaseTitle => 'The application core';

  @override
  String get pocoLessonPocketbaseExplanation =>
      'PocketBase is the control plane and application database. Its port is bound only to the VPS itself, so public requests must pass through the encrypted reverse proxy.';

  @override
  String get pocoLessonAgentTitle => 'The private coding agent';

  @override
  String get pocoLessonAgentExplanation =>
      'Goose is the coding-agent process. It has no public host port and talks to PocketBase over a private, authenticated network created just for that relationship.';

  @override
  String get pocoLessonLocalModelTitle => 'Local model runtime';

  @override
  String get pocoLessonLocalModelExplanation =>
      'Ollama can run models on your own VPS. Its model files survive restarts, and its private networks separate inference traffic from model-management traffic.';

  @override
  String get pocoLessonHarnessImagesTitle => 'On-demand coding harnesses';

  @override
  String get pocoLessonHarnessImagesExplanation =>
      'These entries define images for supported coding tools. They are prepared during release creation but do not run until you choose that harness inside PocketCoder.';

  @override
  String get pocoLessonMcpSandboxTitle => 'Controlled tool access';

  @override
  String get pocoLessonMcpSandboxExplanation =>
      'The MCP gateway gives agents tools, but it reaches Docker through a restricted proxy. The allowlist grants only the operations that tool containers actually need.';

  @override
  String get pocoLessonMemoryTitle => 'Optional agent memory';

  @override
  String get pocoLessonMemoryExplanation =>
      'Pocket Memory is an always-on local service. Agents write observations and interpretations directly, and semantic recall stays on your own server.';

  @override
  String get pocoLessonPocketbaseDockerAccessTitle => 'Limited Docker control';

  @override
  String get pocoLessonPocketbaseDockerAccessExplanation =>
      'PocketBase sometimes needs to inspect or restart trusted containers. This second socket proxy gives it a smaller permission set than the tool gateway receives.';

  @override
  String get pocoLessonDashboardTitle => 'Your local dashboard';

  @override
  String get pocoLessonDashboardExplanation =>
      'SQLPage reads operational databases through read-only mounts and turns them into a private dashboard. An initialization step makes optional data sources safe to query before they exist.';

  @override
  String get pocoLessonNotificationsTitle => 'Optional notifications';

  @override
  String get pocoLessonNotificationsExplanation =>
      'Ntfy can provide a notification server that you own. It is behind an optional Compose profile, so it runs only when you deliberately enable it.';

  @override
  String get pocoLessonPrivateAccessTitle => 'Private remote access';

  @override
  String get pocoLessonPrivateAccessExplanation =>
      'Tailscale can connect the VPS to your private network without opening another public application port. Its identity is stored in a persistent volume.';

  @override
  String get pocoLessonLocalCaddyTitle => 'Alternative HTTPS proxy';

  @override
  String get pocoLessonLocalCaddyExplanation =>
      'Self-managed Docker installations can run Caddy as a container for automatic HTTPS. The supported NixOS VPS uses native host Caddy instead, so this profile stays off there.';

  @override
  String get pocoLessonVolumesTitle => 'Persistent data';

  @override
  String get pocoLessonVolumesExplanation =>
      'Containers are replaceable; volumes are the durable storage underneath them. Databases, workspaces, credentials, backups, and downloaded models live here across restarts and upgrades.';

  @override
  String get pocoLessonNetworksTitle => 'Private service networks';

  @override
  String get pocoLessonNetworksExplanation =>
      'Compose uses several small networks instead of one flat network. Each connection represents a specific trust relationship, limiting which services can reach one another.';

  @override
  String get onboardingNoServerLookingPoco =>
      'Looking for a PocketCoder server...';

  @override
  String get onboardingNoServerPoco =>
      'Are you already part of the PocketCoder Initiative?';

  @override
  String get onboardingNoServerChipExisting => 'Log in';

  @override
  String get onboardingNoServerChipNew => 'Join';

  @override
  String get onboardingWelcomeTitle => 'welcome';

  @override
  String get onboardingWelcomePoco =>
      'Welcome to the PocketCoder Initiative.\n\nI\'ll help you set up PocketCoder on a server—a computer that stays online. That way, PocketCoder is accessible and ready whenever you need it.';

  @override
  String get onboardingWelcomeActionGuided => 'Help me with setup';

  @override
  String get onboardingWelcomeActionSelfHost => 'I\'ll set it up';

  @override
  String get onboardingSelfHostTitle => 'self-host setup';

  @override
  String get onboardingSelfHostPoco =>
      'You\'ll set up PocketCoder on a server you control. The setup guide walks through preparing the server, deploying PocketCoder, and finding the address you\'ll use to connect this app.';

  @override
  String get onboardingSelfHostRequirementsTitle => 'what you\'ll need';

  @override
  String get onboardingSelfHostRequirementServer =>
      'a Linux server or VPS you control';

  @override
  String get onboardingSelfHostRequirementDocker => 'Docker compose v2';

  @override
  String get onboardingSelfHostRequirementAccess => 'SSH access to the server';

  @override
  String get onboardingSelfHostActionGuide => 'guide';

  @override
  String get onboardingSelfHostActionConnect => 'connect';

  @override
  String get onboardingSignInPoco =>
      'Welcome. We\'ll set up a server: a small computer that stays online and runs PocketCoder for you.\n\nStart by choosing the email and password you\'ll use to sign in when it\'s ready.';

  @override
  String get onboardingSignInTitle => 'set up your sign-in';

  @override
  String get onboardingServerCredentialsPoco =>
      'These are the administrator credentials for PocketCoder on the server we are about to provision.\n\nThey are separate from your Linode password. I will use them to finish setup, and you will use them to sign in to PocketCoder when the server is ready. Keep them safe.';

  @override
  String get onboardingPasswordTooShort => 'Must be at least 8 characters';

  @override
  String get onboardingProviderPoco =>
      'Okay, here are our options for who will host your server.\n\nA server provider gives it a computer and internet connection, then keeps it online.';

  @override
  String get onboardingProviderTitle => 'choose a server provider';

  @override
  String get onboardingProviderChipLinode => 'Linode';

  @override
  String get onboardingProviderChipElestioComingSoon => 'Elestio — coming soon';

  @override
  String onboardingTrialPoco(int trialDuration) {
    return 'Your server and AI accounts are yours, and each provider bills you directly. PocketCoder helps you connect and set everything up.\n\nPocketCoder Pro includes a $trialDuration-day free trial. It lets you provision servers and receive notifications from your agents. When the trial ends, your server keeps running exactly as it is.\n\nYour server provider may offer its own trial or credit as well.';
  }

  @override
  String get onboardingTrialChipStart => 'start free trial';

  @override
  String get onboardingTrialChipNotNow => 'not now';

  @override
  String get onboardingProviderAuthorizationPoco =>
      'Connect or create your server provider account. The next page will let you sign in or make one.\n\nWhen you authorize PocketCoder, it will provision a server and deploy PocketCoder on your behalf.';

  @override
  String get onboardingProviderAuthorizationTitle =>
      'connect your server provider';

  @override
  String get onboardingProviderAuthorizationAction => 'continue';

  @override
  String get onboardingProviderAuthorizationWaiting => 'connecting';

  @override
  String get onboardingProviderAuthorizationError => 'connection stopped';

  @override
  String get onboardingProviderAuthorizationCancelled =>
      'The provider sign-in was cancelled. Nothing was provisioned.';

  @override
  String get onboardingProviderAuthorizationFailed =>
      'I could not connect to the server provider. Check your connection and try again.';

  @override
  String get onboardingIntentPoco =>
      'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.';

  @override
  String get onboardingIntentChipCloudModels => 'use cloud models';

  @override
  String get onboardingIntentChipLocalModels => 'run a local model';

  @override
  String onboardingPlanPoco(String providerName) {
    return 'Here are the server sizes available from $providerName.\n\nThe highlighted option is the minimum I recommend for the setup you chose. You can select a larger server at any time.';
  }

  @override
  String get onboardingPlanTitle => 'choose your server size';

  @override
  String get onboardingRegionConsentPoco =>
      'I can find server regions near you, if you want.\n\nYour location stays on this phone. I only use it to sort the available regions by distance.';

  @override
  String get onboardingRegionConsentChipUseLocation => 'use my location';

  @override
  String get onboardingRegionConsentChipChooseMyself => 'I\'ll choose myself';

  @override
  String get onboardingRegionPoco =>
      'A region is the city where your server—and its data—will live. Choose one close to you, or to people who will use PocketCoder most.';

  @override
  String get onboardingRegionTitle => 'choose your server region';

  @override
  String get onboardingHarnessPoco =>
      'Now choose which coding agents to have ready on your server.\n\nA harness is the connection PocketCoder uses to work with a coding agent. This only installs the software; you\'ll connect any required accounts after your server is ready.';

  @override
  String get onboardingHarnessTitle => 'choose coding agents';

  @override
  String get onboardingOsPoco =>
      'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.';

  @override
  String get onboardingOsTitle => 'choose Linux system';

  @override
  String get onboardingOsNixosLabel => 'NixOS — recommended';

  @override
  String onboardingOsNixosDescription(int minutes) {
    return 'Repeatable server setup, easier to recreate and roll back if a system change goes wrong. Estimated about $minutes min.';
  }

  @override
  String get onboardingOsDebianLabel => 'Debian';

  @override
  String onboardingOsDebianDescription(int minutes) {
    return 'Debian server configured with setup scripts. Faster to set up: about $minutes min.';
  }

  @override
  String onboardingReviewPoco(String providerName) {
    return 'Your server is ready to be provisioned.\n\nPocketCoder will create it in your $providerName account, then install the coding agents you selected. Your provider bills you directly.';
  }

  @override
  String get onboardingReviewTitle => 'review your server';

  @override
  String get onboardingReviewActionProvision => 'provision server';

  @override
  String get onboardingProvisioningPoco =>
      'Provisioning is underway. While the new server comes online, welcome to PocketCoder Initiative orientation.\n\nI\'ll show you what we\'re building, one piece at a time.';

  @override
  String get onboardingOrientationTitle => 'initiative orientation';

  @override
  String get onboardingOrientationActionSkip => 'skip orientation';

  @override
  String get onboardingOrientationActionContinue => 'continue orientation';

  @override
  String get onboardingDockerIntroEyebrow => 'introduction';

  @override
  String get onboardingDockerIntroTitle => 'Docker and containers';

  @override
  String get onboardingDockerIntroPoco =>
      'PocketCoder is made of software components, such as its dashboard and coding agents. Docker runs each component in its own separate container on your server.';

  @override
  String get onboardingDockerIntroActionStart => 'start walkthrough';

  @override
  String get onboardingDockerIntroChipComponent => 'What is a component?';

  @override
  String get onboardingDockerIntroChipContainer => 'What is a container?';

  @override
  String get onboardingDockerIntroChipSavedData => 'What is saved data?';

  @override
  String get onboardingDockerIntroChipConnections => 'What are connections?';

  @override
  String get onboardingReadyPoco =>
      'Your PocketCoder server is ready.\n\nWelcome to the PocketCoder Initiative, Commander.\n\nYour server is online at its new HTTPS address. Your selected coding harnesses are ready.';

  @override
  String get onboardingReadyActionLogin => 'log in to PocketCoder';

  @override
  String onboardingFailureConnectionPoco(String providerName) {
    return 'I couldn\'t confirm that PocketCoder finished setting up.\n\nYour server is still available in your $providerName account.';
  }

  @override
  String get onboardingFailureActionRetryConnection => 'retry connection';

  @override
  String get onboardingFailureActionViewServerDetails => 'view server details';

  @override
  String get onboardingFailureCreatePoco =>
      'The server could not be created.\n\nNothing was deployed. Check your server provider connection, then try again.';

  @override
  String get onboardingFailureActionBackToSetup => 'back to setup';

  @override
  String get onboardingFailureActionTechnicalDetails =>
      'show technical details';

  @override
  String walkthroughHeader(String os, int current, int total) {
    return '$os server setup · walkthrough $current / $total';
  }

  @override
  String walkthroughProgress(int current, int total, String brief) {
    return 'walkthrough $current/$total · brief $brief';
  }

  @override
  String get walkthroughActionShowFullCode => 'show full code';

  @override
  String get walkthroughActionShowConciseCode => 'show concise code';

  @override
  String get walkthroughCaddyAddressTitle => 'your HTTPS address';

  @override
  String get walkthroughCaddyAddressPoco =>
      'First, the server finds its public IP address and turns it into an HTTPS address using sslip.io. PocketCoder saves that address so the mobile app knows where to sign in.';

  @override
  String get walkthroughCaddyAddressChipIpAddress => 'What is an IP address?';

  @override
  String get walkthroughCaddyAddressChipHttps => 'What is HTTPS?';

  @override
  String get walkthroughCaddyAddressChipSslip => 'What is sslip.io?';

  @override
  String get walkthroughCaddyWebEntryTitle => 'the secure web entry';

  @override
  String get walkthroughCaddyWebEntryPoco =>
      'Caddy runs directly on the server. It sends regular web traffic to HTTPS, shares PocketCoder\'s deployment status, and passes app requests to PocketBase without exposing PocketBase\'s own port.';

  @override
  String get walkthroughCaddyWebEntryChipCaddy => 'What is Caddy?';

  @override
  String get walkthroughCaddyWebEntryChipPrivatePort =>
      'Why is PocketBase\'s port private?';

  @override
  String get walkthroughNixosStorageTitle => 'your server disk';

  @override
  String get walkthroughNixosStoragePoco =>
      'This tells NixOS where PocketCoder\'s main disk is and lets it expand to use the full size of the server you chose. Without autoResize, it could stay stuck at the smaller size of its original image.';

  @override
  String get walkthroughNixosNetworkTitle => 'network boundaries';

  @override
  String get walkthroughNixosNetworkPoco =>
      'These rules open the three standard entry ports to your server: HTTP and HTTPS for the PocketCoder website, and SSH for secure remote access. Since PocketCoder runs inside Docker, it needs its own specific rules without opening extra entry ports to the internet.';

  @override
  String get walkthroughNixosNetworkChipPorts =>
      'What are HTTP, HTTPS, and SSH?';

  @override
  String get walkthroughNixosNetworkChipDockerRules =>
      'Why does Docker need its own rules?';

  @override
  String get walkthroughNixosNetworkChipIpVersions => 'What are IPv4 and IPv6?';

  @override
  String get walkthroughNixosSshTitle => 'key-only SSH';

  @override
  String get walkthroughNixosSshPoco =>
      'SSH is the secure way to administer a server from another device—even a phone. We accept only your SSH key—not passwords—and temporarily block repeated failed attempts.';

  @override
  String get walkthroughNixosDockerTitle => 'Docker';

  @override
  String get walkthroughNixosDockerPoco =>
      'This turns on Docker, the system that runs PocketCoder\'s containers. It sends their logs to NixOS\'s built-in system log, so there is one place to check what happened.';

  @override
  String get walkthroughServerKeyTitle => 'your server key';

  @override
  String get walkthroughServerKeyPoco =>
      'Before PocketCoder starts, this installs your public SSH key on the server. The mobile app keeps the matching private SSH key securely on your phone: the public key is the lock, and the private key is the key that opens it.';

  @override
  String get walkthroughServerKeyChipPrivate => 'What is a private SSH key?';

  @override
  String get walkthroughServerKeyChipPublic => 'What is a public SSH key?';

  @override
  String get walkthroughServerKeyChipSsh => 'What is SSH?';

  @override
  String get walkthroughVerifiedVersionTitle => 'verified PocketCoder version';

  @override
  String get walkthroughVerifiedVersionPoco =>
      'This downloads the exact PocketCoder version for your server, verifies it, then installs it.';

  @override
  String get walkthroughVerifiedVersionChipVerification =>
      'How is the version verified?';

  @override
  String get walkthroughVerifiedVersionChipDownloadFailure =>
      'What happens if the download fails?';

  @override
  String get walkthroughVerifiedVersionChipUpdates => 'Can I update later?';

  @override
  String get walkthroughStartPocketCoderTitle => 'start PocketCoder';

  @override
  String get walkthroughStartPocketCoderPoco =>
      'This starts the verified PocketCoder version with only the coding harnesses you chose.';

  @override
  String get walkthroughStartPocketCoderChipWhatStarts =>
      'What starts after this?';

  @override
  String get walkthroughStartPocketCoderChipAddHarness =>
      'Can I add a harness later?';

  @override
  String get walkthroughNixosDockerRulesTitle => 'Docker firewall rules';

  @override
  String get walkthroughNixosDockerRulesPoco =>
      'Docker needs its own rules because it manages a separate path for container traffic. These rules keep the same boundaries without opening extra entry ports.';

  @override
  String get walkthroughRuntimeSettingsTitle => 'local settings';

  @override
  String get walkthroughRuntimeSettingsPoco =>
      'This prepares PocketCoder\'s local settings file and locks it so only its administrator—you—can read it. It creates the internal credentials PocketCoder needs to run.';

  @override
  String get walkthroughRuntimeSettingsChipLocalSettings =>
      'What are local settings?';

  @override
  String get walkthroughRuntimeVersionTitle => 'running version';

  @override
  String get walkthroughRuntimeVersionPoco =>
      'PocketCoder records the version it is running in the same protected settings file.';

  @override
  String get walkthroughActivationPrepareTitle => 'prepare the release';

  @override
  String get walkthroughActivationPreparePoco =>
      'This checks that the release files match the verified PocketCoder version and prepares them for installation. It also sets up status reporting for the PocketCoder deployment.';

  @override
  String get walkthroughActivationSelectedSoftwareTitle => 'selected software';

  @override
  String get walkthroughActivationSelectedSoftwarePoco =>
      'Next, the server loads PocketCoder and only the coding agents you chose. It checks each software component before Docker runs it.';

  @override
  String get walkthroughActivationSwitchTitle => 'make it active';

  @override
  String get walkthroughActivationSwitchPoco =>
      'This makes the new PocketCoder version active and starts its containers. It uses prebuilt software for faster setup and consistent versioning.';

  @override
  String get walkthroughActivationHealthTitle => 'check the deployment';

  @override
  String get walkthroughActivationHealthPoco =>
      'Before calling the deployment complete, PocketCoder checks that its core and optional services are healthy. Only then does it record this version as active.';

  @override
  String get walkthroughDebianSetupStatusTitle => 'setup status';

  @override
  String get walkthroughDebianSetupStatusPoco =>
      'This setup script keeps PocketCoder\'s deployment status up to date as it runs. If something fails, it records where and cleans up temporary files so it can be checked or safely retried.';

  @override
  String get walkthroughDebianSetupStatusChipStatus =>
      'How is deployment status shown?';

  @override
  String get walkthroughDebianSetupStatusChipFailure =>
      'What happens if setup fails?';

  @override
  String get walkthroughServicesComposeTitle => 'the Docker blueprint';

  @override
  String get walkthroughServicesComposePoco =>
      'Docker Compose is PocketCoder\'s blueprint. It keeps your data when we update the software, and gives each component only the connections it needs.';

  @override
  String get walkthroughServicesComposeChipDockerCompose =>
      'What is Docker compose?';

  @override
  String get walkthroughServicesComposeChipSavedData => 'What is saved data?';

  @override
  String get walkthroughServicesComposeChipPrivateConnections =>
      'What are private connections?';

  @override
  String get walkthroughServicesPocketBaseTitle => 'PocketBase';

  @override
  String get walkthroughServicesPocketBasePoco =>
      'PocketBase keeps the information PocketCoder needs to run: your sign-in, skills, prompts, agent connections, and API keys. That information stays on your server, and you reach it through the HTTPS address Caddy just set up.';

  @override
  String get walkthroughServicesPocketBaseChipKeeps =>
      'What does PocketBase keep?';

  @override
  String get walkthroughServicesPocketBaseChipSignIn =>
      'How do I sign in securely?';

  @override
  String get walkthroughServicesPocketBaseChipUpdates =>
      'What happens when PocketCoder updates?';

  @override
  String get walkthroughServicesHarnessesTitle => 'coding harnesses';

  @override
  String walkthroughServicesHarnessesPoco(String selectedHarnesses) {
    return 'PocketCoder prepares the coding harnesses you selected: $selectedHarnesses. Each gets its own container, saved workspace, and only the private connections it needs.';
  }

  @override
  String get walkthroughServicesHarnessesChipHarness =>
      'What is a coding harness?';

  @override
  String get walkthroughServicesHarnessesChipWorkspace =>
      'What is a saved workspace?';

  @override
  String get walkthroughServicesHarnessesChipAdd =>
      'Can I add a harness later?';

  @override
  String get walkthroughServicesToolsTitle => 'tool connections';

  @override
  String get walkthroughServicesToolsPoco =>
      'The MCP Gateway is a controlled connection point for extra tools your coding harnesses can use. Its separate Docker proxy grants only the permissions those tools need, while blocking more sensitive actions such as accessing saved data or secrets.';

  @override
  String get walkthroughServicesToolsChipMcp => 'What is MCP?';

  @override
  String get walkthroughServicesToolsChipHarnessTools =>
      'What tools can a harness use?';

  @override
  String get walkthroughServicesToolsChipProxy =>
      'Why does this have a separate proxy?';

  @override
  String get walkthroughServicesOllamaTitle => 'local models';

  @override
  String get walkthroughServicesOllamaPoco =>
      'Ollama is ready to run AI models directly on your server. It appears because you chose a local-model setup; when you later choose a model, PocketCoder downloads it and keeps it as saved data.';

  @override
  String get walkthroughServicesOllamaChipLocalModel =>
      'What is a local model?';

  @override
  String get walkthroughServicesOllamaChipDownload =>
      'When is a model downloaded?';

  @override
  String get walkthroughServicesOllamaChipGpu =>
      'Does this use my server\'s GPU?';

  @override
  String get walkthroughServicesSqlPageTitle => 'server dashboard';

  @override
  String get walkthroughServicesSqlPagePoco =>
      'SQLPage is PocketCoder\'s built-in dashboard for showing what is happening on your server. It starts after PocketBase is ready and uses saved PocketCoder data to build those pages.';

  @override
  String get walkthroughServicesSqlPageChipContents =>
      'What can this dashboard show?';

  @override
  String get walkthroughServicesSqlPageChipStartOrder =>
      'Why does it start after PocketBase?';

  @override
  String get permissionRequestedFallback => 'Permission requested';

  @override
  String permissionRequestingLabel(String source) {
    return '$source is requesting permission:';
  }

  @override
  String get permissionPatternsLabel => 'Patterns:';

  @override
  String get questionIncomingTitle => 'incoming query';

  @override
  String get questionPocoAsking => 'Poco is asking:';

  @override
  String get questionSendReply => 'send reply';

  @override
  String get thoughtsWaiting => '[neural link active. waiting for thoughts...]';

  @override
  String notificationSignalReceived(String title) {
    return 'signal received: $title';
  }

  @override
  String get errorsTitle => 'error reports';

  @override
  String get errorsEmpty => 'no errors captured';

  @override
  String get errorsCopy => 'copy report';

  @override
  String get errorsReportOnGithub => 'report on GitHub';

  @override
  String get errorsCopyAll => 'copy all';

  @override
  String get errorsCopied => 'diagnostic report copied';

  @override
  String get errorsClearAll => 'clear all';

  @override
  String get harnessAuthChallengeTargetCopied => 'challenge target copied';

  @override
  String get harnessAuthCopy => '[copy]';

  @override
  String get harnessAuthChallengeDetailsCopied => 'code copied';

  @override
  String get harnessAuthLoading => 'Loading harnesses';

  @override
  String get harnessAuthConnections => 'Harness connections';

  @override
  String get harnessAuthUnavailable =>
      'Claude Code and Codex are not available on this server.';

  @override
  String get harnessAuthEmpty => 'No harnesses were found.';

  @override
  String harnessAuthStatus(String status) {
    return 'Status: $status';
  }

  @override
  String harnessAuthMode(String mode) {
    return 'Mode: $mode';
  }

  @override
  String harnessAuthAccount(String account, String visibility) {
    return 'Account: $account ($visibility)';
  }

  @override
  String harnessAuthApiKeyConfigured(String provider) {
    return 'API key: $provider';
  }

  @override
  String get harnessAuthShared => 'shared';

  @override
  String get harnessAuthPersonal => 'personal';

  @override
  String get harnessAuthOneTimeCode => 'One-time code';

  @override
  String get harnessAuthPasteCode => 'paste code';

  @override
  String get harnessAuthSubmit => 'Submit';

  @override
  String get harnessAuthRefresh => 'Refresh';

  @override
  String harnessAuthAttempt(String id) {
    return 'Attempt: $id';
  }

  @override
  String get harnessAuthAccountLogin => 'account login';

  @override
  String get harnessAuthApiKey => 'API key';

  @override
  String get harnessAuthDisconnect => 'Disconnect';

  @override
  String get harnessAuthCancel => 'Cancel';

  @override
  String get harnessAuthNoApiKeyTitle => 'No API key';

  @override
  String get harnessAuthNoApiKeyBody =>
      'No matching provider key exists for this harness. Open the LLM management screen to add a provider key first.';

  @override
  String harnessAuthProviderKeyMissing(String harness) {
    return 'No provider key found for $harness.';
  }

  @override
  String get harnessAuthChooseProviderKey => 'Choose provider key';

  @override
  String get harnessAuthVisibilityTitle => 'Who uses this harness account?';

  @override
  String get harnessAuthVisibilityBody =>
      'A shared account reuses one login across profiles on this PocketCoder server. A personal account keeps a separate login.';

  @override
  String get harnessAuthChallenge => 'Challenge';

  @override
  String harnessAuthDetails(String details) {
    return 'Details: $details';
  }

  @override
  String get credentialConnectionApiKey => 'Connect with an API key.';

  @override
  String get credentialConnectionCopy => 'copy';

  @override
  String get credentialConnectionOpenAuthorizationPage =>
      'open authorization page';

  @override
  String get credentialConnectionPasteCode =>
      'Paste this code on the authorization page.';

  @override
  String get credentialConnectionEnterCode =>
      'Enter the code shown on the authorization page.';

  @override
  String get credentialConnectionSubmit => 'submit';

  @override
  String get credentialConnectionCancel => 'cancel';

  @override
  String get credentialConnectionRetry => 'retry';

  @override
  String get credentialConnectionOpenFailed =>
      'Could not open the authorization page. Please try again.';

  @override
  String credentialConnectionExpiresAt(DateTime expiresAt) {
    final intl.DateFormat expiresAtDateFormat = intl.DateFormat.yMd(localeName);
    final String expiresAtString = expiresAtDateFormat.format(expiresAt);

    return 'Expires at $expiresAtString';
  }

  @override
  String get agentModeLabel => 'mode:';

  @override
  String get agentConfigLabel => 'config';

  @override
  String get agentSessionLabel => 'session';

  @override
  String get pocketCoderUpdateChecking =>
      '\$ Checking verified release status...';

  @override
  String get pocketCoderUpdateCheckAgain => 'check again';

  @override
  String get pocketCoderUpdateNoDeployment =>
      'No deployment found on this device.';

  @override
  String get actionDismiss => 'dismiss';

  @override
  String get pocketCoderUpdateWorking => 'Upgrading...';

  @override
  String get pocketCoderUpdateUpgrade => 'upgrade PocketCoder';

  @override
  String get pocketCoderUpdateCommand => 'pocketcoder-release update';

  @override
  String get pocketCoderUpdateOutput => 'output';

  @override
  String get pocketCoderUpdateStderr => '--- stderr ---';

  @override
  String get pocketCoderUpdateSucceeded => 'update succeeded (exit 0)';

  @override
  String pocketCoderUpdateFailed(int exitCode) {
    return 'update failed (exit $exitCode)';
  }

  @override
  String get pocketCoderUpdateReviewDataChange => 'review data change';

  @override
  String get pocketCoderUpdateConfirmUpgrade => 'confirm upgrade';

  @override
  String get pocketCoderUpdateCurrent => 'current';

  @override
  String get pocketCoderUpdateAvailable => 'available';

  @override
  String get pocketCoderUpdateDownload => 'download';

  @override
  String get pocketCoderUpdateRequiredDisk => 'required disk';

  @override
  String get pocketCoderUpdateCurrentStatus => '\$ PocketCoder is current';

  @override
  String get pocketCoderUpdateAvailableStatus => '\$ update available';

  @override
  String get pocketCoderUpdateCriticalStatus => '\$ critical release warning';

  @override
  String get pocketCoderUpdateUnknownStatus => '\$ release status unknown';

  @override
  String get pocketCoderUpdateRollbackWarning =>
      'After success, normal rollback is unavailable. Restoring the pre-upgrade snapshot would discard data created afterward.';

  @override
  String pocketCoderUpdateDataBoundary(
      int currentVersion, int availableVersion) {
    return 'data version $currentVersion → $availableVersion';
  }

  @override
  String errorsOccurred(int count) {
    return 'Occurred ${count}x';
  }

  @override
  String get errorsDeleteAction => 'delete';

  @override
  String get deploymentResetAction => 'reset';

  @override
  String get deploymentResetConfirmationTitle =>
      'Reset local deployment state?';

  @override
  String get deploymentResetConfirmationBody =>
      'This clears local deployment state only: the saved session, instance id, and credentials stored on this device. It does NOT delete your cloud server.';

  @override
  String get deploymentResetConfirmationWarnCloud =>
      'Your cloud instance is unaffected. Use your provider console to inspect or delete it.';

  @override
  String get deploymentResetAlsoClearOAuth =>
      'Also sign out of the cloud provider (clear OAuth tokens)';

  @override
  String get deploymentResetConfirm => 'reset';

  @override
  String get deploymentResetCancel => 'cancel';

  @override
  String get deploymentResetComplete => 'Local deployment state cleared.';

  @override
  String get deploymentDisconnectAction => 'disconnect';

  @override
  String get deploymentDisconnectConfirmationTitle =>
      'Disconnect this instance?';

  @override
  String get deploymentDisconnectConfirmationBody =>
      'This clears the saved session and local deployment state so you can connect to another instance. It does not delete your cloud server.';

  @override
  String get deploymentDisconnectConfirm => 'disconnect';

  @override
  String get deploymentDisconnectCancel => 'cancel';

  @override
  String get instanceVerificationTitle => 'Can\'t verify your deployment';

  @override
  String get instanceVerificationBody =>
      'PocketCoder couldn\'t reach your server, and couldn\'t confirm with your cloud provider whether the instance still exists.';

  @override
  String get instanceVerificationCheckFailedMessage =>
      'Still couldn\'t confirm. Try again, or choose an option below.';

  @override
  String instanceVerificationCheckAction(String provider) {
    return 'check via $provider';
  }

  @override
  String get instanceVerificationResetAction => 'reset';

  @override
  String get instanceVerificationResetConfirmationTitle =>
      'Reset and start over?';

  @override
  String get instanceVerificationResetConfirmationBody =>
      'This clears the saved session and local deployment state on this device. It does not delete your cloud server.';

  @override
  String get instanceVerificationResetConfirm => 'reset';

  @override
  String get instanceVerificationResetCancel => 'cancel';

  @override
  String get instanceGoneTitle => 'Instance no longer exists';

  @override
  String get instanceGoneBody =>
      'The provider confirms this deployment\'s server no longer exists. The only way forward is to reset local state and set up a new deployment.';

  @override
  String get instanceGoneResetAction => 'reset';

  @override
  String get instanceGoneResetConfirmationTitle =>
      'Reset local deployment state?';

  @override
  String get instanceGoneResetConfirmationBody =>
      'This clears all local deployment state on this device. The instance is already gone on the provider side, so nothing further will be deleted remotely.';

  @override
  String get instanceGoneResetCancel => 'cancel';

  @override
  String get instanceGoneResetConfirm => 'reset';

  @override
  String get deploymentDiscardAttemptTitle => 'Discard this deployment record?';

  @override
  String get deploymentDiscardAttemptBody =>
      'PocketCoder still has a record of a provider resource from a previous attempt. Discarding this record does NOT delete anything in your provider account -- it only clears PocketCoder\'s own bookkeeping, so a new deployment can start.';

  @override
  String deploymentDiscardAttemptResourceId(String resourceId) {
    return 'Recorded resource: $resourceId';
  }

  @override
  String get deploymentDiscardAttemptCheckLink =>
      'Open provider dashboard to check';

  @override
  String get deploymentDiscardAttemptConfirmCheckbox =>
      'I checked and this won\'t create a duplicate charge';

  @override
  String get deploymentDiscardAttemptCancel => 'cancel';

  @override
  String get deploymentDiscardAttemptConfirm => 'discard';

  @override
  String get deploymentCleanupSucceeded => 'Cloud server deleted.';

  @override
  String get deploymentCleanupFailed =>
      'Could not delete the cloud server. Use your provider console to remove it.';

  @override
  String get deploymentCleanupPending =>
      'Cleanup could not run automatically. Use your provider console to remove the cloud server.';

  @override
  String get deploymentCleanupNotNeeded => 'No cloud server to clean up.';

  @override
  String get serverControlTitle => 'server controls';

  @override
  String get serverControlConnectionDetails => 'connection details';

  @override
  String get serverControlIpAddress => 'IP address';

  @override
  String get serverControlHttpsEndpoint => 'HTTPS endpoint';

  @override
  String get serverControlAdminIdentity => 'admin identity';

  @override
  String get serverControlAdminPassword => 'admin password';

  @override
  String get serverControlShow => 'show';

  @override
  String get serverControlHide => 'hide';

  @override
  String get serverControlLocalAuthReason =>
      'Authenticate to reveal this credential';

  @override
  String get serverControlCopy => 'copy';

  @override
  String get serverControlCopied => 'copied';

  @override
  String get serverControlConfirmTitle => 'confirm server control';

  @override
  String serverControlConfirmBody(String operation) {
    return '$operation will run on your server.';
  }

  @override
  String get serverControlConfirmCancel => 'cancel';

  @override
  String get serverControlConfirmConfirm => 'confirm';

  @override
  String get serverControlConfirmRestoreTitle => 'Restore backup?';

  @override
  String get serverControlConfirmRestoreBody =>
      'This overwrites all current data on your server with the last saved backup. This cannot be undone.';

  @override
  String get serverControlReleaseChecking => 'release status: checking';

  @override
  String serverControlReleaseStatus(String status) {
    return 'release status: $status';
  }

  @override
  String serverControlReleaseCurrent(String version) {
    return 'current: $version';
  }

  @override
  String serverControlReleaseAvailable(String version) {
    return 'available: $version';
  }

  @override
  String serverControlReleaseContracts(
      String app, String server, String deployment) {
    return 'contracts: app v$app · server v$server · deployment v$deployment';
  }

  @override
  String serverControlReleaseNixos(String version) {
    return 'NixOS: $version';
  }

  @override
  String get serverControlOperationRestartPocketCoder => 'Restart PocketCoder';

  @override
  String get serverControlOperationUpdatePocketCoder => 'Update PocketCoder';

  @override
  String get serverControlOperationRestartNixOs => 'Restart NixOS';

  @override
  String get serverControlOperationUpdateNixOs => 'Update NixOS';

  @override
  String get serverControlOperationSaveBackup => 'Save backup';

  @override
  String get serverControlOperationRestoreBackup => 'Restore backup';

  @override
  String get serverControlActionRestart => 'restart';

  @override
  String get serverControlActionUpdate => 'update';

  @override
  String get serverControlActionSave => 'save';

  @override
  String get serverControlActionRestore => 'restore';

  @override
  String get serverControlGroupPocketCoder => 'app';

  @override
  String get serverControlGroupNixOs => 'system';

  @override
  String get serverControlGroupData => 'data';

  @override
  String get serverControlPublicKeyLabel => 'SSH public key on file';

  @override
  String get serverControlPrivateKeyLabel => 'SSH private key';

  @override
  String get serverControlProviderConsole => 'provider web portal';

  @override
  String get serverControlProviderConsoleUnavailable =>
      'No active provider-managed instance found.';

  @override
  String serverControlErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get serverControlRetryAction => 'retry';

  @override
  String get serverControlOutputLabel => 'output';

  @override
  String get fossServerSetupTitle => 'connect your server';

  @override
  String get fossServerSetupIntro =>
      'Generate a key, add it to your VPS, then verify the connection.';

  @override
  String get fossServerSetupGenerateKey => 'generate key';

  @override
  String get fossServerSetupPublicKeyLabel =>
      'PUBLIC KEY -- add this to /root/.ssh/authorized_keys on your VPS';

  @override
  String get fossServerSetupHostLabel => 'This will connect to:';

  @override
  String get fossServerSetupTestAndSave => 'test connection & save';

  @override
  String get fossServerSetupConnected =>
      'connected -- your server is now managed';

  @override
  String fossServerSetupErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get initializationInstanceId => 'instance ID';

  @override
  String get initializationRetryAttempt => 'retry attempt';

  @override
  String get memoryDashboardTitle => 'pocket memory';

  @override
  String get memoryDashboardUnavailable => 'memory unavailable';

  @override
  String get memoryDashboardObservations => 'observations';

  @override
  String get memoryDashboardInterpretations => 'interpretations';

  @override
  String get memoryDashboardLinks => 'links';

  @override
  String get memoryDashboardByAccount => 'Memory by Account';

  @override
  String get memoryDashboardNoMemoryRecorded => 'No memory recorded yet';

  @override
  String get memoryDashboardRecentObservations => 'Recent Observations';

  @override
  String get memoryDashboardNoObservationsYet => 'No observations yet';

  @override
  String get memoryDashboardRecentInterpretations => 'Recent Interpretations';

  @override
  String get memoryDashboardNoInterpretationsYet => 'No interpretations yet';

  @override
  String memoryDashboardAccountSummary(int observations, int interpretations) {
    return '$observations obs / $interpretations int';
  }

  @override
  String memoryDashboardLinkedPrefix(String links) {
    return 'Linked: $links';
  }

  @override
  String get pocketbaseInspectorTitle => 'PocketBase';

  @override
  String get pocketbaseInspectorUnavailable => 'database unavailable';

  @override
  String get pocketbaseInspectorUsers => 'users';

  @override
  String get pocketbaseInspectorChats => 'chats';

  @override
  String get pocketbaseInspectorAgentProfiles => 'agent profiles';

  @override
  String get pocketbaseInspectorHarnesses => 'harnesses';

  @override
  String get pocketbaseInspectorMcpServers => 'MCP servers';

  @override
  String get pocketbaseInspectorSkills => 'skills';

  @override
  String get pocketbaseInspectorRecentChats => 'Recent Chats';

  @override
  String get pocketbaseInspectorNoChatsYet => 'No chats yet';

  @override
  String pocketbaseInspectorChatArchivedTitle(String title) {
    return '$title (archived)';
  }
}
