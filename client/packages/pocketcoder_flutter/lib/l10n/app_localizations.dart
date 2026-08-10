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

  /// No description provided for @chatListError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load chats'**
  String get chatListError;

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

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get actionContinue;

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
  /// **'SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS\n[!] CHECK_ASSET_MANIFEST'**
  String get bootLoadError;

  /// No description provided for @bootPocoIntro.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m Poco, your Private Operations Coding Officer representing the PocketCoder Initiative.'**
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
  /// **'Connection failed. I\'ll take you back to the setup screen so we can check the server settings.'**
  String get bootConnectionFailed;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFICATION UNLOCK'**
  String get onboardingTitle;

  /// No description provided for @onboardingPocoChallengeMessage.
  ///
  /// In en, this message translates to:
  /// **'WHO GOES THERE? IDENTIFY YOURSELF AND PROVIDE THE SECRET PASSPHRASE.'**
  String get onboardingPocoChallengeMessage;

  /// No description provided for @onboardingPocoWelcome.
  ///
  /// In en, this message translates to:
  /// **'Identity verified! Welcome home. I knew it was you—just had to make sure the Cloud wasn\'t spoofing your signature.'**
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

  /// No description provided for @onboardingDeploy.
  ///
  /// In en, this message translates to:
  /// **'DEPLOY'**
  String get onboardingDeploy;

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

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER SETUP'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingConnectOrDeploy.
  ///
  /// In en, this message translates to:
  /// **'CONNECT TO AN EXISTING SERVER OR DEPLOY A NEW ONE.'**
  String get onboardingConnectOrDeploy;

  /// No description provided for @onboardingExistingServer.
  ///
  /// In en, this message translates to:
  /// **'USE AN EXISTING POCKETBASE SERVER'**
  String get onboardingExistingServer;

  /// No description provided for @onboardingCreateServer.
  ///
  /// In en, this message translates to:
  /// **'CREATE A NEW SERVER'**
  String get onboardingCreateServer;

  /// No description provided for @onboardingServerLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'SERVER LOGIN'**
  String get onboardingServerLoginTitle;

  /// No description provided for @onboardingServerUrl.
  ///
  /// In en, this message translates to:
  /// **'SERVER URL'**
  String get onboardingServerUrl;

  /// No description provided for @onboardingServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://server.example.com'**
  String get onboardingServerUrlHint;

  /// No description provided for @onboardingEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get onboardingEmail;

  /// No description provided for @onboardingEmailHintShort.
  ///
  /// In en, this message translates to:
  /// **'admin@example.com'**
  String get onboardingEmailHintShort;

  /// No description provided for @onboardingPassword.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get onboardingPassword;

  /// No description provided for @onboardingServerConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING...'**
  String get onboardingServerConnecting;

  /// No description provided for @onboardingRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'ENTER ALL REQUIRED FIELDS'**
  String get onboardingRequiredFields;

  /// No description provided for @onboardingChooseHarnessTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR HARNESS'**
  String get onboardingChooseHarnessTitle;

  /// No description provided for @onboardingChooseHarnessBody.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE THE ACCOUNT-BASED AGENT TO CONNECT.'**
  String get onboardingChooseHarnessBody;

  /// No description provided for @onboardingHarnessNotFound.
  ///
  /// In en, this message translates to:
  /// **'HARNESS NOT FOUND'**
  String get onboardingHarnessNotFound;

  /// No description provided for @onboardingClaudeAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'CLAUDE ACCOUNT LOGIN'**
  String get onboardingClaudeAccountLogin;

  /// No description provided for @onboardingCodexAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'CHATGPT ACCOUNT LOGIN'**
  String get onboardingCodexAccountLogin;

  /// No description provided for @onboardingHarnessLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} LOGIN'**
  String onboardingHarnessLoginTitle(String provider);

  /// No description provided for @onboardingConnected.
  ///
  /// In en, this message translates to:
  /// **'CONNECTED'**
  String get onboardingConnected;

  /// No description provided for @onboardingAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT LOGIN'**
  String get onboardingAccountLogin;

  /// No description provided for @onboardingAuthorizationCode.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZATION CODE'**
  String get onboardingAuthorizationCode;

  /// No description provided for @onboardingAuthorizationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'paste code'**
  String get onboardingAuthorizationCodeHint;

  /// No description provided for @onboardingSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT CODE'**
  String get onboardingSubmitCode;

  /// No description provided for @onboardingOpenAuthorization.
  ///
  /// In en, this message translates to:
  /// **'OPEN AUTHORIZATION'**
  String get onboardingOpenAuthorization;

  /// No description provided for @onboardingCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'CHECK STATUS'**
  String get onboardingCheckStatus;

  /// No description provided for @onboardingOpenChatFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open a new chat: {error}'**
  String onboardingOpenChatFailed(String error);

  /// No description provided for @onboardingDeployTitle.
  ///
  /// In en, this message translates to:
  /// **'DEPLOY SERVER'**
  String get onboardingDeployTitle;

  /// No description provided for @onboardingPocketbaseAdminEmail.
  ///
  /// In en, this message translates to:
  /// **'POCKETBASE ADMIN EMAIL'**
  String get onboardingPocketbaseAdminEmail;

  /// No description provided for @onboardingPocketbaseAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'POCKETBASE ADMIN PASSWORD'**
  String get onboardingPocketbaseAdminPassword;

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

  /// No description provided for @chatListNewChat.
  ///
  /// In en, this message translates to:
  /// **'+ NEW CHAT'**
  String get chatListNewChat;

  /// No description provided for @chatListNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatListNoMessages;

  /// No description provided for @newChatTitle.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChatTitle;

  /// No description provided for @newChatTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get newChatTitleField;

  /// No description provided for @newChatHarnessField.
  ///
  /// In en, this message translates to:
  /// **'Harness'**
  String get newChatHarnessField;

  /// No description provided for @newChatModelField.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get newChatModelField;

  /// No description provided for @newChatCwdField.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get newChatCwdField;

  /// No description provided for @newChatCwdHint.
  ///
  /// In en, this message translates to:
  /// **'/workspace'**
  String get newChatCwdHint;

  /// No description provided for @newChatCreate.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get newChatCreate;

  /// No description provided for @newChatCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get newChatCancel;

  /// No description provided for @newChatSelectHarness.
  ///
  /// In en, this message translates to:
  /// **'SELECT HARNESS'**
  String get newChatSelectHarness;

  /// No description provided for @newChatSelectModel.
  ///
  /// In en, this message translates to:
  /// **'SELECT MODEL'**
  String get newChatSelectModel;

  /// No description provided for @newChatNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available for this harness'**
  String get newChatNoModelsAvailable;

  /// No description provided for @chatListArchive.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE'**
  String get chatListArchive;

  /// No description provided for @chatListDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get chatListDelete;

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

  /// No description provided for @chatThinkingLive.
  ///
  /// In en, this message translates to:
  /// **'THINKING...'**
  String get chatThinkingLive;

  /// No description provided for @chatThought.
  ///
  /// In en, this message translates to:
  /// **'THOUGHT'**
  String get chatThought;

  /// No description provided for @chatSessionAction.
  ///
  /// In en, this message translates to:
  /// **'SESSION'**
  String get chatSessionAction;

  /// No description provided for @chatSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendTooltip;

  /// No description provided for @chatCommanderRole.
  ///
  /// In en, this message translates to:
  /// **'COMMANDER'**
  String get chatCommanderRole;

  /// No description provided for @chatThinkingRole.
  ///
  /// In en, this message translates to:
  /// **'THINKING'**
  String get chatThinkingRole;

  /// No description provided for @chatPocoRole.
  ///
  /// In en, this message translates to:
  /// **'POCO'**
  String get chatPocoRole;

  /// No description provided for @chatElicitationRequest.
  ///
  /// In en, this message translates to:
  /// **'ELICITATION REQUEST'**
  String get chatElicitationRequest;

  /// No description provided for @chatDecline.
  ///
  /// In en, this message translates to:
  /// **'DECLINE'**
  String get chatDecline;

  /// No description provided for @chatSubmit.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT'**
  String get chatSubmit;

  /// No description provided for @chatNoFieldsRequested.
  ///
  /// In en, this message translates to:
  /// **'(no fields requested)'**
  String get chatNoFieldsRequested;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'FILES'**
  String get filesTitle;

  /// No description provided for @filesEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO FILES'**
  String get filesEmpty;

  /// No description provided for @filesTooLargeToPreview.
  ///
  /// In en, this message translates to:
  /// **'FILE TOO LARGE TO PREVIEW'**
  String get filesTooLargeToPreview;

  /// No description provided for @filesCantPreviewType.
  ///
  /// In en, this message translates to:
  /// **'CAN\'T PREVIEW THIS FILE TYPE'**
  String get filesCantPreviewType;

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

  /// No description provided for @mcpAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD MCP SERVER'**
  String get mcpAddDialogTitle;

  /// No description provided for @mcpServerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'SERVER NAME'**
  String get mcpServerNameLabel;

  /// No description provided for @mcpImageOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'IMAGE (OPTIONAL)'**
  String get mcpImageOptionalLabel;

  /// No description provided for @mcpAddConfigOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional config (leave blank if none needed)'**
  String get mcpAddConfigOptional;

  /// No description provided for @mcpConnectCap.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get mcpConnectCap;

  /// No description provided for @mcpRetryDeliveryCap.
  ///
  /// In en, this message translates to:
  /// **'RETRY DELIVERY'**
  String get mcpRetryDeliveryCap;

  /// No description provided for @mcpOauthRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'REQUIRES OAUTH: {provider}'**
  String mcpOauthRequiredLabel(String provider);

  /// No description provided for @mcpOauthProviderOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'OAUTH PROVIDER (OPTIONAL)'**
  String get mcpOauthProviderOptionalLabel;

  /// No description provided for @mcpOauthTokenEnvVarOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'OAUTH TOKEN ENV VAR (OPTIONAL)'**
  String get mcpOauthTokenEnvVarOptionalLabel;

  /// No description provided for @mcpOauthProviderNotConfiguredLabel.
  ///
  /// In en, this message translates to:
  /// **'{provider} NOT YET CONFIGURED'**
  String mcpOauthProviderNotConfiguredLabel(String provider);

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get actionAdd;

  /// No description provided for @toolPermissionsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'TOOL PERMISSIONS'**
  String get toolPermissionsScreenTitle;

  /// No description provided for @toolPermissionsRulesRegistry.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION RULES'**
  String get toolPermissionsRulesRegistry;

  /// No description provided for @toolPermissionsNoRules.
  ///
  /// In en, this message translates to:
  /// **'NO RULES CONFIGURED'**
  String get toolPermissionsNoRules;

  /// No description provided for @toolPermissionsAddRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD PERMISSION RULE'**
  String get toolPermissionsAddRuleTitle;

  /// No description provided for @toolPermissionsToolNameLabel.
  ///
  /// In en, this message translates to:
  /// **'TOOL NAME'**
  String get toolPermissionsToolNameLabel;

  /// No description provided for @toolPermissionsAllowLabel.
  ///
  /// In en, this message translates to:
  /// **'ALLOW'**
  String get toolPermissionsAllowLabel;

  /// No description provided for @toolPermissionsAskLabel.
  ///
  /// In en, this message translates to:
  /// **'ASK'**
  String get toolPermissionsAskLabel;

  /// No description provided for @toolPermissionsDenyLabel.
  ///
  /// In en, this message translates to:
  /// **'DENY'**
  String get toolPermissionsDenyLabel;

  /// No description provided for @notificationSettingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notificationSettingsScreenTitle;

  /// No description provided for @notificationSettingsChatReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'CHAT REPLIES'**
  String get notificationSettingsChatReplyLabel;

  /// No description provided for @notificationSettingsScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULED TASKS'**
  String get notificationSettingsScheduleLabel;

  /// No description provided for @notificationSettingsTaskCompleteLabel.
  ///
  /// In en, this message translates to:
  /// **'TASK COMPLETE'**
  String get notificationSettingsTaskCompleteLabel;

  /// No description provided for @notificationSettingsTaskErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'TASK ERRORS'**
  String get notificationSettingsTaskErrorLabel;

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'SKILLS'**
  String get skillsTitle;

  /// No description provided for @skillsRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'SKILLS REGISTRY'**
  String get skillsRegistryTitle;

  /// No description provided for @skillsGlobalSection.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get skillsGlobalSection;

  /// No description provided for @skillsProjectSection.
  ///
  /// In en, this message translates to:
  /// **'PROJECT'**
  String get skillsProjectSection;

  /// No description provided for @skillsNoSkills.
  ///
  /// In en, this message translates to:
  /// **'NO SKILLS CONFIGURED'**
  String get skillsNoSkills;

  /// No description provided for @skillsAddButton.
  ///
  /// In en, this message translates to:
  /// **'ADD SKILL'**
  String get skillsAddButton;

  /// No description provided for @skillsEditButton.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get skillsEditButton;

  /// No description provided for @skillsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get skillsDeleteButton;

  /// No description provided for @skillsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get skillsSaveButton;

  /// No description provided for @skillsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get skillsNameLabel;

  /// No description provided for @skillsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get skillsDescriptionLabel;

  /// No description provided for @skillsContentLabel.
  ///
  /// In en, this message translates to:
  /// **'CONTENT'**
  String get skillsContentLabel;

  /// No description provided for @skillsGlobalLabel.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get skillsGlobalLabel;

  /// No description provided for @skillsProjectLabel.
  ///
  /// In en, this message translates to:
  /// **'PROJECT'**
  String get skillsProjectLabel;

  /// No description provided for @skillsAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD SKILL'**
  String get skillsAddDialogTitle;

  /// No description provided for @skillsEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT: {name}'**
  String skillsEditDialogTitle(String name);

  /// No description provided for @skillsNoEligibleConfig.
  ///
  /// In en, this message translates to:
  /// **'No agent config has a workspace folder configured.'**
  String get skillsNoEligibleConfig;

  /// No description provided for @schedulerTitle.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULER'**
  String get schedulerTitle;

  /// No description provided for @schedulerRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULED TASKS'**
  String get schedulerRegistryTitle;

  /// No description provided for @schedulerNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'NO SCHEDULES CONFIGURED'**
  String get schedulerNoSchedules;

  /// No description provided for @schedulerAddButton.
  ///
  /// In en, this message translates to:
  /// **'ADD SCHEDULE'**
  String get schedulerAddButton;

  /// No description provided for @schedulerEditButton.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get schedulerEditButton;

  /// No description provided for @schedulerDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get schedulerDeleteButton;

  /// No description provided for @schedulerSaveButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get schedulerSaveButton;

  /// No description provided for @schedulerPauseButton.
  ///
  /// In en, this message translates to:
  /// **'PAUSE'**
  String get schedulerPauseButton;

  /// No description provided for @schedulerResumeButton.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get schedulerResumeButton;

  /// No description provided for @schedulerRunNowButton.
  ///
  /// In en, this message translates to:
  /// **'RUN NOW'**
  String get schedulerRunNowButton;

  /// No description provided for @schedulerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get schedulerNameLabel;

  /// No description provided for @schedulerCronLabel.
  ///
  /// In en, this message translates to:
  /// **'CRON EXPRESSION'**
  String get schedulerCronLabel;

  /// No description provided for @schedulerPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'PROMPT'**
  String get schedulerPromptLabel;

  /// No description provided for @schedulerAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD SCHEDULE'**
  String get schedulerAddDialogTitle;

  /// No description provided for @schedulerEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT: {name}'**
  String schedulerEditDialogTitle(String name);

  /// No description provided for @schedulerPausedBadge.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get schedulerPausedBadge;

  /// No description provided for @schedulerRunningBadge.
  ///
  /// In en, this message translates to:
  /// **'RUNNING'**
  String get schedulerRunningBadge;

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

  /// No description provided for @settingsAutomationSection.
  ///
  /// In en, this message translates to:
  /// **'AUTOMATION'**
  String get settingsAutomationSection;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsAccountSection;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'SIGN OUT'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will end your current session. You will need to log in again to continue.'**
  String get settingsLogoutConfirmBody;

  /// No description provided for @settingsLogoutCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get settingsLogoutCancel;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'SIGN OUT'**
  String get settingsLogoutConfirm;

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

  /// No description provided for @agentConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'AGENT CONFIGURATION'**
  String get agentConfigTitle;

  /// No description provided for @agentConfigRegistry.
  ///
  /// In en, this message translates to:
  /// **'AGENT CONFIGS'**
  String get agentConfigRegistry;

  /// No description provided for @agentConfigEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO AGENT CONFIGS YET'**
  String get agentConfigEmpty;

  /// No description provided for @agentConfigDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'AGENT CONFIG: {name}'**
  String agentConfigDialogTitle(String name);

  /// No description provided for @agentConfigNameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get agentConfigNameLabel;

  /// No description provided for @agentConfigHarnessModelLabel.
  ///
  /// In en, this message translates to:
  /// **'HARNESS MODEL'**
  String get agentConfigHarnessModelLabel;

  /// No description provided for @agentConfigPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM PROMPT'**
  String get agentConfigPromptLabel;

  /// No description provided for @agentConfigModeLabel.
  ///
  /// In en, this message translates to:
  /// **'MODE'**
  String get agentConfigModeLabel;

  /// No description provided for @agentConfigIsDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'IS DEFAULT'**
  String get agentConfigIsDefaultLabel;

  /// No description provided for @agentConfigNoHarnessModels.
  ///
  /// In en, this message translates to:
  /// **'NO HARNESS MODELS AVAILABLE'**
  String get agentConfigNoHarnessModels;

  /// No description provided for @agentConfigNoPrompts.
  ///
  /// In en, this message translates to:
  /// **'NO PROMPTS AVAILABLE'**
  String get agentConfigNoPrompts;

  /// No description provided for @agentConfigNoModes.
  ///
  /// In en, this message translates to:
  /// **'NO MODES AVAILABLE'**
  String get agentConfigNoModes;

  /// No description provided for @agentConfigSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'SELECT PROMPT'**
  String get agentConfigSelectPrompt;

  /// No description provided for @agentConfigSelectHarnessModel.
  ///
  /// In en, this message translates to:
  /// **'SELECT HARNESS MODEL'**
  String get agentConfigSelectHarnessModel;

  /// No description provided for @agentConfigSelectMode.
  ///
  /// In en, this message translates to:
  /// **'SELECT MODE'**
  String get agentConfigSelectMode;

  /// No description provided for @agentConfigDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get agentConfigDelete;

  /// No description provided for @agentConfigDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'DELETE CONFIG?'**
  String get agentConfigDeleteConfirmTitle;

  /// No description provided for @agentConfigDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'DELETE {name}? THIS CANNOT BE UNDONE.'**
  String agentConfigDeleteConfirmBody(String name);

  /// No description provided for @agentConfigDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'[ DEFAULT ]'**
  String get agentConfigDefaultBadge;

  /// No description provided for @agentConfigErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String agentConfigErrorPrefix(String error);

  /// No description provided for @providerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'PROVIDER MANAGEMENT'**
  String get providerScreenTitle;

  /// No description provided for @providerScreenLoading.
  ///
  /// In en, this message translates to:
  /// **'LOADING PROVIDERS'**
  String get providerScreenLoading;

  /// No description provided for @providerScreenHarnessModelsSection.
  ///
  /// In en, this message translates to:
  /// **'HARNESS MODELS'**
  String get providerScreenHarnessModelsSection;

  /// No description provided for @providerScreenApiKeysSection.
  ///
  /// In en, this message translates to:
  /// **'API KEYS'**
  String get providerScreenApiKeysSection;

  /// No description provided for @providerScreenNoHarnessModels.
  ///
  /// In en, this message translates to:
  /// **'NO HARNESS MODELS LISTED'**
  String get providerScreenNoHarnessModels;

  /// No description provided for @providerScreenNoApiKeys.
  ///
  /// In en, this message translates to:
  /// **'NO API KEYS CONFIGURED'**
  String get providerScreenNoApiKeys;

  /// No description provided for @providerScreenEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'NO HARNESS MODELS OR API KEYS YET'**
  String get providerScreenEmptyHint;

  /// No description provided for @providerScreenAddKey.
  ///
  /// In en, this message translates to:
  /// **'ADD KEY'**
  String get providerScreenAddKey;

  /// No description provided for @providerScreenUpdateKey.
  ///
  /// In en, this message translates to:
  /// **'UPDATE KEY'**
  String get providerScreenUpdateKey;

  /// No description provided for @providerScreenAddKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'API KEY: {provider}'**
  String providerScreenAddKeyTitle(String provider);

  /// No description provided for @providerScreenAddKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Enter credentials for {provider}:'**
  String providerScreenAddKeyBody(String provider);

  /// No description provided for @providerScreenSelectProvider.
  ///
  /// In en, this message translates to:
  /// **'SELECT PROVIDER'**
  String get providerScreenSelectProvider;

  /// No description provided for @providerScreenNoProviders.
  ///
  /// In en, this message translates to:
  /// **'NO PROVIDERS AVAILABLE'**
  String get providerScreenNoProviders;

  /// No description provided for @providerScreenDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'[ DEFAULT ]'**
  String get providerScreenDefaultBadge;

  /// No description provided for @providerScreenErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String providerScreenErrorPrefix(String error);

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

  /// No description provided for @relayRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get relayRestore;

  /// No description provided for @relayFunctionalOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'FUNCTIONAL OVERVIEW:'**
  String get relayFunctionalOverviewTitle;

  /// No description provided for @relayFunctionalOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Permission Relays send agent intents to your device for remote authorization when you are away from the terminal.'**
  String get relayFunctionalOverviewBody;

  /// No description provided for @relayUnlimitedCapacity.
  ///
  /// In en, this message translates to:
  /// **'REMOTE AUTHORIZATION CAPACITY: UNLIMITED'**
  String get relayUnlimitedCapacity;

  /// No description provided for @relayPermissionRelayLabel.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION RELAY'**
  String get relayPermissionRelayLabel;

  /// No description provided for @relayNtfyTitle.
  ///
  /// In en, this message translates to:
  /// **'NTFY RELAY'**
  String get relayNtfyTitle;

  /// No description provided for @relayNtfyDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to your own NTFY server for free, unlimited relays without registration.'**
  String get relayNtfyDescription;

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

  /// No description provided for @deployComingSoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get deployComingSoon;

  /// No description provided for @deploymentSyncAttempt.
  ///
  /// In en, this message translates to:
  /// **'SYNC ATTEMPT: {attempt}'**
  String deploymentSyncAttempt(int attempt);

  /// No description provided for @deploymentCurrentOperation.
  ///
  /// In en, this message translates to:
  /// **'CURRENT OPERATION'**
  String get deploymentCurrentOperation;

  /// No description provided for @deploymentSourceCommit.
  ///
  /// In en, this message translates to:
  /// **'SOURCE COMMIT'**
  String get deploymentSourceCommit;

  /// No description provided for @deploymentRunId.
  ///
  /// In en, this message translates to:
  /// **'DEPLOYMENT RUN'**
  String get deploymentRunId;

  /// No description provided for @deploymentStatusSchema.
  ///
  /// In en, this message translates to:
  /// **'STATUS SCHEMA'**
  String get deploymentStatusSchema;

  /// No description provided for @deploymentLastSignal.
  ///
  /// In en, this message translates to:
  /// **'LAST SERVER SIGNAL'**
  String get deploymentLastSignal;

  /// No description provided for @deploymentErrorCode.
  ///
  /// In en, this message translates to:
  /// **'SERVER ERROR CODE'**
  String get deploymentErrorCode;

  /// No description provided for @pocoProvisioningTourTitle.
  ///
  /// In en, this message translates to:
  /// **'POCO VPS TOUR'**
  String get pocoProvisioningTourTitle;

  /// No description provided for @pocoProvisioningWaitingForSource.
  ///
  /// In en, this message translates to:
  /// **'I am waiting for your VPS to report its exact source commit. Once it does, I can show you the code actually being installed.'**
  String get pocoProvisioningWaitingForSource;

  /// No description provided for @pocoProvisioningLoadingSource.
  ///
  /// In en, this message translates to:
  /// **'I found the exact release commit. I am fetching its public provisioning code so we can inspect it together.'**
  String get pocoProvisioningLoadingSource;

  /// No description provided for @pocoProvisioningSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The deployment is still running, but I could not load its annotated source right now. This lesson is optional and never blocks your VPS.'**
  String get pocoProvisioningSourceUnavailable;

  /// No description provided for @pocoProvisioningPrevious.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUS'**
  String get pocoProvisioningPrevious;

  /// No description provided for @pocoProvisioningNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get pocoProvisioningNext;

  /// No description provided for @pocoProvisioningShowFull.
  ///
  /// In en, this message translates to:
  /// **'SHOW FULL SECTION'**
  String get pocoProvisioningShowFull;

  /// No description provided for @pocoProvisioningShowConcise.
  ///
  /// In en, this message translates to:
  /// **'SHOW CONCISE VIEW'**
  String get pocoProvisioningShowConcise;

  /// No description provided for @pocoLessonVpsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your VPS disk'**
  String get pocoLessonVpsStorageTitle;

  /// No description provided for @pocoLessonVpsStorageExplanation.
  ///
  /// In en, this message translates to:
  /// **'The release image is only the starting shape of the server. This tells NixOS to expand its filesystem so PocketCoder can use the full disk you rented.'**
  String get pocoLessonVpsStorageExplanation;

  /// No description provided for @pocoLessonPublicFirewallTitle.
  ///
  /// In en, this message translates to:
  /// **'The public firewall'**
  String get pocoLessonPublicFirewallTitle;

  /// No description provided for @pocoLessonPublicFirewallExplanation.
  ///
  /// In en, this message translates to:
  /// **'A firewall is a guest list for network traffic. This VPS exposes only SSH and web traffic; everything else is refused by default.'**
  String get pocoLessonPublicFirewallExplanation;

  /// No description provided for @pocoLessonContainerFirewallTitle.
  ///
  /// In en, this message translates to:
  /// **'The container firewall'**
  String get pocoLessonContainerFirewallTitle;

  /// No description provided for @pocoLessonContainerFirewallExplanation.
  ///
  /// In en, this message translates to:
  /// **'Docker has its own traffic path, so the host firewall alone is not enough. These rules apply the same boundaries to containers and block access to cloud metadata credentials.'**
  String get pocoLessonContainerFirewallExplanation;

  /// No description provided for @pocoLessonSshTitle.
  ///
  /// In en, this message translates to:
  /// **'Key-only administration'**
  String get pocoLessonSshTitle;

  /// No description provided for @pocoLessonSshExplanation.
  ///
  /// In en, this message translates to:
  /// **'SSH is the emergency and administration door to your VPS. PocketCoder disables password login, requires your cryptographic key, and temporarily bans repeated guessing attempts.'**
  String get pocoLessonSshExplanation;

  /// No description provided for @pocoLessonDockerTitle.
  ///
  /// In en, this message translates to:
  /// **'The container engine'**
  String get pocoLessonDockerTitle;

  /// No description provided for @pocoLessonDockerExplanation.
  ///
  /// In en, this message translates to:
  /// **'Docker runs each PocketCoder component in a defined container. NixOS manages the Docker engine itself, while Compose describes what Docker should run.'**
  String get pocoLessonDockerExplanation;

  /// No description provided for @pocoLessonOwnerConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Receiving your configuration'**
  String get pocoLessonOwnerConfigTitle;

  /// No description provided for @pocoLessonOwnerConfigExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your VPS receives its owner settings once, stores them in a protected file, installs your SSH key, and removes the temporary copy used during first boot.'**
  String get pocoLessonOwnerConfigExplanation;

  /// No description provided for @pocoLessonLocalSecretsTitle.
  ///
  /// In en, this message translates to:
  /// **'Host-local secrets'**
  String get pocoLessonLocalSecretsTitle;

  /// No description provided for @pocoLessonLocalSecretsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Internal services need private handshake secrets. The VPS creates random values locally instead of sending those secrets through the app or committing them to GitHub.'**
  String get pocoLessonLocalSecretsExplanation;

  /// No description provided for @pocoLessonReleaseSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'The exact release source'**
  String get pocoLessonReleaseSourceTitle;

  /// No description provided for @pocoLessonReleaseSourceExplanation.
  ///
  /// In en, this message translates to:
  /// **'The server checks out the precise Git commit embedded in the release. That makes the code on your VPS inspectable and keeps later updates tied to a real repository.'**
  String get pocoLessonReleaseSourceExplanation;

  /// No description provided for @pocoLessonVerifiedImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified container images'**
  String get pocoLessonVerifiedImagesTitle;

  /// No description provided for @pocoLessonVerifiedImagesExplanation.
  ///
  /// In en, this message translates to:
  /// **'The VPS downloads prebuilt container images and checks their SHA-256 fingerprint before loading them. A missing, incomplete, or modified bundle stops deployment instead of silently building something different.'**
  String get pocoLessonVerifiedImagesExplanation;

  /// No description provided for @pocoLessonComposeStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Starting the stack'**
  String get pocoLessonComposeStartTitle;

  /// No description provided for @pocoLessonComposeStartExplanation.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose starts the verified images in the background without rebuilding them. PocketCoder then writes a completion marker, while the app independently waits for a real health response.'**
  String get pocoLessonComposeStartExplanation;

  /// No description provided for @pocoLessonPocketbaseTitle.
  ///
  /// In en, this message translates to:
  /// **'The application core'**
  String get pocoLessonPocketbaseTitle;

  /// No description provided for @pocoLessonPocketbaseExplanation.
  ///
  /// In en, this message translates to:
  /// **'PocketBase is the control plane and application database. Its port is bound only to the VPS itself, so public requests must pass through the encrypted reverse proxy.'**
  String get pocoLessonPocketbaseExplanation;

  /// No description provided for @pocoLessonAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'The private coding agent'**
  String get pocoLessonAgentTitle;

  /// No description provided for @pocoLessonAgentExplanation.
  ///
  /// In en, this message translates to:
  /// **'Goose is the coding-agent process. It has no public host port and talks to PocketBase over a private, authenticated network created just for that relationship.'**
  String get pocoLessonAgentExplanation;

  /// No description provided for @pocoLessonLocalModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Local model runtime'**
  String get pocoLessonLocalModelTitle;

  /// No description provided for @pocoLessonLocalModelExplanation.
  ///
  /// In en, this message translates to:
  /// **'Ollama can run models on your own VPS. Its model files survive restarts, and its private networks separate inference traffic from model-management traffic.'**
  String get pocoLessonLocalModelExplanation;

  /// No description provided for @pocoLessonHarnessImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'On-demand coding harnesses'**
  String get pocoLessonHarnessImagesTitle;

  /// No description provided for @pocoLessonHarnessImagesExplanation.
  ///
  /// In en, this message translates to:
  /// **'These entries define images for supported coding tools. They are prepared during release creation but do not run until you choose that harness inside PocketCoder.'**
  String get pocoLessonHarnessImagesExplanation;

  /// No description provided for @pocoLessonMcpSandboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Controlled tool access'**
  String get pocoLessonMcpSandboxTitle;

  /// No description provided for @pocoLessonMcpSandboxExplanation.
  ///
  /// In en, this message translates to:
  /// **'The MCP gateway gives agents tools, but it reaches Docker through a restricted proxy. The allowlist grants only the operations that tool containers actually need.'**
  String get pocoLessonMcpSandboxExplanation;

  /// No description provided for @pocoLessonMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional agent memory'**
  String get pocoLessonMemoryTitle;

  /// No description provided for @pocoLessonMemoryExplanation.
  ///
  /// In en, this message translates to:
  /// **'Cognee is an optional memory service. Its initialization step fixes storage ownership first, and its private network lets the agent reach memory without exposing it publicly.'**
  String get pocoLessonMemoryExplanation;

  /// No description provided for @pocoLessonPocketbaseDockerAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Limited Docker control'**
  String get pocoLessonPocketbaseDockerAccessTitle;

  /// No description provided for @pocoLessonPocketbaseDockerAccessExplanation.
  ///
  /// In en, this message translates to:
  /// **'PocketBase sometimes needs to inspect or restart trusted containers. This second socket proxy gives it a smaller permission set than the tool gateway receives.'**
  String get pocoLessonPocketbaseDockerAccessExplanation;

  /// No description provided for @pocoLessonDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your local dashboard'**
  String get pocoLessonDashboardTitle;

  /// No description provided for @pocoLessonDashboardExplanation.
  ///
  /// In en, this message translates to:
  /// **'SQLPage reads operational databases through read-only mounts and turns them into a private dashboard. An initialization step makes optional data sources safe to query before they exist.'**
  String get pocoLessonDashboardExplanation;

  /// No description provided for @pocoLessonNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional notifications'**
  String get pocoLessonNotificationsTitle;

  /// No description provided for @pocoLessonNotificationsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Ntfy can provide a notification server that you own. It is behind an optional Compose profile, so it runs only when you deliberately enable it.'**
  String get pocoLessonNotificationsExplanation;

  /// No description provided for @pocoLessonPrivateAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Private remote access'**
  String get pocoLessonPrivateAccessTitle;

  /// No description provided for @pocoLessonPrivateAccessExplanation.
  ///
  /// In en, this message translates to:
  /// **'Tailscale can connect the VPS to your private network without opening another public application port. Its identity is stored in a persistent volume.'**
  String get pocoLessonPrivateAccessExplanation;

  /// No description provided for @pocoLessonLocalCaddyTitle.
  ///
  /// In en, this message translates to:
  /// **'Alternative HTTPS proxy'**
  String get pocoLessonLocalCaddyTitle;

  /// No description provided for @pocoLessonLocalCaddyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Self-managed Docker installations can run Caddy as a container for automatic HTTPS. The supported NixOS VPS uses native host Caddy instead, so this profile stays off there.'**
  String get pocoLessonLocalCaddyExplanation;

  /// No description provided for @pocoLessonVolumesTitle.
  ///
  /// In en, this message translates to:
  /// **'Persistent data'**
  String get pocoLessonVolumesTitle;

  /// No description provided for @pocoLessonVolumesExplanation.
  ///
  /// In en, this message translates to:
  /// **'Containers are replaceable; volumes are the durable storage underneath them. Databases, workspaces, credentials, backups, and downloaded models live here across restarts and upgrades.'**
  String get pocoLessonVolumesExplanation;

  /// No description provided for @pocoLessonNetworksTitle.
  ///
  /// In en, this message translates to:
  /// **'Private service networks'**
  String get pocoLessonNetworksTitle;

  /// No description provided for @pocoLessonNetworksExplanation.
  ///
  /// In en, this message translates to:
  /// **'Compose uses several small networks instead of one flat network. Each connection represents a specific trust relationship, limiting which services can reach one another.'**
  String get pocoLessonNetworksExplanation;

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

  /// No description provided for @errorsTitle.
  ///
  /// In en, this message translates to:
  /// **'ERROR REPORTS'**
  String get errorsTitle;

  /// No description provided for @errorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO ERRORS CAPTURED'**
  String get errorsEmpty;

  /// No description provided for @errorsCopy.
  ///
  /// In en, this message translates to:
  /// **'COPY REPORT'**
  String get errorsCopy;

  /// No description provided for @errorsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'COPY ALL'**
  String get errorsCopyAll;

  /// No description provided for @errorsCopied.
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTIC REPORT COPIED'**
  String get errorsCopied;

  /// No description provided for @errorsClearAll.
  ///
  /// In en, this message translates to:
  /// **'CLEAR ALL'**
  String get errorsClearAll;

  /// No description provided for @harnessAuthChallengeTargetCopied.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGE TARGET COPIED'**
  String get harnessAuthChallengeTargetCopied;

  /// No description provided for @errorsOccurred.
  ///
  /// In en, this message translates to:
  /// **'Occurred {count}x'**
  String errorsOccurred(int count);
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
