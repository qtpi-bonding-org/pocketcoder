import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'PocketCoder'**
  String get appTitle;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error occurred'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out'**
  String get errorTimeout;

  /// No description provided for @errorAuthUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized access'**
  String get errorAuthUnauthorized;

  /// No description provided for @errorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get errorAuthFailed;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get authNotAuthenticated;

  /// No description provided for @authTokenExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please log in again'**
  String get authTokenExpired;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error'**
  String get authError;

  /// No description provided for @chatFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load chats'**
  String get chatFetchFailed;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get chatSendFailed;

  /// No description provided for @chatNotFound.
  ///
  /// In en, this message translates to:
  /// **'Chat not found'**
  String get chatNotFound;

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'Chat error'**
  String get chatError;

  /// No description provided for @chatMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get chatMessageSent;

  /// No description provided for @chatCreated.
  ///
  /// In en, this message translates to:
  /// **'Chat created'**
  String get chatCreated;

  /// No description provided for @permissionFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load permissions'**
  String get permissionFetchFailed;

  /// No description provided for @permissionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update permission'**
  String get permissionUpdateFailed;

  /// No description provided for @permissionError.
  ///
  /// In en, this message translates to:
  /// **'Permission error'**
  String get permissionError;

  /// No description provided for @aiFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load AI resources'**
  String get aiFetchFailed;

  /// No description provided for @aiSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save AI configuration'**
  String get aiSaveFailed;

  /// No description provided for @aiError.
  ///
  /// In en, this message translates to:
  /// **'AI error'**
  String get aiError;

  /// No description provided for @toolPermissionsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load tool permissions'**
  String get toolPermissionsFetchFailed;

  /// No description provided for @toolPermissionsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update tool permissions'**
  String get toolPermissionsUpdateFailed;

  /// No description provided for @toolPermissionsError.
  ///
  /// In en, this message translates to:
  /// **'Tool permissions error'**
  String get toolPermissionsError;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get actionSave;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get actionClose;

  /// No description provided for @actionDeny.
  ///
  /// In en, this message translates to:
  /// **'DENY'**
  String get actionDeny;

  /// No description provided for @actionAuthorize.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZE'**
  String get actionAuthorize;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'REFRESH'**
  String get actionRefresh;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get actionBack;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'CHANGE'**
  String get actionChange;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get actionCreate;

  /// No description provided for @actionAddNew.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW'**
  String get actionAddNew;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get actionRestore;

  /// No description provided for @actionConfigure.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE'**
  String get actionConfigure;

  /// No description provided for @actionReject.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get actionReject;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'CHATS'**
  String get navChats;

  /// No description provided for @navMonitor.
  ///
  /// In en, this message translates to:
  /// **'MONITOR'**
  String get navMonitor;

  /// No description provided for @navConfigure.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE'**
  String get navConfigure;

  /// No description provided for @bootLoadError.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS...'**
  String get bootLoadError;

  /// No description provided for @bootPocoIntro.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m Poco, your Private Operations Coding Officer. I help you build software on your own terms — private, powerful, and under your control. Let\'s get started!'**
  String get bootPocoIntro;

  /// No description provided for @bootCheckingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking secure connection...'**
  String get bootCheckingConnection;

  /// No description provided for @bootWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get bootWelcomeBack;

  /// No description provided for @bootSystemsNominal.
  ///
  /// In en, this message translates to:
  /// **'Systems nominal. I\'m ready.'**
  String get bootSystemsNominal;

  /// No description provided for @bootConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. I\'ll take you back to reconnect.'**
  String get bootConnectionFailed;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFICATION UNLOCK'**
  String get onboardingTitle;

  /// No description provided for @onboardingPocoChallengeMessage.
  ///
  /// In en, this message translates to:
  /// **'WHO GOES THERE? IDENTIFY YOURSELF. ENTER YOUR SERVER ADDRESS AND CREDENTIALS TO PROVE YOU BELONG HERE.'**
  String get onboardingPocoChallengeMessage;

  /// No description provided for @onboardingPocoWelcome.
  ///
  /// In en, this message translates to:
  /// **'Identity verified! Welcome home, Commander. All systems are at your disposal.'**
  String get onboardingPocoWelcome;

  /// No description provided for @onboardingAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'ACCESS DENIED.'**
  String get onboardingAccessDenied;

  /// No description provided for @onboardingProcessing.
  ///
  /// In en, this message translates to:
  /// **'PROCESSING...'**
  String get onboardingProcessing;

  /// No description provided for @onboardingLogin.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get onboardingLogin;

  /// No description provided for @onboardingHomeServer.
  ///
  /// In en, this message translates to:
  /// **'HOME SERVER'**
  String get onboardingHomeServer;

  /// No description provided for @onboardingIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'IDENTITY'**
  String get onboardingIdentityLabel;

  /// No description provided for @onboardingEmailHint.
  ///
  /// In en, this message translates to:
  /// **'ENTER EMAIL'**
  String get onboardingEmailHint;

  /// No description provided for @onboardingPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSPHRASE'**
  String get onboardingPassphraseLabel;

  /// No description provided for @onboardingPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'ENTER PASSWORD'**
  String get onboardingPasswordHint;

  /// No description provided for @onboardingAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICATING'**
  String get onboardingAuthenticating;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'CHATS'**
  String get homeTitle;

  /// No description provided for @homeLoadingChats.
  ///
  /// In en, this message translates to:
  /// **'LOADING CHATS'**
  String get homeLoadingChats;

  /// No description provided for @homeErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String homeErrorPrefix(String error);

  /// No description provided for @homeNewChat.
  ///
  /// In en, this message translates to:
  /// **'NEW CHAT'**
  String get homeNewChat;

  /// No description provided for @homeNoChats.
  ///
  /// In en, this message translates to:
  /// **'No active chats found.'**
  String get homeNoChats;

  /// No description provided for @chatSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'CHAT SESSION'**
  String get chatSessionTitle;

  /// No description provided for @chatTerminalAction.
  ///
  /// In en, this message translates to:
  /// **'TERMINAL'**
  String get chatTerminalAction;

  /// No description provided for @chatFilesAction.
  ///
  /// In en, this message translates to:
  /// **'FILES'**
  String get chatFilesAction;

  /// No description provided for @chatNewCapabilityRequest.
  ///
  /// In en, this message translates to:
  /// **'[!] NEW CAPABILITY REQUEST RECEIVED'**
  String get chatNewCapabilityRequest;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'THINKING'**
  String get chatThinking;

  /// No description provided for @chatModelLabel.
  ///
  /// In en, this message translates to:
  /// **'MODEL:'**
  String get chatModelLabel;

  /// No description provided for @chatModelDefault.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get chatModelDefault;

  /// No description provided for @chatModelPerChat.
  ///
  /// In en, this message translates to:
  /// **'[CHAT]'**
  String get chatModelPerChat;

  /// No description provided for @chatSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECT MODEL'**
  String get chatSelectModelTitle;

  /// No description provided for @chatUseGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'USE GLOBAL DEFAULT'**
  String get chatUseGlobalDefault;

  /// No description provided for @llmTitle.
  ///
  /// In en, this message translates to:
  /// **'LLM MANAGEMENT'**
  String get llmTitle;

  /// No description provided for @llmLoadingProviders.
  ///
  /// In en, this message translates to:
  /// **'LOADING PROVIDERS'**
  String get llmLoadingProviders;

  /// No description provided for @llmActiveModelSection.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE MODEL'**
  String get llmActiveModelSection;

  /// No description provided for @llmProvidersSection.
  ///
  /// In en, this message translates to:
  /// **'PROVIDERS'**
  String get llmProvidersSection;

  /// No description provided for @llmApiKeysSection.
  ///
  /// In en, this message translates to:
  /// **'API KEYS'**
  String get llmApiKeysSection;

  /// No description provided for @llmGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL DEFAULT'**
  String get llmGlobalDefault;

  /// No description provided for @llmNotSet.
  ///
  /// In en, this message translates to:
  /// **'NOT SET'**
  String get llmNotSet;

  /// No description provided for @llmAddKeyHint.
  ///
  /// In en, this message translates to:
  /// **'ADD AN API KEY TO ENABLE MODEL SELECTION'**
  String get llmAddKeyHint;

  /// No description provided for @llmNoProviders.
  ///
  /// In en, this message translates to:
  /// **'NO PROVIDERS AVAILABLE'**
  String get llmNoProviders;

  /// No description provided for @llmConnected.
  ///
  /// In en, this message translates to:
  /// **'[ CONNECTED ]'**
  String get llmConnected;

  /// No description provided for @llmNoKey.
  ///
  /// In en, this message translates to:
  /// **'[ NO KEY ]'**
  String get llmNoKey;

  /// No description provided for @llmModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} MODEL(S) AVAILABLE'**
  String llmModelsAvailable(int count);

  /// No description provided for @llmUpdateKey.
  ///
  /// In en, this message translates to:
  /// **'UPDATE KEY'**
  String get llmUpdateKey;

  /// No description provided for @llmAddKey.
  ///
  /// In en, this message translates to:
  /// **'ADD KEY'**
  String get llmAddKey;

  /// No description provided for @llmModelsButton.
  ///
  /// In en, this message translates to:
  /// **'MODELS'**
  String get llmModelsButton;

  /// No description provided for @llmApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'API KEY: {provider}'**
  String llmApiKeyDialogTitle(String provider);

  /// No description provided for @llmEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter credentials for {provider}:'**
  String llmEnterCredentials(String provider);

  /// No description provided for @llmSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECT MODEL'**
  String get llmSelectModelTitle;

  /// No description provided for @llmProviderModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} MODELS'**
  String llmProviderModelsTitle(String provider);

  /// No description provided for @llmNoModels.
  ///
  /// In en, this message translates to:
  /// **'NO MODELS LISTED'**
  String get llmNoModels;

  /// No description provided for @llmSelect.
  ///
  /// In en, this message translates to:
  /// **'[ SELECT ]'**
  String get llmSelect;

  /// No description provided for @mcpTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP MANAGEMENT'**
  String get mcpTitle;

  /// No description provided for @mcpCapabilitiesRegistry.
  ///
  /// In en, this message translates to:
  /// **'CAPABILITIES REGISTRY'**
  String get mcpCapabilitiesRegistry;

  /// No description provided for @mcpPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'PENDING APPROVAL'**
  String get mcpPendingApproval;

  /// No description provided for @mcpActiveCapabilities.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE CAPABILITIES'**
  String get mcpActiveCapabilities;

  /// No description provided for @mcpNoCapabilities.
  ///
  /// In en, this message translates to:
  /// **'NO CAPABILITIES REGISTERED'**
  String get mcpNoCapabilities;

  /// No description provided for @mcpImageLabel.
  ///
  /// In en, this message translates to:
  /// **'IMAGE: {image}'**
  String mcpImageLabel(String image);

  /// No description provided for @mcpPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'PURPOSE: {reason}'**
  String mcpPurposeLabel(String reason);

  /// No description provided for @mcpRequiredConfig.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED CONFIG:'**
  String get mcpRequiredConfig;

  /// No description provided for @mcpAuthorizeCap.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZE CAPABILITY'**
  String get mcpAuthorizeCap;

  /// No description provided for @mcpEditConfig.
  ///
  /// In en, this message translates to:
  /// **'EDIT CONFIGURATION'**
  String get mcpEditConfig;

  /// No description provided for @mcpRevoke.
  ///
  /// In en, this message translates to:
  /// **'REVOKE'**
  String get mcpRevoke;

  /// No description provided for @mcpAuthorizeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZE: {name}'**
  String mcpAuthorizeDialogTitle(String name);

  /// No description provided for @mcpUpdateConfigDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'UPDATE CONFIG: {name}'**
  String mcpUpdateConfigDialogTitle(String name);

  /// No description provided for @mcpNoConfigRequired.
  ///
  /// In en, this message translates to:
  /// **'No configuration required.'**
  String get mcpNoConfigRequired;

  /// No description provided for @mcpEnterSecrets.
  ///
  /// In en, this message translates to:
  /// **'Enter required secrets:'**
  String get mcpEnterSecrets;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE'**
  String get settingsTitle;

  /// No description provided for @settingsAiAgentsSection.
  ///
  /// In en, this message translates to:
  /// **'AI & AGENTS'**
  String get settingsAiAgentsSection;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get settingsSecuritySection;

  /// No description provided for @settingsGovernanceSection.
  ///
  /// In en, this message translates to:
  /// **'GOVERNANCE'**
  String get settingsGovernanceSection;

  /// No description provided for @settingsSystemSection.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get settingsSystemSection;

  /// No description provided for @settingsObservabilitySection.
  ///
  /// In en, this message translates to:
  /// **'OBSERVABILITY'**
  String get settingsObservabilitySection;

  /// No description provided for @agentTitle.
  ///
  /// In en, this message translates to:
  /// **'AGENT REGISTRY'**
  String get agentTitle;

  /// No description provided for @agentModelsPersonas.
  ///
  /// In en, this message translates to:
  /// **'MODELS & PERSONAS'**
  String get agentModelsPersonas;

  /// No description provided for @agentSearching.
  ///
  /// In en, this message translates to:
  /// **'SEARCHING...'**
  String get agentSearching;

  /// No description provided for @agentRegistryEmpty.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY EMPTY.'**
  String get agentRegistryEmpty;

  /// No description provided for @agentSelectToConfigure.
  ///
  /// In en, this message translates to:
  /// **'SELECT AGENT TO CONFIGURE'**
  String get agentSelectToConfigure;

  /// No description provided for @agentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'AGENT: {name}'**
  String agentDialogTitle(String name);

  /// No description provided for @agentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get agentNameLabel;

  /// No description provided for @agentDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get agentDescriptionLabel;

  /// No description provided for @agentPromptsLabel.
  ///
  /// In en, this message translates to:
  /// **'PROMPTS'**
  String get agentPromptsLabel;

  /// No description provided for @agentModelsLabel.
  ///
  /// In en, this message translates to:
  /// **'MODELS'**
  String get agentModelsLabel;

  /// No description provided for @agentParametersLabel.
  ///
  /// In en, this message translates to:
  /// **'PARAMETERS'**
  String get agentParametersLabel;

  /// No description provided for @agentNone.
  ///
  /// In en, this message translates to:
  /// **'NONE'**
  String get agentNone;

  /// No description provided for @agentNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'NONE SELECTED'**
  String get agentNoneSelected;

  /// No description provided for @agentDefaultTuned.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT [TUNED]'**
  String get agentDefaultTuned;

  /// No description provided for @toolPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'GATEKEEPER CONFIGURATION'**
  String get toolPermissionsTitle;

  /// No description provided for @toolPermissionsFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'TOOL PERMISSIONS'**
  String get toolPermissionsFrameTitle;

  /// No description provided for @toolPermissionsLoading.
  ///
  /// In en, this message translates to:
  /// **'LOADING PERMISSIONS'**
  String get toolPermissionsLoading;

  /// No description provided for @toolPermissionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO PERMISSIONS DEFINED.'**
  String get toolPermissionsEmpty;

  /// No description provided for @toolPermissionsAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD PERMISSION'**
  String get toolPermissionsAdd;

  /// No description provided for @toolPermissionsScopeAgent.
  ///
  /// In en, this message translates to:
  /// **'AGENT'**
  String get toolPermissionsScopeAgent;

  /// No description provided for @toolPermissionsScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get toolPermissionsScopeGlobal;

  /// No description provided for @toolPermissionsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD TOOL PERMISSION'**
  String get toolPermissionsAddTitle;

  /// No description provided for @toolPermissionsToolLabel.
  ///
  /// In en, this message translates to:
  /// **'TOOL (e.g. bash, edit, cao_*)'**
  String get toolPermissionsToolLabel;

  /// No description provided for @toolPermissionsPatternLabel.
  ///
  /// In en, this message translates to:
  /// **'PATTERN (e.g. *, git *, rm *)'**
  String get toolPermissionsPatternLabel;

  /// No description provided for @toolPermissionsActionLabel.
  ///
  /// In en, this message translates to:
  /// **'ACTION:'**
  String get toolPermissionsActionLabel;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'TERMINAL MIRROR'**
  String get terminalTitle;

  /// No description provided for @terminalTransfer.
  ///
  /// In en, this message translates to:
  /// **'TRANSFER'**
  String get terminalTransfer;

  /// No description provided for @terminalReconnect.
  ///
  /// In en, this message translates to:
  /// **'RECONNECT'**
  String get terminalReconnect;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISHING SSH LINK'**
  String get terminalConnecting;

  /// No description provided for @terminalConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION FAILED'**
  String get terminalConnectionFailed;

  /// No description provided for @terminalRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY CONNECTION'**
  String get terminalRetry;

  /// No description provided for @terminalSftpTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP TRANSFER'**
  String get terminalSftpTitle;

  /// No description provided for @terminalDestinationPath.
  ///
  /// In en, this message translates to:
  /// **'DESTINATION PATH'**
  String get terminalDestinationPath;

  /// No description provided for @terminalUpload.
  ///
  /// In en, this message translates to:
  /// **'UPLOAD'**
  String get terminalUpload;

  /// No description provided for @terminalConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION_STATUS'**
  String get terminalConnectionStatus;

  /// No description provided for @terminalSshLink.
  ///
  /// In en, this message translates to:
  /// **'SSH LINK: {host}:{port}'**
  String terminalSshLink(String host, String port);

  /// No description provided for @terminalOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get terminalOnline;

  /// No description provided for @terminalOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get terminalOffline;

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'MONITOR'**
  String get monitorTitle;

  /// No description provided for @monitorFetchingTelemetry.
  ///
  /// In en, this message translates to:
  /// **'FETCHING TELEMETRY'**
  String get monitorFetchingTelemetry;

  /// No description provided for @monitorSystemHealth.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM HEALTH'**
  String get monitorSystemHealth;

  /// No description provided for @monitorKeyMetrics.
  ///
  /// In en, this message translates to:
  /// **'KEY METRICS'**
  String get monitorKeyMetrics;

  /// No description provided for @monitorTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'TOKEN USAGE BY MODEL'**
  String get monitorTokenUsage;

  /// No description provided for @monitorAgentActivity.
  ///
  /// In en, this message translates to:
  /// **'AGENT ACTIVITY'**
  String get monitorAgentActivity;

  /// No description provided for @monitorTelemetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TELEMETRY UNAVAILABLE'**
  String get monitorTelemetryUnavailable;

  /// No description provided for @monitorNoData.
  ///
  /// In en, this message translates to:
  /// **'NO DATA — TAP REFRESH'**
  String get monitorNoData;

  /// No description provided for @monitorMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'MESSAGES'**
  String get monitorMessagesLabel;

  /// No description provided for @monitorCostLabel.
  ///
  /// In en, this message translates to:
  /// **'COST'**
  String get monitorCostLabel;

  /// No description provided for @monitorTokensLabel.
  ///
  /// In en, this message translates to:
  /// **'TOKENS'**
  String get monitorTokensLabel;

  /// No description provided for @fileTitle.
  ///
  /// In en, this message translates to:
  /// **'SOURCE OUTPUT MANIFEST'**
  String get fileTitle;

  /// No description provided for @fileDashboardAction.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get fileDashboardAction;

  /// No description provided for @fileClearAction.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get fileClearAction;

  /// No description provided for @fileNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'NO FILE SELECTED.'**
  String get fileNoFileSelected;

  /// No description provided for @fileSelectFromChat.
  ///
  /// In en, this message translates to:
  /// **'>> SELECT FROM CHAT TO VIEW'**
  String get fileSelectFromChat;

  /// No description provided for @fileFetching.
  ///
  /// In en, this message translates to:
  /// **'FETCHING DATA...'**
  String get fileFetching;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'EMPTY FILE'**
  String get fileEmpty;

  /// No description provided for @sopTitle.
  ///
  /// In en, this message translates to:
  /// **'SOP MANAGEMENT'**
  String get sopTitle;

  /// No description provided for @sopProjectProcedures.
  ///
  /// In en, this message translates to:
  /// **'PROJECT PROCEDURES'**
  String get sopProjectProcedures;

  /// No description provided for @sopNewProposal.
  ///
  /// In en, this message translates to:
  /// **'NEW PROPOSAL'**
  String get sopNewProposal;

  /// No description provided for @sopActiveProcedures.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PROCEDURES'**
  String get sopActiveProcedures;

  /// No description provided for @sopDraftProposals.
  ///
  /// In en, this message translates to:
  /// **'DRAFT PROPOSALS'**
  String get sopDraftProposals;

  /// No description provided for @sopPendingSignature.
  ///
  /// In en, this message translates to:
  /// **'PENDING SIGNATURE'**
  String get sopPendingSignature;

  /// No description provided for @systemChecksTitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM CHECKS'**
  String get systemChecksTitle;

  /// No description provided for @systemChecksDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM DIAGNOSTICS'**
  String get systemChecksDiagnostics;

  /// No description provided for @systemChecksEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO DIAGNOSTICS AVAILABLE'**
  String get systemChecksEmpty;

  /// No description provided for @observabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'PLATFORM OBSERVABILITY'**
  String get observabilityTitle;

  /// No description provided for @observabilityRegistry.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY'**
  String get observabilityRegistry;

  /// No description provided for @observabilityLogTerminal.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM LOG TERMINAL'**
  String get observabilityLogTerminal;

  /// No description provided for @observabilityCost.
  ///
  /// In en, this message translates to:
  /// **'COST'**
  String get observabilityCost;

  /// No description provided for @observabilityTokens.
  ///
  /// In en, this message translates to:
  /// **'TOKENS'**
  String get observabilityTokens;

  /// No description provided for @observabilityMsgs.
  ///
  /// In en, this message translates to:
  /// **'MSGS'**
  String get observabilityMsgs;

  /// No description provided for @observabilityBackend.
  ///
  /// In en, this message translates to:
  /// **'BACKEND'**
  String get observabilityBackend;

  /// No description provided for @observabilitySelectContainer.
  ///
  /// In en, this message translates to:
  /// **'>> SELECT CONTAINER FOR LOG STREAM'**
  String get observabilitySelectContainer;

  /// No description provided for @relayTitle.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION RELAY'**
  String get relayTitle;

  /// No description provided for @relaySubsystem.
  ///
  /// In en, this message translates to:
  /// **'RELAY SUBSYSTEM'**
  String get relaySubsystem;

  /// No description provided for @relayCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'CHECKING RELAY STATUS...'**
  String get relayCheckingStatus;

  /// No description provided for @relayActive.
  ///
  /// In en, this message translates to:
  /// **'>>> RELAY ACTIVE <<<'**
  String get relayActive;

  /// No description provided for @relaySubsystemsNominal.
  ///
  /// In en, this message translates to:
  /// **'SUBSYSTEMS NOMINAL'**
  String get relaySubsystemsNominal;

  /// No description provided for @relayConfigSection.
  ///
  /// In en, this message translates to:
  /// **'RELAY CONFIGURATION'**
  String get relayConfigSection;

  /// No description provided for @relayActivate.
  ///
  /// In en, this message translates to:
  /// **'ACTIVATE RELAY'**
  String get relayActivate;

  /// No description provided for @deployTitle.
  ///
  /// In en, this message translates to:
  /// **'DEPLOY POCKETCODER'**
  String get deployTitle;

  /// No description provided for @deploySelectProvider.
  ///
  /// In en, this message translates to:
  /// **'SELECT PROVIDER'**
  String get deploySelectProvider;

  /// No description provided for @deployChooseProvider.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE WHERE TO DEPLOY YOUR INSTANCE'**
  String get deployChooseProvider;

  /// No description provided for @deployProBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get deployProBadge;

  /// No description provided for @permissionSignoffTitle.
  ///
  /// In en, this message translates to:
  /// **'COMMANDER\'S SIGNOFF'**
  String get permissionSignoffTitle;

  /// No description provided for @permissionRequestingLabel.
  ///
  /// In en, this message translates to:
  /// **'{source} IS REQUESTING PERMISSION:'**
  String permissionRequestingLabel(String source);

  /// No description provided for @permissionPatternsLabel.
  ///
  /// In en, this message translates to:
  /// **'Patterns:'**
  String get permissionPatternsLabel;

  /// No description provided for @questionIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'INCOMING QUERY'**
  String get questionIncomingTitle;

  /// No description provided for @questionPocoAsking.
  ///
  /// In en, this message translates to:
  /// **'POCO IS ASKING:'**
  String get questionPocoAsking;

  /// No description provided for @questionSendReply.
  ///
  /// In en, this message translates to:
  /// **'SEND REPLY'**
  String get questionSendReply;

  /// No description provided for @thoughtsWaiting.
  ///
  /// In en, this message translates to:
  /// **'[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]'**
  String get thoughtsWaiting;

  /// No description provided for @notificationSignalReceived.
  ///
  /// In en, this message translates to:
  /// **'SIGNAL RECEIVED: {title}'**
  String notificationSignalReceived(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
