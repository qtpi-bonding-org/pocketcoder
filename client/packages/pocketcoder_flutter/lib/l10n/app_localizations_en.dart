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
  String get bootLoadError => 'SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS...';

  @override
  String get bootPocoIntro =>
      'Hi! I\'m Poco, your Private Operations Coding Officer. I help you build software on your own terms — private, powerful, and under your control. Let\'s get started!';

  @override
  String get bootCheckingConnection => 'Checking secure connection...';

  @override
  String get bootWelcomeBack => 'Welcome back.';

  @override
  String get bootSystemsNominal => 'Systems nominal. I\'m ready.';

  @override
  String get bootConnectionFailed =>
      'Connection failed. I\'ll take you back to reconnect.';

  @override
  String get onboardingTitle => 'IDENTIFICATION UNLOCK';

  @override
  String get onboardingPocoChallengeMessage =>
      'WHO GOES THERE? IDENTIFY YOURSELF. ENTER YOUR SERVER ADDRESS AND CREDENTIALS TO PROVE YOU BELONG HERE.';

  @override
  String get onboardingPocoWelcome =>
      'Identity verified! Welcome home, Commander. All systems are at your disposal.';

  @override
  String get onboardingAccessDenied => 'ACCESS DENIED.';

  @override
  String get onboardingProcessing => 'PROCESSING...';

  @override
  String get onboardingLogin => 'LOGIN';

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
  String get chatFilesAction => 'FILES';

  @override
  String get chatNewCapabilityRequest => '[!] NEW CAPABILITY REQUEST RECEIVED';

  @override
  String get chatThinking => 'THINKING';

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
  String get sopTitle => 'SOP MANAGEMENT';

  @override
  String get sopProjectProcedures => 'PROJECT PROCEDURES';

  @override
  String get sopNewProposal => 'NEW PROPOSAL';

  @override
  String get sopActiveProcedures => 'ACTIVE PROCEDURES';

  @override
  String get sopDraftProposals => 'DRAFT PROPOSALS';

  @override
  String get sopPendingSignature => 'PENDING SIGNATURE';

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
}
