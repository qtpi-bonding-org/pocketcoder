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
  String get onboardingLogin => 'LOGIN';

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
      'CONNECT TO AN EXISTING SERVER OR DEPLOY A NEW ONE.';

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
  String get chatListArchive => 'ARCHIVE';

  @override
  String get chatListDelete => 'DELETE';

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
  String get relayTitle => 'PERMISSION RELAY';

  @override
  String get relaySubsystem => 'RELAY SUBSYSTEM';

  @override
  String get relayCheckingStatus => 'CHECKING RELAY STATUS...';

  @override
  String get relayActive => '>>> RELAY ACTIVE <<<';

  @override
  String get relaySubsystemsNominal => 'SUBSYSTEMS NOMINAL';

  @override
  String get relayConfigSection => 'RELAY CONFIGURATION';

  @override
  String get relayActivate => 'ACTIVATE RELAY';

  @override
  String get relayRestore => 'RESTORE';

  @override
  String get relayFunctionalOverviewTitle => 'FUNCTIONAL OVERVIEW:';

  @override
  String get relayFunctionalOverviewBody =>
      'Permission Relays send agent intents to your device for remote authorization when you are away from the terminal.';

  @override
  String get relayUnlimitedCapacity =>
      'REMOTE AUTHORIZATION CAPACITY: UNLIMITED';

  @override
  String get relayPermissionRelayLabel => 'PERMISSION RELAY';

  @override
  String get relayNtfyTitle => 'NTFY RELAY';

  @override
  String get relayNtfyDescription =>
      'Connect to your own NTFY server for free, unlimited relays without registration.';

  @override
  String get deployTitle => 'DEPLOY POCKETCODER';

  @override
  String get deploySelectProvider => 'SELECT PROVIDER';

  @override
  String get deployChooseProvider => 'CHOOSE WHERE TO DEPLOY YOUR INSTANCE';

  @override
  String get deployProBadge => 'PRO';

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
  String errorsOccurred(int count) {
    return 'Occurred ${count}x';
  }
}
