# Localization Backlog

Generated: 2026-03-15

## Current State

- **19 ARB keys exist** — all cubit/service error messages (e.g. `authLoginFailed`, `chatSendFailed`)
- **0 presentation strings localized** — every widget uses hardcoded English
- **~170 hardcoded strings** across 18 files need extraction

Convention: dot-notation keys mapped to camelCase ARB keys (`app.title` -> `appTitle`).
Use `MessageKey` for programmatic strings in cubits/services.

## Shared Action Labels (reusable across screens)

These appear repeatedly and should be common keys:

| ARB Key | String |
|---|---|
| `actionCancel` | `CANCEL` |
| `actionSave` | `SAVE` |
| `actionClose` | `CLOSE` |
| `actionDeny` | `DENY` |
| `actionAuthorize` | `AUTHORIZE` |
| `actionRefresh` | `REFRESH` |
| `actionBack` | `BACK` |
| `actionChange` | `CHANGE` |
| `actionCreate` | `CREATE` |
| `actionAddNew` | `ADD NEW` |
| `actionRestore` | `RESTORE` |
| `actionConfigure` | `CONFIGURE` |
| `actionReject` | `REJECT` |

## Navigation Labels

| ARB Key | String |
|---|---|
| `navChats` | `CHATS` |
| `navMonitor` | `MONITOR` |
| `navConfigure` | `CONFIGURE` |

## By Screen

### Boot Screen (`boot_screen.dart`)

| ARB Key | String |
|---|---|
| `bootLoadError` | `SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS...` |
| `bootPocoIntro` | `Hi! I'm Poco, your Private Operations Coding Officer...` |
| `bootCheckingConnection` | `Checking secure connection...` |
| `bootWelcomeBack` | `Welcome back.` |
| `bootSystemsNominal` | `Systems nominal. I'm ready.` |
| `bootConnectionFailed` | `Connection failed. I'll take you back...` |

### Onboarding (`onboarding_screen.dart`)

| ARB Key | String |
|---|---|
| `onboardingTitle` | `IDENTIFICATION UNLOCK` |
| `onboardingPocoChallengeMessage` | `WHO GOES THERE? IDENTIFY YOURSELF...` |
| `onboardingPocoWelcome` | `Identity verified! Welcome home...` |
| `onboardingAccessDenied` | `ACCESS DENIED.` |
| `onboardingProcessing` | `PROCESSING...` |
| `onboardingLogin` | `LOGIN` |
| `onboardingHomeServer` | `HOME SERVER` |
| `onboardingIdentityLabel` | `IDENTITY` |
| `onboardingEmailHint` | `ENTER EMAIL` |
| `onboardingPassphraseLabel` | `PASSPHRASE` |
| `onboardingPasswordHint` | `ENTER PASSWORD` |
| `onboardingAuthenticating` | `AUTHENTICATING` |

### Home (`home_screen.dart`)

| ARB Key | String |
|---|---|
| `homeTitle` | `CHATS` |
| `homeLoadingChats` | `LOADING CHATS` |
| `homeErrorPrefix` | `ERROR: {error}` |
| `homeNewChat` | `NEW CHAT` |
| `homeNoChats` | `No active chats found.` |

### Chat (`chat_screen.dart`)

| ARB Key | String |
|---|---|
| `chatSessionTitle` | `CHAT SESSION` |
| `chatTerminalAction` | `TERMINAL` |
| `chatFilesAction` | `FILES` |
| `chatNewCapabilityRequest` | `[!] NEW CAPABILITY REQUEST RECEIVED` |
| `chatThinking` | `THINKING` |
| `chatModelLabel` | `MODEL:` |
| `chatModelDefault` | `DEFAULT` |
| `chatModelPerChat` | `[CHAT]` |
| `chatSelectModelTitle` | `SELECT MODEL` |
| `chatUseGlobalDefault` | `USE GLOBAL DEFAULT` |

### LLM Management (`llm_management_screen.dart`)

| ARB Key | String |
|---|---|
| `llmTitle` | `LLM MANAGEMENT` |
| `llmLoadingProviders` | `LOADING PROVIDERS` |
| `llmActiveModelSection` | `ACTIVE MODEL` |
| `llmProvidersSection` | `PROVIDERS` |
| `llmApiKeysSection` | `API KEYS` |
| `llmGlobalDefault` | `GLOBAL DEFAULT` |
| `llmNotSet` | `NOT SET` |
| `llmAddKeyHint` | `ADD AN API KEY TO ENABLE MODEL SELECTION` |
| `llmNoProviders` | `NO PROVIDERS AVAILABLE` |
| `llmConnected` | `[ CONNECTED ]` |
| `llmNoKey` | `[ NO KEY ]` |
| `llmModelsAvailable` | `{count} MODEL(S) AVAILABLE` (needs plural) |
| `llmUpdateKey` | `UPDATE KEY` |
| `llmAddKey` | `ADD KEY` |
| `llmModelsButton` | `MODELS` |
| `llmApiKeyDialogTitle` | `API KEY: {provider}` |
| `llmEnterCredentials` | `Enter credentials for {provider}:` |
| `llmSelectModelTitle` | `SELECT MODEL` |
| `llmProviderModelsTitle` | `{provider} MODELS` |
| `llmNoModels` | `NO MODELS LISTED` |
| `llmSelect` | `[ SELECT ]` |

