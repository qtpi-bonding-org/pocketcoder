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

  /// No description provided for @errorCouldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Please try again.'**
  String get errorCouldNotOpenBrowser;

  /// No description provided for @errorCouldNotOpenMailApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open a mail app. Please try again.'**
  String get errorCouldNotOpenMailApp;

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

  /// No description provided for @providerReauthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Your provider needs to be reauthenticated. Your saved login was kept.'**
  String get providerReauthenticationRequired;

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

  /// No description provided for @billingRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore your purchases. Check your connection and try again.'**
  String get billingRestoreFailed;

  /// No description provided for @billingError.
  ///
  /// In en, this message translates to:
  /// **'Billing error'**
  String get billingError;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get actionSave;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get actionClose;

  /// No description provided for @actionDeny.
  ///
  /// In en, this message translates to:
  /// **'deny'**
  String get actionDeny;

  /// No description provided for @actionAuthorize.
  ///
  /// In en, this message translates to:
  /// **'authorize'**
  String get actionAuthorize;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'refresh'**
  String get actionRefresh;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get actionBack;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'skip'**
  String get actionSkip;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'next'**
  String get actionContinue;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'change'**
  String get actionChange;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'create'**
  String get actionCreate;

  /// No description provided for @actionAddNew.
  ///
  /// In en, this message translates to:
  /// **'add new'**
  String get actionAddNew;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'restore'**
  String get actionRestore;

  /// No description provided for @actionConfigure.
  ///
  /// In en, this message translates to:
  /// **'configure'**
  String get actionConfigure;

  /// No description provided for @actionReject.
  ///
  /// In en, this message translates to:
  /// **'reject'**
  String get actionReject;

  /// No description provided for @externalAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'external authentication'**
  String get externalAuthTitle;

  /// No description provided for @externalAuthConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {label}...'**
  String externalAuthConnecting(String label);

  /// No description provided for @externalAuthRetry.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get externalAuthRetry;

  /// No description provided for @externalAuthCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get externalAuthCancel;

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

  /// No description provided for @bootNoiseHeartbeat.
  ///
  /// In en, this message translates to:
  /// **'[sys] heartbeat: ok'**
  String get bootNoiseHeartbeat;

  /// No description provided for @bootNoiseKeepalive.
  ///
  /// In en, this message translates to:
  /// **'[net] keepalive sent'**
  String get bootNoiseKeepalive;

  /// No description provided for @bootNoiseGcMinor.
  ///
  /// In en, this message translates to:
  /// **'[mem] gc_minor completed'**
  String get bootNoiseGcMinor;

  /// No description provided for @bootNoiseContextSwitch.
  ///
  /// In en, this message translates to:
  /// **'[proc] context_switch: 1241'**
  String get bootNoiseContextSwitch;

  /// No description provided for @bootNoiseReasoningEngine.
  ///
  /// In en, this message translates to:
  /// **'[agent] reasoning_engine: idle'**
  String get bootNoiseReasoningEngine;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'identification unlock'**
  String get onboardingTitle;

  /// No description provided for @onboardingPocoChallengeMessage.
  ///
  /// In en, this message translates to:
  /// **'Who goes there? Identify yourself and provide the secret passphrase.'**
  String get onboardingPocoChallengeMessage;

  /// No description provided for @onboardingPocoWelcome.
  ///
  /// In en, this message translates to:
  /// **'Identity verified! Welcome home. I knew it was you—just had to make sure the Cloud wasn\'t spoofing your signature.'**
  String get onboardingPocoWelcome;

  /// No description provided for @onboardingAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied.'**
  String get onboardingAccessDenied;

  /// No description provided for @onboardingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get onboardingProcessing;

  /// No description provided for @onboardingLogin.
  ///
  /// In en, this message translates to:
  /// **'connect'**
  String get onboardingLogin;

  /// No description provided for @onboardingDeploy.
  ///
  /// In en, this message translates to:
  /// **'deploy'**
  String get onboardingDeploy;

  /// No description provided for @onboardingHomeServer.
  ///
  /// In en, this message translates to:
  /// **'home server'**
  String get onboardingHomeServer;

  /// No description provided for @onboardingIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'identity'**
  String get onboardingIdentityLabel;

  /// No description provided for @onboardingEmailHint.
  ///
  /// In en, this message translates to:
  /// **'enter email'**
  String get onboardingEmailHint;

  /// No description provided for @onboardingPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'passphrase'**
  String get onboardingPassphraseLabel;

  /// No description provided for @onboardingPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'enter password'**
  String get onboardingPasswordHint;

  /// No description provided for @onboardingAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'authenticating'**
  String get onboardingAuthenticating;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder setup'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingConnectOrDeploy.
  ///
  /// In en, this message translates to:
  /// **'Are you already part of the PocketCoder initiative?'**
  String get onboardingConnectOrDeploy;

  /// No description provided for @onboardingExistingServer.
  ///
  /// In en, this message translates to:
  /// **'use an existing PocketBase server'**
  String get onboardingExistingServer;

  /// No description provided for @onboardingCreateServer.
  ///
  /// In en, this message translates to:
  /// **'create a new server'**
  String get onboardingCreateServer;

  /// No description provided for @onboardingServerLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'server login'**
  String get onboardingServerLoginTitle;

  /// No description provided for @onboardingServerUrl.
  ///
  /// In en, this message translates to:
  /// **'server URL'**
  String get onboardingServerUrl;

  /// No description provided for @onboardingServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://server.example.com'**
  String get onboardingServerUrlHint;

  /// No description provided for @onboardingEmail.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get onboardingEmail;

  /// No description provided for @onboardingEmailHintShort.
  ///
  /// In en, this message translates to:
  /// **'admin@example.com'**
  String get onboardingEmailHintShort;

  /// No description provided for @onboardingPassword.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get onboardingPassword;

  /// No description provided for @onboardingServerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get onboardingServerConnecting;

  /// No description provided for @onboardingRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'enter all required fields'**
  String get onboardingRequiredFields;

  /// No description provided for @onboardingChooseHarnessTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your harness'**
  String get onboardingChooseHarnessTitle;

  /// No description provided for @onboardingChooseHarnessBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the account-based agent to connect.'**
  String get onboardingChooseHarnessBody;

  /// No description provided for @onboardingChooseHarnessLoadingProviders.
  ///
  /// In en, this message translates to:
  /// **'Loading provider connections…'**
  String get onboardingChooseHarnessLoadingProviders;

  /// No description provided for @onboardingHarnessProvidersLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading harness providers…'**
  String get onboardingHarnessProvidersLoading;

  /// No description provided for @onboardingHarnessNotFound.
  ///
  /// In en, this message translates to:
  /// **'harness not found'**
  String get onboardingHarnessNotFound;

  /// No description provided for @onboardingClaudeAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Claude account login'**
  String get onboardingClaudeAccountLogin;

  /// No description provided for @onboardingCodexAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'ChatGPT account login'**
  String get onboardingCodexAccountLogin;

  /// No description provided for @onboardingHarnessAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'{harness} account login'**
  String onboardingHarnessAccountLogin(String harness);

  /// No description provided for @onboardingHarnessLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} login'**
  String onboardingHarnessLoginTitle(String provider);

  /// No description provided for @onboardingHarnessAccountVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Who uses this harness account?'**
  String get onboardingHarnessAccountVisibilityTitle;

  /// No description provided for @onboardingHarnessAccountVisibilityBody.
  ///
  /// In en, this message translates to:
  /// **'Shared reuses this login across profiles on this server. Personal keeps a separate login for this profile.'**
  String get onboardingHarnessAccountVisibilityBody;

  /// No description provided for @onboardingHarnessAccountVisibilityPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get onboardingHarnessAccountVisibilityPersonal;

  /// No description provided for @onboardingHarnessAccountVisibilityShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get onboardingHarnessAccountVisibilityShared;

  /// No description provided for @onboardingHarnessAccountVisibilityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get onboardingHarnessAccountVisibilityCancel;

  /// No description provided for @onboardingConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get onboardingConnected;

  /// No description provided for @onboardingAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'account login'**
  String get onboardingAccountLogin;

  /// No description provided for @onboardingAuthorizationCode.
  ///
  /// In en, this message translates to:
  /// **'authorization code'**
  String get onboardingAuthorizationCode;

  /// No description provided for @onboardingAuthorizationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'paste code'**
  String get onboardingAuthorizationCodeHint;

  /// No description provided for @onboardingSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'submit code'**
  String get onboardingSubmitCode;

  /// No description provided for @onboardingOpenAuthorization.
  ///
  /// In en, this message translates to:
  /// **'open authorization'**
  String get onboardingOpenAuthorization;

  /// No description provided for @onboardingCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'check status'**
  String get onboardingCheckStatus;

  /// No description provided for @onboardingOpenChatFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open a new chat. Please try again.'**
  String get onboardingOpenChatFailed;

  /// No description provided for @onboardingServerCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'server credentials'**
  String get onboardingServerCredentialsTitle;

  /// No description provided for @onboardingPocketbaseAdminEmail.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder admin email'**
  String get onboardingPocketbaseAdminEmail;

  /// No description provided for @onboardingPocketbaseAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder admin password'**
  String get onboardingPocketbaseAdminPassword;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'chats'**
  String get homeTitle;

  /// No description provided for @homeLoadingChats.
  ///
  /// In en, this message translates to:
  /// **'loading chats'**
  String get homeLoadingChats;

  /// No description provided for @homeErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String homeErrorPrefix(String error);

  /// No description provided for @homeNewChat.
  ///
  /// In en, this message translates to:
  /// **'new chat'**
  String get homeNewChat;

  /// No description provided for @homeNoChats.
  ///
  /// In en, this message translates to:
  /// **'No active chats found.'**
  String get homeNoChats;

  /// No description provided for @chatSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'chat session'**
  String get chatSessionTitle;

  /// No description provided for @chatTerminalAction.
  ///
  /// In en, this message translates to:
  /// **'terminal'**
  String get chatTerminalAction;

  /// No description provided for @chatListNewChat.
  ///
  /// In en, this message translates to:
  /// **'new'**
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
  /// **'create'**
  String get newChatCreate;

  /// No description provided for @newChatCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get newChatCancel;

  /// No description provided for @newChatSelectHarness.
  ///
  /// In en, this message translates to:
  /// **'select harness'**
  String get newChatSelectHarness;

  /// No description provided for @newChatSelectModel.
  ///
  /// In en, this message translates to:
  /// **'select model'**
  String get newChatSelectModel;

  /// No description provided for @newChatNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available for this harness'**
  String get newChatNoModelsAvailable;

  /// No description provided for @newChatWorkspaceErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Path cannot be empty'**
  String get newChatWorkspaceErrorEmpty;

  /// No description provided for @newChatWorkspaceErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Path must be /workspace or a subdirectory of it'**
  String get newChatWorkspaceErrorInvalid;

  /// No description provided for @chatListArchive.
  ///
  /// In en, this message translates to:
  /// **'archive'**
  String get chatListArchive;

  /// No description provided for @chatListDelete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get chatListDelete;

  /// No description provided for @chatListActionsBody.
  ///
  /// In en, this message translates to:
  /// **'archive hides \"{title}\" from this list. delete removes it permanently.'**
  String chatListActionsBody(String title);

  /// No description provided for @chatListTimestampNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get chatListTimestampNow;

  /// No description provided for @chatListTimestampMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String chatListTimestampMinutesAgo(int count);

  /// No description provided for @chatListTimestampHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String chatListTimestampHoursAgo(int count);

  /// No description provided for @chatListTimestampDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String chatListTimestampDaysAgo(int count);

  /// No description provided for @chatFilesAction.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get chatFilesAction;

  /// No description provided for @chatNewCapabilityRequest.
  ///
  /// In en, this message translates to:
  /// **'[!] new capability request received'**
  String get chatNewCapabilityRequest;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get chatThinking;

  /// No description provided for @chatThinkingLive.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatThinkingLive;

  /// No description provided for @chatThought.
  ///
  /// In en, this message translates to:
  /// **'thought'**
  String get chatThought;

  /// No description provided for @chatAwaitingHarnessStart.
  ///
  /// In en, this message translates to:
  /// **'Starting the harness -- this can take a minute or two on a fresh container.'**
  String get chatAwaitingHarnessStart;

  /// No description provided for @chatWorkingThroughRequest.
  ///
  /// In en, this message translates to:
  /// **'Working through the request.'**
  String get chatWorkingThroughRequest;

  /// No description provided for @chatCommandOutput.
  ///
  /// In en, this message translates to:
  /// **'output'**
  String get chatCommandOutput;

  /// No description provided for @chatToolCallFallback.
  ///
  /// In en, this message translates to:
  /// **'Tool call'**
  String get chatToolCallFallback;

  /// No description provided for @chatSessionAction.
  ///
  /// In en, this message translates to:
  /// **'session'**
  String get chatSessionAction;

  /// No description provided for @chatMonitorAction.
  ///
  /// In en, this message translates to:
  /// **'watch'**
  String get chatMonitorAction;

  /// No description provided for @chatSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendTooltip;

  /// No description provided for @chatCommanderRole.
  ///
  /// In en, this message translates to:
  /// **'commander'**
  String get chatCommanderRole;

  /// No description provided for @chatThinkingRole.
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get chatThinkingRole;

  /// No description provided for @chatPocoRole.
  ///
  /// In en, this message translates to:
  /// **'Poco'**
  String get chatPocoRole;

  /// No description provided for @chatElicitationRequest.
  ///
  /// In en, this message translates to:
  /// **'elicitation request'**
  String get chatElicitationRequest;

  /// No description provided for @chatElicitationFormLabel.
  ///
  /// In en, this message translates to:
  /// **'form'**
  String get chatElicitationFormLabel;

  /// No description provided for @chatCommanderPrompt.
  ///
  /// In en, this message translates to:
  /// **'commander@pc \$ '**
  String get chatCommanderPrompt;

  /// No description provided for @chatComposerPrompt.
  ///
  /// In en, this message translates to:
  /// **'commander@pc \$'**
  String get chatComposerPrompt;

  /// No description provided for @chatPocoPrompt.
  ///
  /// In en, this message translates to:
  /// **'[poco] '**
  String get chatPocoPrompt;

  /// No description provided for @chatPickerFieldIndicator.
  ///
  /// In en, this message translates to:
  /// **'[v]'**
  String get chatPickerFieldIndicator;

  /// No description provided for @chatDecline.
  ///
  /// In en, this message translates to:
  /// **'decline'**
  String get chatDecline;

  /// No description provided for @chatSubmit.
  ///
  /// In en, this message translates to:
  /// **'submit'**
  String get chatSubmit;

  /// No description provided for @chatNoFieldsRequested.
  ///
  /// In en, this message translates to:
  /// **'(no fields requested)'**
  String get chatNoFieldsRequested;

  /// No description provided for @chatRunOutcomeInterruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'run interrupted'**
  String get chatRunOutcomeInterruptedTitle;

  /// No description provided for @chatRunOutcomeInterruptedBody.
  ///
  /// In en, this message translates to:
  /// **'The connection ended before the run finished.'**
  String get chatRunOutcomeInterruptedBody;

  /// No description provided for @chatRunOutcomeCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'run stopped'**
  String get chatRunOutcomeCancelledTitle;

  /// No description provided for @chatRunOutcomeCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The run was stopped.'**
  String get chatRunOutcomeCancelledBody;

  /// No description provided for @chatRunOutcomeFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'run failed'**
  String get chatRunOutcomeFailedTitle;

  /// No description provided for @chatRunOutcomeFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while running this request.'**
  String get chatRunOutcomeFailedBody;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get filesTitle;

  /// No description provided for @filesEmpty.
  ///
  /// In en, this message translates to:
  /// **'no files'**
  String get filesEmpty;

  /// No description provided for @filesTooLargeToPreview.
  ///
  /// In en, this message translates to:
  /// **'file too large to preview'**
  String get filesTooLargeToPreview;

  /// No description provided for @filesCantPreviewType.
  ///
  /// In en, this message translates to:
  /// **'can\'t preview this file type'**
  String get filesCantPreviewType;

  /// No description provided for @chatModelLabel.
  ///
  /// In en, this message translates to:
  /// **'model:'**
  String get chatModelLabel;

  /// No description provided for @chatModelDefault.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get chatModelDefault;

  /// No description provided for @chatModelPerChat.
  ///
  /// In en, this message translates to:
  /// **'[chat]'**
  String get chatModelPerChat;

  /// No description provided for @chatSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'select model'**
  String get chatSelectModelTitle;

  /// No description provided for @chatUseGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'use global default'**
  String get chatUseGlobalDefault;

  /// No description provided for @llmTitle.
  ///
  /// In en, this message translates to:
  /// **'llm management'**
  String get llmTitle;

  /// No description provided for @llmLoadingProviders.
  ///
  /// In en, this message translates to:
  /// **'loading providers'**
  String get llmLoadingProviders;

  /// No description provided for @llmActiveModelSection.
  ///
  /// In en, this message translates to:
  /// **'active model'**
  String get llmActiveModelSection;

  /// No description provided for @llmProvidersSection.
  ///
  /// In en, this message translates to:
  /// **'providers'**
  String get llmProvidersSection;

  /// No description provided for @llmApiKeysSection.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get llmApiKeysSection;

  /// No description provided for @llmGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'global default'**
  String get llmGlobalDefault;

  /// No description provided for @llmNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get llmNotSet;

  /// No description provided for @llmAddKeyHint.
  ///
  /// In en, this message translates to:
  /// **'add an API key to enable model selection'**
  String get llmAddKeyHint;

  /// No description provided for @llmNoProviders.
  ///
  /// In en, this message translates to:
  /// **'no providers available'**
  String get llmNoProviders;

  /// No description provided for @llmConnected.
  ///
  /// In en, this message translates to:
  /// **'[ connected ]'**
  String get llmConnected;

  /// No description provided for @llmNoKey.
  ///
  /// In en, this message translates to:
  /// **'[ no key ]'**
  String get llmNoKey;

  /// No description provided for @llmModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} model(s) available'**
  String llmModelsAvailable(int count);

  /// No description provided for @llmUpdateKey.
  ///
  /// In en, this message translates to:
  /// **'update key'**
  String get llmUpdateKey;

  /// No description provided for @llmAddKey.
  ///
  /// In en, this message translates to:
  /// **'add key'**
  String get llmAddKey;

  /// No description provided for @llmModelsButton.
  ///
  /// In en, this message translates to:
  /// **'models'**
  String get llmModelsButton;

  /// No description provided for @llmApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'API key: {provider}'**
  String llmApiKeyDialogTitle(String provider);

  /// No description provided for @llmEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter credentials for {provider}:'**
  String llmEnterCredentials(String provider);

  /// No description provided for @llmSelectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'select model'**
  String get llmSelectModelTitle;

  /// No description provided for @llmProviderModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} models'**
  String llmProviderModelsTitle(String provider);

  /// No description provided for @llmNoModels.
  ///
  /// In en, this message translates to:
  /// **'no models listed'**
  String get llmNoModels;

  /// No description provided for @llmSelect.
  ///
  /// In en, this message translates to:
  /// **'[ select ]'**
  String get llmSelect;

  /// No description provided for @mcpTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP management'**
  String get mcpTitle;

  /// No description provided for @mcpCapabilitiesRegistry.
  ///
  /// In en, this message translates to:
  /// **'capabilities registry'**
  String get mcpCapabilitiesRegistry;

  /// No description provided for @mcpPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'pending approval'**
  String get mcpPendingApproval;

  /// No description provided for @mcpActiveCapabilities.
  ///
  /// In en, this message translates to:
  /// **'active capabilities'**
  String get mcpActiveCapabilities;

  /// No description provided for @mcpNoCapabilities.
  ///
  /// In en, this message translates to:
  /// **'no capabilities registered'**
  String get mcpNoCapabilities;

  /// No description provided for @mcpImageLabel.
  ///
  /// In en, this message translates to:
  /// **'image: {image}'**
  String mcpImageLabel(String image);

  /// No description provided for @mcpPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'purpose: {reason}'**
  String mcpPurposeLabel(String reason);

  /// No description provided for @mcpRequiredConfig.
  ///
  /// In en, this message translates to:
  /// **'required config:'**
  String get mcpRequiredConfig;

  /// No description provided for @mcpAuthorizeCap.
  ///
  /// In en, this message translates to:
  /// **'authorize capability'**
  String get mcpAuthorizeCap;

  /// No description provided for @mcpEditConfig.
  ///
  /// In en, this message translates to:
  /// **'edit configuration'**
  String get mcpEditConfig;

  /// No description provided for @mcpRevoke.
  ///
  /// In en, this message translates to:
  /// **'revoke'**
  String get mcpRevoke;

  /// No description provided for @mcpAuthorizeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'authorize: {name}'**
  String mcpAuthorizeDialogTitle(String name);

  /// No description provided for @mcpUpdateConfigDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'update config: {name}'**
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
  /// **'add MCP server'**
  String get mcpAddDialogTitle;

  /// No description provided for @mcpServerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'server name'**
  String get mcpServerNameLabel;

  /// No description provided for @mcpImageOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'image (optional)'**
  String get mcpImageOptionalLabel;

  /// No description provided for @mcpAddConfigOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional config (leave blank if none needed)'**
  String get mcpAddConfigOptional;

  /// No description provided for @mcpConnectCap.
  ///
  /// In en, this message translates to:
  /// **'connect'**
  String get mcpConnectCap;

  /// No description provided for @mcpRetryDeliveryCap.
  ///
  /// In en, this message translates to:
  /// **'retry delivery'**
  String get mcpRetryDeliveryCap;

  /// No description provided for @mcpOauthRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'requires OAuth: {provider}'**
  String mcpOauthRequiredLabel(String provider);

  /// No description provided for @mcpOauthProviderOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'OAuth provider (optional)'**
  String get mcpOauthProviderOptionalLabel;

  /// No description provided for @mcpOauthTokenEnvVarOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'OAuth token env var (optional)'**
  String get mcpOauthTokenEnvVarOptionalLabel;

  /// No description provided for @mcpOauthProviderNotConfiguredLabel.
  ///
  /// In en, this message translates to:
  /// **'{provider} not yet configured'**
  String mcpOauthProviderNotConfiguredLabel(String provider);

  /// No description provided for @mcpAddNew.
  ///
  /// In en, this message translates to:
  /// **'add new'**
  String get mcpAddNew;

  /// No description provided for @mcpDeny.
  ///
  /// In en, this message translates to:
  /// **'deny'**
  String get mcpDeny;

  /// No description provided for @mcpAuthorize.
  ///
  /// In en, this message translates to:
  /// **'authorize'**
  String get mcpAuthorize;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'add'**
  String get actionAdd;

  /// No description provided for @toolPermissionsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'tool permissions'**
  String get toolPermissionsScreenTitle;

  /// No description provided for @toolPermissionsRulesRegistry.
  ///
  /// In en, this message translates to:
  /// **'permission rules'**
  String get toolPermissionsRulesRegistry;

  /// No description provided for @toolPermissionsNoRules.
  ///
  /// In en, this message translates to:
  /// **'no rules configured'**
  String get toolPermissionsNoRules;

  /// No description provided for @toolPermissionsAddRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'add permission rule'**
  String get toolPermissionsAddRuleTitle;

  /// No description provided for @toolPermissionsToolNameLabel.
  ///
  /// In en, this message translates to:
  /// **'tool name'**
  String get toolPermissionsToolNameLabel;

  /// No description provided for @toolPermissionsAllowLabel.
  ///
  /// In en, this message translates to:
  /// **'allow'**
  String get toolPermissionsAllowLabel;

  /// No description provided for @toolPermissionsAskLabel.
  ///
  /// In en, this message translates to:
  /// **'ask'**
  String get toolPermissionsAskLabel;

  /// No description provided for @toolPermissionsDenyLabel.
  ///
  /// In en, this message translates to:
  /// **'deny'**
  String get toolPermissionsDenyLabel;

  /// No description provided for @toolPermissionsAddRuleButton.
  ///
  /// In en, this message translates to:
  /// **'add rule'**
  String get toolPermissionsAddRuleButton;

  /// No description provided for @notificationSettingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get notificationSettingsScreenTitle;

  /// No description provided for @notificationSettingsChatReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'chat replies'**
  String get notificationSettingsChatReplyLabel;

  /// No description provided for @notificationSettingsScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'scheduled tasks'**
  String get notificationSettingsScheduleLabel;

  /// No description provided for @notificationSettingsTaskCompleteLabel.
  ///
  /// In en, this message translates to:
  /// **'task complete'**
  String get notificationSettingsTaskCompleteLabel;

  /// No description provided for @notificationSettingsTaskErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'task errors'**
  String get notificationSettingsTaskErrorLabel;

  /// No description provided for @notificationSettingsPoco.
  ///
  /// In en, this message translates to:
  /// **'I can notify you when an agent needs approval or finishes a task, even when PocketCoder is not open. Your phone will ask for permission before I enable alerts on this device.'**
  String get notificationSettingsPoco;

  /// No description provided for @notificationSettingsEnableDevice.
  ///
  /// In en, this message translates to:
  /// **'enable on this device'**
  String get notificationSettingsEnableDevice;

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'skills'**
  String get skillsTitle;

  /// No description provided for @skillsRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'skills registry'**
  String get skillsRegistryTitle;

  /// No description provided for @skillsGlobalSection.
  ///
  /// In en, this message translates to:
  /// **'global'**
  String get skillsGlobalSection;

  /// No description provided for @skillsProjectSection.
  ///
  /// In en, this message translates to:
  /// **'project'**
  String get skillsProjectSection;

  /// No description provided for @skillsNoSkills.
  ///
  /// In en, this message translates to:
  /// **'no skills configured'**
  String get skillsNoSkills;

  /// No description provided for @skillsAddButton.
  ///
  /// In en, this message translates to:
  /// **'add skill'**
  String get skillsAddButton;

  /// No description provided for @skillsEditButton.
  ///
  /// In en, this message translates to:
  /// **'edit'**
  String get skillsEditButton;

  /// No description provided for @skillsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get skillsDeleteButton;

  /// No description provided for @skillsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get skillsSaveButton;

  /// No description provided for @skillsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get skillsNameLabel;

  /// No description provided for @skillsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'description'**
  String get skillsDescriptionLabel;

  /// No description provided for @skillsContentLabel.
  ///
  /// In en, this message translates to:
  /// **'content'**
  String get skillsContentLabel;

  /// No description provided for @skillsGlobalLabel.
  ///
  /// In en, this message translates to:
  /// **'global'**
  String get skillsGlobalLabel;

  /// No description provided for @skillsProjectLabel.
  ///
  /// In en, this message translates to:
  /// **'project'**
  String get skillsProjectLabel;

  /// No description provided for @skillsAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'add skill'**
  String get skillsAddDialogTitle;

  /// No description provided for @skillsEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'edit: {name}'**
  String skillsEditDialogTitle(String name);

  /// No description provided for @skillsNoEligibleConfig.
  ///
  /// In en, this message translates to:
  /// **'No agent config has a workspace folder configured.'**
  String get skillsNoEligibleConfig;

  /// No description provided for @skillsBuiltInLabel.
  ///
  /// In en, this message translates to:
  /// **'built-in'**
  String get skillsBuiltInLabel;

  /// No description provided for @schedulerTitle.
  ///
  /// In en, this message translates to:
  /// **'scheduler'**
  String get schedulerTitle;

  /// No description provided for @schedulerRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'scheduled tasks'**
  String get schedulerRegistryTitle;

  /// No description provided for @schedulerNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'no schedules configured'**
  String get schedulerNoSchedules;

  /// No description provided for @schedulerAddButton.
  ///
  /// In en, this message translates to:
  /// **'add schedule'**
  String get schedulerAddButton;

  /// No description provided for @schedulerEditButton.
  ///
  /// In en, this message translates to:
  /// **'edit'**
  String get schedulerEditButton;

  /// No description provided for @schedulerDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get schedulerDeleteButton;

  /// No description provided for @schedulerSaveButton.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get schedulerSaveButton;

  /// No description provided for @schedulerPauseButton.
  ///
  /// In en, this message translates to:
  /// **'pause'**
  String get schedulerPauseButton;

  /// No description provided for @schedulerResumeButton.
  ///
  /// In en, this message translates to:
  /// **'resume'**
  String get schedulerResumeButton;

  /// No description provided for @schedulerRunNowButton.
  ///
  /// In en, this message translates to:
  /// **'run now'**
  String get schedulerRunNowButton;

  /// No description provided for @schedulerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get schedulerNameLabel;

  /// No description provided for @schedulerCronLabel.
  ///
  /// In en, this message translates to:
  /// **'cron expression'**
  String get schedulerCronLabel;

  /// No description provided for @schedulerPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'prompt'**
  String get schedulerPromptLabel;

  /// No description provided for @schedulerAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'add schedule'**
  String get schedulerAddDialogTitle;

  /// No description provided for @schedulerEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'edit: {name}'**
  String schedulerEditDialogTitle(String name);

  /// No description provided for @schedulerPausedBadge.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get schedulerPausedBadge;

  /// No description provided for @schedulerRunningBadge.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get schedulerRunningBadge;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'configure'**
  String get settingsTitle;

  /// No description provided for @settingsAiAgentsSection.
  ///
  /// In en, this message translates to:
  /// **'agents & access'**
  String get settingsAiAgentsSection;

  /// No description provided for @settingsReportAiContentLabel.
  ///
  /// In en, this message translates to:
  /// **'report AI content'**
  String get settingsReportAiContentLabel;

  /// No description provided for @settingsSystemSection.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get settingsSystemSection;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'account'**
  String get settingsAccountSection;

  /// No description provided for @settingsMenuLlmManagement.
  ///
  /// In en, this message translates to:
  /// **'llm management'**
  String get settingsMenuLlmManagement;

  /// No description provided for @settingsMenuAgentRegistry.
  ///
  /// In en, this message translates to:
  /// **'agent registry'**
  String get settingsMenuAgentRegistry;

  /// No description provided for @settingsMenuMcpManagement.
  ///
  /// In en, this message translates to:
  /// **'MCP management'**
  String get settingsMenuMcpManagement;

  /// No description provided for @settingsMenuSkills.
  ///
  /// In en, this message translates to:
  /// **'skills'**
  String get settingsMenuSkills;

  /// No description provided for @settingsMenuToolPermissions.
  ///
  /// In en, this message translates to:
  /// **'tool permissions'**
  String get settingsMenuToolPermissions;

  /// No description provided for @settingsMenuHarnessConnections.
  ///
  /// In en, this message translates to:
  /// **'harness connections'**
  String get settingsMenuHarnessConnections;

  /// No description provided for @settingsMenuSystemChecks.
  ///
  /// In en, this message translates to:
  /// **'system checks'**
  String get settingsMenuSystemChecks;

  /// No description provided for @settingsMenuPocketMemory.
  ///
  /// In en, this message translates to:
  /// **'pocket memory'**
  String get settingsMenuPocketMemory;

  /// No description provided for @settingsMenuPocketbase.
  ///
  /// In en, this message translates to:
  /// **'PocketBase'**
  String get settingsMenuPocketbase;

  /// No description provided for @settingsMenuScheduler.
  ///
  /// In en, this message translates to:
  /// **'scheduler'**
  String get settingsMenuScheduler;

  /// No description provided for @settingsMenuNotifications.
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get settingsMenuNotifications;

  /// No description provided for @settingsMenuLogout.
  ///
  /// In en, this message translates to:
  /// **'logout'**
  String get settingsMenuLogout;

  /// No description provided for @settingsMenuReset.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get settingsMenuReset;

  /// No description provided for @settingsMenuHapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'haptic feedback'**
  String get settingsMenuHapticFeedback;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'sign out'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will end your current session. You will need to log in again to continue.'**
  String get settingsLogoutConfirmBody;

  /// No description provided for @settingsLogoutCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get settingsLogoutCancel;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'sign out'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsFactoryResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get settingsFactoryResetConfirmTitle;

  /// No description provided for @settingsFactoryResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This clears the saved session and local deployment state so you can connect to another instance. It does not delete your cloud server.'**
  String get settingsFactoryResetConfirmBody;

  /// No description provided for @settingsFactoryResetCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get settingsFactoryResetCancel;

  /// No description provided for @settingsFactoryResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get settingsFactoryResetConfirm;

  /// No description provided for @settingsDeleteProDataLabel.
  ///
  /// In en, this message translates to:
  /// **'delete PocketCoder Pro data'**
  String get settingsDeleteProDataLabel;

  /// No description provided for @settingsDeleteProDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'delete pro data'**
  String get settingsDeleteProDataConfirmTitle;

  /// No description provided for @settingsDeleteProDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your subscription and notification records from PocketCoder Pro\'s systems. Your server and everything on it are unaffected -- use your own SSH access if you want to wipe that too.'**
  String get settingsDeleteProDataConfirmBody;

  /// No description provided for @settingsDeleteProDataCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get settingsDeleteProDataCancel;

  /// No description provided for @settingsDeleteProDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get settingsDeleteProDataConfirm;

  /// No description provided for @agentTitle.
  ///
  /// In en, this message translates to:
  /// **'agent registry'**
  String get agentTitle;

  /// No description provided for @agentModelsPersonas.
  ///
  /// In en, this message translates to:
  /// **'models & personas'**
  String get agentModelsPersonas;

  /// No description provided for @agentSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get agentSearching;

  /// No description provided for @agentRegistryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Registry empty.'**
  String get agentRegistryEmpty;

  /// No description provided for @agentSelectToConfigure.
  ///
  /// In en, this message translates to:
  /// **'select agent to configure'**
  String get agentSelectToConfigure;

  /// No description provided for @agentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'agent: {name}'**
  String agentDialogTitle(String name);

  /// No description provided for @agentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get agentNameLabel;

  /// No description provided for @agentDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'description'**
  String get agentDescriptionLabel;

  /// No description provided for @agentPromptsLabel.
  ///
  /// In en, this message translates to:
  /// **'prompts'**
  String get agentPromptsLabel;

  /// No description provided for @agentModelsLabel.
  ///
  /// In en, this message translates to:
  /// **'models'**
  String get agentModelsLabel;

  /// No description provided for @agentParametersLabel.
  ///
  /// In en, this message translates to:
  /// **'parameters'**
  String get agentParametersLabel;

  /// No description provided for @agentNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get agentNone;

  /// No description provided for @agentNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'none selected'**
  String get agentNoneSelected;

  /// No description provided for @agentDefaultTuned.
  ///
  /// In en, this message translates to:
  /// **'default [tuned]'**
  String get agentDefaultTuned;

  /// No description provided for @agentPlanPanelBadge.
  ///
  /// In en, this message translates to:
  /// **'[plan]'**
  String get agentPlanPanelBadge;

  /// No description provided for @agentPlanPanelLabel.
  ///
  /// In en, this message translates to:
  /// **'plan'**
  String get agentPlanPanelLabel;

  /// No description provided for @agentConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'agent configuration'**
  String get agentConfigTitle;

  /// No description provided for @agentConfigRegistry.
  ///
  /// In en, this message translates to:
  /// **'agent configs'**
  String get agentConfigRegistry;

  /// No description provided for @agentConfigEmpty.
  ///
  /// In en, this message translates to:
  /// **'no agent configs yet'**
  String get agentConfigEmpty;

  /// No description provided for @agentConfigDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'agent config: {name}'**
  String agentConfigDialogTitle(String name);

  /// No description provided for @agentConfigNameLabel.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get agentConfigNameLabel;

  /// No description provided for @agentConfigPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'system prompt'**
  String get agentConfigPromptLabel;

  /// No description provided for @agentConfigModeLabel.
  ///
  /// In en, this message translates to:
  /// **'mode'**
  String get agentConfigModeLabel;

  /// No description provided for @agentConfigIsDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'is default'**
  String get agentConfigIsDefaultLabel;

  /// No description provided for @agentConfigNoPrompts.
  ///
  /// In en, this message translates to:
  /// **'no prompts available'**
  String get agentConfigNoPrompts;

  /// No description provided for @agentConfigNoModes.
  ///
  /// In en, this message translates to:
  /// **'no modes available'**
  String get agentConfigNoModes;

  /// No description provided for @agentConfigSelectPrompt.
  ///
  /// In en, this message translates to:
  /// **'select prompt'**
  String get agentConfigSelectPrompt;

  /// No description provided for @agentConfigSelectMode.
  ///
  /// In en, this message translates to:
  /// **'select mode'**
  String get agentConfigSelectMode;

  /// No description provided for @agentConfigDelete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get agentConfigDelete;

  /// No description provided for @agentConfigDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete config?'**
  String get agentConfigDeleteConfirmTitle;

  /// No description provided for @agentConfigDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String agentConfigDeleteConfirmBody(String name);

  /// No description provided for @agentConfigDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'[ default ]'**
  String get agentConfigDefaultBadge;

  /// No description provided for @agentConfigErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String agentConfigErrorPrefix(String error);

  /// No description provided for @providerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'provider management'**
  String get providerScreenTitle;

  /// No description provided for @providerScreenLoading.
  ///
  /// In en, this message translates to:
  /// **'loading providers'**
  String get providerScreenLoading;

  /// No description provided for @providerScreenHarnessModelsSection.
  ///
  /// In en, this message translates to:
  /// **'harness models'**
  String get providerScreenHarnessModelsSection;

  /// No description provided for @providerScreenApiKeysSection.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get providerScreenApiKeysSection;

  /// No description provided for @providerScreenNoHarnessModels.
  ///
  /// In en, this message translates to:
  /// **'no harness models listed'**
  String get providerScreenNoHarnessModels;

  /// No description provided for @providerScreenHarnessModelCount.
  ///
  /// In en, this message translates to:
  /// **'{count} models'**
  String providerScreenHarnessModelCount(int count);

  /// No description provided for @providerScreenBrowseAllModels.
  ///
  /// In en, this message translates to:
  /// **'browse all {count} models'**
  String providerScreenBrowseAllModels(int count);

  /// No description provided for @providerScreenNoApiKeys.
  ///
  /// In en, this message translates to:
  /// **'no API keys configured'**
  String get providerScreenNoApiKeys;

  /// No description provided for @providerScreenEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'no harness models or API keys yet'**
  String get providerScreenEmptyHint;

  /// No description provided for @providerScreenAddKey.
  ///
  /// In en, this message translates to:
  /// **'add key'**
  String get providerScreenAddKey;

  /// No description provided for @providerScreenUpdateKey.
  ///
  /// In en, this message translates to:
  /// **'update key'**
  String get providerScreenUpdateKey;

  /// No description provided for @providerScreenAddKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'API key: {provider}'**
  String providerScreenAddKeyTitle(String provider);

  /// No description provided for @providerScreenAddKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Enter credentials for {provider}:'**
  String providerScreenAddKeyBody(String provider);

  /// No description provided for @providerScreenSelectProvider.
  ///
  /// In en, this message translates to:
  /// **'select provider'**
  String get providerScreenSelectProvider;

  /// No description provided for @providerScreenNoProviders.
  ///
  /// In en, this message translates to:
  /// **'no providers available'**
  String get providerScreenNoProviders;

  /// No description provided for @providerScreenSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'search'**
  String get providerScreenSearchLabel;

  /// No description provided for @providerScreenSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Filter providers'**
  String get providerScreenSearchHint;

  /// No description provided for @providerScreenSearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'no matching providers'**
  String get providerScreenSearchNoMatches;

  /// No description provided for @providerScreenDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'[ default ]'**
  String get providerScreenDefaultBadge;

  /// No description provided for @providerScreenErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String providerScreenErrorPrefix(String error);

  /// No description provided for @providerScreenApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerScreenApiKeyLabel;

  /// No description provided for @providerScreenApiKeyLeaveBlankHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the existing key'**
  String get providerScreenApiKeyLeaveBlankHint;

  /// No description provided for @providerScreenApiKeyNotSet.
  ///
  /// In en, this message translates to:
  /// **'(not set)'**
  String get providerScreenApiKeyNotSet;

  /// No description provided for @providerScreenApiKeyStoredSecurely.
  ///
  /// In en, this message translates to:
  /// **'Existing key is stored securely; enter a new key to replace it.'**
  String get providerScreenApiKeyStoredSecurely;

  /// No description provided for @providerScreenProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'provider'**
  String get providerScreenProviderLabel;

  /// No description provided for @providerScreenDeleteKeyAction.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get providerScreenDeleteKeyAction;

  /// No description provided for @toolPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'gatekeeper configuration'**
  String get toolPermissionsTitle;

  /// No description provided for @toolPermissionsFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'tool permissions'**
  String get toolPermissionsFrameTitle;

  /// No description provided for @toolPermissionsLoading.
  ///
  /// In en, this message translates to:
  /// **'loading permissions'**
  String get toolPermissionsLoading;

  /// No description provided for @toolPermissionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No permissions defined.'**
  String get toolPermissionsEmpty;

  /// No description provided for @toolPermissionsAdd.
  ///
  /// In en, this message translates to:
  /// **'add permission'**
  String get toolPermissionsAdd;

  /// No description provided for @toolPermissionsScopeAgent.
  ///
  /// In en, this message translates to:
  /// **'agent'**
  String get toolPermissionsScopeAgent;

  /// No description provided for @toolPermissionsScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'global'**
  String get toolPermissionsScopeGlobal;

  /// No description provided for @toolPermissionsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'add tool permission'**
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
  /// **'action:'**
  String get toolPermissionsActionLabel;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'terminal mirror'**
  String get terminalTitle;

  /// No description provided for @terminalTransfer.
  ///
  /// In en, this message translates to:
  /// **'transfer'**
  String get terminalTransfer;

  /// No description provided for @terminalReconnect.
  ///
  /// In en, this message translates to:
  /// **'reconnect'**
  String get terminalReconnect;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'establishing SSH link'**
  String get terminalConnecting;

  /// No description provided for @terminalConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'connection failed'**
  String get terminalConnectionFailed;

  /// No description provided for @terminalRetry.
  ///
  /// In en, this message translates to:
  /// **'retry connection'**
  String get terminalRetry;

  /// No description provided for @terminalSftpTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP transfer'**
  String get terminalSftpTitle;

  /// No description provided for @terminalDestinationPath.
  ///
  /// In en, this message translates to:
  /// **'destination path'**
  String get terminalDestinationPath;

  /// No description provided for @terminalUpload.
  ///
  /// In en, this message translates to:
  /// **'upload'**
  String get terminalUpload;

  /// No description provided for @terminalConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'connection_status'**
  String get terminalConnectionStatus;

  /// No description provided for @terminalSshLink.
  ///
  /// In en, this message translates to:
  /// **'SSH link: {host}:{port}'**
  String terminalSshLink(String host, String port);

  /// No description provided for @terminalOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get terminalOnline;

  /// No description provided for @terminalOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get terminalOffline;

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'monitor'**
  String get monitorTitle;

  /// No description provided for @monitorTelemetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'telemetry unavailable'**
  String get monitorTelemetryUnavailable;

  /// No description provided for @fileTitle.
  ///
  /// In en, this message translates to:
  /// **'source output manifest'**
  String get fileTitle;

  /// No description provided for @fileDashboardAction.
  ///
  /// In en, this message translates to:
  /// **'dashboard'**
  String get fileDashboardAction;

  /// No description provided for @fileClearAction.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get fileClearAction;

  /// No description provided for @fileNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected.'**
  String get fileNoFileSelected;

  /// No description provided for @fileSelectFromChat.
  ///
  /// In en, this message translates to:
  /// **'>> select from chat to view'**
  String get fileSelectFromChat;

  /// No description provided for @fileFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching data...'**
  String get fileFetching;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'empty file'**
  String get fileEmpty;

  /// No description provided for @systemChecksTitle.
  ///
  /// In en, this message translates to:
  /// **'system checks'**
  String get systemChecksTitle;

  /// No description provided for @systemChecksDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'system diagnostics'**
  String get systemChecksDiagnostics;

  /// No description provided for @systemChecksEmpty.
  ///
  /// In en, this message translates to:
  /// **'no diagnostics available'**
  String get systemChecksEmpty;

  /// No description provided for @observabilityRegistry.
  ///
  /// In en, this message translates to:
  /// **'registry'**
  String get observabilityRegistry;

  /// No description provided for @observabilityLogTerminal.
  ///
  /// In en, this message translates to:
  /// **'system log terminal'**
  String get observabilityLogTerminal;

  /// No description provided for @observabilitySelectContainer.
  ///
  /// In en, this message translates to:
  /// **'>> select container for log stream'**
  String get observabilitySelectContainer;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder Pro'**
  String get proTitle;

  /// No description provided for @proPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'unlock all systems'**
  String get proPlanTitle;

  /// No description provided for @proCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking pro status...'**
  String get proCheckingStatus;

  /// No description provided for @proUnlockCommand.
  ///
  /// In en, this message translates to:
  /// **'\$ unlock --all'**
  String get proUnlockCommand;

  /// No description provided for @proSummary.
  ///
  /// In en, this message translates to:
  /// **'One subscription. Every PocketCoder Pro capability.'**
  String get proSummary;

  /// No description provided for @proFeatureReady.
  ///
  /// In en, this message translates to:
  /// **'[OK]'**
  String get proFeatureReady;

  /// No description provided for @proFeatureDeploy.
  ///
  /// In en, this message translates to:
  /// **'provision and deploy PocketCoder servers'**
  String get proFeatureDeploy;

  /// No description provided for @proFeaturePush.
  ///
  /// In en, this message translates to:
  /// **'receive hosted agent notifications'**
  String get proFeaturePush;

  /// No description provided for @proFeatureConsole.
  ///
  /// In en, this message translates to:
  /// **'use pro console controls as they ship'**
  String get proFeatureConsole;

  /// No description provided for @proTrialDuration.
  ///
  /// In en, this message translates to:
  /// **'{days} days free'**
  String proTrialDuration(int days);

  /// No description provided for @proTrialNoPaymentInfo.
  ///
  /// In en, this message translates to:
  /// **'Starts a free week. No payment info is collected now.'**
  String get proTrialNoPaymentInfo;

  /// No description provided for @proTrialLapseExplainer.
  ///
  /// In en, this message translates to:
  /// **'If you do not keep pro, only hosted push notifications stop. Your server keeps running.'**
  String get proTrialLapseExplainer;

  /// No description provided for @proPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}'**
  String proPrice(String price);

  /// No description provided for @proPriceAfterTrial.
  ///
  /// In en, this message translates to:
  /// **'then {price}'**
  String proPriceAfterTrial(String price);

  /// No description provided for @proPricePerWeek.
  ///
  /// In en, this message translates to:
  /// **'{price} / week'**
  String proPricePerWeek(String price);

  /// No description provided for @proPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String proPricePerMonth(String price);

  /// No description provided for @proPricePerYear.
  ///
  /// In en, this message translates to:
  /// **'{price} / year'**
  String proPricePerYear(String price);

  /// No description provided for @proStartTrial.
  ///
  /// In en, this message translates to:
  /// **'start {days}-day free trial'**
  String proStartTrial(int days);

  /// No description provided for @proSubscribe.
  ///
  /// In en, this message translates to:
  /// **'unlock PocketCoder Pro'**
  String get proSubscribe;

  /// No description provided for @proRestore.
  ///
  /// In en, this message translates to:
  /// **'restore purchases'**
  String get proRestore;

  /// No description provided for @proManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'manage subscription'**
  String get proManageSubscription;

  /// No description provided for @proTerms.
  ///
  /// In en, this message translates to:
  /// **'Subscription renews at {price} Until cancelled. Manage or cancel in your app store account.'**
  String proTerms(String price);

  /// No description provided for @proTrialTerms.
  ///
  /// In en, this message translates to:
  /// **'Free for {days} Days, then {price} Until cancelled. Manage or cancel in your app store account.'**
  String proTrialTerms(int days, String price);

  /// No description provided for @proTermsOfServiceLink.
  ///
  /// In en, this message translates to:
  /// **'terms of service'**
  String get proTermsOfServiceLink;

  /// No description provided for @proPrivacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get proPrivacyPolicyLink;

  /// No description provided for @proBenefitServerSetup.
  ///
  /// In en, this message translates to:
  /// **'one-tap server setup -- no manual VPS configuration'**
  String get proBenefitServerSetup;

  /// No description provided for @proBenefitPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'push notifications for agent activity -- approvals, task completion'**
  String get proBenefitPushNotifications;

  /// No description provided for @proBenefitLiveMonitoring.
  ///
  /// In en, this message translates to:
  /// **'live agent monitoring'**
  String get proBenefitLiveMonitoring;

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'> entitlement: active'**
  String get proActive;

  /// No description provided for @proActiveBody.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder Pro is active. Deployment and hosted notifications are unlocked.'**
  String get proActiveBody;

  /// No description provided for @proUnavailable.
  ///
  /// In en, this message translates to:
  /// **'> offering: unavailable'**
  String get proUnavailable;

  /// No description provided for @proUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The app store could not return the PocketCoder Pro subscription. Check your connection or restore an existing purchase.'**
  String get proUnavailableBody;

  /// No description provided for @proSelfHostedPushTitle.
  ///
  /// In en, this message translates to:
  /// **'self-hosted notifications'**
  String get proSelfHostedPushTitle;

  /// No description provided for @proSelfHostedPushBody.
  ///
  /// In en, this message translates to:
  /// **'You can connect your own Ntfy or UnifiedPush distributor without PocketCoder Pro.'**
  String get proSelfHostedPushBody;

  /// No description provided for @proConfigureSelfHostedPush.
  ///
  /// In en, this message translates to:
  /// **'configure self-hosted push'**
  String get proConfigureSelfHostedPush;

  /// No description provided for @proSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder Pro'**
  String get proSettingsLabel;

  /// No description provided for @proSettingsStatus.
  ///
  /// In en, this message translates to:
  /// **'[status]'**
  String get proSettingsStatus;

  /// No description provided for @chooseProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'choose provider'**
  String get chooseProviderTitle;

  /// No description provided for @deploySelectProvider.
  ///
  /// In en, this message translates to:
  /// **'select provider'**
  String get deploySelectProvider;

  /// No description provided for @deployChooseProvider.
  ///
  /// In en, this message translates to:
  /// **'choose where to deploy your instance'**
  String get deployChooseProvider;

  /// No description provided for @chooseProviderProBadge.
  ///
  /// In en, this message translates to:
  /// **'pro'**
  String get chooseProviderProBadge;

  /// No description provided for @chooseProviderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'coming soon'**
  String get chooseProviderComingSoon;

  /// No description provided for @pocketCoderProgressProvisionServer.
  ///
  /// In en, this message translates to:
  /// **'provision server'**
  String get pocketCoderProgressProvisionServer;

  /// No description provided for @pocketCoderProgressDeployPocketCoder.
  ///
  /// In en, this message translates to:
  /// **'deploy PocketCoder'**
  String get pocketCoderProgressDeployPocketCoder;

  /// No description provided for @pocketCoderProgressWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get pocketCoderProgressWaiting;

  /// No description provided for @pocketCoderProgressActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get pocketCoderProgressActive;

  /// No description provided for @pocketCoderProgressComplete.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get pocketCoderProgressComplete;

  /// No description provided for @pocketCoderProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get pocketCoderProgressFailed;

  /// No description provided for @pocketCoderProgressInitializing.
  ///
  /// In en, this message translates to:
  /// **'initializing'**
  String get pocketCoderProgressInitializing;

  /// No description provided for @deploymentStepCreateInstance.
  ///
  /// In en, this message translates to:
  /// **'Creating server'**
  String get deploymentStepCreateInstance;

  /// No description provided for @deploymentStepPlanLookup.
  ///
  /// In en, this message translates to:
  /// **'Looking up plan details'**
  String get deploymentStepPlanLookup;

  /// No description provided for @deploymentStepCreateInstallerDisk.
  ///
  /// In en, this message translates to:
  /// **'Preparing installer disk'**
  String get deploymentStepCreateInstallerDisk;

  /// No description provided for @deploymentStepWaitInstallerDiskReady.
  ///
  /// In en, this message translates to:
  /// **'Waiting for installer disk'**
  String get deploymentStepWaitInstallerDiskReady;

  /// No description provided for @deploymentStepCreateTargetDisk.
  ///
  /// In en, this message translates to:
  /// **'Preparing target disk'**
  String get deploymentStepCreateTargetDisk;

  /// No description provided for @deploymentStepWaitTargetDiskReady.
  ///
  /// In en, this message translates to:
  /// **'Waiting for target disk'**
  String get deploymentStepWaitTargetDiskReady;

  /// No description provided for @deploymentStepCreateInstallerConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuring installer boot'**
  String get deploymentStepCreateInstallerConfig;

  /// No description provided for @deploymentStepBootInstaller.
  ///
  /// In en, this message translates to:
  /// **'Booting installer'**
  String get deploymentStepBootInstaller;

  /// No description provided for @deploymentStepWaitInstallerCompletion.
  ///
  /// In en, this message translates to:
  /// **'Installing operating system'**
  String get deploymentStepWaitInstallerCompletion;

  /// No description provided for @deploymentStepRemoveInstallerResources.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up installer'**
  String get deploymentStepRemoveInstallerResources;

  /// No description provided for @deploymentStepCreateFinalConfig.
  ///
  /// In en, this message translates to:
  /// **'Configuring server boot'**
  String get deploymentStepCreateFinalConfig;

  /// No description provided for @deploymentStepPreBootShutdown.
  ///
  /// In en, this message translates to:
  /// **'Restarting server'**
  String get deploymentStepPreBootShutdown;

  /// No description provided for @deploymentStepBootFinal.
  ///
  /// In en, this message translates to:
  /// **'Booting server'**
  String get deploymentStepBootFinal;

  /// No description provided for @deploymentStepFinalInstanceFetch.
  ///
  /// In en, this message translates to:
  /// **'Confirming server is up'**
  String get deploymentStepFinalInstanceFetch;

  /// No description provided for @deploymentStepEnableWatchdog.
  ///
  /// In en, this message translates to:
  /// **'Re-enabling server monitoring'**
  String get deploymentStepEnableWatchdog;

  /// No description provided for @deploymentStepWaitingForConnection.
  ///
  /// In en, this message translates to:
  /// **'Connecting to server'**
  String get deploymentStepWaitingForConnection;

  /// No description provided for @deploymentStepConfiguringOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Configuring operating system'**
  String get deploymentStepConfiguringOperatingSystem;

  /// No description provided for @deploymentStepFetchingRelease.
  ///
  /// In en, this message translates to:
  /// **'Fetching PocketCoder release'**
  String get deploymentStepFetchingRelease;

  /// No description provided for @deploymentStepLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'Loading container images'**
  String get deploymentStepLoadingImages;

  /// No description provided for @deploymentStepComposeUp.
  ///
  /// In en, this message translates to:
  /// **'Starting services'**
  String get deploymentStepComposeUp;

  /// No description provided for @deploymentStepBootstrapComplete.
  ///
  /// In en, this message translates to:
  /// **'Finishing setup'**
  String get deploymentStepBootstrapComplete;

  /// No description provided for @deploymentStepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get deploymentStepReady;

  /// No description provided for @initializationScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'initializing server'**
  String get initializationScreenTitle;

  /// No description provided for @initializationActionAbort.
  ///
  /// In en, this message translates to:
  /// **'abort'**
  String get initializationActionAbort;

  /// No description provided for @initializationActionRetry.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get initializationActionRetry;

  /// No description provided for @initializationUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get initializationUnknown;

  /// No description provided for @initializationTechnicalDetailsToggle.
  ///
  /// In en, this message translates to:
  /// **'technical details'**
  String get initializationTechnicalDetailsToggle;

  /// No description provided for @initializationNetworkIp.
  ///
  /// In en, this message translates to:
  /// **'network IP'**
  String get initializationNetworkIp;

  /// No description provided for @initializationGeoGrid.
  ///
  /// In en, this message translates to:
  /// **'geo grid'**
  String get initializationGeoGrid;

  /// No description provided for @initializationFaultDetected.
  ///
  /// In en, this message translates to:
  /// **'fault detected: {error}'**
  String initializationFaultDetected(Object error);

  /// No description provided for @initializationFaultGeneric.
  ///
  /// In en, this message translates to:
  /// **'Setup could not continue. Return and try again.'**
  String get initializationFaultGeneric;

  /// No description provided for @initializationFaultProvisionInterruptedNoResource.
  ///
  /// In en, this message translates to:
  /// **'Provisioning was interrupted before a provider resource was recorded. Return to configuration to retry or reset local initialization state.'**
  String get initializationFaultProvisionInterruptedNoResource;

  /// No description provided for @initializationFaultProvisionResourceStillExists.
  ///
  /// In en, this message translates to:
  /// **'Provisioning was interrupted after a provider resource was created. The resource still exists and was not recreated automatically. Use cleanup or resume from the provider account before trying again.'**
  String get initializationFaultProvisionResourceStillExists;

  /// No description provided for @initializationFaultProvisionResourceNotFound.
  ///
  /// In en, this message translates to:
  /// **'The tracked provider resource is no longer found in your account. It may have been deleted outside the app. Use Reset Deployment State to clear local state, or re-deploy from configuration.'**
  String get initializationFaultProvisionResourceNotFound;

  /// No description provided for @deploymentFaultDeploymentInstanceNotFound.
  ///
  /// In en, this message translates to:
  /// **'The tracked deployment instance is no longer found in your provider account. It may have been deleted outside the app. Use Reset Deployment State to clear local state, or re-deploy from configuration.'**
  String get deploymentFaultDeploymentInstanceNotFound;

  /// No description provided for @initializationFaultResourceAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A provider resource already exists. Retrying provisioning could create a duplicate billable resource. Use Reset/Cleanup/Resume instead.'**
  String get initializationFaultResourceAlreadyExists;

  /// No description provided for @initializationFaultAuthenticationExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Linode connection has expired or was revoked. Reconnect your account, then restart the initialization.'**
  String get initializationFaultAuthenticationExpired;

  /// No description provided for @initializationFaultMaxRetriesExceeded.
  ///
  /// In en, this message translates to:
  /// **'Max retry attempts ({maxAttempts}) exceeded.'**
  String initializationFaultMaxRetriesExceeded(Object maxAttempts);

  /// No description provided for @initializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup could not continue. Return and try again.'**
  String get initializationFailed;

  /// No description provided for @initializationReady.
  ///
  /// In en, this message translates to:
  /// **'Server ready at {ipAddress}.'**
  String initializationReady(Object ipAddress);

  /// No description provided for @initializationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Server setup started.'**
  String get initializationInProgress;

  /// No description provided for @deploymentStatusValidating.
  ///
  /// In en, this message translates to:
  /// **'validating configuration'**
  String get deploymentStatusValidating;

  /// No description provided for @deploymentStatusConstructing.
  ///
  /// In en, this message translates to:
  /// **'constructing instance'**
  String get deploymentStatusConstructing;

  /// No description provided for @deploymentStatusPreparingOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'preparing OS'**
  String get deploymentStatusPreparingOperatingSystem;

  /// No description provided for @deploymentStatusSecuring.
  ///
  /// In en, this message translates to:
  /// **'securing connection'**
  String get deploymentStatusSecuring;

  /// No description provided for @deploymentStatusTlsReady.
  ///
  /// In en, this message translates to:
  /// **'connection secured'**
  String get deploymentStatusTlsReady;

  /// No description provided for @deploymentStatusTlsZeroSsl.
  ///
  /// In en, this message translates to:
  /// **'using backup certificate authority'**
  String get deploymentStatusTlsZeroSsl;

  /// No description provided for @deploymentStatusTlsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'certificate authority rate limited'**
  String get deploymentStatusTlsRateLimited;

  /// No description provided for @deploymentStatusTlsFailed.
  ///
  /// In en, this message translates to:
  /// **'certificate issuance failed'**
  String get deploymentStatusTlsFailed;

  /// No description provided for @deploymentStatusConfiguringOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'configuring OS'**
  String get deploymentStatusConfiguringOperatingSystem;

  /// No description provided for @deploymentStatusFetching.
  ///
  /// In en, this message translates to:
  /// **'fetching release'**
  String get deploymentStatusFetching;

  /// No description provided for @deploymentStatusLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'loading images'**
  String get deploymentStatusLoadingImages;

  /// No description provided for @deploymentStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'starting services'**
  String get deploymentStatusStarting;

  /// No description provided for @deploymentStatusFinishing.
  ///
  /// In en, this message translates to:
  /// **'finishing up'**
  String get deploymentStatusFinishing;

  /// No description provided for @deploymentStatusReady.
  ///
  /// In en, this message translates to:
  /// **'handshake successful'**
  String get deploymentStatusReady;

  /// No description provided for @deploymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'deployment aborted'**
  String get deploymentStatusFailed;

  /// No description provided for @initializationStatusInitializing.
  ///
  /// In en, this message translates to:
  /// **'initializing stack'**
  String get initializationStatusInitializing;

  /// No description provided for @deploymentDescriptionValidating.
  ///
  /// In en, this message translates to:
  /// **'Checking the provisioning configuration.'**
  String get deploymentDescriptionValidating;

  /// No description provided for @deploymentDescriptionConstructing.
  ///
  /// In en, this message translates to:
  /// **'Allocating hardware resources on cloud grid.'**
  String get deploymentDescriptionConstructing;

  /// No description provided for @deploymentDescriptionPreparingOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Preparing the operating system.'**
  String get deploymentDescriptionPreparingOperatingSystem;

  /// No description provided for @deploymentDescriptionSecuring.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the native reverse proxy.'**
  String get deploymentDescriptionSecuring;

  /// No description provided for @deploymentDescriptionTlsReady.
  ///
  /// In en, this message translates to:
  /// **'A browser-trusted certificate is active.'**
  String get deploymentDescriptionTlsReady;

  /// No description provided for @deploymentDescriptionTlsZeroSsl.
  ///
  /// In en, this message translates to:
  /// **'Issued via the backup authority after the primary was unavailable.'**
  String get deploymentDescriptionTlsZeroSsl;

  /// No description provided for @deploymentDescriptionTlsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Retrying automatically with a backup certificate authority.'**
  String get deploymentDescriptionTlsRateLimited;

  /// No description provided for @deploymentDescriptionTlsFailed.
  ///
  /// In en, this message translates to:
  /// **'The reverse proxy could not obtain a certificate.'**
  String get deploymentDescriptionTlsFailed;

  /// No description provided for @deploymentDescriptionConfiguringOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Preparing native services and dependencies.'**
  String get deploymentDescriptionConfiguringOperatingSystem;

  /// No description provided for @deploymentDescriptionFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching the immutable release.'**
  String get deploymentDescriptionFetching;

  /// No description provided for @deploymentDescriptionLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'Loading the verified image bundle.'**
  String get deploymentDescriptionLoadingImages;

  /// No description provided for @deploymentDescriptionStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting application services.'**
  String get deploymentDescriptionStarting;

  /// No description provided for @deploymentDescriptionFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing deployment.'**
  String get deploymentDescriptionFinishing;

  /// No description provided for @deploymentDescriptionReady.
  ///
  /// In en, this message translates to:
  /// **'The server is fully operational.'**
  String get deploymentDescriptionReady;

  /// No description provided for @deploymentDescriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup stopped before completion. No later step will continue.'**
  String get deploymentDescriptionFailed;

  /// No description provided for @initializationDescriptionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Preparing initialization manifest.'**
  String get initializationDescriptionInitializing;

  /// No description provided for @initializationStatusPrefix.
  ///
  /// In en, this message translates to:
  /// **'status: {status}'**
  String initializationStatusPrefix(Object status);

  /// No description provided for @initializationSecure.
  ///
  /// In en, this message translates to:
  /// **'[secure]'**
  String get initializationSecure;

  /// No description provided for @initializationConnectionParameters.
  ///
  /// In en, this message translates to:
  /// **'connection parameters'**
  String get initializationConnectionParameters;

  /// No description provided for @initializationMetadataRegistry.
  ///
  /// In en, this message translates to:
  /// **'metadata registry'**
  String get initializationMetadataRegistry;

  /// No description provided for @initializationActionLogin.
  ///
  /// In en, this message translates to:
  /// **'login'**
  String get initializationActionLogin;

  /// No description provided for @deploymentActionRefresh.
  ///
  /// In en, this message translates to:
  /// **'refresh'**
  String get deploymentActionRefresh;

  /// No description provided for @deploymentActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'update'**
  String get deploymentActionUpdate;

  /// No description provided for @deploymentActionDismiss.
  ///
  /// In en, this message translates to:
  /// **'dismiss'**
  String get deploymentActionDismiss;

  /// No description provided for @initializationInstanceManifest.
  ///
  /// In en, this message translates to:
  /// **'instance manifest'**
  String get initializationInstanceManifest;

  /// No description provided for @initializationIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get initializationIpAddress;

  /// No description provided for @initializationHttpsEndpoint.
  ///
  /// In en, this message translates to:
  /// **'HTTPS endpoint'**
  String get initializationHttpsEndpoint;

  /// No description provided for @initializationAdminIdentity.
  ///
  /// In en, this message translates to:
  /// **'admin identity'**
  String get initializationAdminIdentity;

  /// No description provided for @initializationAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'admin password'**
  String get initializationAdminPassword;

  /// No description provided for @initializationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get initializationNotAvailable;

  /// No description provided for @initializationCopyAction.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get initializationCopyAction;

  /// No description provided for @initializationHideAction.
  ///
  /// In en, this message translates to:
  /// **'hide'**
  String get initializationHideAction;

  /// No description provided for @initializationShowAction.
  ///
  /// In en, this message translates to:
  /// **'show'**
  String get initializationShowAction;

  /// No description provided for @deploymentProvisioned.
  ///
  /// In en, this message translates to:
  /// **'provisioned'**
  String get deploymentProvisioned;

  /// No description provided for @initializationCloudRegion.
  ///
  /// In en, this message translates to:
  /// **'cloud region'**
  String get initializationCloudRegion;

  /// No description provided for @initializationHardwarePlan.
  ///
  /// In en, this message translates to:
  /// **'hardware plan'**
  String get initializationHardwarePlan;

  /// No description provided for @initializationSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'Security notice: credentials are stored in local secure enclave. Passphrase retains encryption at rest.'**
  String get initializationSecurityNotice;

  /// No description provided for @initializationCopiedToBuffer.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to buffer'**
  String initializationCopiedToBuffer(Object label);

  /// No description provided for @initializationCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'copy {label}'**
  String initializationCopyLabel(Object label);

  /// No description provided for @deploymentManifestConfiguration.
  ///
  /// In en, this message translates to:
  /// **'manifest configuration'**
  String get deploymentManifestConfiguration;

  /// No description provided for @deploymentActionBack.
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get deploymentActionBack;

  /// No description provided for @deploymentActionDeployInstance.
  ///
  /// In en, this message translates to:
  /// **'deploy instance'**
  String get deploymentActionDeployInstance;

  /// No description provided for @deploymentActionInitialize.
  ///
  /// In en, this message translates to:
  /// **'initialize'**
  String get deploymentActionInitialize;

  /// No description provided for @deploymentSystemParameters.
  ///
  /// In en, this message translates to:
  /// **'system parameters'**
  String get deploymentSystemParameters;

  /// No description provided for @deploymentHardwareGeography.
  ///
  /// In en, this message translates to:
  /// **'hardware & geography'**
  String get deploymentHardwareGeography;

  /// No description provided for @deploymentInitializingHardware.
  ///
  /// In en, this message translates to:
  /// **'Initializing HW registry...'**
  String get deploymentInitializingHardware;

  /// No description provided for @deploymentScanningRegions.
  ///
  /// In en, this message translates to:
  /// **'Scanning global regions...'**
  String get deploymentScanningRegions;

  /// No description provided for @deploymentCodingHarnesses.
  ///
  /// In en, this message translates to:
  /// **'coding harnesses'**
  String get deploymentCodingHarnesses;

  /// No description provided for @deploymentHarnessSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what is downloaded onto your VPS. Goose is ready by default; you can select more than one.'**
  String get deploymentHarnessSelectionDescription;

  /// No description provided for @deploymentOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'operating system'**
  String get deploymentOperatingSystem;

  /// No description provided for @deploymentInstancePlan.
  ///
  /// In en, this message translates to:
  /// **'instance plan'**
  String get deploymentInstancePlan;

  /// No description provided for @deploymentMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String deploymentMonthlyPrice(String price);

  /// No description provided for @deploymentRegion.
  ///
  /// In en, this message translates to:
  /// **'deployment region'**
  String get deploymentRegion;

  /// No description provided for @deploymentBackend.
  ///
  /// In en, this message translates to:
  /// **'backend'**
  String get deploymentBackend;

  /// No description provided for @deploymentDistribution.
  ///
  /// In en, this message translates to:
  /// **'distribution'**
  String get deploymentDistribution;

  /// No description provided for @deploymentNixos.
  ///
  /// In en, this message translates to:
  /// **'NixOS'**
  String get deploymentNixos;

  /// No description provided for @deploymentStandardLinux.
  ///
  /// In en, this message translates to:
  /// **'Standard Linux'**
  String get deploymentStandardLinux;

  /// No description provided for @deploymentDebian.
  ///
  /// In en, this message translates to:
  /// **'Debian'**
  String get deploymentDebian;

  /// No description provided for @deploymentUbuntu.
  ///
  /// In en, this message translates to:
  /// **'Ubuntu'**
  String get deploymentUbuntu;

  /// No description provided for @deploymentSetupTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your setup'**
  String get deploymentSetupTypeTitle;

  /// No description provided for @deploymentServerSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your server size'**
  String get deploymentServerSizeTitle;

  /// No description provided for @deploymentServerRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your server region'**
  String get deploymentServerRegionTitle;

  /// No description provided for @deploymentCodingAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'choose coding agents'**
  String get deploymentCodingAgentsTitle;

  /// No description provided for @deploymentLinuxSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'Linux system'**
  String get deploymentLinuxSystemTitle;

  /// No description provided for @deploymentReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'review your server'**
  String get deploymentReviewTitle;

  /// No description provided for @deploymentWorkloadPoco.
  ///
  /// In en, this message translates to:
  /// **'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.'**
  String get deploymentWorkloadPoco;

  /// No description provided for @deploymentWorkloadCloudReply.
  ///
  /// In en, this message translates to:
  /// **'Cloud models run inference through your online AI account. Your server mainly needs room for PocketCoder, your agents, and your projects.\n\nI\'ll show the minimum server size I recommend. You can choose a larger one.'**
  String get deploymentWorkloadCloudReply;

  /// No description provided for @deploymentWorkloadLocalReply.
  ///
  /// In en, this message translates to:
  /// **'A local model runs on your own server through Ollama. It needs more computing power, and is usually faster with a GPU.\n\nI\'ll show the minimum server size I recommend. You can choose a larger one.'**
  String get deploymentWorkloadLocalReply;

  /// No description provided for @deploymentUseCloudModels.
  ///
  /// In en, this message translates to:
  /// **'use cloud models'**
  String get deploymentUseCloudModels;

  /// No description provided for @deploymentRunLocalModel.
  ///
  /// In en, this message translates to:
  /// **'run a local model'**
  String get deploymentRunLocalModel;

  /// No description provided for @deploymentPlanPoco.
  ///
  /// In en, this message translates to:
  /// **'The {minimumMemory} option is the minimum for remote models. Choose it or go larger for builds, tests, and updates.'**
  String deploymentPlanPoco(String minimumMemory);

  /// No description provided for @deploymentRegionPoco.
  ///
  /// In en, this message translates to:
  /// **'Choose where your server will live. A nearby region will usually respond faster, but you can use any available Linode region.'**
  String get deploymentRegionPoco;

  /// No description provided for @deploymentHarnessPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose which coding agents to have ready on your server.\n\nThis installs their software. You\'ll connect any required accounts after your server is ready.'**
  String get deploymentHarnessPoco;

  /// No description provided for @deploymentLinuxPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder deploys on NixOS -- chosen for reproducible, deterministic builds.'**
  String get deploymentLinuxPoco;

  /// No description provided for @deploymentReviewPoco.
  ///
  /// In en, this message translates to:
  /// **'Your server is ready to be provisioned.\n\nPocketCoder will create it in your Linode account, then install the coding agents you selected. Linode will bill you directly for the server.'**
  String get deploymentReviewPoco;

  /// No description provided for @deploymentNoSuitablePlans.
  ///
  /// In en, this message translates to:
  /// **'No suitable server sizes are available for this setup.'**
  String get deploymentNoSuitablePlans;

  /// No description provided for @deploymentMinimum.
  ///
  /// In en, this message translates to:
  /// **'minimum'**
  String get deploymentMinimum;

  /// No description provided for @deploymentRecommended.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get deploymentRecommended;

  /// No description provided for @deploymentGpuBadge.
  ///
  /// In en, this message translates to:
  /// **'GPU'**
  String get deploymentGpuBadge;

  /// No description provided for @deploymentDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'ready by default'**
  String get deploymentDefaultAgent;

  /// No description provided for @deploymentPlanSpecs.
  ///
  /// In en, this message translates to:
  /// **'{vcpus} CPU · {memory} RAM · {diskGb} GB disk'**
  String deploymentPlanSpecs(int vcpus, String memory, int diskGb);

  /// No description provided for @deploymentMemoryGb.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String deploymentMemoryGb(int value);

  /// No description provided for @deploymentMemoryMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String deploymentMemoryMb(int value);

  /// No description provided for @deploymentNixosDescription.
  ///
  /// In en, this message translates to:
  /// **'A repeatable server setup that is easier to recreate and roll back if a system change goes wrong.'**
  String get deploymentNixosDescription;

  /// No description provided for @deploymentDebianDescription.
  ///
  /// In en, this message translates to:
  /// **'A Debian server configured with setup scripts. Faster to set up.'**
  String get deploymentDebianDescription;

  /// No description provided for @deploymentProvisioningSummary.
  ///
  /// In en, this message translates to:
  /// **'provisioning summary'**
  String get deploymentProvisioningSummary;

  /// No description provided for @deploymentServerProvider.
  ///
  /// In en, this message translates to:
  /// **'server provider'**
  String get deploymentServerProvider;

  /// No description provided for @deploymentProviderLinode.
  ///
  /// In en, this message translates to:
  /// **'Linode'**
  String get deploymentProviderLinode;

  /// No description provided for @deploymentProviderFake.
  ///
  /// In en, this message translates to:
  /// **'fake'**
  String get deploymentProviderFake;

  /// No description provided for @deploymentConfigNotReadyError.
  ///
  /// In en, this message translates to:
  /// **'Deployment is not ready yet — configuration is still loading.'**
  String get deploymentConfigNotReadyError;

  /// No description provided for @deploymentAdminPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The admin password must be at least {minLength} characters.'**
  String deploymentAdminPasswordTooShort(int minLength);

  /// No description provided for @walkthroughLabel.
  ///
  /// In en, this message translates to:
  /// **'walkthrough {current} / {total}'**
  String walkthroughLabel(int current, int total);

  /// No description provided for @briefLabel.
  ///
  /// In en, this message translates to:
  /// **'brief {current} / {total}'**
  String briefLabel(int current, int total);

  /// No description provided for @walkthroughAskPoco.
  ///
  /// In en, this message translates to:
  /// **'ask Poco'**
  String get walkthroughAskPoco;

  /// No description provided for @walkthroughActionSkip.
  ///
  /// In en, this message translates to:
  /// **'skip'**
  String get walkthroughActionSkip;

  /// No description provided for @walkthroughBriefDivider.
  ///
  /// In en, this message translates to:
  /// **'brief'**
  String get walkthroughBriefDivider;

  /// No description provided for @walkthroughTransitionProvisioning.
  ///
  /// In en, this message translates to:
  /// **'Let\'s follow this next part of the server setup together.'**
  String get walkthroughTransitionProvisioning;

  /// No description provided for @walkthroughTransitionDeployment.
  ///
  /// In en, this message translates to:
  /// **'Now we\'ll follow the verified release onto the host.'**
  String get walkthroughTransitionDeployment;

  /// No description provided for @initializationSyncAttempt.
  ///
  /// In en, this message translates to:
  /// **'sync attempt: {attempt}'**
  String initializationSyncAttempt(Object attempt);

  /// No description provided for @initializationCurrentOperation.
  ///
  /// In en, this message translates to:
  /// **'current operation'**
  String get initializationCurrentOperation;

  /// No description provided for @initializationSourceCommit.
  ///
  /// In en, this message translates to:
  /// **'source commit'**
  String get initializationSourceCommit;

  /// No description provided for @initializationRunId.
  ///
  /// In en, this message translates to:
  /// **'initialization run'**
  String get initializationRunId;

  /// No description provided for @initializationStatusSchema.
  ///
  /// In en, this message translates to:
  /// **'status schema'**
  String get initializationStatusSchema;

  /// No description provided for @initializationLastSignal.
  ///
  /// In en, this message translates to:
  /// **'last server signal'**
  String get initializationLastSignal;

  /// No description provided for @initializationErrorCode.
  ///
  /// In en, this message translates to:
  /// **'server error code'**
  String get initializationErrorCode;

  /// No description provided for @pocoProvisioningTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Poco walkthrough'**
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

  /// No description provided for @pocoProvisioningFailed.
  ///
  /// In en, this message translates to:
  /// **'The setup stopped, so I stopped the walkthrough too. Go back to review the configuration, then we can try again.'**
  String get pocoProvisioningFailed;

  /// No description provided for @pocoProvisioningPrevious.
  ///
  /// In en, this message translates to:
  /// **'previous'**
  String get pocoProvisioningPrevious;

  /// No description provided for @pocoProvisioningNext.
  ///
  /// In en, this message translates to:
  /// **'next'**
  String get pocoProvisioningNext;

  /// No description provided for @pocoProvisioningShowFull.
  ///
  /// In en, this message translates to:
  /// **'show full snippet'**
  String get pocoProvisioningShowFull;

  /// No description provided for @pocoProvisioningShowConcise.
  ///
  /// In en, this message translates to:
  /// **'show preview'**
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
  /// **'Getting the OS ready'**
  String get pocoLessonDockerTitle;

  /// No description provided for @pocoLessonDockerExplanation.
  ///
  /// In en, this message translates to:
  /// **'NixOS enables the Docker engine that will run every PocketCoder component. The VPS then receives its owner settings once, stores them in a protected file, installs your SSH key, and removes the temporary copy used during first boot.'**
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
  /// **'Activating the verified release'**
  String get pocoLessonReleaseSourceTitle;

  /// No description provided for @pocoLessonReleaseSourceExplanation.
  ///
  /// In en, this message translates to:
  /// **'The server checks out the exact release commit, verifies every container image\'s signature, prepares fresh internal secrets, and starts the stack — writing a completion marker only once a real health check succeeds.'**
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
  /// **'Pocket Memory is an always-on local service. Agents write observations and interpretations directly, and semantic recall stays on your own server.'**
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

  /// No description provided for @onboardingNoServerLookingPoco.
  ///
  /// In en, this message translates to:
  /// **'Looking for a PocketCoder server...'**
  String get onboardingNoServerLookingPoco;

  /// No description provided for @onboardingNoServerPoco.
  ///
  /// In en, this message translates to:
  /// **'Are you already part of the PocketCoder Initiative?'**
  String get onboardingNoServerPoco;

  /// No description provided for @onboardingNoServerChipExisting.
  ///
  /// In en, this message translates to:
  /// **'log in'**
  String get onboardingNoServerChipExisting;

  /// No description provided for @onboardingNoServerChipNew.
  ///
  /// In en, this message translates to:
  /// **'join'**
  String get onboardingNoServerChipNew;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'welcome'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomePoco.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the PocketCoder Initiative.\n\nI\'ll help you set up PocketCoder on a server—a computer that stays online. That way, PocketCoder is accessible and ready whenever you need it.'**
  String get onboardingWelcomePoco;

  /// No description provided for @onboardingWelcomeActionGuided.
  ///
  /// In en, this message translates to:
  /// **'help me with setup'**
  String get onboardingWelcomeActionGuided;

  /// No description provided for @onboardingWelcomeActionSelfHost.
  ///
  /// In en, this message translates to:
  /// **'I\'ll set it up'**
  String get onboardingWelcomeActionSelfHost;

  /// No description provided for @onboardingSelfHostTitle.
  ///
  /// In en, this message translates to:
  /// **'self-host setup'**
  String get onboardingSelfHostTitle;

  /// No description provided for @onboardingSelfHostPoco.
  ///
  /// In en, this message translates to:
  /// **'You\'ll set up PocketCoder on a server you control. The setup guide walks through preparing the server, deploying PocketCoder, and finding the address you\'ll use to connect this app.'**
  String get onboardingSelfHostPoco;

  /// No description provided for @onboardingSelfHostRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'what you\'ll need'**
  String get onboardingSelfHostRequirementsTitle;

  /// No description provided for @onboardingSelfHostRequirementServer.
  ///
  /// In en, this message translates to:
  /// **'a Linux server or VPS you control'**
  String get onboardingSelfHostRequirementServer;

  /// No description provided for @onboardingSelfHostRequirementDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker compose v2'**
  String get onboardingSelfHostRequirementDocker;

  /// No description provided for @onboardingSelfHostRequirementAccess.
  ///
  /// In en, this message translates to:
  /// **'SSH access to the server'**
  String get onboardingSelfHostRequirementAccess;

  /// No description provided for @onboardingSelfHostActionGuide.
  ///
  /// In en, this message translates to:
  /// **'guide'**
  String get onboardingSelfHostActionGuide;

  /// No description provided for @onboardingSelfHostActionConnect.
  ///
  /// In en, this message translates to:
  /// **'connect'**
  String get onboardingSelfHostActionConnect;

  /// No description provided for @onboardingSignInPoco.
  ///
  /// In en, this message translates to:
  /// **'Welcome. We\'ll set up a server: a small computer that stays online and runs PocketCoder for you.\n\nStart by choosing the email and password you\'ll use to sign in when it\'s ready.'**
  String get onboardingSignInPoco;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'set up your sign-in'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingServerCredentialsPoco.
  ///
  /// In en, this message translates to:
  /// **'These are the administrator credentials for PocketCoder on the server we are about to provision.\n\nThey are separate from your Linode password. I will use them to finish setup, and you will use them to sign in to PocketCoder when the server is ready. Keep them safe.'**
  String get onboardingServerCredentialsPoco;

  /// No description provided for @onboardingPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters'**
  String get onboardingPasswordTooShort;

  /// No description provided for @onboardingProviderPoco.
  ///
  /// In en, this message translates to:
  /// **'Okay, here are our options for who will host your server.\n\nA server provider gives it a computer and internet connection, then keeps it online.'**
  String get onboardingProviderPoco;

  /// No description provided for @onboardingProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'choose a server provider'**
  String get onboardingProviderTitle;

  /// No description provided for @onboardingProviderChipLinode.
  ///
  /// In en, this message translates to:
  /// **'Linode'**
  String get onboardingProviderChipLinode;

  /// No description provided for @onboardingProviderChipElestioComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Elestio — coming soon'**
  String get onboardingProviderChipElestioComingSoon;

  /// No description provided for @onboardingTrialPoco.
  ///
  /// In en, this message translates to:
  /// **'Your server and AI accounts are yours, and each provider bills you directly. PocketCoder helps you connect and set everything up.\n\nPocketCoder Pro includes a {trialDuration}-day free trial. It lets you provision servers and receive notifications from your agents. When the trial ends, your server keeps running exactly as it is.\n\nYour server provider may offer its own trial or credit as well.'**
  String onboardingTrialPoco(int trialDuration);

  /// No description provided for @onboardingTrialChipStart.
  ///
  /// In en, this message translates to:
  /// **'start free trial'**
  String get onboardingTrialChipStart;

  /// No description provided for @onboardingTrialChipNotNow.
  ///
  /// In en, this message translates to:
  /// **'not now'**
  String get onboardingTrialChipNotNow;

  /// No description provided for @onboardingProviderAuthorizationPoco.
  ///
  /// In en, this message translates to:
  /// **'Connect or create your server provider account. The next page will let you sign in or make one.\n\nWhen you authorize PocketCoder, it will provision a server and deploy PocketCoder on your behalf.'**
  String get onboardingProviderAuthorizationPoco;

  /// No description provided for @onboardingProviderAuthorizationTitle.
  ///
  /// In en, this message translates to:
  /// **'connect your server provider'**
  String get onboardingProviderAuthorizationTitle;

  /// No description provided for @onboardingProviderAuthorizationAction.
  ///
  /// In en, this message translates to:
  /// **'continue'**
  String get onboardingProviderAuthorizationAction;

  /// No description provided for @onboardingProviderAuthorizationWaiting.
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get onboardingProviderAuthorizationWaiting;

  /// No description provided for @onboardingProviderAuthorizationError.
  ///
  /// In en, this message translates to:
  /// **'connection stopped'**
  String get onboardingProviderAuthorizationError;

  /// No description provided for @onboardingProviderAuthorizationCancelled.
  ///
  /// In en, this message translates to:
  /// **'The provider sign-in was cancelled. Nothing was provisioned.'**
  String get onboardingProviderAuthorizationCancelled;

  /// No description provided for @onboardingProviderAuthorizationFailed.
  ///
  /// In en, this message translates to:
  /// **'I could not connect to the server provider. Check your connection and try again.'**
  String get onboardingProviderAuthorizationFailed;

  /// No description provided for @onboardingIntentPoco.
  ///
  /// In en, this message translates to:
  /// **'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.'**
  String get onboardingIntentPoco;

  /// No description provided for @onboardingIntentChipCloudModels.
  ///
  /// In en, this message translates to:
  /// **'use cloud models'**
  String get onboardingIntentChipCloudModels;

  /// No description provided for @onboardingIntentChipLocalModels.
  ///
  /// In en, this message translates to:
  /// **'run a local model'**
  String get onboardingIntentChipLocalModels;

  /// No description provided for @onboardingPlanPoco.
  ///
  /// In en, this message translates to:
  /// **'Here are the server sizes available from {providerName}.\n\nThe highlighted option is the minimum I recommend for the setup you chose. You can select a larger server at any time.'**
  String onboardingPlanPoco(String providerName);

  /// No description provided for @onboardingPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your server size'**
  String get onboardingPlanTitle;

  /// No description provided for @onboardingRegionConsentPoco.
  ///
  /// In en, this message translates to:
  /// **'I can find server regions near you, if you want.\n\nYour location stays on this phone. I only use it to sort the available regions by distance.'**
  String get onboardingRegionConsentPoco;

  /// No description provided for @onboardingRegionConsentChipUseLocation.
  ///
  /// In en, this message translates to:
  /// **'use my location'**
  String get onboardingRegionConsentChipUseLocation;

  /// No description provided for @onboardingRegionConsentChipChooseMyself.
  ///
  /// In en, this message translates to:
  /// **'I\'ll choose myself'**
  String get onboardingRegionConsentChipChooseMyself;

  /// No description provided for @onboardingRegionPoco.
  ///
  /// In en, this message translates to:
  /// **'A region is the city where your server—and its data—will live. Choose one close to you, or to people who will use PocketCoder most.'**
  String get onboardingRegionPoco;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'choose your server region'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingHarnessPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose which coding agents to have ready on your server.\n\nA harness is the connection PocketCoder uses to work with a coding agent. This only installs the software; you\'ll connect any required accounts after your server is ready.'**
  String get onboardingHarnessPoco;

  /// No description provided for @onboardingHarnessTitle.
  ///
  /// In en, this message translates to:
  /// **'choose coding agents'**
  String get onboardingHarnessTitle;

  /// No description provided for @onboardingOsPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.'**
  String get onboardingOsPoco;

  /// No description provided for @onboardingOsTitle.
  ///
  /// In en, this message translates to:
  /// **'choose Linux system'**
  String get onboardingOsTitle;

  /// No description provided for @onboardingOsNixosLabel.
  ///
  /// In en, this message translates to:
  /// **'NixOS — recommended'**
  String get onboardingOsNixosLabel;

  /// No description provided for @onboardingOsNixosDescription.
  ///
  /// In en, this message translates to:
  /// **'Repeatable server setup, easier to recreate and roll back if a system change goes wrong. Estimated about {minutes} min.'**
  String onboardingOsNixosDescription(int minutes);

  /// No description provided for @onboardingOsDebianLabel.
  ///
  /// In en, this message translates to:
  /// **'Debian'**
  String get onboardingOsDebianLabel;

  /// No description provided for @onboardingOsDebianDescription.
  ///
  /// In en, this message translates to:
  /// **'Debian server configured with setup scripts. Faster to set up: about {minutes} min.'**
  String onboardingOsDebianDescription(int minutes);

  /// No description provided for @onboardingReviewPoco.
  ///
  /// In en, this message translates to:
  /// **'Your server is ready to be provisioned.\n\nPocketCoder will create it in your {providerName} account, then install the coding agents you selected. Your provider bills you directly.'**
  String onboardingReviewPoco(String providerName);

  /// No description provided for @onboardingReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'review your server'**
  String get onboardingReviewTitle;

  /// No description provided for @onboardingReviewActionProvision.
  ///
  /// In en, this message translates to:
  /// **'provision server'**
  String get onboardingReviewActionProvision;

  /// No description provided for @onboardingProvisioningPoco.
  ///
  /// In en, this message translates to:
  /// **'Provisioning is underway. While the new server comes online, welcome to PocketCoder Initiative orientation.\n\nI\'ll show you what we\'re building, one piece at a time.'**
  String get onboardingProvisioningPoco;

  /// No description provided for @onboardingOrientationTitle.
  ///
  /// In en, this message translates to:
  /// **'initiative orientation'**
  String get onboardingOrientationTitle;

  /// No description provided for @onboardingOrientationActionSkip.
  ///
  /// In en, this message translates to:
  /// **'skip orientation'**
  String get onboardingOrientationActionSkip;

  /// No description provided for @onboardingOrientationActionContinue.
  ///
  /// In en, this message translates to:
  /// **'continue orientation'**
  String get onboardingOrientationActionContinue;

  /// No description provided for @onboardingDockerIntroEyebrow.
  ///
  /// In en, this message translates to:
  /// **'introduction'**
  String get onboardingDockerIntroEyebrow;

  /// No description provided for @onboardingDockerIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Docker and containers'**
  String get onboardingDockerIntroTitle;

  /// No description provided for @onboardingDockerIntroPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder is made of software components, such as its dashboard and coding agents. Docker runs each component in its own separate container on your server.'**
  String get onboardingDockerIntroPoco;

  /// No description provided for @onboardingDockerIntroActionStart.
  ///
  /// In en, this message translates to:
  /// **'start walkthrough'**
  String get onboardingDockerIntroActionStart;

  /// No description provided for @onboardingDockerIntroChipComponent.
  ///
  /// In en, this message translates to:
  /// **'What is a component?'**
  String get onboardingDockerIntroChipComponent;

  /// No description provided for @onboardingDockerIntroChipContainer.
  ///
  /// In en, this message translates to:
  /// **'What is a container?'**
  String get onboardingDockerIntroChipContainer;

  /// No description provided for @onboardingDockerIntroChipSavedData.
  ///
  /// In en, this message translates to:
  /// **'What is saved data?'**
  String get onboardingDockerIntroChipSavedData;

  /// No description provided for @onboardingDockerIntroChipConnections.
  ///
  /// In en, this message translates to:
  /// **'What are connections?'**
  String get onboardingDockerIntroChipConnections;

  /// No description provided for @onboardingReadyPoco.
  ///
  /// In en, this message translates to:
  /// **'Your PocketCoder server is ready.\n\nWelcome to the PocketCoder Initiative, Commander.\n\nYour server is online at its new HTTPS address. Your selected coding harnesses are ready.'**
  String get onboardingReadyPoco;

  /// No description provided for @onboardingReadyActionLogin.
  ///
  /// In en, this message translates to:
  /// **'log in to PocketCoder'**
  String get onboardingReadyActionLogin;

  /// No description provided for @onboardingFailureConnectionPoco.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t confirm that PocketCoder finished setting up.\n\nYour server is still available in your {providerName} account.'**
  String onboardingFailureConnectionPoco(String providerName);

  /// No description provided for @onboardingFailureActionRetryConnection.
  ///
  /// In en, this message translates to:
  /// **'retry connection'**
  String get onboardingFailureActionRetryConnection;

  /// No description provided for @onboardingFailureActionViewServerDetails.
  ///
  /// In en, this message translates to:
  /// **'view server details'**
  String get onboardingFailureActionViewServerDetails;

  /// No description provided for @onboardingFailureCreatePoco.
  ///
  /// In en, this message translates to:
  /// **'The server could not be created.\n\nNothing was deployed. Check your server provider connection, then try again.'**
  String get onboardingFailureCreatePoco;

  /// No description provided for @onboardingFailureActionBackToSetup.
  ///
  /// In en, this message translates to:
  /// **'back to setup'**
  String get onboardingFailureActionBackToSetup;

  /// No description provided for @onboardingFailureActionTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'show technical details'**
  String get onboardingFailureActionTechnicalDetails;

  /// No description provided for @walkthroughHeader.
  ///
  /// In en, this message translates to:
  /// **'{os} server setup · walkthrough {current} / {total}'**
  String walkthroughHeader(String os, int current, int total);

  /// No description provided for @walkthroughProgress.
  ///
  /// In en, this message translates to:
  /// **'walkthrough {current}/{total} · brief {brief}'**
  String walkthroughProgress(int current, int total, String brief);

  /// No description provided for @walkthroughActionShowFullCode.
  ///
  /// In en, this message translates to:
  /// **'show full code'**
  String get walkthroughActionShowFullCode;

  /// No description provided for @walkthroughActionShowConciseCode.
  ///
  /// In en, this message translates to:
  /// **'show concise code'**
  String get walkthroughActionShowConciseCode;

  /// No description provided for @walkthroughCaddyAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'your HTTPS address'**
  String get walkthroughCaddyAddressTitle;

  /// No description provided for @walkthroughCaddyAddressPoco.
  ///
  /// In en, this message translates to:
  /// **'First, the server finds its public IP address and turns it into an HTTPS address using sslip.io. PocketCoder saves that address so the mobile app knows where to sign in.'**
  String get walkthroughCaddyAddressPoco;

  /// No description provided for @walkthroughCaddyAddressChipIpAddress.
  ///
  /// In en, this message translates to:
  /// **'What is an IP address?'**
  String get walkthroughCaddyAddressChipIpAddress;

  /// No description provided for @walkthroughCaddyAddressChipHttps.
  ///
  /// In en, this message translates to:
  /// **'What is HTTPS?'**
  String get walkthroughCaddyAddressChipHttps;

  /// No description provided for @walkthroughCaddyAddressChipSslip.
  ///
  /// In en, this message translates to:
  /// **'What is sslip.io?'**
  String get walkthroughCaddyAddressChipSslip;

  /// No description provided for @walkthroughCaddyWebEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'the secure web entry'**
  String get walkthroughCaddyWebEntryTitle;

  /// No description provided for @walkthroughCaddyWebEntryPoco.
  ///
  /// In en, this message translates to:
  /// **'Caddy runs directly on the server. It sends regular web traffic to HTTPS, shares PocketCoder\'s deployment status, and passes app requests to PocketBase without exposing PocketBase\'s own port.'**
  String get walkthroughCaddyWebEntryPoco;

  /// No description provided for @walkthroughCaddyWebEntryChipCaddy.
  ///
  /// In en, this message translates to:
  /// **'What is Caddy?'**
  String get walkthroughCaddyWebEntryChipCaddy;

  /// No description provided for @walkthroughCaddyWebEntryChipPrivatePort.
  ///
  /// In en, this message translates to:
  /// **'Why is PocketBase\'s port private?'**
  String get walkthroughCaddyWebEntryChipPrivatePort;

  /// No description provided for @walkthroughNixosStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'your server disk'**
  String get walkthroughNixosStorageTitle;

  /// No description provided for @walkthroughNixosStoragePoco.
  ///
  /// In en, this message translates to:
  /// **'This tells NixOS where PocketCoder\'s main disk is and lets it expand to use the full size of the server you chose. Without autoResize, it could stay stuck at the smaller size of its original image.'**
  String get walkthroughNixosStoragePoco;

  /// No description provided for @walkthroughNixosNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'network boundaries'**
  String get walkthroughNixosNetworkTitle;

  /// No description provided for @walkthroughNixosNetworkPoco.
  ///
  /// In en, this message translates to:
  /// **'These rules open the three standard entry ports to your server: HTTP and HTTPS for the PocketCoder website, and SSH for secure remote access. Since PocketCoder runs inside Docker, it needs its own specific rules without opening extra entry ports to the internet.'**
  String get walkthroughNixosNetworkPoco;

  /// No description provided for @walkthroughNixosNetworkChipPorts.
  ///
  /// In en, this message translates to:
  /// **'What are HTTP, HTTPS, and SSH?'**
  String get walkthroughNixosNetworkChipPorts;

  /// No description provided for @walkthroughNixosNetworkChipDockerRules.
  ///
  /// In en, this message translates to:
  /// **'Why does Docker need its own rules?'**
  String get walkthroughNixosNetworkChipDockerRules;

  /// No description provided for @walkthroughNixosNetworkChipIpVersions.
  ///
  /// In en, this message translates to:
  /// **'What are IPv4 and IPv6?'**
  String get walkthroughNixosNetworkChipIpVersions;

  /// No description provided for @walkthroughNixosSshTitle.
  ///
  /// In en, this message translates to:
  /// **'key-only SSH'**
  String get walkthroughNixosSshTitle;

  /// No description provided for @walkthroughNixosSshPoco.
  ///
  /// In en, this message translates to:
  /// **'SSH is the secure way to administer a server from another device—even a phone. We accept only your SSH key—not passwords—and temporarily block repeated failed attempts.'**
  String get walkthroughNixosSshPoco;

  /// No description provided for @walkthroughNixosDockerTitle.
  ///
  /// In en, this message translates to:
  /// **'Docker'**
  String get walkthroughNixosDockerTitle;

  /// No description provided for @walkthroughNixosDockerPoco.
  ///
  /// In en, this message translates to:
  /// **'This turns on Docker, the system that runs PocketCoder\'s containers. It sends their logs to NixOS\'s built-in system log, so there is one place to check what happened.'**
  String get walkthroughNixosDockerPoco;

  /// No description provided for @walkthroughServerKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'your server key'**
  String get walkthroughServerKeyTitle;

  /// No description provided for @walkthroughServerKeyPoco.
  ///
  /// In en, this message translates to:
  /// **'Before PocketCoder starts, this installs your public SSH key on the server. The mobile app keeps the matching private SSH key securely on your phone: the public key is the lock, and the private key is the key that opens it.'**
  String get walkthroughServerKeyPoco;

  /// No description provided for @walkthroughServerKeyChipPrivate.
  ///
  /// In en, this message translates to:
  /// **'What is a private SSH key?'**
  String get walkthroughServerKeyChipPrivate;

  /// No description provided for @walkthroughServerKeyChipPublic.
  ///
  /// In en, this message translates to:
  /// **'What is a public SSH key?'**
  String get walkthroughServerKeyChipPublic;

  /// No description provided for @walkthroughServerKeyChipSsh.
  ///
  /// In en, this message translates to:
  /// **'What is SSH?'**
  String get walkthroughServerKeyChipSsh;

  /// No description provided for @walkthroughVerifiedVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'verified PocketCoder version'**
  String get walkthroughVerifiedVersionTitle;

  /// No description provided for @walkthroughVerifiedVersionPoco.
  ///
  /// In en, this message translates to:
  /// **'This downloads the exact PocketCoder version for your server, verifies it, then installs it.'**
  String get walkthroughVerifiedVersionPoco;

  /// No description provided for @walkthroughVerifiedVersionChipVerification.
  ///
  /// In en, this message translates to:
  /// **'How is the version verified?'**
  String get walkthroughVerifiedVersionChipVerification;

  /// No description provided for @walkthroughVerifiedVersionChipDownloadFailure.
  ///
  /// In en, this message translates to:
  /// **'What happens if the download fails?'**
  String get walkthroughVerifiedVersionChipDownloadFailure;

  /// No description provided for @walkthroughVerifiedVersionChipUpdates.
  ///
  /// In en, this message translates to:
  /// **'Can I update later?'**
  String get walkthroughVerifiedVersionChipUpdates;

  /// No description provided for @walkthroughStartPocketCoderTitle.
  ///
  /// In en, this message translates to:
  /// **'start PocketCoder'**
  String get walkthroughStartPocketCoderTitle;

  /// No description provided for @walkthroughStartPocketCoderPoco.
  ///
  /// In en, this message translates to:
  /// **'This starts the verified PocketCoder version with only the coding harnesses you chose.'**
  String get walkthroughStartPocketCoderPoco;

  /// No description provided for @walkthroughStartPocketCoderChipWhatStarts.
  ///
  /// In en, this message translates to:
  /// **'What starts after this?'**
  String get walkthroughStartPocketCoderChipWhatStarts;

  /// No description provided for @walkthroughStartPocketCoderChipAddHarness.
  ///
  /// In en, this message translates to:
  /// **'Can I add a harness later?'**
  String get walkthroughStartPocketCoderChipAddHarness;

  /// No description provided for @walkthroughNixosDockerRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Docker firewall rules'**
  String get walkthroughNixosDockerRulesTitle;

  /// No description provided for @walkthroughNixosDockerRulesPoco.
  ///
  /// In en, this message translates to:
  /// **'Docker needs its own rules because it manages a separate path for container traffic. These rules keep the same boundaries without opening extra entry ports.'**
  String get walkthroughNixosDockerRulesPoco;

  /// No description provided for @walkthroughRuntimeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'local settings'**
  String get walkthroughRuntimeSettingsTitle;

  /// No description provided for @walkthroughRuntimeSettingsPoco.
  ///
  /// In en, this message translates to:
  /// **'This prepares PocketCoder\'s local settings file and locks it so only its administrator—you—can read it. It creates the internal credentials PocketCoder needs to run.'**
  String get walkthroughRuntimeSettingsPoco;

  /// No description provided for @walkthroughRuntimeSettingsChipLocalSettings.
  ///
  /// In en, this message translates to:
  /// **'What are local settings?'**
  String get walkthroughRuntimeSettingsChipLocalSettings;

  /// No description provided for @walkthroughRuntimeVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'running version'**
  String get walkthroughRuntimeVersionTitle;

  /// No description provided for @walkthroughRuntimeVersionPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder records the version it is running in the same protected settings file.'**
  String get walkthroughRuntimeVersionPoco;

  /// No description provided for @walkthroughActivationPrepareTitle.
  ///
  /// In en, this message translates to:
  /// **'prepare the release'**
  String get walkthroughActivationPrepareTitle;

  /// No description provided for @walkthroughActivationPreparePoco.
  ///
  /// In en, this message translates to:
  /// **'This checks that the release files match the verified PocketCoder version and prepares them for installation. It also sets up status reporting for the PocketCoder deployment.'**
  String get walkthroughActivationPreparePoco;

  /// No description provided for @walkthroughActivationSelectedSoftwareTitle.
  ///
  /// In en, this message translates to:
  /// **'selected software'**
  String get walkthroughActivationSelectedSoftwareTitle;

  /// No description provided for @walkthroughActivationSelectedSoftwarePoco.
  ///
  /// In en, this message translates to:
  /// **'Next, the server loads PocketCoder and only the coding agents you chose. It checks each software component before Docker runs it.'**
  String get walkthroughActivationSelectedSoftwarePoco;

  /// No description provided for @walkthroughActivationSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'make it active'**
  String get walkthroughActivationSwitchTitle;

  /// No description provided for @walkthroughActivationSwitchPoco.
  ///
  /// In en, this message translates to:
  /// **'This makes the new PocketCoder version active and starts its containers. It uses prebuilt software for faster setup and consistent versioning.'**
  String get walkthroughActivationSwitchPoco;

  /// No description provided for @walkthroughActivationHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'check the deployment'**
  String get walkthroughActivationHealthTitle;

  /// No description provided for @walkthroughActivationHealthPoco.
  ///
  /// In en, this message translates to:
  /// **'Before calling the deployment complete, PocketCoder checks that its core and optional services are healthy. Only then does it record this version as active.'**
  String get walkthroughActivationHealthPoco;

  /// No description provided for @walkthroughDebianSetupStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'setup status'**
  String get walkthroughDebianSetupStatusTitle;

  /// No description provided for @walkthroughDebianSetupStatusPoco.
  ///
  /// In en, this message translates to:
  /// **'This setup script keeps PocketCoder\'s deployment status up to date as it runs. If something fails, it records where and cleans up temporary files so it can be checked or safely retried.'**
  String get walkthroughDebianSetupStatusPoco;

  /// No description provided for @walkthroughDebianSetupStatusChipStatus.
  ///
  /// In en, this message translates to:
  /// **'How is deployment status shown?'**
  String get walkthroughDebianSetupStatusChipStatus;

  /// No description provided for @walkthroughDebianSetupStatusChipFailure.
  ///
  /// In en, this message translates to:
  /// **'What happens if setup fails?'**
  String get walkthroughDebianSetupStatusChipFailure;

  /// No description provided for @walkthroughServicesComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'the Docker blueprint'**
  String get walkthroughServicesComposeTitle;

  /// No description provided for @walkthroughServicesComposePoco.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose is PocketCoder\'s blueprint. It keeps your data when we update the software, and gives each component only the connections it needs.'**
  String get walkthroughServicesComposePoco;

  /// No description provided for @walkthroughServicesComposeChipDockerCompose.
  ///
  /// In en, this message translates to:
  /// **'What is Docker compose?'**
  String get walkthroughServicesComposeChipDockerCompose;

  /// No description provided for @walkthroughServicesComposeChipSavedData.
  ///
  /// In en, this message translates to:
  /// **'What is saved data?'**
  String get walkthroughServicesComposeChipSavedData;

  /// No description provided for @walkthroughServicesComposeChipPrivateConnections.
  ///
  /// In en, this message translates to:
  /// **'What are private connections?'**
  String get walkthroughServicesComposeChipPrivateConnections;

  /// No description provided for @walkthroughServicesPocketBaseTitle.
  ///
  /// In en, this message translates to:
  /// **'PocketBase'**
  String get walkthroughServicesPocketBaseTitle;

  /// No description provided for @walkthroughServicesPocketBasePoco.
  ///
  /// In en, this message translates to:
  /// **'PocketBase keeps the information PocketCoder needs to run: your sign-in, skills, prompts, agent connections, and API keys. That information stays on your server, and you reach it through the HTTPS address Caddy just set up.'**
  String get walkthroughServicesPocketBasePoco;

  /// No description provided for @walkthroughServicesPocketBaseChipKeeps.
  ///
  /// In en, this message translates to:
  /// **'What does PocketBase keep?'**
  String get walkthroughServicesPocketBaseChipKeeps;

  /// No description provided for @walkthroughServicesPocketBaseChipSignIn.
  ///
  /// In en, this message translates to:
  /// **'How do I sign in securely?'**
  String get walkthroughServicesPocketBaseChipSignIn;

  /// No description provided for @walkthroughServicesPocketBaseChipUpdates.
  ///
  /// In en, this message translates to:
  /// **'What happens when PocketCoder updates?'**
  String get walkthroughServicesPocketBaseChipUpdates;

  /// No description provided for @walkthroughServicesHarnessesTitle.
  ///
  /// In en, this message translates to:
  /// **'coding harnesses'**
  String get walkthroughServicesHarnessesTitle;

  /// No description provided for @walkthroughServicesHarnessesPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder prepares the coding harnesses you selected: {selectedHarnesses}. Each gets its own container, saved workspace, and only the private connections it needs.'**
  String walkthroughServicesHarnessesPoco(String selectedHarnesses);

  /// No description provided for @walkthroughServicesHarnessesChipHarness.
  ///
  /// In en, this message translates to:
  /// **'What is a coding harness?'**
  String get walkthroughServicesHarnessesChipHarness;

  /// No description provided for @walkthroughServicesHarnessesChipWorkspace.
  ///
  /// In en, this message translates to:
  /// **'What is a saved workspace?'**
  String get walkthroughServicesHarnessesChipWorkspace;

  /// No description provided for @walkthroughServicesHarnessesChipAdd.
  ///
  /// In en, this message translates to:
  /// **'Can I add a harness later?'**
  String get walkthroughServicesHarnessesChipAdd;

  /// No description provided for @walkthroughServicesToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'tool connections'**
  String get walkthroughServicesToolsTitle;

  /// No description provided for @walkthroughServicesToolsPoco.
  ///
  /// In en, this message translates to:
  /// **'The MCP Gateway is a controlled connection point for extra tools your coding harnesses can use. Its separate Docker proxy grants only the permissions those tools need, while blocking more sensitive actions such as accessing saved data or secrets.'**
  String get walkthroughServicesToolsPoco;

  /// No description provided for @walkthroughServicesToolsChipMcp.
  ///
  /// In en, this message translates to:
  /// **'What is MCP?'**
  String get walkthroughServicesToolsChipMcp;

  /// No description provided for @walkthroughServicesToolsChipHarnessTools.
  ///
  /// In en, this message translates to:
  /// **'What tools can a harness use?'**
  String get walkthroughServicesToolsChipHarnessTools;

  /// No description provided for @walkthroughServicesToolsChipProxy.
  ///
  /// In en, this message translates to:
  /// **'Why does this have a separate proxy?'**
  String get walkthroughServicesToolsChipProxy;

  /// No description provided for @walkthroughServicesOllamaTitle.
  ///
  /// In en, this message translates to:
  /// **'local models'**
  String get walkthroughServicesOllamaTitle;

  /// No description provided for @walkthroughServicesOllamaPoco.
  ///
  /// In en, this message translates to:
  /// **'Ollama is ready to run AI models directly on your server. It appears because you chose a local-model setup; when you later choose a model, PocketCoder downloads it and keeps it as saved data.'**
  String get walkthroughServicesOllamaPoco;

  /// No description provided for @walkthroughServicesOllamaChipLocalModel.
  ///
  /// In en, this message translates to:
  /// **'What is a local model?'**
  String get walkthroughServicesOllamaChipLocalModel;

  /// No description provided for @walkthroughServicesOllamaChipDownload.
  ///
  /// In en, this message translates to:
  /// **'When is a model downloaded?'**
  String get walkthroughServicesOllamaChipDownload;

  /// No description provided for @walkthroughServicesOllamaChipGpu.
  ///
  /// In en, this message translates to:
  /// **'Does this use my server\'s GPU?'**
  String get walkthroughServicesOllamaChipGpu;

  /// No description provided for @walkthroughServicesSqlPageTitle.
  ///
  /// In en, this message translates to:
  /// **'server dashboard'**
  String get walkthroughServicesSqlPageTitle;

  /// No description provided for @walkthroughServicesSqlPagePoco.
  ///
  /// In en, this message translates to:
  /// **'SQLPage is PocketCoder\'s built-in dashboard for showing what is happening on your server. It starts after PocketBase is ready and uses saved PocketCoder data to build those pages.'**
  String get walkthroughServicesSqlPagePoco;

  /// No description provided for @walkthroughServicesSqlPageChipContents.
  ///
  /// In en, this message translates to:
  /// **'What can this dashboard show?'**
  String get walkthroughServicesSqlPageChipContents;

  /// No description provided for @walkthroughServicesSqlPageChipStartOrder.
  ///
  /// In en, this message translates to:
  /// **'Why does it start after PocketBase?'**
  String get walkthroughServicesSqlPageChipStartOrder;

  /// No description provided for @permissionRequestedFallback.
  ///
  /// In en, this message translates to:
  /// **'Permission requested'**
  String get permissionRequestedFallback;

  /// No description provided for @permissionRequestingLabel.
  ///
  /// In en, this message translates to:
  /// **'{source} is requesting permission:'**
  String permissionRequestingLabel(String source);

  /// No description provided for @permissionPatternsLabel.
  ///
  /// In en, this message translates to:
  /// **'Patterns:'**
  String get permissionPatternsLabel;

  /// No description provided for @questionIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'incoming query'**
  String get questionIncomingTitle;

  /// No description provided for @questionPocoAsking.
  ///
  /// In en, this message translates to:
  /// **'Poco is asking:'**
  String get questionPocoAsking;

  /// No description provided for @questionSendReply.
  ///
  /// In en, this message translates to:
  /// **'send reply'**
  String get questionSendReply;

  /// No description provided for @thoughtsWaiting.
  ///
  /// In en, this message translates to:
  /// **'[neural link active. waiting for thoughts...]'**
  String get thoughtsWaiting;

  /// No description provided for @notificationSignalReceived.
  ///
  /// In en, this message translates to:
  /// **'signal received: {title}'**
  String notificationSignalReceived(String title);

  /// No description provided for @errorsTitle.
  ///
  /// In en, this message translates to:
  /// **'error reports'**
  String get errorsTitle;

  /// No description provided for @errorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'no errors captured'**
  String get errorsEmpty;

  /// No description provided for @errorsCopy.
  ///
  /// In en, this message translates to:
  /// **'copy report'**
  String get errorsCopy;

  /// No description provided for @errorsReportOnGithub.
  ///
  /// In en, this message translates to:
  /// **'report on GitHub'**
  String get errorsReportOnGithub;

  /// No description provided for @errorsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'copy all'**
  String get errorsCopyAll;

  /// No description provided for @errorsCopied.
  ///
  /// In en, this message translates to:
  /// **'diagnostic report copied'**
  String get errorsCopied;

  /// No description provided for @errorsClearAll.
  ///
  /// In en, this message translates to:
  /// **'clear all'**
  String get errorsClearAll;

  /// No description provided for @harnessAuthChallengeTargetCopied.
  ///
  /// In en, this message translates to:
  /// **'challenge target copied'**
  String get harnessAuthChallengeTargetCopied;

  /// No description provided for @harnessAuthCopy.
  ///
  /// In en, this message translates to:
  /// **'[copy]'**
  String get harnessAuthCopy;

  /// No description provided for @harnessAuthChallengeDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'code copied'**
  String get harnessAuthChallengeDetailsCopied;

  /// No description provided for @harnessAuthLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading harnesses'**
  String get harnessAuthLoading;

  /// No description provided for @harnessAuthConnections.
  ///
  /// In en, this message translates to:
  /// **'Harness connections'**
  String get harnessAuthConnections;

  /// No description provided for @harnessAuthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Claude Code and Codex are not available on this server.'**
  String get harnessAuthUnavailable;

  /// No description provided for @harnessAuthEmpty.
  ///
  /// In en, this message translates to:
  /// **'No harnesses were found.'**
  String get harnessAuthEmpty;

  /// No description provided for @harnessAuthStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String harnessAuthStatus(String status);

  /// No description provided for @harnessAuthMode.
  ///
  /// In en, this message translates to:
  /// **'Mode: {mode}'**
  String harnessAuthMode(String mode);

  /// No description provided for @harnessAuthAccount.
  ///
  /// In en, this message translates to:
  /// **'Account: {account} ({visibility})'**
  String harnessAuthAccount(String account, String visibility);

  /// No description provided for @harnessAuthApiKeyConfigured.
  ///
  /// In en, this message translates to:
  /// **'API key: {provider}'**
  String harnessAuthApiKeyConfigured(String provider);

  /// No description provided for @harnessAuthShared.
  ///
  /// In en, this message translates to:
  /// **'shared'**
  String get harnessAuthShared;

  /// No description provided for @harnessAuthPersonal.
  ///
  /// In en, this message translates to:
  /// **'personal'**
  String get harnessAuthPersonal;

  /// No description provided for @harnessAuthOneTimeCode.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get harnessAuthOneTimeCode;

  /// No description provided for @harnessAuthPasteCode.
  ///
  /// In en, this message translates to:
  /// **'paste code'**
  String get harnessAuthPasteCode;

  /// No description provided for @harnessAuthSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get harnessAuthSubmit;

  /// No description provided for @harnessAuthRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get harnessAuthRefresh;

  /// No description provided for @harnessAuthAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt: {id}'**
  String harnessAuthAttempt(String id);

  /// No description provided for @harnessAuthAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Account login'**
  String get harnessAuthAccountLogin;

  /// No description provided for @harnessAuthApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get harnessAuthApiKey;

  /// No description provided for @harnessAuthDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get harnessAuthDisconnect;

  /// No description provided for @harnessAuthCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get harnessAuthCancel;

  /// No description provided for @harnessAuthNoApiKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'No API key'**
  String get harnessAuthNoApiKeyTitle;

  /// No description provided for @harnessAuthNoApiKeyBody.
  ///
  /// In en, this message translates to:
  /// **'No matching provider key exists for this harness. Open the LLM management screen to add a provider key first.'**
  String get harnessAuthNoApiKeyBody;

  /// No description provided for @harnessAuthProviderKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'No provider key found for {harness}.'**
  String harnessAuthProviderKeyMissing(String harness);

  /// No description provided for @harnessAuthChooseProviderKey.
  ///
  /// In en, this message translates to:
  /// **'Choose provider key'**
  String get harnessAuthChooseProviderKey;

  /// No description provided for @harnessAuthVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Who uses this harness account?'**
  String get harnessAuthVisibilityTitle;

  /// No description provided for @harnessAuthVisibilityBody.
  ///
  /// In en, this message translates to:
  /// **'A shared account reuses one login across profiles on this PocketCoder server. A personal account keeps a separate login.'**
  String get harnessAuthVisibilityBody;

  /// No description provided for @harnessAuthChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get harnessAuthChallenge;

  /// No description provided for @harnessAuthDetails.
  ///
  /// In en, this message translates to:
  /// **'Details: {details}'**
  String harnessAuthDetails(String details);

  /// No description provided for @credentialConnectionApiKey.
  ///
  /// In en, this message translates to:
  /// **'Connect with an API key.'**
  String get credentialConnectionApiKey;

  /// No description provided for @credentialConnectionCopy.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get credentialConnectionCopy;

  /// No description provided for @credentialConnectionOpenAuthorizationPage.
  ///
  /// In en, this message translates to:
  /// **'open authorization page'**
  String get credentialConnectionOpenAuthorizationPage;

  /// No description provided for @credentialConnectionPasteCode.
  ///
  /// In en, this message translates to:
  /// **'Paste this code on the authorization page.'**
  String get credentialConnectionPasteCode;

  /// No description provided for @credentialConnectionEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on the authorization page.'**
  String get credentialConnectionEnterCode;

  /// No description provided for @credentialConnectionSubmit.
  ///
  /// In en, this message translates to:
  /// **'submit'**
  String get credentialConnectionSubmit;

  /// No description provided for @credentialConnectionCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get credentialConnectionCancel;

  /// No description provided for @credentialConnectionRetry.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get credentialConnectionRetry;

  /// No description provided for @credentialConnectionOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the authorization page. Please try again.'**
  String get credentialConnectionOpenFailed;

  /// No description provided for @credentialConnectionExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires at {expiresAt}'**
  String credentialConnectionExpiresAt(DateTime expiresAt);

  /// No description provided for @agentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'mode:'**
  String get agentModeLabel;

  /// No description provided for @agentConfigLabel.
  ///
  /// In en, this message translates to:
  /// **'config'**
  String get agentConfigLabel;

  /// No description provided for @pocketCoderUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'\$ Checking verified release status...'**
  String get pocketCoderUpdateChecking;

  /// No description provided for @pocketCoderUpdateCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'check again'**
  String get pocketCoderUpdateCheckAgain;

  /// No description provided for @pocketCoderUpdateNoDeployment.
  ///
  /// In en, this message translates to:
  /// **'No deployment found on this device.'**
  String get pocketCoderUpdateNoDeployment;

  /// No description provided for @actionDismiss.
  ///
  /// In en, this message translates to:
  /// **'dismiss'**
  String get actionDismiss;

  /// No description provided for @pocketCoderUpdateWorking.
  ///
  /// In en, this message translates to:
  /// **'Upgrading...'**
  String get pocketCoderUpdateWorking;

  /// No description provided for @pocketCoderUpdateUpgrade.
  ///
  /// In en, this message translates to:
  /// **'upgrade PocketCoder'**
  String get pocketCoderUpdateUpgrade;

  /// No description provided for @pocketCoderUpdateCommand.
  ///
  /// In en, this message translates to:
  /// **'pocketcoder-release update'**
  String get pocketCoderUpdateCommand;

  /// No description provided for @pocketCoderUpdateOutput.
  ///
  /// In en, this message translates to:
  /// **'output'**
  String get pocketCoderUpdateOutput;

  /// No description provided for @pocketCoderUpdateStderr.
  ///
  /// In en, this message translates to:
  /// **'--- stderr ---'**
  String get pocketCoderUpdateStderr;

  /// No description provided for @pocketCoderUpdateSucceeded.
  ///
  /// In en, this message translates to:
  /// **'update succeeded (exit 0)'**
  String get pocketCoderUpdateSucceeded;

  /// No description provided for @pocketCoderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'update failed (exit {exitCode})'**
  String pocketCoderUpdateFailed(int exitCode);

  /// No description provided for @pocketCoderUpdateReviewDataChange.
  ///
  /// In en, this message translates to:
  /// **'review data change'**
  String get pocketCoderUpdateReviewDataChange;

  /// No description provided for @pocketCoderUpdateConfirmUpgrade.
  ///
  /// In en, this message translates to:
  /// **'confirm upgrade'**
  String get pocketCoderUpdateConfirmUpgrade;

  /// No description provided for @pocketCoderUpdateCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get pocketCoderUpdateCurrent;

  /// No description provided for @pocketCoderUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get pocketCoderUpdateAvailable;

  /// No description provided for @pocketCoderUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'download'**
  String get pocketCoderUpdateDownload;

  /// No description provided for @pocketCoderUpdateRequiredDisk.
  ///
  /// In en, this message translates to:
  /// **'required disk'**
  String get pocketCoderUpdateRequiredDisk;

  /// No description provided for @pocketCoderUpdateCurrentStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ PocketCoder is current'**
  String get pocketCoderUpdateCurrentStatus;

  /// No description provided for @pocketCoderUpdateAvailableStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ update available'**
  String get pocketCoderUpdateAvailableStatus;

  /// No description provided for @pocketCoderUpdateCriticalStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ critical release warning'**
  String get pocketCoderUpdateCriticalStatus;

  /// No description provided for @pocketCoderUpdateUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ release status unknown'**
  String get pocketCoderUpdateUnknownStatus;

  /// No description provided for @pocketCoderUpdateRollbackWarning.
  ///
  /// In en, this message translates to:
  /// **'After success, normal rollback is unavailable. Restoring the pre-upgrade snapshot would discard data created afterward.'**
  String get pocketCoderUpdateRollbackWarning;

  /// No description provided for @pocketCoderUpdateDataBoundary.
  ///
  /// In en, this message translates to:
  /// **'data version {currentVersion} → {availableVersion}'**
  String pocketCoderUpdateDataBoundary(
      int currentVersion, int availableVersion);

  /// No description provided for @errorsOccurred.
  ///
  /// In en, this message translates to:
  /// **'Occurred {count}x'**
  String errorsOccurred(int count);

  /// No description provided for @errorsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get errorsDeleteAction;

  /// Label for the reset deployment state action on the config screen recovery section
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get deploymentResetAction;

  /// Title of the reset confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Reset local deployment state?'**
  String get deploymentResetConfirmationTitle;

  /// Body of the reset confirmation dialog explaining local-only scope
  ///
  /// In en, this message translates to:
  /// **'This clears local deployment state only: the saved session, instance id, and credentials stored on this device. It does NOT delete your cloud server.'**
  String get deploymentResetConfirmationBody;

  /// Cloud-unaffected warning in the reset confirmation
  ///
  /// In en, this message translates to:
  /// **'Your cloud instance is unaffected. Use your provider console to inspect or delete it.'**
  String get deploymentResetConfirmationWarnCloud;

  /// Optional checkbox label to also clear OAuth credentials during reset
  ///
  /// In en, this message translates to:
  /// **'Also sign out of the cloud provider (clear OAuth tokens)'**
  String get deploymentResetAlsoClearOAuth;

  /// Confirm button label on the reset dialog
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get deploymentResetConfirm;

  /// Cancel button label on the reset dialog
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get deploymentResetCancel;

  /// Snack/banner shown after a successful reset
  ///
  /// In en, this message translates to:
  /// **'Local deployment state cleared.'**
  String get deploymentResetComplete;

  /// Label for manually disconnecting the current managed instance
  ///
  /// In en, this message translates to:
  /// **'disconnect'**
  String get deploymentDisconnectAction;

  /// Title of the disconnect confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Disconnect this instance?'**
  String get deploymentDisconnectConfirmationTitle;

  /// Body of the disconnect confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This clears the saved session and local deployment state so you can connect to another instance. It does not delete your cloud server.'**
  String get deploymentDisconnectConfirmationBody;

  /// Confirm button label on the disconnect dialog
  ///
  /// In en, this message translates to:
  /// **'disconnect'**
  String get deploymentDisconnectConfirm;

  /// Cancel button label on the disconnect dialog
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get deploymentDisconnectCancel;

  /// Title of the screen shown when the app can't reach the server and can't confirm with the cloud provider whether the instance still exists
  ///
  /// In en, this message translates to:
  /// **'Can\'t verify your deployment'**
  String get instanceVerificationTitle;

  /// Body text explaining why the instance-verification screen is showing
  ///
  /// In en, this message translates to:
  /// **'PocketCoder couldn\'t reach your server, and couldn\'t confirm with your cloud provider whether the instance still exists.'**
  String get instanceVerificationBody;

  /// Shown after a retry via Linode still couldn't get a definitive answer
  ///
  /// In en, this message translates to:
  /// **'Still couldn\'t confirm. Try again, or choose an option below.'**
  String get instanceVerificationCheckFailedMessage;

  /// Button label to sign in to (or re-verify via) the cloud provider and retry the existence check
  ///
  /// In en, this message translates to:
  /// **'check via {provider}'**
  String instanceVerificationCheckAction(String provider);

  /// Button label for the destructive option that clears local deployment state
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get instanceVerificationResetAction;

  /// Title of the confirmation dialog for the destructive reset option
  ///
  /// In en, this message translates to:
  /// **'Reset and start over?'**
  String get instanceVerificationResetConfirmationTitle;

  /// Body of the reset confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This clears the saved session and local deployment state on this device. It does not delete your cloud server.'**
  String get instanceVerificationResetConfirmationBody;

  /// Confirm button label on the reset confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get instanceVerificationResetConfirm;

  /// Cancel button label on the reset confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get instanceVerificationResetCancel;

  /// Title for the screen shown when a cloud provider confirms the deployed instance was deleted.
  ///
  /// In en, this message translates to:
  /// **'Instance no longer exists'**
  String get instanceGoneTitle;

  /// Body copy for the instance-gone screen.
  ///
  /// In en, this message translates to:
  /// **'The provider confirms this deployment\'s server no longer exists. The only way forward is to reset local state and set up a new deployment.'**
  String get instanceGoneBody;

  /// Label for the destructive reset button on the instance-gone screen.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get instanceGoneResetAction;

  /// Confirm-dialog title before clearing local state on the instance-gone screen.
  ///
  /// In en, this message translates to:
  /// **'Reset local deployment state?'**
  String get instanceGoneResetConfirmationTitle;

  /// Confirm-dialog body before clearing local state on the instance-gone screen.
  ///
  /// In en, this message translates to:
  /// **'This clears all local deployment state on this device. The instance is already gone on the provider side, so nothing further will be deleted remotely.'**
  String get instanceGoneResetConfirmationBody;

  /// Cancel label for the instance-gone reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get instanceGoneResetCancel;

  /// Confirm label for the instance-gone reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get instanceGoneResetConfirm;

  /// Title of the confirmation dialog for discarding a stuck local deployment record
  ///
  /// In en, this message translates to:
  /// **'Discard this deployment record?'**
  String get deploymentDiscardAttemptTitle;

  /// Body copy explaining what discarding a stuck deployment record does and does not do
  ///
  /// In en, this message translates to:
  /// **'PocketCoder still has a record of a provider resource from a previous attempt. Discarding this record does NOT delete anything in your provider account -- it only clears PocketCoder\'s own bookkeeping, so a new deployment can start.'**
  String get deploymentDiscardAttemptBody;

  /// Shows the provider resource id the app has on file, so the user can look it up themselves
  ///
  /// In en, this message translates to:
  /// **'Recorded resource: {resourceId}'**
  String deploymentDiscardAttemptResourceId(String resourceId);

  /// Link that opens the cloud provider's own dashboard so the user can verify the resource
  ///
  /// In en, this message translates to:
  /// **'Open provider dashboard to check'**
  String get deploymentDiscardAttemptCheckLink;

  /// Checkbox the user must tick before the discard confirmation button enables
  ///
  /// In en, this message translates to:
  /// **'I checked and this won\'t create a duplicate charge'**
  String get deploymentDiscardAttemptConfirmCheckbox;

  /// Cancel button on the discard-stale-attempt confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get deploymentDiscardAttemptCancel;

  /// Confirm button on the discard-stale-attempt confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'discard'**
  String get deploymentDiscardAttemptConfirm;

  /// Cleanup outcome shown when the cloud server was deleted successfully
  ///
  /// In en, this message translates to:
  /// **'Cloud server deleted.'**
  String get deploymentCleanupSucceeded;

  /// Cleanup outcome shown when deleting the cloud server failed
  ///
  /// In en, this message translates to:
  /// **'Could not delete the cloud server. Use your provider console to remove it.'**
  String get deploymentCleanupFailed;

  /// Cleanup outcome shown when cleanup is pending manual action
  ///
  /// In en, this message translates to:
  /// **'Cleanup could not run automatically. Use your provider console to remove the cloud server.'**
  String get deploymentCleanupPending;

  /// Cleanup outcome shown when no cloud server needed cleanup
  ///
  /// In en, this message translates to:
  /// **'No cloud server to clean up.'**
  String get deploymentCleanupNotNeeded;

  /// No description provided for @serverControlTitle.
  ///
  /// In en, this message translates to:
  /// **'server controls'**
  String get serverControlTitle;

  /// No description provided for @serverControlConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'connection details'**
  String get serverControlConnectionDetails;

  /// No description provided for @serverControlIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get serverControlIpAddress;

  /// No description provided for @serverControlHttpsEndpoint.
  ///
  /// In en, this message translates to:
  /// **'HTTPS endpoint'**
  String get serverControlHttpsEndpoint;

  /// No description provided for @serverControlAdminIdentity.
  ///
  /// In en, this message translates to:
  /// **'admin identity'**
  String get serverControlAdminIdentity;

  /// No description provided for @serverControlAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'admin password'**
  String get serverControlAdminPassword;

  /// No description provided for @serverControlShow.
  ///
  /// In en, this message translates to:
  /// **'show'**
  String get serverControlShow;

  /// No description provided for @serverControlHide.
  ///
  /// In en, this message translates to:
  /// **'hide'**
  String get serverControlHide;

  /// No description provided for @serverControlLocalAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to reveal this credential'**
  String get serverControlLocalAuthReason;

  /// No description provided for @serverControlCopy.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get serverControlCopy;

  /// No description provided for @serverControlCopied.
  ///
  /// In en, this message translates to:
  /// **'copied'**
  String get serverControlCopied;

  /// No description provided for @serverControlConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'confirm server control'**
  String get serverControlConfirmTitle;

  /// No description provided for @serverControlConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{operation} will run on your server.'**
  String serverControlConfirmBody(String operation);

  /// No description provided for @serverControlConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get serverControlConfirmCancel;

  /// No description provided for @serverControlConfirmConfirm.
  ///
  /// In en, this message translates to:
  /// **'confirm'**
  String get serverControlConfirmConfirm;

  /// No description provided for @serverControlConfirmRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get serverControlConfirmRestoreTitle;

  /// No description provided for @serverControlConfirmRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This overwrites all current data on your server with the last saved backup. This cannot be undone.'**
  String get serverControlConfirmRestoreBody;

  /// No description provided for @serverControlReleaseChecking.
  ///
  /// In en, this message translates to:
  /// **'release status: checking'**
  String get serverControlReleaseChecking;

  /// No description provided for @serverControlReleaseStatus.
  ///
  /// In en, this message translates to:
  /// **'release status: {status}'**
  String serverControlReleaseStatus(String status);

  /// No description provided for @serverControlReleaseCurrent.
  ///
  /// In en, this message translates to:
  /// **'current: {version}'**
  String serverControlReleaseCurrent(String version);

  /// No description provided for @serverControlReleaseAvailable.
  ///
  /// In en, this message translates to:
  /// **'available: {version}'**
  String serverControlReleaseAvailable(String version);

  /// No description provided for @serverControlReleaseContracts.
  ///
  /// In en, this message translates to:
  /// **'contracts: app v{app} · server v{server} · deployment v{deployment}'**
  String serverControlReleaseContracts(
      String app, String server, String deployment);

  /// No description provided for @serverControlReleaseNixos.
  ///
  /// In en, this message translates to:
  /// **'NixOS: {version}'**
  String serverControlReleaseNixos(String version);

  /// No description provided for @serverControlOperationRestartPocketCoder.
  ///
  /// In en, this message translates to:
  /// **'Restart PocketCoder'**
  String get serverControlOperationRestartPocketCoder;

  /// No description provided for @serverControlOperationUpdatePocketCoder.
  ///
  /// In en, this message translates to:
  /// **'Update PocketCoder'**
  String get serverControlOperationUpdatePocketCoder;

  /// No description provided for @serverControlOperationRestartNixOs.
  ///
  /// In en, this message translates to:
  /// **'Restart NixOS'**
  String get serverControlOperationRestartNixOs;

  /// No description provided for @serverControlOperationUpdateNixOs.
  ///
  /// In en, this message translates to:
  /// **'Update NixOS'**
  String get serverControlOperationUpdateNixOs;

  /// No description provided for @serverControlOperationSaveBackup.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get serverControlOperationSaveBackup;

  /// No description provided for @serverControlOperationRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get serverControlOperationRestoreBackup;

  /// No description provided for @serverControlActionRestart.
  ///
  /// In en, this message translates to:
  /// **'restart'**
  String get serverControlActionRestart;

  /// No description provided for @serverControlActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'update'**
  String get serverControlActionUpdate;

  /// No description provided for @serverControlActionSave.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get serverControlActionSave;

  /// No description provided for @serverControlActionRestore.
  ///
  /// In en, this message translates to:
  /// **'restore'**
  String get serverControlActionRestore;

  /// No description provided for @serverControlGroupPocketCoder.
  ///
  /// In en, this message translates to:
  /// **'app'**
  String get serverControlGroupPocketCoder;

  /// No description provided for @serverControlGroupNixOs.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get serverControlGroupNixOs;

  /// No description provided for @serverControlGroupData.
  ///
  /// In en, this message translates to:
  /// **'data'**
  String get serverControlGroupData;

  /// No description provided for @serverControlPublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'SSH public key on file'**
  String get serverControlPublicKeyLabel;

  /// No description provided for @serverControlPrivateKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'SSH private key'**
  String get serverControlPrivateKeyLabel;

  /// No description provided for @serverControlProviderConsole.
  ///
  /// In en, this message translates to:
  /// **'provider web portal'**
  String get serverControlProviderConsole;

  /// No description provided for @serverControlProviderConsoleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No active provider-managed instance found.'**
  String get serverControlProviderConsoleUnavailable;

  /// No description provided for @serverControlErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String serverControlErrorPrefix(String error);

  /// No description provided for @serverControlRetryAction.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get serverControlRetryAction;

  /// No description provided for @serverControlOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'output'**
  String get serverControlOutputLabel;

  /// No description provided for @fossServerSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'connect your server'**
  String get fossServerSetupTitle;

  /// No description provided for @fossServerSetupIntro.
  ///
  /// In en, this message translates to:
  /// **'Generate a key, add it to your VPS, then verify the connection.'**
  String get fossServerSetupIntro;

  /// No description provided for @fossServerSetupGenerateKey.
  ///
  /// In en, this message translates to:
  /// **'generate key'**
  String get fossServerSetupGenerateKey;

  /// No description provided for @fossServerSetupPublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC KEY -- add this to /root/.ssh/authorized_keys on your VPS'**
  String get fossServerSetupPublicKeyLabel;

  /// No description provided for @fossServerSetupHostLabel.
  ///
  /// In en, this message translates to:
  /// **'This will connect to:'**
  String get fossServerSetupHostLabel;

  /// No description provided for @fossServerSetupTestAndSave.
  ///
  /// In en, this message translates to:
  /// **'test connection & save'**
  String get fossServerSetupTestAndSave;

  /// No description provided for @fossServerSetupConnected.
  ///
  /// In en, this message translates to:
  /// **'connected -- your server is now managed'**
  String get fossServerSetupConnected;

  /// No description provided for @fossServerSetupErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {error}'**
  String fossServerSetupErrorPrefix(String error);

  /// No description provided for @initializationInstanceId.
  ///
  /// In en, this message translates to:
  /// **'instance ID'**
  String get initializationInstanceId;

  /// No description provided for @initializationRetryAttempt.
  ///
  /// In en, this message translates to:
  /// **'retry attempt'**
  String get initializationRetryAttempt;

  /// No description provided for @memoryDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'pocket memory'**
  String get memoryDashboardTitle;

  /// No description provided for @memoryDashboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'memory unavailable'**
  String get memoryDashboardUnavailable;

  /// No description provided for @memoryDashboardObservations.
  ///
  /// In en, this message translates to:
  /// **'observations'**
  String get memoryDashboardObservations;

  /// No description provided for @memoryDashboardInterpretations.
  ///
  /// In en, this message translates to:
  /// **'interpretations'**
  String get memoryDashboardInterpretations;

  /// No description provided for @memoryDashboardLinks.
  ///
  /// In en, this message translates to:
  /// **'links'**
  String get memoryDashboardLinks;

  /// No description provided for @memoryDashboardByAccount.
  ///
  /// In en, this message translates to:
  /// **'Memory by Account'**
  String get memoryDashboardByAccount;

  /// No description provided for @memoryDashboardNoMemoryRecorded.
  ///
  /// In en, this message translates to:
  /// **'No memory recorded yet'**
  String get memoryDashboardNoMemoryRecorded;

  /// No description provided for @memoryDashboardRecentObservations.
  ///
  /// In en, this message translates to:
  /// **'Recent Observations'**
  String get memoryDashboardRecentObservations;

  /// No description provided for @memoryDashboardNoObservationsYet.
  ///
  /// In en, this message translates to:
  /// **'No observations yet'**
  String get memoryDashboardNoObservationsYet;

  /// No description provided for @memoryDashboardRecentInterpretations.
  ///
  /// In en, this message translates to:
  /// **'Recent Interpretations'**
  String get memoryDashboardRecentInterpretations;

  /// No description provided for @memoryDashboardNoInterpretationsYet.
  ///
  /// In en, this message translates to:
  /// **'No interpretations yet'**
  String get memoryDashboardNoInterpretationsYet;

  /// No description provided for @memoryDashboardAccountSummary.
  ///
  /// In en, this message translates to:
  /// **'{observations} obs / {interpretations} int'**
  String memoryDashboardAccountSummary(int observations, int interpretations);

  /// No description provided for @memoryDashboardLinkedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Linked: {links}'**
  String memoryDashboardLinkedPrefix(String links);

  /// No description provided for @pocketbaseInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'PocketBase'**
  String get pocketbaseInspectorTitle;

  /// No description provided for @pocketbaseInspectorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'database unavailable'**
  String get pocketbaseInspectorUnavailable;

  /// No description provided for @pocketbaseInspectorUsers.
  ///
  /// In en, this message translates to:
  /// **'users'**
  String get pocketbaseInspectorUsers;

  /// No description provided for @pocketbaseInspectorChats.
  ///
  /// In en, this message translates to:
  /// **'chats'**
  String get pocketbaseInspectorChats;

  /// No description provided for @pocketbaseInspectorAgentProfiles.
  ///
  /// In en, this message translates to:
  /// **'agent profiles'**
  String get pocketbaseInspectorAgentProfiles;

  /// No description provided for @pocketbaseInspectorHarnesses.
  ///
  /// In en, this message translates to:
  /// **'harnesses'**
  String get pocketbaseInspectorHarnesses;

  /// No description provided for @pocketbaseInspectorMcpServers.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get pocketbaseInspectorMcpServers;

  /// No description provided for @pocketbaseInspectorSkills.
  ///
  /// In en, this message translates to:
  /// **'skills'**
  String get pocketbaseInspectorSkills;

  /// No description provided for @pocketbaseInspectorRecentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent Chats'**
  String get pocketbaseInspectorRecentChats;

  /// No description provided for @pocketbaseInspectorNoChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get pocketbaseInspectorNoChatsYet;

  /// No description provided for @pocketbaseInspectorChatArchivedTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (archived)'**
  String pocketbaseInspectorChatArchivedTitle(String title);
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
