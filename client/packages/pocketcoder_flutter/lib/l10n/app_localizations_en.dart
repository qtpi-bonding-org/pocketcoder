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
  String get authLoginFailed => 'Login failed';

  @override
  String get authNotAuthenticated => 'Please log in';

  @override
  String get authTokenExpired => 'Session expired, please log in again';

  @override
  String get authError => 'Authentication error';

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
  String get actionCancel => 'CANCEL';

  @override
  String get actionSave => 'SAVE';

  @override
  String get actionClose => 'CLOSE';

  @override
  String get actionDeny => 'DENY';

  @override
  String get actionAuthorize => 'AUTHORIZE';

  @override
  String get actionRefresh => 'REFRESH';

  @override
  String get actionBack => 'BACK';

  @override
  String get actionContinue => 'CONTINUE';

  @override
  String get actionChange => 'CHANGE';

  @override
  String get actionCreate => 'CREATE';

  @override
  String get actionAddNew => 'ADD NEW';

  @override
  String get actionRestore => 'RESTORE';

  @override
  String get actionConfigure => 'CONFIGURE';

  @override
  String get actionReject => 'REJECT';

  @override
  String get navChats => 'CHATS';

  @override
  String get navMonitor => 'MONITOR';

  @override
  String get navConfigure => 'CONFIGURE';

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
  String get onboardingTitle => 'IDENTIFICATION UNLOCK';

  @override
  String get onboardingPocoChallengeMessage =>
      'WHO GOES THERE? IDENTIFY YOURSELF AND PROVIDE THE SECRET PASSPHRASE.';

  @override
  String get onboardingPocoWelcome =>
      'Identity verified! Welcome home. I knew it was you—just had to make sure the Cloud wasn\'t spoofing your signature.';

  @override
  String get onboardingAccessDenied => 'ACCESS DENIED.';

  @override
  String get onboardingProcessing => 'PROCESSING...';

  @override
  String get onboardingLogin => 'CONNECT';

  @override
  String get onboardingDeploy => 'DEPLOY';

  @override
  String get onboardingHomeServer => 'HOME SERVER';

  @override
  String get onboardingIdentityLabel => 'IDENTITY';

  @override
  String get onboardingEmailHint => 'ENTER EMAIL';

  @override
  String get onboardingPassphraseLabel => 'PASSPHRASE';

  @override
  String get onboardingPasswordHint => 'ENTER PASSWORD';

  @override
  String get onboardingAuthenticating => 'AUTHENTICATING';

  @override
  String get onboardingSetupTitle => 'POCKETCODER SETUP';

  @override
  String get onboardingConnectOrDeploy =>
      'ARE YOU ALREADY PART OF THE POCKETCODER INITIATIVE?';

  @override
  String get onboardingExistingServer => 'USE AN EXISTING POCKETBASE SERVER';

  @override
  String get onboardingCreateServer => 'CREATE A NEW SERVER';

  @override
  String get onboardingServerLoginTitle => 'SERVER LOGIN';

  @override
  String get onboardingServerUrl => 'SERVER URL';

  @override
  String get onboardingServerUrlHint => 'https://server.example.com';

  @override
  String get onboardingEmail => 'EMAIL';

  @override
  String get onboardingEmailHintShort => 'admin@example.com';

  @override
  String get onboardingPassword => 'PASSWORD';

  @override
  String get onboardingServerConnecting => 'CONNECTING...';

  @override
  String get onboardingRequiredFields => 'ENTER ALL REQUIRED FIELDS';

  @override
  String get onboardingChooseHarnessTitle => 'CHOOSE YOUR HARNESS';

  @override
  String get onboardingChooseHarnessBody =>
      'CHOOSE THE ACCOUNT-BASED AGENT TO CONNECT.';

  @override
  String get onboardingHarnessNotFound => 'HARNESS NOT FOUND';

  @override
  String get onboardingClaudeAccountLogin => 'CLAUDE ACCOUNT LOGIN';

  @override
  String get onboardingCodexAccountLogin => 'CHATGPT ACCOUNT LOGIN';

  @override
  String onboardingHarnessLoginTitle(String provider) {
    return '$provider LOGIN';
  }

  @override
  String get onboardingConnected => 'CONNECTED';

  @override
  String get onboardingAccountLogin => 'ACCOUNT LOGIN';

  @override
  String get onboardingAuthorizationCode => 'AUTHORIZATION CODE';

  @override
  String get onboardingAuthorizationCodeHint => 'paste code';

  @override
  String get onboardingSubmitCode => 'SUBMIT CODE';

  @override
  String get onboardingOpenAuthorization => 'OPEN AUTHORIZATION';

  @override
  String get onboardingCheckStatus => 'CHECK STATUS';

  @override
  String onboardingOpenChatFailed(String error) {
    return 'Could not open a new chat: $error';
  }

  @override
  String get onboardingDeployTitle => 'DEPLOY SERVER';

  @override
  String get onboardingPocketbaseAdminEmail => 'POCKETBASE ADMIN EMAIL';

  @override
  String get onboardingPocketbaseAdminPassword => 'POCKETBASE ADMIN PASSWORD';

  @override
  String get homeTitle => 'CHATS';

  @override
  String get homeLoadingChats => 'LOADING CHATS';

  @override
  String homeErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get homeNewChat => 'NEW CHAT';

  @override
  String get homeNoChats => 'No active chats found.';

  @override
  String get chatSessionTitle => 'CHAT SESSION';

  @override
  String get chatTerminalAction => 'TERMINAL';

  @override
  String get chatListNewChat => '+ NEW CHAT';

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
  String get newChatCreate => 'CREATE';

  @override
  String get newChatCancel => 'CANCEL';

  @override
  String get newChatSelectHarness => 'SELECT HARNESS';

  @override
  String get newChatSelectModel => 'SELECT MODEL';

  @override
  String get newChatNoModelsAvailable => 'No models available for this harness';

  @override
  String get newChatWorkspaceErrorEmpty => 'Path cannot be empty';

  @override
  String get newChatWorkspaceErrorInvalid =>
      'Path must be /workspace or a subdirectory of it';

  @override
  String get chatListArchive => 'ARCHIVE';

  @override
  String get chatListDelete => 'DELETE';

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
  String get chatFilesAction => 'FILES';

  @override
  String get chatNewCapabilityRequest => '[!] NEW CAPABILITY REQUEST RECEIVED';

  @override
  String get chatThinking => 'THINKING';

  @override
  String get chatThinkingLive => 'THINKING...';

  @override
  String get chatThought => 'THOUGHT';

  @override
  String get chatCommandOutput => 'OUTPUT';

  @override
  String get chatSessionAction => 'SESSION';

  @override
  String get chatSendTooltip => 'Send';

  @override
  String get chatCommanderRole => 'COMMANDER';

  @override
  String get chatThinkingRole => 'THINKING';

  @override
  String get chatPocoRole => 'POCO';

  @override
  String get chatElicitationRequest => 'ELICITATION REQUEST';

  @override
  String get chatDecline => 'DECLINE';

  @override
  String get chatSubmit => 'SUBMIT';

  @override
  String get chatNoFieldsRequested => '(no fields requested)';

  @override
  String get filesTitle => 'FILES';

  @override
  String get filesEmpty => 'NO FILES';

  @override
  String get filesTooLargeToPreview => 'FILE TOO LARGE TO PREVIEW';

  @override
  String get filesCantPreviewType => 'CAN\'T PREVIEW THIS FILE TYPE';

  @override
  String get chatModelLabel => 'MODEL:';

  @override
  String get chatModelDefault => 'DEFAULT';

  @override
  String get chatModelPerChat => '[CHAT]';

  @override
  String get chatSelectModelTitle => 'SELECT MODEL';

  @override
  String get chatUseGlobalDefault => 'USE GLOBAL DEFAULT';

  @override
  String get llmTitle => 'LLM MANAGEMENT';

  @override
  String get llmLoadingProviders => 'LOADING PROVIDERS';

  @override
  String get llmActiveModelSection => 'ACTIVE MODEL';

  @override
  String get llmProvidersSection => 'PROVIDERS';

  @override
  String get llmApiKeysSection => 'API KEYS';

  @override
  String get llmGlobalDefault => 'GLOBAL DEFAULT';

  @override
  String get llmNotSet => 'NOT SET';

  @override
  String get llmAddKeyHint => 'ADD AN API KEY TO ENABLE MODEL SELECTION';

  @override
  String get llmNoProviders => 'NO PROVIDERS AVAILABLE';

  @override
  String get llmConnected => '[ CONNECTED ]';

  @override
  String get llmNoKey => '[ NO KEY ]';

  @override
  String llmModelsAvailable(int count) {
    return '$count MODEL(S) AVAILABLE';
  }

  @override
  String get llmUpdateKey => 'UPDATE KEY';

  @override
  String get llmAddKey => 'ADD KEY';

  @override
  String get llmModelsButton => 'MODELS';

  @override
  String llmApiKeyDialogTitle(String provider) {
    return 'API KEY: $provider';
  }

  @override
  String llmEnterCredentials(String provider) {
    return 'Enter credentials for $provider:';
  }

  @override
  String get llmSelectModelTitle => 'SELECT MODEL';

  @override
  String llmProviderModelsTitle(String provider) {
    return '$provider MODELS';
  }

  @override
  String get llmNoModels => 'NO MODELS LISTED';

  @override
  String get llmSelect => '[ SELECT ]';

  @override
  String get mcpTitle => 'MCP MANAGEMENT';

  @override
  String get mcpCapabilitiesRegistry => 'CAPABILITIES REGISTRY';

  @override
  String get mcpPendingApproval => 'PENDING APPROVAL';

  @override
  String get mcpActiveCapabilities => 'ACTIVE CAPABILITIES';

  @override
  String get mcpNoCapabilities => 'NO CAPABILITIES REGISTERED';

  @override
  String mcpImageLabel(String image) {
    return 'IMAGE: $image';
  }

  @override
  String mcpPurposeLabel(String reason) {
    return 'PURPOSE: $reason';
  }

  @override
  String get mcpRequiredConfig => 'REQUIRED CONFIG:';

  @override
  String get mcpAuthorizeCap => 'AUTHORIZE CAPABILITY';

  @override
  String get mcpEditConfig => 'EDIT CONFIGURATION';

  @override
  String get mcpRevoke => 'REVOKE';

  @override
  String mcpAuthorizeDialogTitle(String name) {
    return 'AUTHORIZE: $name';
  }

  @override
  String mcpUpdateConfigDialogTitle(String name) {
    return 'UPDATE CONFIG: $name';
  }

  @override
  String get mcpNoConfigRequired => 'No configuration required.';

  @override
  String get mcpEnterSecrets => 'Enter required secrets:';

  @override
  String get mcpAddDialogTitle => 'ADD MCP SERVER';

  @override
  String get mcpServerNameLabel => 'SERVER NAME';

  @override
  String get mcpImageOptionalLabel => 'IMAGE (OPTIONAL)';

  @override
  String get mcpAddConfigOptional =>
      'Optional config (leave blank if none needed)';

  @override
  String get mcpConnectCap => 'CONNECT';

  @override
  String get mcpRetryDeliveryCap => 'RETRY DELIVERY';

  @override
  String mcpOauthRequiredLabel(String provider) {
    return 'REQUIRES OAUTH: $provider';
  }

  @override
  String get mcpOauthProviderOptionalLabel => 'OAUTH PROVIDER (OPTIONAL)';

  @override
  String get mcpOauthTokenEnvVarOptionalLabel =>
      'OAUTH TOKEN ENV VAR (OPTIONAL)';

  @override
  String mcpOauthProviderNotConfiguredLabel(String provider) {
    return '$provider NOT YET CONFIGURED';
  }

  @override
  String get actionAdd => 'ADD';

  @override
  String get toolPermissionsScreenTitle => 'TOOL PERMISSIONS';

  @override
  String get toolPermissionsRulesRegistry => 'PERMISSION RULES';

  @override
  String get toolPermissionsNoRules => 'NO RULES CONFIGURED';

  @override
  String get toolPermissionsAddRuleTitle => 'ADD PERMISSION RULE';

  @override
  String get toolPermissionsToolNameLabel => 'TOOL NAME';

  @override
  String get toolPermissionsAllowLabel => 'ALLOW';

  @override
  String get toolPermissionsAskLabel => 'ASK';

  @override
  String get toolPermissionsDenyLabel => 'DENY';

  @override
  String get notificationSettingsScreenTitle => 'NOTIFICATIONS';

  @override
  String get notificationSettingsChatReplyLabel => 'CHAT REPLIES';

  @override
  String get notificationSettingsScheduleLabel => 'SCHEDULED TASKS';

  @override
  String get notificationSettingsTaskCompleteLabel => 'TASK COMPLETE';

  @override
  String get notificationSettingsTaskErrorLabel => 'TASK ERRORS';

  @override
  String get notificationSettingsPoco =>
      'I can notify you when an agent needs approval or finishes a task, even when PocketCoder is not open. Your phone will ask for permission before I enable alerts on this device.';

  @override
  String get notificationSettingsEnableDevice => 'ENABLE ON THIS DEVICE';

  @override
  String get skillsTitle => 'SKILLS';

  @override
  String get skillsRegistryTitle => 'SKILLS REGISTRY';

  @override
  String get skillsGlobalSection => 'GLOBAL';

  @override
  String get skillsProjectSection => 'PROJECT';

  @override
  String get skillsNoSkills => 'NO SKILLS CONFIGURED';

  @override
  String get skillsAddButton => 'ADD SKILL';

  @override
  String get skillsEditButton => 'EDIT';

  @override
  String get skillsDeleteButton => 'DELETE';

  @override
  String get skillsSaveButton => 'SAVE';

  @override
  String get skillsNameLabel => 'NAME';

  @override
  String get skillsDescriptionLabel => 'DESCRIPTION';

  @override
  String get skillsContentLabel => 'CONTENT';

  @override
  String get skillsGlobalLabel => 'GLOBAL';

  @override
  String get skillsProjectLabel => 'PROJECT';

  @override
  String get skillsAddDialogTitle => 'ADD SKILL';

  @override
  String skillsEditDialogTitle(String name) {
    return 'EDIT: $name';
  }

  @override
  String get skillsNoEligibleConfig =>
      'No agent config has a workspace folder configured.';

  @override
  String get schedulerTitle => 'SCHEDULER';

  @override
  String get schedulerRegistryTitle => 'SCHEDULED TASKS';

  @override
  String get schedulerNoSchedules => 'NO SCHEDULES CONFIGURED';

  @override
  String get schedulerAddButton => 'ADD SCHEDULE';

  @override
  String get schedulerEditButton => 'EDIT';

  @override
  String get schedulerDeleteButton => 'DELETE';

  @override
  String get schedulerSaveButton => 'SAVE';

  @override
  String get schedulerPauseButton => 'PAUSE';

  @override
  String get schedulerResumeButton => 'RESUME';

  @override
  String get schedulerRunNowButton => 'RUN NOW';

  @override
  String get schedulerNameLabel => 'NAME';

  @override
  String get schedulerCronLabel => 'CRON EXPRESSION';

  @override
  String get schedulerPromptLabel => 'PROMPT';

  @override
  String get schedulerAddDialogTitle => 'ADD SCHEDULE';

  @override
  String schedulerEditDialogTitle(String name) {
    return 'EDIT: $name';
  }

  @override
  String get schedulerPausedBadge => 'PAUSED';

  @override
  String get schedulerRunningBadge => 'RUNNING';

  @override
  String get settingsTitle => 'CONFIGURE';

  @override
  String get settingsAiAgentsSection => 'AI & AGENTS';

  @override
  String get settingsSecuritySection => 'SECURITY';

  @override
  String get settingsGovernanceSection => 'GOVERNANCE';

  @override
  String get settingsSystemSection => 'SYSTEM';

  @override
  String get settingsObservabilitySection => 'OBSERVABILITY';

  @override
  String get settingsAutomationSection => 'AUTOMATION';

  @override
  String get settingsAccountSection => 'ACCOUNT';

  @override
  String get settingsLogoutConfirmTitle => 'SIGN OUT';

  @override
  String get settingsLogoutConfirmBody =>
      'This will end your current session. You will need to log in again to continue.';

  @override
  String get settingsLogoutCancel => 'CANCEL';

  @override
  String get settingsLogoutConfirm => 'SIGN OUT';

  @override
  String get agentTitle => 'AGENT REGISTRY';

  @override
  String get agentModelsPersonas => 'MODELS & PERSONAS';

  @override
  String get agentSearching => 'SEARCHING...';

  @override
  String get agentRegistryEmpty => 'REGISTRY EMPTY.';

  @override
  String get agentSelectToConfigure => 'SELECT AGENT TO CONFIGURE';

  @override
  String agentDialogTitle(String name) {
    return 'AGENT: $name';
  }

  @override
  String get agentNameLabel => 'NAME';

  @override
  String get agentDescriptionLabel => 'DESCRIPTION';

  @override
  String get agentPromptsLabel => 'PROMPTS';

  @override
  String get agentModelsLabel => 'MODELS';

  @override
  String get agentParametersLabel => 'PARAMETERS';

  @override
  String get agentNone => 'NONE';

  @override
  String get agentNoneSelected => 'NONE SELECTED';

  @override
  String get agentDefaultTuned => 'DEFAULT [TUNED]';

  @override
  String get agentConfigTitle => 'AGENT CONFIGURATION';

  @override
  String get agentConfigRegistry => 'AGENT CONFIGS';

  @override
  String get agentConfigEmpty => 'NO AGENT CONFIGS YET';

  @override
  String agentConfigDialogTitle(String name) {
    return 'AGENT CONFIG: $name';
  }

  @override
  String get agentConfigNameLabel => 'NAME';

  @override
  String get agentConfigHarnessModelLabel => 'HARNESS MODEL';

  @override
  String get agentConfigPromptLabel => 'SYSTEM PROMPT';

  @override
  String get agentConfigModeLabel => 'MODE';

  @override
  String get agentConfigIsDefaultLabel => 'IS DEFAULT';

  @override
  String get agentConfigNoHarnessModels => 'NO HARNESS MODELS AVAILABLE';

  @override
  String get agentConfigNoPrompts => 'NO PROMPTS AVAILABLE';

  @override
  String get agentConfigNoModes => 'NO MODES AVAILABLE';

  @override
  String get agentConfigSelectPrompt => 'SELECT PROMPT';

  @override
  String get agentConfigSelectHarnessModel => 'SELECT HARNESS MODEL';

  @override
  String get agentConfigSelectMode => 'SELECT MODE';

  @override
  String get agentConfigDelete => 'DELETE';

  @override
  String get agentConfigDeleteConfirmTitle => 'DELETE CONFIG?';

  @override
  String agentConfigDeleteConfirmBody(String name) {
    return 'DELETE $name? THIS CANNOT BE UNDONE.';
  }

  @override
  String get agentConfigDefaultBadge => '[ DEFAULT ]';

  @override
  String agentConfigErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get providerScreenTitle => 'PROVIDER MANAGEMENT';

  @override
  String get providerScreenLoading => 'LOADING PROVIDERS';

  @override
  String get providerScreenHarnessModelsSection => 'HARNESS MODELS';

  @override
  String get providerScreenApiKeysSection => 'API KEYS';

  @override
  String get providerScreenNoHarnessModels => 'NO HARNESS MODELS LISTED';

  @override
  String get providerScreenNoApiKeys => 'NO API KEYS CONFIGURED';

  @override
  String get providerScreenEmptyHint => 'NO HARNESS MODELS OR API KEYS YET';

  @override
  String get providerScreenAddKey => 'ADD KEY';

  @override
  String get providerScreenUpdateKey => 'UPDATE KEY';

  @override
  String providerScreenAddKeyTitle(String provider) {
    return 'API KEY: $provider';
  }

  @override
  String providerScreenAddKeyBody(String provider) {
    return 'Enter credentials for $provider:';
  }

  @override
  String get providerScreenSelectProvider => 'SELECT PROVIDER';

  @override
  String get providerScreenNoProviders => 'NO PROVIDERS AVAILABLE';

  @override
  String get providerScreenDefaultBadge => '[ DEFAULT ]';

  @override
  String providerScreenErrorPrefix(String error) {
    return 'ERROR: $error';
  }

  @override
  String get toolPermissionsTitle => 'GATEKEEPER CONFIGURATION';

  @override
  String get toolPermissionsFrameTitle => 'TOOL PERMISSIONS';

  @override
  String get toolPermissionsLoading => 'LOADING PERMISSIONS';

  @override
  String get toolPermissionsEmpty => 'NO PERMISSIONS DEFINED.';

  @override
  String get toolPermissionsAdd => 'ADD PERMISSION';

  @override
  String get toolPermissionsScopeAgent => 'AGENT';

  @override
  String get toolPermissionsScopeGlobal => 'GLOBAL';

  @override
  String get toolPermissionsAddTitle => 'ADD TOOL PERMISSION';

  @override
  String get toolPermissionsToolLabel => 'TOOL (e.g. bash, edit, cao_*)';

  @override
  String get toolPermissionsPatternLabel => 'PATTERN (e.g. *, git *, rm *)';

  @override
  String get toolPermissionsActionLabel => 'ACTION:';

  @override
  String get terminalTitle => 'TERMINAL MIRROR';

  @override
  String get terminalTransfer => 'TRANSFER';

  @override
  String get terminalReconnect => 'RECONNECT';

  @override
  String get terminalConnecting => 'ESTABLISHING SSH LINK';

  @override
  String get terminalConnectionFailed => 'CONNECTION FAILED';

  @override
  String get terminalRetry => 'RETRY CONNECTION';

  @override
  String get terminalSftpTitle => 'SFTP TRANSFER';

  @override
  String get terminalDestinationPath => 'DESTINATION PATH';

  @override
  String get terminalUpload => 'UPLOAD';

  @override
  String get terminalConnectionStatus => 'CONNECTION_STATUS';

  @override
  String terminalSshLink(String host, String port) {
    return 'SSH LINK: $host:$port';
  }

  @override
  String get terminalOnline => 'ONLINE';

  @override
  String get terminalOffline => 'OFFLINE';

  @override
  String get monitorTitle => 'MONITOR';

  @override
  String get monitorFetchingTelemetry => 'FETCHING TELEMETRY';

  @override
  String get monitorSystemHealth => 'SYSTEM HEALTH';

  @override
  String get monitorKeyMetrics => 'KEY METRICS';

  @override
  String get monitorTokenUsage => 'TOKEN USAGE BY MODEL';

  @override
  String get monitorAgentActivity => 'AGENT ACTIVITY';

  @override
  String get monitorTelemetryUnavailable => 'TELEMETRY UNAVAILABLE';

  @override
  String get monitorNoData => 'NO DATA — TAP REFRESH';

  @override
  String get monitorMessagesLabel => 'MESSAGES';

  @override
  String get monitorCostLabel => 'COST';

  @override
  String get monitorTokensLabel => 'TOKENS';

  @override
  String get fileTitle => 'SOURCE OUTPUT MANIFEST';

  @override
  String get fileDashboardAction => 'DASHBOARD';

  @override
  String get fileClearAction => 'CLEAR';

  @override
  String get fileNoFileSelected => 'NO FILE SELECTED.';

  @override
  String get fileSelectFromChat => '>> SELECT FROM CHAT TO VIEW';

  @override
  String get fileFetching => 'FETCHING DATA...';

  @override
  String get fileEmpty => 'EMPTY FILE';

  @override
  String get systemChecksTitle => 'SYSTEM CHECKS';

  @override
  String get systemChecksDiagnostics => 'SYSTEM DIAGNOSTICS';

  @override
  String get systemChecksEmpty => 'NO DIAGNOSTICS AVAILABLE';

  @override
  String get observabilityTitle => 'PLATFORM OBSERVABILITY';

  @override
  String get observabilityRegistry => 'REGISTRY';

  @override
  String get observabilityLogTerminal => 'SYSTEM LOG TERMINAL';

  @override
  String get observabilityCost => 'COST';

  @override
  String get observabilityTokens => 'TOKENS';

  @override
  String get observabilityMsgs => 'MSGS';

  @override
  String get observabilityBackend => 'BACKEND';

  @override
  String get observabilitySelectContainer =>
      '>> SELECT CONTAINER FOR LOG STREAM';

  @override
  String get proTitle => 'POCKETCODER PRO';

  @override
  String get proPlanTitle => 'UNLOCK ALL SYSTEMS';

  @override
  String get proCheckingStatus => 'CHECKING PRO STATUS...';

  @override
  String get proUnlockCommand => '\$ unlock --all';

  @override
  String get proSummary =>
      'ONE SUBSCRIPTION. EVERY POCKETCODER PRO CAPABILITY.';

  @override
  String get proFeatureReady => '[OK]';

  @override
  String get proFeatureDeploy => 'PROVISION AND DEPLOY POCKETCODER SERVERS';

  @override
  String get proFeaturePush => 'RECEIVE HOSTED AGENT NOTIFICATIONS';

  @override
  String get proFeatureConsole => 'USE PRO CONSOLE CONTROLS AS THEY SHIP';

  @override
  String proTrialDuration(int days) {
    return '$days DAYS FREE';
  }

  @override
  String proPrice(String price) {
    return '$price';
  }

  @override
  String proPriceAfterTrial(String price) {
    return 'THEN $price';
  }

  @override
  String proPricePerWeek(String price) {
    return '$price / WEEK';
  }

  @override
  String proPricePerMonth(String price) {
    return '$price / MONTH';
  }

  @override
  String proPricePerYear(String price) {
    return '$price / YEAR';
  }

  @override
  String proStartTrial(int days) {
    return 'START $days-DAY FREE TRIAL';
  }

  @override
  String get proSubscribe => 'UNLOCK POCKETCODER PRO';

  @override
  String get proRestore => 'RESTORE PURCHASES';

  @override
  String get proNotNow => 'NOT NOW';

  @override
  String proTerms(String price) {
    return 'SUBSCRIPTION RENEWS AT $price UNTIL CANCELLED. MANAGE OR CANCEL IN YOUR APP STORE ACCOUNT.';
  }

  @override
  String proTrialTerms(int days, String price) {
    return 'FREE FOR $days DAYS, THEN $price UNTIL CANCELLED. MANAGE OR CANCEL IN YOUR APP STORE ACCOUNT.';
  }

  @override
  String get proActive => '> ENTITLEMENT: ACTIVE';

  @override
  String get proActiveBody =>
      'POCKETCODER PRO IS ACTIVE. DEPLOYMENT AND HOSTED NOTIFICATIONS ARE UNLOCKED.';

  @override
  String get proUnavailable => '> OFFERING: UNAVAILABLE';

  @override
  String get proUnavailableBody =>
      'THE APP STORE COULD NOT RETURN THE POCKETCODER PRO SUBSCRIPTION. CHECK YOUR CONNECTION OR RESTORE AN EXISTING PURCHASE.';

  @override
  String get proSelfHostedPushTitle => 'SELF-HOSTED NOTIFICATIONS';

  @override
  String get proSelfHostedPushBody =>
      'YOU CAN CONNECT YOUR OWN NTFY OR UNIFIEDPUSH DISTRIBUTOR WITHOUT POCKETCODER PRO.';

  @override
  String get proConfigureSelfHostedPush => 'CONFIGURE SELF-HOSTED PUSH';

  @override
  String get proSettingsLabel => 'POCKETCODER PRO';

  @override
  String get proSettingsStatus => '[STATUS]';

  @override
  String get deployTitle => 'DEPLOY POCKETCODER';

  @override
  String get deploySelectProvider => 'SELECT PROVIDER';

  @override
  String get deployChooseProvider => 'CHOOSE WHERE TO DEPLOY YOUR INSTANCE';

  @override
  String get deployProBadge => 'PRO';

  @override
  String get deployComingSoon => 'COMING SOON';

  @override
  String get pocketCoderProgressProvisionServer => 'PROVISION SERVER';

  @override
  String get pocketCoderProgressDeployPocketCoder => 'DEPLOY POCKETCODER';

  @override
  String get pocketCoderProgressWaiting => 'WAITING';

  @override
  String get pocketCoderProgressActive => 'ACTIVE';

  @override
  String get pocketCoderProgressComplete => 'DONE';

  @override
  String get pocketCoderProgressFailed => 'FAILED';

  @override
  String get pocketCoderProgressInitializing => 'INITIALIZING';

  @override
  String get deploymentScreenTitle => 'DEPLOYMENT IN PROGRESS';

  @override
  String get deploymentActionAbort => 'ABORT';

  @override
  String get deploymentActionRetryScan => 'RETRY SCAN';

  @override
  String get deploymentUnknown => 'UNKNOWN';

  @override
  String get deploymentNetworkIp => 'NETWORK IP';

  @override
  String get deploymentGeoGrid => 'GEO GRID';

  @override
  String deploymentFaultDetected(String error) {
    return 'FAULT DETECTED: $error';
  }

  @override
  String get deploymentFaultGeneric =>
      'SETUP COULD NOT CONTINUE. RETURN AND TRY AGAIN.';

  @override
  String get deploymentFailed =>
      'SETUP COULD NOT CONTINUE. RETURN AND TRY AGAIN.';

  @override
  String deploymentReady(String ipAddress) {
    return 'SERVER READY AT $ipAddress.';
  }

  @override
  String get deploymentInProgress => 'SERVER SETUP STARTED.';

  @override
  String get deploymentStatusValidating => 'VALIDATING CONFIGURATION';

  @override
  String get deploymentStatusConstructing => 'CONSTRUCTING INSTANCE';

  @override
  String get deploymentStatusPreparingOperatingSystem => 'PREPARING OS';

  @override
  String get deploymentStatusSecuring => 'SECURING CONNECTION';

  @override
  String get deploymentStatusConfiguringOperatingSystem => 'CONFIGURING OS';

  @override
  String get deploymentStatusFetching => 'FETCHING RELEASE';

  @override
  String get deploymentStatusLoadingImages => 'LOADING IMAGES';

  @override
  String get deploymentStatusStarting => 'STARTING SERVICES';

  @override
  String get deploymentStatusFinishing => 'FINISHING UP';

  @override
  String get deploymentStatusReady => 'HANDSHAKE SUCCESSFUL';

  @override
  String get deploymentStatusFailed => 'DEPLOYMENT ABORTED';

  @override
  String get deploymentStatusInitializing => 'INITIALIZING STACK';

  @override
  String get deploymentDescriptionValidating =>
      'CHECKING THE PROVISIONING CONFIGURATION.';

  @override
  String get deploymentDescriptionConstructing =>
      'ALLOCATING HARDWARE RESOURCES ON CLOUD GRID.';

  @override
  String get deploymentDescriptionPreparingOperatingSystem =>
      'PREPARING THE OPERATING SYSTEM.';

  @override
  String get deploymentDescriptionSecuring =>
      'WAITING FOR THE NATIVE REVERSE PROXY.';

  @override
  String get deploymentDescriptionConfiguringOperatingSystem =>
      'PREPARING NATIVE SERVICES AND DEPENDENCIES.';

  @override
  String get deploymentDescriptionFetching => 'FETCHING THE IMMUTABLE RELEASE.';

  @override
  String get deploymentDescriptionLoadingImages =>
      'LOADING THE VERIFIED IMAGE BUNDLE.';

  @override
  String get deploymentDescriptionStarting => 'STARTING APPLICATION SERVICES.';

  @override
  String get deploymentDescriptionFinishing => 'FINISHING DEPLOYMENT.';

  @override
  String get deploymentDescriptionReady => 'THE SERVER IS FULLY OPERATIONAL.';

  @override
  String get deploymentDescriptionFailed =>
      'SETUP STOPPED BEFORE COMPLETION. NO LATER STEP WILL CONTINUE.';

  @override
  String get deploymentDescriptionInitializing =>
      'PREPARING DEPLOYMENT MANIFEST.';

  @override
  String deploymentStatusPrefix(String status) {
    return 'STATUS: $status';
  }

  @override
  String get deploymentSecure => '[SECURE]';

  @override
  String get deploymentConnectionParameters => 'CONNECTION PARAMETERS';

  @override
  String get deploymentMetadataRegistry => 'METADATA REGISTRY';

  @override
  String get deploymentActionLoginNow => 'LOG IN NOW';

  @override
  String get deploymentActionRefresh => 'REFRESH';

  @override
  String get deploymentActionUpdate => 'UPDATE';

  @override
  String get deploymentActionDismiss => 'DISMISS';

  @override
  String get deploymentInstanceManifest => 'INSTANCE MANIFEST';

  @override
  String get deploymentIpAddress => 'IP ADDRESS';

  @override
  String get deploymentHttpsEndpoint => 'HTTPS ENDPOINT';

  @override
  String get deploymentAdminIdentity => 'ADMIN IDENTITY';

  @override
  String get deploymentAdminPassword => 'ADMIN PASSWORD';

  @override
  String get deploymentProvisioned => 'PROVISIONED';

  @override
  String get deploymentCloudRegion => 'CLOUD REGION';

  @override
  String get deploymentHardwarePlan => 'HARDWARE PLAN';

  @override
  String get deploymentSecurityNotice =>
      'SECURITY NOTICE: CREDENTIALS ARE STORED IN LOCAL SECURE ENCLAVE. PASSPHRASE RETAINS ENCRYPTION AT REST.';

  @override
  String deploymentCopiedToBuffer(String label) {
    return '$label COPIED TO BUFFER';
  }

  @override
  String deploymentCopyLabel(String label) {
    return 'COPY $label';
  }

  @override
  String get deploymentManifestConfiguration => 'MANIFEST CONFIGURATION';

  @override
  String get deploymentActionBack => 'BACK';

  @override
  String get deploymentActionDeployInstance => 'DEPLOY INSTANCE';

  @override
  String get deploymentActionProvisionServer => 'PROVISION SERVER';

  @override
  String get deploymentSystemParameters => 'SYSTEM PARAMETERS';

  @override
  String get deploymentHardwareGeography => 'HARDWARE & GEOGRAPHY';

  @override
  String get deploymentInitializingHardware => 'INITIALIZING HW REGISTRY...';

  @override
  String get deploymentScanningRegions => 'SCANNING GLOBAL REGIONS...';

  @override
  String get deploymentCodingHarnesses => 'CODING HARNESSES';

  @override
  String get deploymentHarnessSelectionDescription =>
      'Choose what is downloaded onto your VPS. Goose is ready by default; you can select more than one.';

  @override
  String get deploymentOperatingSystem => 'OPERATING SYSTEM';

  @override
  String get deploymentInstancePlan => 'INSTANCE PLAN';

  @override
  String deploymentMonthlyPrice(String price) {
    return '$price/MO';
  }

  @override
  String get deploymentRegion => 'DEPLOYMENT REGION';

  @override
  String get deploymentBackend => 'BACKEND';

  @override
  String get deploymentDistribution => 'DISTRIBUTION';

  @override
  String get deploymentNixos => 'NixOS';

  @override
  String get deploymentStandardLinux => 'Standard Linux';

  @override
  String get deploymentDebian => 'Debian';

  @override
  String get deploymentUbuntu => 'Ubuntu';

  @override
  String get deploymentSetupTypeTitle => 'CHOOSE YOUR SETUP';

  @override
  String get deploymentServerSizeTitle => 'CHOOSE YOUR SERVER SIZE';

  @override
  String get deploymentServerRegionTitle => 'CHOOSE YOUR SERVER REGION';

  @override
  String get deploymentCodingAgentsTitle => 'CHOOSE CODING AGENTS';

  @override
  String get deploymentLinuxSystemTitle => 'CHOOSE LINUX SYSTEM';

  @override
  String get deploymentReviewTitle => 'REVIEW YOUR SERVER';

  @override
  String get deploymentWorkloadPoco =>
      'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.';

  @override
  String get deploymentWorkloadCloudReply =>
      'Cloud models run inference through your online AI account. Your server mainly needs room for PocketCoder, your agents, and your projects.\n\nI’ll show the minimum server size I recommend. You can choose a larger one.';

  @override
  String get deploymentWorkloadLocalReply =>
      'A local model runs on your own server through Ollama. It needs more computing power, and is usually faster with a GPU.\n\nI’ll show the minimum server size I recommend. You can choose a larger one.';

  @override
  String get deploymentUseCloudModels => 'USE CLOUD MODELS';

  @override
  String get deploymentRunLocalModel => 'RUN A LOCAL MODEL';

  @override
  String get deploymentPlanPoco =>
      'Here are the server sizes available from Linode.\n\nThe highlighted option is the minimum I recommend for the setup you chose. You can select a larger server.';

  @override
  String get deploymentRegionPoco =>
      'Choose where your server will live. A nearby region will usually respond faster, but you can use any available Linode region.';

  @override
  String get deploymentHarnessPoco =>
      'Now choose which coding agents to have ready on your server.\n\nThis installs their software. You’ll connect any required accounts after your server is ready.';

  @override
  String get deploymentLinuxPoco =>
      'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.';

  @override
  String get deploymentReviewPoco =>
      'Your server is ready to be provisioned.\n\nPocketCoder will create it in your Linode account, then install the coding agents you selected. Linode will bill you directly for the server.';

  @override
  String get deploymentNoSuitablePlans =>
      'NO SUITABLE SERVER SIZES ARE AVAILABLE FOR THIS SETUP.';

  @override
  String get deploymentRecommendedMinimum => 'RECOMMENDED MINIMUM';

  @override
  String get deploymentRecommended => 'RECOMMENDED';

  @override
  String get deploymentGpuBadge => 'GPU';

  @override
  String get deploymentDefaultAgent => 'READY BY DEFAULT';

  @override
  String deploymentPlanSpecs(int vcpus, String memory, int diskGb) {
    return '$vcpus CPU · $memory RAM · $diskGb GB DISK';
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
  String get deploymentProvisioningSummary => 'PROVISIONING SUMMARY';

  @override
  String get deploymentServerProvider => 'SERVER PROVIDER';

  @override
  String get deploymentProviderLinode => 'LINODE';

  @override
  String walkthroughLabel(int current, int total) {
    return 'WALKTHROUGH $current / $total';
  }

  @override
  String briefLabel(int current, int total) {
    return 'BRIEF $current / $total';
  }

  @override
  String get walkthroughAskPoco => 'ASK POCO';

  @override
  String get walkthroughBriefDivider => 'BRIEF';

  @override
  String get walkthroughTransitionProvisioning =>
      'Let’s follow this next part of the server setup together.';

  @override
  String get walkthroughTransitionDeployment =>
      'Now we’ll follow the verified release onto the host.';

  @override
  String deploymentSyncAttempt(int attempt) {
    return 'SYNC ATTEMPT: $attempt';
  }

  @override
  String get deploymentCurrentOperation => 'CURRENT OPERATION';

  @override
  String get deploymentSourceCommit => 'SOURCE COMMIT';

  @override
  String get deploymentRunId => 'DEPLOYMENT RUN';

  @override
  String get deploymentStatusSchema => 'STATUS SCHEMA';

  @override
  String get deploymentLastSignal => 'LAST SERVER SIGNAL';

  @override
  String get deploymentErrorCode => 'SERVER ERROR CODE';

  @override
  String get pocoProvisioningTourTitle => 'POCO WALKTHROUGH';

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
  String get pocoProvisioningPrevious => 'PREVIOUS';

  @override
  String get pocoProvisioningNext => 'NEXT';

  @override
  String get pocoProvisioningShowFull => 'SHOW FULL SNIPPET';

  @override
  String get pocoProvisioningShowConcise => 'SHOW PREVIEW';

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
  String get pocoLessonDockerTitle => 'The container engine';

  @override
  String get pocoLessonDockerExplanation =>
      'Docker runs each PocketCoder component in a defined container. NixOS manages the Docker engine itself, while Compose describes what Docker should run.';

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
  String get pocoLessonReleaseSourceTitle => 'The exact release source';

  @override
  String get pocoLessonReleaseSourceExplanation =>
      'The server checks out the precise Git commit embedded in the release. That makes the code on your VPS inspectable and keeps later updates tied to a real repository.';

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
      'Cognee is an optional memory service. Its initialization step fixes storage ownership first, and its private network lets the agent reach memory without exposing it publicly.';

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
  String get onboardingNoServerChipExisting => 'YES — CONNECT ME';

  @override
  String get onboardingNoServerChipNew => 'NO — I’D LIKE TO JOIN';

  @override
  String get onboardingWelcomeTitle => 'WELCOME';

  @override
  String get onboardingWelcomePoco =>
      'Welcome to the PocketCoder Initiative.\n\nI’ll help you set up PocketCoder on a server—a computer that stays online. That way, PocketCoder is accessible and ready whenever you need it.';

  @override
  String get onboardingWelcomeActionGuided => 'HELP ME WITH SETUP';

  @override
  String get onboardingWelcomeActionSelfHost => 'I’LL SET IT UP';

  @override
  String get onboardingSelfHostTitle => 'SELF-HOST SETUP';

  @override
  String get onboardingSelfHostPoco =>
      'You’ll set up PocketCoder on a server you control. The setup guide walks through preparing the server, deploying PocketCoder, and finding the address you’ll use to connect this app.';

  @override
  String get onboardingSelfHostRequirementsTitle => 'WHAT YOU’LL NEED';

  @override
  String get onboardingSelfHostRequirementServer =>
      'A LINUX SERVER OR VPS YOU CONTROL';

  @override
  String get onboardingSelfHostRequirementDocker => 'DOCKER COMPOSE V2';

  @override
  String get onboardingSelfHostRequirementAccess => 'SSH ACCESS TO THE SERVER';

  @override
  String get onboardingSelfHostActionGuide => 'OPEN SETUP GUIDE';

  @override
  String get onboardingSelfHostActionConnect => 'CONNECT TO MY SERVER';

  @override
  String get onboardingSignInPoco =>
      'Welcome. We’ll set up a server: a small computer that stays online and runs PocketCoder for you.\n\nStart by choosing the email and password you’ll use to sign in when it’s ready.';

  @override
  String get onboardingSignInTitle => 'SET UP YOUR SIGN-IN';

  @override
  String get onboardingProviderPoco =>
      'Okay, here are our options for who will host your server.\n\nA server provider gives it a computer and internet connection, then keeps it online.';

  @override
  String get onboardingProviderTitle => 'CHOOSE A SERVER PROVIDER';

  @override
  String get onboardingProviderChipLinode => 'LINODE';

  @override
  String get onboardingProviderChipElestioComingSoon => 'ELESTIO — COMING SOON';

  @override
  String onboardingTrialPoco(int trialDuration) {
    return 'Your server and AI accounts are yours, and each provider bills you directly. PocketCoder helps you connect and set everything up.\n\nPocketCoder Pro includes a $trialDuration-day free trial. It lets you provision servers and receive notifications from your agents. When the trial ends, your server keeps running exactly as it is.\n\nYour server provider may offer its own trial or credit as well.';
  }

  @override
  String get onboardingTrialChipStart => 'START FREE TRIAL';

  @override
  String get onboardingTrialChipNotNow => 'NOT NOW';

  @override
  String get onboardingProviderAuthorizationPoco =>
      'Connect or create your server provider account. The next page will let you sign in or make one.\n\nWhen you authorize PocketCoder, it will provision a server and deploy PocketCoder on your behalf.';

  @override
  String get onboardingProviderAuthorizationTitle =>
      'CONNECT YOUR SERVER PROVIDER';

  @override
  String onboardingProviderAuthorizationAction(String providerName) {
    return 'CONTINUE WITH $providerName';
  }

  @override
  String get onboardingProviderAuthorizationWaiting =>
      'WAITING FOR PROVIDER SIGN-IN';

  @override
  String get onboardingProviderAuthorizationError => 'CONNECTION STOPPED';

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
  String get onboardingIntentChipCloudModels => 'USE CLOUD MODELS';

  @override
  String get onboardingIntentChipLocalModels => 'RUN A LOCAL MODEL';

  @override
  String onboardingPlanPoco(String providerName) {
    return 'Here are the server sizes available from $providerName.\n\nThe highlighted option is the minimum I recommend for the setup you chose. You can select a larger server at any time.';
  }

  @override
  String get onboardingPlanTitle => 'CHOOSE YOUR SERVER SIZE';

  @override
  String get onboardingRegionConsentPoco =>
      'I can find server regions near you, if you want.\n\nYour location stays on this phone. I only use it to sort the available regions by distance.';

  @override
  String get onboardingRegionConsentChipUseLocation => 'USE MY LOCATION';

  @override
  String get onboardingRegionConsentChipChooseMyself => 'I’LL CHOOSE MYSELF';

  @override
  String get onboardingRegionPoco =>
      'A region is the city where your server—and its data—will live. Choose one close to you, or to people who will use PocketCoder most.';

  @override
  String get onboardingRegionTitle => 'CHOOSE YOUR SERVER REGION';

  @override
  String get onboardingHarnessPoco =>
      'Now choose which coding agents to have ready on your server.\n\nA harness is the connection PocketCoder uses to work with a coding agent. This only installs the software; you’ll connect any required accounts after your server is ready.';

  @override
  String get onboardingHarnessTitle => 'CHOOSE CODING AGENTS';

  @override
  String get onboardingOsPoco =>
      'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.';

  @override
  String get onboardingOsTitle => 'CHOOSE LINUX SYSTEM';

  @override
  String get onboardingOsNixosLabel => 'NIXOS — RECOMMENDED';

  @override
  String onboardingOsNixosDescription(int minutes) {
    return 'Repeatable server setup, easier to recreate and roll back if a system change goes wrong. Estimated about $minutes min.';
  }

  @override
  String get onboardingOsDebianLabel => 'DEBIAN';

  @override
  String onboardingOsDebianDescription(int minutes) {
    return 'Debian server configured with setup scripts. Faster to set up: about $minutes min.';
  }

  @override
  String onboardingReviewPoco(String providerName) {
    return 'Your server is ready to be provisioned.\n\nPocketCoder will create it in your $providerName account, then install the coding agents you selected. Your provider bills you directly.';
  }

  @override
  String get onboardingReviewTitle => 'REVIEW YOUR SERVER';

  @override
  String get onboardingReviewActionProvision => 'PROVISION SERVER';

  @override
  String get onboardingProvisioningPoco =>
      'Provisioning is underway. While the new server comes online, welcome to PocketCoder Initiative orientation.\n\nI’ll show you what we’re building, one piece at a time.';

  @override
  String get onboardingOrientationTitle => 'INITIATIVE ORIENTATION';

  @override
  String get onboardingOrientationActionSkip => 'SKIP ORIENTATION';

  @override
  String get onboardingOrientationActionContinue => 'CONTINUE ORIENTATION';

  @override
  String get onboardingDockerIntroEyebrow => 'INTRODUCTION';

  @override
  String get onboardingDockerIntroTitle => 'DOCKER AND CONTAINERS';

  @override
  String get onboardingDockerIntroPoco =>
      'PocketCoder is made of software components, such as its dashboard and coding agents. Docker runs each component in its own separate container on your server.';

  @override
  String get onboardingDockerIntroActionStart => 'START WALKTHROUGH';

  @override
  String get onboardingDockerIntroChipComponent => 'WHAT IS A COMPONENT?';

  @override
  String get onboardingDockerIntroChipContainer => 'WHAT IS A CONTAINER?';

  @override
  String get onboardingDockerIntroChipSavedData => 'WHAT IS SAVED DATA?';

  @override
  String get onboardingDockerIntroChipConnections => 'WHAT ARE CONNECTIONS?';

  @override
  String get onboardingReadyPoco =>
      'Your PocketCoder server is ready.\n\nWelcome to the PocketCoder Initiative, Commander.\n\nYour server is online at its new HTTPS address. Your selected coding harnesses are ready.';

  @override
  String get onboardingReadyActionLogin => 'LOG IN TO POCKETCODER';

  @override
  String onboardingFailureConnectionPoco(String providerName) {
    return 'I couldn’t confirm that PocketCoder finished setting up.\n\nYour server is still available in your $providerName account.';
  }

  @override
  String get onboardingFailureActionRetryConnection => 'RETRY CONNECTION';

  @override
  String get onboardingFailureActionViewServerDetails => 'VIEW SERVER DETAILS';

  @override
  String get onboardingFailureCreatePoco =>
      'The server could not be created.\n\nNothing was deployed. Check your server provider connection, then try again.';

  @override
  String get onboardingFailureActionBackToSetup => 'BACK TO SETUP';

  @override
  String get onboardingFailureActionTechnicalDetails =>
      'SHOW TECHNICAL DETAILS';

  @override
  String walkthroughHeader(String os, int current, int total) {
    return '$os SERVER SETUP · WALKTHROUGH $current / $total';
  }

  @override
  String walkthroughProgress(int current, int total, String brief) {
    return 'WALKTHROUGH $current/$total · BRIEF $brief';
  }

  @override
  String get walkthroughActionShowFullCode => 'SHOW FULL CODE';

  @override
  String get walkthroughActionShowConciseCode => 'SHOW CONCISE CODE';

  @override
  String get walkthroughCaddyAddressTitle => 'YOUR HTTPS ADDRESS';

  @override
  String get walkthroughCaddyAddressPoco =>
      'First, the server finds its public IP address and turns it into an HTTPS address using sslip.io. PocketCoder saves that address so the mobile app knows where to sign in.';

  @override
  String get walkthroughCaddyAddressChipIpAddress => 'WHAT IS AN IP ADDRESS?';

  @override
  String get walkthroughCaddyAddressChipHttps => 'WHAT IS HTTPS?';

  @override
  String get walkthroughCaddyAddressChipSslip => 'WHAT IS SSLIP.IO?';

  @override
  String get walkthroughCaddyWebEntryTitle => 'THE SECURE WEB ENTRY';

  @override
  String get walkthroughCaddyWebEntryPoco =>
      'Caddy runs directly on the server. It sends regular web traffic to HTTPS, shares PocketCoder’s deployment status, and passes app requests to PocketBase without exposing PocketBase’s own port.';

  @override
  String get walkthroughCaddyWebEntryChipCaddy => 'WHAT IS CADDY?';

  @override
  String get walkthroughCaddyWebEntryChipPrivatePort =>
      'WHY IS POCKETBASE\'S PORT PRIVATE?';

  @override
  String get walkthroughNixosStorageTitle => 'YOUR SERVER DISK';

  @override
  String get walkthroughNixosStoragePoco =>
      'This tells NixOS where PocketCoder’s main disk is and lets it expand to use the full size of the server you chose. Without autoResize, it could stay stuck at the smaller size of its original image.';

  @override
  String get walkthroughNixosNetworkTitle => 'NETWORK BOUNDARIES';

  @override
  String get walkthroughNixosNetworkPoco =>
      'These rules open the three standard entry ports to your server: HTTP and HTTPS for the PocketCoder website, and SSH for secure remote access. Since PocketCoder runs inside Docker, it needs its own specific rules without opening extra entry ports to the internet.';

  @override
  String get walkthroughNixosNetworkChipPorts =>
      'WHAT ARE HTTP, HTTPS, AND SSH?';

  @override
  String get walkthroughNixosNetworkChipDockerRules =>
      'WHY DOES DOCKER NEED ITS OWN RULES?';

  @override
  String get walkthroughNixosNetworkChipIpVersions => 'WHAT ARE IPv4 AND IPv6?';

  @override
  String get walkthroughNixosSshTitle => 'KEY-ONLY SSH';

  @override
  String get walkthroughNixosSshPoco =>
      'SSH is the secure way to administer a server from another device—even a phone. We accept only your SSH key—not passwords—and temporarily block repeated failed attempts.';

  @override
  String get walkthroughNixosDockerTitle => 'DOCKER';

  @override
  String get walkthroughNixosDockerPoco =>
      'This turns on Docker, the system that runs PocketCoder’s containers. It sends their logs to NixOS’s built-in system log, so there is one place to check what happened.';

  @override
  String get walkthroughServerKeyTitle => 'YOUR SERVER KEY';

  @override
  String get walkthroughServerKeyPoco =>
      'Before PocketCoder starts, this installs your public SSH key on the server. The mobile app keeps the matching private SSH key securely on your phone: the public key is the lock, and the private key is the key that opens it.';

  @override
  String get walkthroughServerKeyChipPrivate => 'WHAT IS A PRIVATE SSH KEY?';

  @override
  String get walkthroughServerKeyChipPublic => 'WHAT IS A PUBLIC SSH KEY?';

  @override
  String get walkthroughServerKeyChipSsh => 'WHAT IS SSH?';

  @override
  String get walkthroughVerifiedVersionTitle => 'VERIFIED POCKETCODER VERSION';

  @override
  String get walkthroughVerifiedVersionPoco =>
      'This downloads the exact PocketCoder version for your server, verifies it, then installs it.';

  @override
  String get walkthroughVerifiedVersionChipVerification =>
      'HOW IS THE VERSION VERIFIED?';

  @override
  String get walkthroughVerifiedVersionChipDownloadFailure =>
      'WHAT HAPPENS IF THE DOWNLOAD FAILS?';

  @override
  String get walkthroughVerifiedVersionChipUpdates => 'CAN I UPDATE LATER?';

  @override
  String get walkthroughStartPocketCoderTitle => 'START POCKETCODER';

  @override
  String get walkthroughStartPocketCoderPoco =>
      'This starts the verified PocketCoder version with only the coding harnesses you chose.';

  @override
  String get walkthroughStartPocketCoderChipWhatStarts =>
      'WHAT STARTS AFTER THIS?';

  @override
  String get walkthroughStartPocketCoderChipAddHarness =>
      'CAN I ADD A HARNESS LATER?';

  @override
  String get walkthroughNixosDockerRulesTitle => 'DOCKER FIREWALL RULES';

  @override
  String get walkthroughNixosDockerRulesPoco =>
      'Docker needs its own rules because it manages a separate path for container traffic. These rules keep the same boundaries without opening extra entry ports.';

  @override
  String get walkthroughRuntimeSettingsTitle => 'LOCAL SETTINGS';

  @override
  String get walkthroughRuntimeSettingsPoco =>
      'This prepares PocketCoder’s local settings file and locks it so only its administrator—you—can read it. It creates the internal credentials PocketCoder needs to run.';

  @override
  String get walkthroughRuntimeSettingsChipLocalSettings =>
      'WHAT ARE LOCAL SETTINGS?';

  @override
  String get walkthroughRuntimeVersionTitle => 'RUNNING VERSION';

  @override
  String get walkthroughRuntimeVersionPoco =>
      'PocketCoder records the version it is running in the same protected settings file.';

  @override
  String get walkthroughActivationPrepareTitle => 'PREPARE THE RELEASE';

  @override
  String get walkthroughActivationPreparePoco =>
      'This checks that the release files match the verified PocketCoder version and prepares them for installation. It also sets up status reporting for the PocketCoder deployment.';

  @override
  String get walkthroughActivationSelectedSoftwareTitle => 'SELECTED SOFTWARE';

  @override
  String get walkthroughActivationSelectedSoftwarePoco =>
      'Next, the server loads PocketCoder and only the coding agents you chose. It checks each software component before Docker runs it.';

  @override
  String get walkthroughActivationSwitchTitle => 'MAKE IT ACTIVE';

  @override
  String get walkthroughActivationSwitchPoco =>
      'This makes the new PocketCoder version active and starts its containers. It uses prebuilt software for faster setup and consistent versioning.';

  @override
  String get walkthroughActivationHealthTitle => 'CHECK THE DEPLOYMENT';

  @override
  String get walkthroughActivationHealthPoco =>
      'Before calling the deployment complete, PocketCoder checks that its core and optional services are healthy. Only then does it record this version as active.';

  @override
  String get walkthroughDebianSetupStatusTitle => 'SETUP STATUS';

  @override
  String get walkthroughDebianSetupStatusPoco =>
      'This setup script keeps PocketCoder’s deployment status up to date as it runs. If something fails, it records where and cleans up temporary files so it can be checked or safely retried.';

  @override
  String get walkthroughDebianSetupStatusChipStatus =>
      'HOW IS DEPLOYMENT STATUS SHOWN?';

  @override
  String get walkthroughDebianSetupStatusChipFailure =>
      'WHAT HAPPENS IF SETUP FAILS?';

  @override
  String get walkthroughServicesComposeTitle => 'THE DOCKER BLUEPRINT';

  @override
  String get walkthroughServicesComposePoco =>
      'Docker Compose is PocketCoder’s blueprint. It keeps your data when we update the software, and gives each component only the connections it needs.';

  @override
  String get walkthroughServicesComposeChipDockerCompose =>
      'WHAT IS DOCKER COMPOSE?';

  @override
  String get walkthroughServicesComposeChipSavedData => 'WHAT IS SAVED DATA?';

  @override
  String get walkthroughServicesComposeChipPrivateConnections =>
      'WHAT ARE PRIVATE CONNECTIONS?';

  @override
  String get walkthroughServicesPocketBaseTitle => 'POCKETBASE';

  @override
  String get walkthroughServicesPocketBasePoco =>
      'PocketBase keeps the information PocketCoder needs to run: your sign-in, skills, prompts, agent connections, and API keys. That information stays on your server, and you reach it through the HTTPS address Caddy just set up.';

  @override
  String get walkthroughServicesPocketBaseChipKeeps =>
      'WHAT DOES POCKETBASE KEEP?';

  @override
  String get walkthroughServicesPocketBaseChipSignIn =>
      'HOW DO I SIGN IN SECURELY?';

  @override
  String get walkthroughServicesPocketBaseChipUpdates =>
      'WHAT HAPPENS WHEN POCKETCODER UPDATES?';

  @override
  String get walkthroughServicesHarnessesTitle => 'CODING HARNESSES';

  @override
  String walkthroughServicesHarnessesPoco(String selectedHarnesses) {
    return 'PocketCoder prepares the coding harnesses you selected: $selectedHarnesses. Each gets its own container, saved workspace, and only the private connections it needs.';
  }

  @override
  String get walkthroughServicesHarnessesChipHarness =>
      'WHAT IS A CODING HARNESS?';

  @override
  String get walkthroughServicesHarnessesChipWorkspace =>
      'WHAT IS A SAVED WORKSPACE?';

  @override
  String get walkthroughServicesHarnessesChipAdd =>
      'CAN I ADD A HARNESS LATER?';

  @override
  String get walkthroughServicesToolsTitle => 'TOOL CONNECTIONS';

  @override
  String get walkthroughServicesToolsPoco =>
      'The MCP Gateway is a controlled connection point for extra tools your coding harnesses can use. Its separate Docker proxy grants only the permissions those tools need, while blocking more sensitive actions such as accessing saved data or secrets.';

  @override
  String get walkthroughServicesToolsChipMcp => 'WHAT IS MCP?';

  @override
  String get walkthroughServicesToolsChipHarnessTools =>
      'WHAT TOOLS CAN A HARNESS USE?';

  @override
  String get walkthroughServicesToolsChipProxy =>
      'WHY DOES THIS HAVE A SEPARATE PROXY?';

  @override
  String get walkthroughServicesOllamaTitle => 'LOCAL MODELS';

  @override
  String get walkthroughServicesOllamaPoco =>
      'Ollama is ready to run AI models directly on your server. It appears because you chose a local-model setup; when you later choose a model, PocketCoder downloads it and keeps it as saved data.';

  @override
  String get walkthroughServicesOllamaChipLocalModel =>
      'WHAT IS A LOCAL MODEL?';

  @override
  String get walkthroughServicesOllamaChipDownload =>
      'WHEN IS A MODEL DOWNLOADED?';

  @override
  String get walkthroughServicesOllamaChipGpu =>
      'DOES THIS USE MY SERVER\'S GPU?';

  @override
  String get walkthroughServicesCogneeTitle => 'LONG-TERM MEMORY';

  @override
  String get walkthroughServicesCogneeBadge => 'COMING SOON';

  @override
  String get walkthroughServicesCogneePoco =>
      'Cognee will help PocketCoder build long-term memory from your work. It is not included in this setup yet, so there is nothing more to configure today.';

  @override
  String get walkthroughServicesSqlPageTitle => 'SERVER DASHBOARD';

  @override
  String get walkthroughServicesSqlPagePoco =>
      'SQLPage is PocketCoder’s built-in dashboard for showing what is happening on your server. It starts after PocketBase is ready and uses saved PocketCoder data to build those pages.';

  @override
  String get walkthroughServicesSqlPageChipContents =>
      'WHAT CAN THIS DASHBOARD SHOW?';

  @override
  String get walkthroughServicesSqlPageChipStartOrder =>
      'WHY DOES IT START AFTER POCKETBASE?';

  @override
  String get permissionSignoffTitle => 'COMMANDER\'S SIGNOFF';

  @override
  String permissionRequestingLabel(String source) {
    return '$source IS REQUESTING PERMISSION:';
  }

  @override
  String get permissionPatternsLabel => 'Patterns:';

  @override
  String get questionIncomingTitle => 'INCOMING QUERY';

  @override
  String get questionPocoAsking => 'POCO IS ASKING:';

  @override
  String get questionSendReply => 'SEND REPLY';

  @override
  String get thoughtsWaiting => '[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]';

  @override
  String notificationSignalReceived(String title) {
    return 'SIGNAL RECEIVED: $title';
  }

  @override
  String get errorsTitle => 'ERROR REPORTS';

  @override
  String get errorsEmpty => 'NO ERRORS CAPTURED';

  @override
  String get errorsCopy => 'COPY REPORT';

  @override
  String get errorsCopyAll => 'COPY ALL';

  @override
  String get errorsCopied => 'DIAGNOSTIC REPORT COPIED';

  @override
  String get errorsClearAll => 'CLEAR ALL';

  @override
  String get harnessAuthChallengeTargetCopied => 'CHALLENGE TARGET COPIED';

  @override
  String get serverUpdateChecking => '\$ CHECKING VERIFIED RELEASE STATUS...';

  @override
  String get serverUpdateCheckAgain => 'CHECK AGAIN';

  @override
  String get actionDismiss => 'DISMISS';

  @override
  String get serverUpdateWorking => 'UPGRADING...';

  @override
  String get serverUpdateUpgrade => 'UPGRADE POCKETCODER';

  @override
  String get serverUpdateCommand => 'pocketcoder-release update';

  @override
  String get serverUpdateOutput => 'OUTPUT';

  @override
  String get serverUpdateReviewDataChange => 'REVIEW DATA CHANGE';

  @override
  String get serverUpdateConfirmUpgrade => 'CONFIRM UPGRADE';

  @override
  String get serverUpdateCurrent => 'CURRENT';

  @override
  String get serverUpdateAvailable => 'AVAILABLE';

  @override
  String get serverUpdateDownload => 'DOWNLOAD';

  @override
  String get serverUpdateRequiredDisk => 'REQUIRED DISK';

  @override
  String get serverUpdateCurrentStatus => '\$ POCKETCODER IS CURRENT';

  @override
  String get serverUpdateAvailableStatus => '\$ UPDATE AVAILABLE';

  @override
  String get serverUpdateCriticalStatus => '\$ CRITICAL RELEASE WARNING';

  @override
  String get serverUpdateUnknownStatus => '\$ RELEASE STATUS UNKNOWN';

  @override
  String get serverUpdateRollbackWarning =>
      'AFTER SUCCESS, NORMAL ROLLBACK IS UNAVAILABLE. RESTORING THE PRE-UPGRADE SNAPSHOT WOULD DISCARD DATA CREATED AFTERWARD.';

  @override
  String serverUpdateDataBoundary(int currentVersion, int availableVersion) {
    return 'DATA VERSION $currentVersion → $availableVersion';
  }

  @override
  String errorsOccurred(int count) {
    return 'Occurred ${count}x';
  }
}