### MCP Management (`mcp_management_screen.dart`)

| ARB Key | String |
|---|---|
| `mcpTitle` | `MCP MANAGEMENT` |
| `mcpCapabilitiesRegistry` | `CAPABILITIES REGISTRY` |
| `mcpPendingApproval` | `PENDING APPROVAL` |
| `mcpActiveCapabilities` | `ACTIVE CAPABILITIES` |
| `mcpNoCapabilities` | `NO CAPABILITIES REGISTERED` |
| `mcpImageLabel` | `IMAGE: {image}` |
| `mcpPurposeLabel` | `PURPOSE: {reason}` |
| `mcpRequiredConfig` | `REQUIRED CONFIG:` |
| `mcpAuthorizeCap` | `AUTHORIZE CAPABILITY` |
| `mcpEditConfig` | `EDIT CONFIGURATION` |
| `mcpRevoke` | `REVOKE` |
| `mcpAuthorizeDialogTitle` | `AUTHORIZE: {name}` |
| `mcpUpdateConfigDialogTitle` | `UPDATE CONFIG: {name}` |
| `mcpNoConfigRequired` | `No configuration required.` |
| `mcpEnterSecrets` | `Enter required secrets:` |

### Settings (`settings_screen.dart`)

| ARB Key | String |
|---|---|
| `settingsTitle` | `CONFIGURE` |
| `settingsAiAgentsSection` | `AI & AGENTS` |
| `settingsSecuritySection` | `SECURITY` |
| `settingsGovernanceSection` | `GOVERNANCE` |
| `settingsSystemSection` | `SYSTEM` |
| `settingsObservabilitySection` | `OBSERVABILITY` |

### Agent Management (`agent_management_screen.dart`)

| ARB Key | String |
|---|---|
| `agentTitle` | `AGENT REGISTRY` |
| `agentModelsPersonas` | `MODELS & PERSONAS` |
| `agentSearching` | `SEARCHING...` |
| `agentRegistryEmpty` | `REGISTRY EMPTY.` |
| `agentSelectToConfigure` | `SELECT AGENT TO CONFIGURE` |
| `agentDialogTitle` | `AGENT: {name}` |
| `agentNameLabel` | `NAME` |
| `agentDescriptionLabel` | `DESCRIPTION` |
| `agentPromptsLabel` | `PROMPTS` |
| `agentModelsLabel` | `MODELS` |
| `agentParametersLabel` | `PARAMETERS` |
| `agentNone` | `NONE` |
| `agentNoneSelected` | `NONE SELECTED` |
| `agentDefaultTuned` | `DEFAULT [TUNED]` |

### Tool Permissions (`tool_permissions_screen.dart`)

| ARB Key | String |
|---|---|
| `toolPermissionsTitle` | `GATEKEEPER CONFIGURATION` |
| `toolPermissionsFrameTitle` | `TOOL PERMISSIONS` |
| `toolPermissionsLoading` | `LOADING PERMISSIONS` |
| `toolPermissionsEmpty` | `NO PERMISSIONS DEFINED.` |
| `toolPermissionsAdd` | `ADD PERMISSION` |
| `toolPermissionsScopeAgent` | `AGENT` |
| `toolPermissionsScopeGlobal` | `GLOBAL` |
| `toolPermissionsAddTitle` | `ADD TOOL PERMISSION` |
| `toolPermissionsToolLabel` | `TOOL (e.g. bash, edit, cao_*)` |
| `toolPermissionsPatternLabel` | `PATTERN (e.g. *, git *, rm *)` |
| `toolPermissionsActionLabel` | `ACTION:` |

### Terminal (`terminal_screen.dart`)

| ARB Key | String |
|---|---|
| `terminalTitle` | `TERMINAL MIRROR` |
| `terminalTransfer` | `TRANSFER` |
| `terminalReconnect` | `RECONNECT` |
| `terminalConnecting` | `ESTABLISHING SSH LINK` |
| `terminalConnectionFailed` | `CONNECTION FAILED` |
| `terminalRetry` | `RETRY CONNECTION` |
| `terminalSftpTitle` | `SFTP TRANSFER` |
| `terminalDestinationPath` | `DESTINATION PATH` |
| `terminalUpload` | `UPLOAD` |
| `terminalConnectionStatus` | `CONNECTION_STATUS` |
| `terminalSshLink` | `SSH LINK: {host}:{port}` |
| `terminalOnline` | `ONLINE` |
| `terminalOffline` | `OFFLINE` |

### Monitor (`monitor_screen.dart`)

| ARB Key | String |
|---|---|
| `monitorTitle` | `MONITOR` |
| `monitorFetchingTelemetry` | `FETCHING TELEMETRY` |
| `monitorSystemHealth` | `SYSTEM HEALTH` |
| `monitorKeyMetrics` | `KEY METRICS` |
| `monitorTokenUsage` | `TOKEN USAGE BY MODEL` |
| `monitorAgentActivity` | `AGENT ACTIVITY` |
| `monitorTelemetryUnavailable` | `TELEMETRY UNAVAILABLE` |
| `monitorNoData` | `NO DATA — TAP REFRESH` |
| `monitorMessagesLabel` | `MESSAGES` |
| `monitorCostLabel` | `COST` |
| `monitorTokensLabel` | `TOKENS` |

### Files (`file_screen.dart`)

| ARB Key | String |
|---|---|
| `fileTitle` | `SOURCE OUTPUT MANIFEST` |
| `fileDashboardAction` | `DASHBOARD` |
| `fileClearAction` | `CLEAR` |
| `fileNoFileSelected` | `NO FILE SELECTED.` |
| `fileSelectFromChat` | `>> SELECT FROM CHAT TO VIEW` |
| `fileFetching` | `FETCHING DATA...` |
| `fileEmpty` | `EMPTY FILE` |

### SOP Management (`sop_management_screen.dart`)

| ARB Key | String |
|---|---|
| `sopTitle` | `SOP MANAGEMENT` |
| `sopProjectProcedures` | `PROJECT PROCEDURES` |
| `sopNewProposal` | `NEW PROPOSAL` |
| `sopActiveProcedures` | `ACTIVE PROCEDURES` |
| `sopDraftProposals` | `DRAFT PROPOSALS` |
| `sopPendingSignature` | `PENDING SIGNATURE` |

### System Checks (`system_checks_screen.dart`)

| ARB Key | String |
|---|---|
| `systemChecksTitle` | `SYSTEM CHECKS` |
| `systemChecksDiagnostics` | `SYSTEM DIAGNOSTICS` |
| `systemChecksEmpty` | `NO DIAGNOSTICS AVAILABLE` |

### Observability (`agent_observability_screen.dart`)

| ARB Key | String |
|---|---|
| `observabilityTitle` | `PLATFORM OBSERVABILITY` |
| `observabilityRegistry` | `REGISTRY` |
| `observabilityLogTerminal` | `SYSTEM LOG TERMINAL` |
| `observabilityCost` | `COST` |
| `observabilityTokens` | `TOKENS` |
| `observabilityMsgs` | `MSGS` |
| `observabilityBackend` | `BACKEND` |
| `observabilitySelectContainer` | `>> SELECT CONTAINER FOR LOG STREAM` |

### Permission Relay (`permission_relay_screen.dart`)

| ARB Key | String |
|---|---|
| `relayTitle` | `PERMISSION RELAY` |
| `relaySubsystem` | `RELAY SUBSYSTEM` |
| `relayCheckingStatus` | `CHECKING RELAY STATUS...` |
| `relayActive` | `>>> RELAY ACTIVE <<<` |
| `relaySubsystemsNominal` | `SUBSYSTEMS NOMINAL` |
| `relayConfigSection` | `RELAY CONFIGURATION` |
| `relayActivate` | `ACTIVATE RELAY` |

### Deploy (`deploy_picker_screen.dart`)

| ARB Key | String |
|---|---|
| `deployTitle` | `DEPLOY POCKETCODER` |
| `deploySelectProvider` | `SELECT PROVIDER` |
| `deployChooseProvider` | `CHOOSE WHERE TO DEPLOY YOUR INSTANCE` |
| `deployProBadge` | `PRO` |

### Core Widgets

| File | ARB Key | String |
|---|---|---|
| `permission_prompt.dart` | `permissionSignoffTitle` | `COMMANDER'S SIGNOFF` |
| `permission_prompt.dart` | `permissionRequestingLabel` | `{source} IS REQUESTING PERMISSION:` |
| `permission_prompt.dart` | `permissionPatternsLabel` | `Patterns:` |
| `question_prompt.dart` | `questionIncomingTitle` | `INCOMING QUERY` |
| `question_prompt.dart` | `questionPocoAsking` | `POCO IS ASKING:` |
| `question_prompt.dart` | `questionSendReply` | `SEND REPLY` |
| `thoughts_stream.dart` | `thoughtsWaiting` | `[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]` |
| `thoughts_stream.dart` | `thoughtsRunning` | `[RUNNING...]` |
| `notification_wrapper.dart` | `notificationSignalReceived` | `SIGNAL RECEIVED: {title}` |
