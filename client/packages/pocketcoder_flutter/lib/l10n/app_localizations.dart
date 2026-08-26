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
  /// **'NEXT'**
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

  /// No description provided for @externalAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'EXTERNAL AUTHENTICATION'**
  String get externalAuthTitle;

  /// No description provided for @externalAuthConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {label}...'**
  String externalAuthConnecting(String label);

  /// No description provided for @externalAuthRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get externalAuthRetry;

  /// No description provided for @externalAuthCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get externalAuthCancel;

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
  /// **'CONNECT'**
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
  /// **'ARE YOU ALREADY PART OF THE POCKETCODER INITIATIVE?'**
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
  /// **'Could not open a new chat. Please try again.'**
  String get onboardingOpenChatFailed;

  /// No description provided for @onboardingServerCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'SERVER CREDENTIALS'**
  String get onboardingServerCredentialsTitle;

  /// No description provided for @onboardingPocketbaseAdminEmail.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER ADMIN EMAIL'**
  String get onboardingPocketbaseAdminEmail;

  /// No description provided for @onboardingPocketbaseAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER ADMIN PASSWORD'**
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
  /// **'NEW'**
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
  /// **'ARCHIVE'**
  String get chatListArchive;

  /// No description provided for @chatListDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get chatListDelete;

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

  /// No description provided for @chatCommandOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get chatCommandOutput;

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

  /// No description provided for @chatRunOutcomeInterruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'RUN INTERRUPTED'**
  String get chatRunOutcomeInterruptedTitle;

  /// No description provided for @chatRunOutcomeInterruptedBody.
  ///
  /// In en, this message translates to:
  /// **'The connection ended before the run finished.'**
  String get chatRunOutcomeInterruptedBody;

  /// No description provided for @chatRunOutcomeCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'RUN STOPPED'**
  String get chatRunOutcomeCancelledTitle;

  /// No description provided for @chatRunOutcomeCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The run was stopped.'**
  String get chatRunOutcomeCancelledBody;

  /// No description provided for @chatRunOutcomeFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'RUN FAILED'**
  String get chatRunOutcomeFailedTitle;

  /// No description provided for @chatRunOutcomeFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while running this request.'**
  String get chatRunOutcomeFailedBody;

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

  /// No description provided for @mcpAddNew.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW'**
  String get mcpAddNew;

  /// No description provided for @mcpDeny.
  ///
  /// In en, this message translates to:
  /// **'DENY'**
  String get mcpDeny;

  /// No description provided for @mcpAuthorize.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZE'**
  String get mcpAuthorize;

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

  /// No description provided for @notificationSettingsPoco.
  ///
  /// In en, this message translates to:
  /// **'I can notify you when an agent needs approval or finishes a task, even when PocketCoder is not open. Your phone will ask for permission before I enable alerts on this device.'**
  String get notificationSettingsPoco;

  /// No description provided for @notificationSettingsEnableDevice.
  ///
  /// In en, this message translates to:
  /// **'ENABLE ON THIS DEVICE'**
  String get notificationSettingsEnableDevice;

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

  /// No description provided for @monitorTelemetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TELEMETRY UNAVAILABLE'**
  String get monitorTelemetryUnavailable;

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

  /// No description provided for @observabilitySelectContainer.
  ///
  /// In en, this message translates to:
  /// **'>> SELECT CONTAINER FOR LOG STREAM'**
  String get observabilitySelectContainer;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER PRO'**
  String get proTitle;

  /// No description provided for @proPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK ALL SYSTEMS'**
  String get proPlanTitle;

  /// No description provided for @proCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'CHECKING PRO STATUS...'**
  String get proCheckingStatus;

  /// No description provided for @proUnlockCommand.
  ///
  /// In en, this message translates to:
  /// **'\$ unlock --all'**
  String get proUnlockCommand;

  /// No description provided for @proSummary.
  ///
  /// In en, this message translates to:
  /// **'ONE SUBSCRIPTION. EVERY POCKETCODER PRO CAPABILITY.'**
  String get proSummary;

  /// No description provided for @proFeatureReady.
  ///
  /// In en, this message translates to:
  /// **'[OK]'**
  String get proFeatureReady;

  /// No description provided for @proFeatureDeploy.
  ///
  /// In en, this message translates to:
  /// **'PROVISION AND DEPLOY POCKETCODER SERVERS'**
  String get proFeatureDeploy;

  /// No description provided for @proFeaturePush.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE HOSTED AGENT NOTIFICATIONS'**
  String get proFeaturePush;

  /// No description provided for @proFeatureConsole.
  ///
  /// In en, this message translates to:
  /// **'USE PRO CONSOLE CONTROLS AS THEY SHIP'**
  String get proFeatureConsole;

  /// No description provided for @proTrialDuration.
  ///
  /// In en, this message translates to:
  /// **'{days} DAYS FREE'**
  String proTrialDuration(int days);

  /// No description provided for @proTrialNoPaymentInfo.
  ///
  /// In en, this message translates to:
  /// **'STARTS A FREE WEEK. NO PAYMENT INFO IS COLLECTED NOW.'**
  String get proTrialNoPaymentInfo;

  /// No description provided for @proTrialLapseExplainer.
  ///
  /// In en, this message translates to:
  /// **'IF YOU DO NOT KEEP PRO, ONLY HOSTED PUSH NOTIFICATIONS STOP. YOUR SERVER KEEPS RUNNING.'**
  String get proTrialLapseExplainer;

  /// No description provided for @proPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}'**
  String proPrice(String price);

  /// No description provided for @proPriceAfterTrial.
  ///
  /// In en, this message translates to:
  /// **'THEN {price}'**
  String proPriceAfterTrial(String price);

  /// No description provided for @proPricePerWeek.
  ///
  /// In en, this message translates to:
  /// **'{price} / WEEK'**
  String proPricePerWeek(String price);

  /// No description provided for @proPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / MONTH'**
  String proPricePerMonth(String price);

  /// No description provided for @proPricePerYear.
  ///
  /// In en, this message translates to:
  /// **'{price} / YEAR'**
  String proPricePerYear(String price);

  /// No description provided for @proStartTrial.
  ///
  /// In en, this message translates to:
  /// **'START {days}-DAY FREE TRIAL'**
  String proStartTrial(int days);

  /// No description provided for @proSubscribe.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK POCKETCODER PRO'**
  String get proSubscribe;

  /// No description provided for @proRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE PURCHASES'**
  String get proRestore;

  /// No description provided for @proNotNow.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get proNotNow;

  /// No description provided for @proTerms.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTION RENEWS AT {price} UNTIL CANCELLED. MANAGE OR CANCEL IN YOUR APP STORE ACCOUNT.'**
  String proTerms(String price);

  /// No description provided for @proTrialTerms.
  ///
  /// In en, this message translates to:
  /// **'FREE FOR {days} DAYS, THEN {price} UNTIL CANCELLED. MANAGE OR CANCEL IN YOUR APP STORE ACCOUNT.'**
  String proTrialTerms(int days, String price);

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'> ENTITLEMENT: ACTIVE'**
  String get proActive;

  /// No description provided for @proActiveBody.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER PRO IS ACTIVE. DEPLOYMENT AND HOSTED NOTIFICATIONS ARE UNLOCKED.'**
  String get proActiveBody;

  /// No description provided for @proUnavailable.
  ///
  /// In en, this message translates to:
  /// **'> OFFERING: UNAVAILABLE'**
  String get proUnavailable;

  /// No description provided for @proUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'THE APP STORE COULD NOT RETURN THE POCKETCODER PRO SUBSCRIPTION. CHECK YOUR CONNECTION OR RESTORE AN EXISTING PURCHASE.'**
  String get proUnavailableBody;

  /// No description provided for @proSelfHostedPushTitle.
  ///
  /// In en, this message translates to:
  /// **'SELF-HOSTED NOTIFICATIONS'**
  String get proSelfHostedPushTitle;

  /// No description provided for @proSelfHostedPushBody.
  ///
  /// In en, this message translates to:
  /// **'YOU CAN CONNECT YOUR OWN NTFY OR UNIFIEDPUSH DISTRIBUTOR WITHOUT POCKETCODER PRO.'**
  String get proSelfHostedPushBody;

  /// No description provided for @proConfigureSelfHostedPush.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE SELF-HOSTED PUSH'**
  String get proConfigureSelfHostedPush;

  /// No description provided for @proSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER PRO'**
  String get proSettingsLabel;

  /// No description provided for @proSettingsStatus.
  ///
  /// In en, this message translates to:
  /// **'[STATUS]'**
  String get proSettingsStatus;

  /// No description provided for @chooseProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE PROVIDER'**
  String get chooseProviderTitle;

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

  /// No description provided for @chooseProviderProBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get chooseProviderProBadge;

  /// No description provided for @chooseProviderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get chooseProviderComingSoon;

  /// No description provided for @pocketCoderProgressProvisionServer.
  ///
  /// In en, this message translates to:
  /// **'PROVISION SERVER'**
  String get pocketCoderProgressProvisionServer;

  /// No description provided for @pocketCoderProgressDeployPocketCoder.
  ///
  /// In en, this message translates to:
  /// **'DEPLOY POCKETCODER'**
  String get pocketCoderProgressDeployPocketCoder;

  /// No description provided for @pocketCoderProgressWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get pocketCoderProgressWaiting;

  /// No description provided for @pocketCoderProgressActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get pocketCoderProgressActive;

  /// No description provided for @pocketCoderProgressComplete.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get pocketCoderProgressComplete;

  /// No description provided for @pocketCoderProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get pocketCoderProgressFailed;

  /// No description provided for @pocketCoderProgressInitializing.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZING'**
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
  /// **'INITIALIZING SERVER'**
  String get initializationScreenTitle;

  /// No description provided for @initializationActionAbort.
  ///
  /// In en, this message translates to:
  /// **'ABORT'**
  String get initializationActionAbort;

  /// No description provided for @initializationActionRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get initializationActionRetry;

  /// No description provided for @initializationUnknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get initializationUnknown;

  /// No description provided for @initializationTechnicalDetailsToggle.
  ///
  /// In en, this message translates to:
  /// **'TECHNICAL DETAILS'**
  String get initializationTechnicalDetailsToggle;

  /// No description provided for @initializationNetworkIp.
  ///
  /// In en, this message translates to:
  /// **'NETWORK IP'**
  String get initializationNetworkIp;

  /// No description provided for @initializationGeoGrid.
  ///
  /// In en, this message translates to:
  /// **'GEO GRID'**
  String get initializationGeoGrid;

  /// No description provided for @initializationFaultDetected.
  ///
  /// In en, this message translates to:
  /// **'FAULT DETECTED: {error}'**
  String initializationFaultDetected(Object error);

  /// No description provided for @initializationFaultGeneric.
  ///
  /// In en, this message translates to:
  /// **'SETUP COULD NOT CONTINUE. RETURN AND TRY AGAIN.'**
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
  /// **'SETUP COULD NOT CONTINUE. RETURN AND TRY AGAIN.'**
  String get initializationFailed;

  /// No description provided for @initializationReady.
  ///
  /// In en, this message translates to:
  /// **'SERVER READY AT {ipAddress}.'**
  String initializationReady(Object ipAddress);

  /// No description provided for @initializationInProgress.
  ///
  /// In en, this message translates to:
  /// **'SERVER SETUP STARTED.'**
  String get initializationInProgress;

  /// No description provided for @deploymentStatusValidating.
  ///
  /// In en, this message translates to:
  /// **'VALIDATING CONFIGURATION'**
  String get deploymentStatusValidating;

  /// No description provided for @deploymentStatusConstructing.
  ///
  /// In en, this message translates to:
  /// **'CONSTRUCTING INSTANCE'**
  String get deploymentStatusConstructing;

  /// No description provided for @deploymentStatusPreparingOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'PREPARING OS'**
  String get deploymentStatusPreparingOperatingSystem;

  /// No description provided for @deploymentStatusSecuring.
  ///
  /// In en, this message translates to:
  /// **'SECURING CONNECTION'**
  String get deploymentStatusSecuring;

  /// No description provided for @deploymentStatusTlsReady.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION SECURED'**
  String get deploymentStatusTlsReady;

  /// No description provided for @deploymentStatusTlsZeroSsl.
  ///
  /// In en, this message translates to:
  /// **'USING BACKUP CERTIFICATE AUTHORITY'**
  String get deploymentStatusTlsZeroSsl;

  /// No description provided for @deploymentStatusTlsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'CERTIFICATE AUTHORITY RATE LIMITED'**
  String get deploymentStatusTlsRateLimited;

  /// No description provided for @deploymentStatusTlsFailed.
  ///
  /// In en, this message translates to:
  /// **'CERTIFICATE ISSUANCE FAILED'**
  String get deploymentStatusTlsFailed;

  /// No description provided for @deploymentStatusConfiguringOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURING OS'**
  String get deploymentStatusConfiguringOperatingSystem;

  /// No description provided for @deploymentStatusFetching.
  ///
  /// In en, this message translates to:
  /// **'FETCHING RELEASE'**
  String get deploymentStatusFetching;

  /// No description provided for @deploymentStatusLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'LOADING IMAGES'**
  String get deploymentStatusLoadingImages;

  /// No description provided for @deploymentStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'STARTING SERVICES'**
  String get deploymentStatusStarting;

  /// No description provided for @deploymentStatusFinishing.
  ///
  /// In en, this message translates to:
  /// **'FINISHING UP'**
  String get deploymentStatusFinishing;

  /// No description provided for @deploymentStatusReady.
  ///
  /// In en, this message translates to:
  /// **'HANDSHAKE SUCCESSFUL'**
  String get deploymentStatusReady;

  /// No description provided for @deploymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'DEPLOYMENT ABORTED'**
  String get deploymentStatusFailed;

  /// No description provided for @initializationStatusInitializing.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZING STACK'**
  String get initializationStatusInitializing;

  /// No description provided for @deploymentDescriptionValidating.
  ///
  /// In en, this message translates to:
  /// **'CHECKING THE PROVISIONING CONFIGURATION.'**
  String get deploymentDescriptionValidating;

  /// No description provided for @deploymentDescriptionConstructing.
  ///
  /// In en, this message translates to:
  /// **'ALLOCATING HARDWARE RESOURCES ON CLOUD GRID.'**
  String get deploymentDescriptionConstructing;

  /// No description provided for @deploymentDescriptionPreparingOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'PREPARING THE OPERATING SYSTEM.'**
  String get deploymentDescriptionPreparingOperatingSystem;

  /// No description provided for @deploymentDescriptionSecuring.
  ///
  /// In en, this message translates to:
  /// **'WAITING FOR THE NATIVE REVERSE PROXY.'**
  String get deploymentDescriptionSecuring;

  /// No description provided for @deploymentDescriptionTlsReady.
  ///
  /// In en, this message translates to:
  /// **'A BROWSER-TRUSTED CERTIFICATE IS ACTIVE.'**
  String get deploymentDescriptionTlsReady;

  /// No description provided for @deploymentDescriptionTlsZeroSsl.
  ///
  /// In en, this message translates to:
  /// **'ISSUED VIA THE BACKUP AUTHORITY AFTER THE PRIMARY WAS UNAVAILABLE.'**
  String get deploymentDescriptionTlsZeroSsl;

  /// No description provided for @deploymentDescriptionTlsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'RETRYING AUTOMATICALLY WITH A BACKUP CERTIFICATE AUTHORITY.'**
  String get deploymentDescriptionTlsRateLimited;

  /// No description provided for @deploymentDescriptionTlsFailed.
  ///
  /// In en, this message translates to:
  /// **'THE REVERSE PROXY COULD NOT OBTAIN A CERTIFICATE.'**
  String get deploymentDescriptionTlsFailed;

  /// No description provided for @deploymentDescriptionConfiguringOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'PREPARING NATIVE SERVICES AND DEPENDENCIES.'**
  String get deploymentDescriptionConfiguringOperatingSystem;

  /// No description provided for @deploymentDescriptionFetching.
  ///
  /// In en, this message translates to:
  /// **'FETCHING THE IMMUTABLE RELEASE.'**
  String get deploymentDescriptionFetching;

  /// No description provided for @deploymentDescriptionLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'LOADING THE VERIFIED IMAGE BUNDLE.'**
  String get deploymentDescriptionLoadingImages;

  /// No description provided for @deploymentDescriptionStarting.
  ///
  /// In en, this message translates to:
  /// **'STARTING APPLICATION SERVICES.'**
  String get deploymentDescriptionStarting;

  /// No description provided for @deploymentDescriptionFinishing.
  ///
  /// In en, this message translates to:
  /// **'FINISHING DEPLOYMENT.'**
  String get deploymentDescriptionFinishing;

  /// No description provided for @deploymentDescriptionReady.
  ///
  /// In en, this message translates to:
  /// **'THE SERVER IS FULLY OPERATIONAL.'**
  String get deploymentDescriptionReady;

  /// No description provided for @deploymentDescriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'SETUP STOPPED BEFORE COMPLETION. NO LATER STEP WILL CONTINUE.'**
  String get deploymentDescriptionFailed;

  /// No description provided for @initializationDescriptionInitializing.
  ///
  /// In en, this message translates to:
  /// **'PREPARING INITIALIZATION MANIFEST.'**
  String get initializationDescriptionInitializing;

  /// No description provided for @initializationStatusPrefix.
  ///
  /// In en, this message translates to:
  /// **'STATUS: {status}'**
  String initializationStatusPrefix(Object status);

  /// No description provided for @initializationSecure.
  ///
  /// In en, this message translates to:
  /// **'[SECURE]'**
  String get initializationSecure;

  /// No description provided for @initializationConnectionParameters.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION PARAMETERS'**
  String get initializationConnectionParameters;

  /// No description provided for @initializationMetadataRegistry.
  ///
  /// In en, this message translates to:
  /// **'METADATA REGISTRY'**
  String get initializationMetadataRegistry;

  /// No description provided for @initializationActionLogin.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get initializationActionLogin;

  /// No description provided for @deploymentActionRefresh.
  ///
  /// In en, this message translates to:
  /// **'REFRESH'**
  String get deploymentActionRefresh;

  /// No description provided for @deploymentActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get deploymentActionUpdate;

  /// No description provided for @deploymentActionDismiss.
  ///
  /// In en, this message translates to:
  /// **'DISMISS'**
  String get deploymentActionDismiss;

  /// No description provided for @initializationInstanceManifest.
  ///
  /// In en, this message translates to:
  /// **'INSTANCE MANIFEST'**
  String get initializationInstanceManifest;

  /// No description provided for @initializationIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP ADDRESS'**
  String get initializationIpAddress;

  /// No description provided for @initializationHttpsEndpoint.
  ///
  /// In en, this message translates to:
  /// **'HTTPS ENDPOINT'**
  String get initializationHttpsEndpoint;

  /// No description provided for @initializationAdminIdentity.
  ///
  /// In en, this message translates to:
  /// **'ADMIN IDENTITY'**
  String get initializationAdminIdentity;

  /// No description provided for @initializationAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'ADMIN PASSWORD'**
  String get initializationAdminPassword;

  /// No description provided for @deploymentProvisioned.
  ///
  /// In en, this message translates to:
  /// **'PROVISIONED'**
  String get deploymentProvisioned;

  /// No description provided for @initializationCloudRegion.
  ///
  /// In en, this message translates to:
  /// **'CLOUD REGION'**
  String get initializationCloudRegion;

  /// No description provided for @initializationHardwarePlan.
  ///
  /// In en, this message translates to:
  /// **'HARDWARE PLAN'**
  String get initializationHardwarePlan;

  /// No description provided for @initializationSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'SECURITY NOTICE: CREDENTIALS ARE STORED IN LOCAL SECURE ENCLAVE. PASSPHRASE RETAINS ENCRYPTION AT REST.'**
  String get initializationSecurityNotice;

  /// No description provided for @initializationCopiedToBuffer.
  ///
  /// In en, this message translates to:
  /// **'{label} COPIED TO BUFFER'**
  String initializationCopiedToBuffer(Object label);

  /// No description provided for @initializationCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'COPY {label}'**
  String initializationCopyLabel(Object label);

  /// No description provided for @deploymentManifestConfiguration.
  ///
  /// In en, this message translates to:
  /// **'MANIFEST CONFIGURATION'**
  String get deploymentManifestConfiguration;

  /// No description provided for @deploymentActionBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get deploymentActionBack;

  /// No description provided for @deploymentActionDeployInstance.
  ///
  /// In en, this message translates to:
  /// **'DEPLOY INSTANCE'**
  String get deploymentActionDeployInstance;

  /// No description provided for @deploymentActionInitialize.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZE'**
  String get deploymentActionInitialize;

  /// No description provided for @deploymentSystemParameters.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM PARAMETERS'**
  String get deploymentSystemParameters;

  /// No description provided for @deploymentHardwareGeography.
  ///
  /// In en, this message translates to:
  /// **'HARDWARE & GEOGRAPHY'**
  String get deploymentHardwareGeography;

  /// No description provided for @deploymentInitializingHardware.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZING HW REGISTRY...'**
  String get deploymentInitializingHardware;

  /// No description provided for @deploymentScanningRegions.
  ///
  /// In en, this message translates to:
  /// **'SCANNING GLOBAL REGIONS...'**
  String get deploymentScanningRegions;

  /// No description provided for @deploymentCodingHarnesses.
  ///
  /// In en, this message translates to:
  /// **'CODING HARNESSES'**
  String get deploymentCodingHarnesses;

  /// No description provided for @deploymentHarnessSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what is downloaded onto your VPS. Goose is ready by default; you can select more than one.'**
  String get deploymentHarnessSelectionDescription;

  /// No description provided for @deploymentOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'OPERATING SYSTEM'**
  String get deploymentOperatingSystem;

  /// No description provided for @deploymentInstancePlan.
  ///
  /// In en, this message translates to:
  /// **'INSTANCE PLAN'**
  String get deploymentInstancePlan;

  /// No description provided for @deploymentMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}/MO'**
  String deploymentMonthlyPrice(String price);

  /// No description provided for @deploymentRegion.
  ///
  /// In en, this message translates to:
  /// **'DEPLOYMENT REGION'**
  String get deploymentRegion;

  /// No description provided for @deploymentBackend.
  ///
  /// In en, this message translates to:
  /// **'BACKEND'**
  String get deploymentBackend;

  /// No description provided for @deploymentDistribution.
  ///
  /// In en, this message translates to:
  /// **'DISTRIBUTION'**
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
  /// **'CHOOSE YOUR SETUP'**
  String get deploymentSetupTypeTitle;

  /// No description provided for @deploymentServerSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR SERVER SIZE'**
  String get deploymentServerSizeTitle;

  /// No description provided for @deploymentServerRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR SERVER REGION'**
  String get deploymentServerRegionTitle;

  /// No description provided for @deploymentCodingAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE CODING AGENTS'**
  String get deploymentCodingAgentsTitle;

  /// No description provided for @deploymentLinuxSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE LINUX SYSTEM'**
  String get deploymentLinuxSystemTitle;

  /// No description provided for @deploymentReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'REVIEW YOUR SERVER'**
  String get deploymentReviewTitle;

  /// No description provided for @deploymentWorkloadPoco.
  ///
  /// In en, this message translates to:
  /// **'Before we choose your server, what kind of PocketCoder setup are you planning?\n\nA cloud model runs through an online AI account. A local model runs on your own server.'**
  String get deploymentWorkloadPoco;

  /// No description provided for @deploymentWorkloadCloudReply.
  ///
  /// In en, this message translates to:
  /// **'Cloud models run inference through your online AI account. Your server mainly needs room for PocketCoder, your agents, and your projects.\n\nI’ll show the minimum server size I recommend. You can choose a larger one.'**
  String get deploymentWorkloadCloudReply;

  /// No description provided for @deploymentWorkloadLocalReply.
  ///
  /// In en, this message translates to:
  /// **'A local model runs on your own server through Ollama. It needs more computing power, and is usually faster with a GPU.\n\nI’ll show the minimum server size I recommend. You can choose a larger one.'**
  String get deploymentWorkloadLocalReply;

  /// No description provided for @deploymentUseCloudModels.
  ///
  /// In en, this message translates to:
  /// **'USE CLOUD MODELS'**
  String get deploymentUseCloudModels;

  /// No description provided for @deploymentRunLocalModel.
  ///
  /// In en, this message translates to:
  /// **'RUN A LOCAL MODEL'**
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
  /// **'Now choose which coding agents to have ready on your server.\n\nThis installs their software. You’ll connect any required accounts after your server is ready.'**
  String get deploymentHarnessPoco;

  /// No description provided for @deploymentLinuxPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.'**
  String get deploymentLinuxPoco;

  /// No description provided for @deploymentReviewPoco.
  ///
  /// In en, this message translates to:
  /// **'Your server is ready to be provisioned.\n\nPocketCoder will create it in your Linode account, then install the coding agents you selected. Linode will bill you directly for the server.'**
  String get deploymentReviewPoco;

  /// No description provided for @deploymentNoSuitablePlans.
  ///
  /// In en, this message translates to:
  /// **'NO SUITABLE SERVER SIZES ARE AVAILABLE FOR THIS SETUP.'**
  String get deploymentNoSuitablePlans;

  /// No description provided for @deploymentMinimum.
  ///
  /// In en, this message translates to:
  /// **'MINIMUM'**
  String get deploymentMinimum;

  /// No description provided for @deploymentRecommended.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get deploymentRecommended;

  /// No description provided for @deploymentGpuBadge.
  ///
  /// In en, this message translates to:
  /// **'GPU'**
  String get deploymentGpuBadge;

  /// No description provided for @deploymentDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'READY BY DEFAULT'**
  String get deploymentDefaultAgent;

  /// No description provided for @deploymentPlanSpecs.
  ///
  /// In en, this message translates to:
  /// **'{vcpus} CPU · {memory} RAM · {diskGb} GB DISK'**
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
  /// **'PROVISIONING SUMMARY'**
  String get deploymentProvisioningSummary;

  /// No description provided for @deploymentServerProvider.
  ///
  /// In en, this message translates to:
  /// **'SERVER PROVIDER'**
  String get deploymentServerProvider;

  /// No description provided for @deploymentProviderLinode.
  ///
  /// In en, this message translates to:
  /// **'LINODE'**
  String get deploymentProviderLinode;

  /// No description provided for @walkthroughLabel.
  ///
  /// In en, this message translates to:
  /// **'WALKTHROUGH {current} / {total}'**
  String walkthroughLabel(int current, int total);

  /// No description provided for @briefLabel.
  ///
  /// In en, this message translates to:
  /// **'BRIEF {current} / {total}'**
  String briefLabel(int current, int total);

  /// No description provided for @walkthroughAskPoco.
  ///
  /// In en, this message translates to:
  /// **'ASK POCO'**
  String get walkthroughAskPoco;

  /// No description provided for @walkthroughActionSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get walkthroughActionSkip;

  /// No description provided for @walkthroughBriefDivider.
  ///
  /// In en, this message translates to:
  /// **'BRIEF'**
  String get walkthroughBriefDivider;

  /// No description provided for @walkthroughTransitionProvisioning.
  ///
  /// In en, this message translates to:
  /// **'Let’s follow this next part of the server setup together.'**
  String get walkthroughTransitionProvisioning;

  /// No description provided for @walkthroughTransitionDeployment.
  ///
  /// In en, this message translates to:
  /// **'Now we’ll follow the verified release onto the host.'**
  String get walkthroughTransitionDeployment;

  /// No description provided for @initializationSyncAttempt.
  ///
  /// In en, this message translates to:
  /// **'SYNC ATTEMPT: {attempt}'**
  String initializationSyncAttempt(Object attempt);

  /// No description provided for @initializationCurrentOperation.
  ///
  /// In en, this message translates to:
  /// **'CURRENT OPERATION'**
  String get initializationCurrentOperation;

  /// No description provided for @initializationSourceCommit.
  ///
  /// In en, this message translates to:
  /// **'SOURCE COMMIT'**
  String get initializationSourceCommit;

  /// No description provided for @initializationRunId.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZATION RUN'**
  String get initializationRunId;

  /// No description provided for @initializationStatusSchema.
  ///
  /// In en, this message translates to:
  /// **'STATUS SCHEMA'**
  String get initializationStatusSchema;

  /// No description provided for @initializationLastSignal.
  ///
  /// In en, this message translates to:
  /// **'LAST SERVER SIGNAL'**
  String get initializationLastSignal;

  /// No description provided for @initializationErrorCode.
  ///
  /// In en, this message translates to:
  /// **'SERVER ERROR CODE'**
  String get initializationErrorCode;

  /// No description provided for @pocoProvisioningTourTitle.
  ///
  /// In en, this message translates to:
  /// **'POCO WALKTHROUGH'**
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
  /// **'SHOW FULL SNIPPET'**
  String get pocoProvisioningShowFull;

  /// No description provided for @pocoProvisioningShowConcise.
  ///
  /// In en, this message translates to:
  /// **'SHOW PREVIEW'**
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
  /// **'YES — CONNECT ME'**
  String get onboardingNoServerChipExisting;

  /// No description provided for @onboardingNoServerChipNew.
  ///
  /// In en, this message translates to:
  /// **'NO — I’D LIKE TO JOIN'**
  String get onboardingNoServerChipNew;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'WELCOME'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomePoco.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the PocketCoder Initiative.\n\nI’ll help you set up PocketCoder on a server—a computer that stays online. That way, PocketCoder is accessible and ready whenever you need it.'**
  String get onboardingWelcomePoco;

  /// No description provided for @onboardingWelcomeActionGuided.
  ///
  /// In en, this message translates to:
  /// **'HELP ME WITH SETUP'**
  String get onboardingWelcomeActionGuided;

  /// No description provided for @onboardingWelcomeActionSelfHost.
  ///
  /// In en, this message translates to:
  /// **'I’LL SET IT UP'**
  String get onboardingWelcomeActionSelfHost;

  /// No description provided for @onboardingSelfHostTitle.
  ///
  /// In en, this message translates to:
  /// **'SELF-HOST SETUP'**
  String get onboardingSelfHostTitle;

  /// No description provided for @onboardingSelfHostPoco.
  ///
  /// In en, this message translates to:
  /// **'You’ll set up PocketCoder on a server you control. The setup guide walks through preparing the server, deploying PocketCoder, and finding the address you’ll use to connect this app.'**
  String get onboardingSelfHostPoco;

  /// No description provided for @onboardingSelfHostRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU’LL NEED'**
  String get onboardingSelfHostRequirementsTitle;

  /// No description provided for @onboardingSelfHostRequirementServer.
  ///
  /// In en, this message translates to:
  /// **'A LINUX SERVER OR VPS YOU CONTROL'**
  String get onboardingSelfHostRequirementServer;

  /// No description provided for @onboardingSelfHostRequirementDocker.
  ///
  /// In en, this message translates to:
  /// **'DOCKER COMPOSE V2'**
  String get onboardingSelfHostRequirementDocker;

  /// No description provided for @onboardingSelfHostRequirementAccess.
  ///
  /// In en, this message translates to:
  /// **'SSH ACCESS TO THE SERVER'**
  String get onboardingSelfHostRequirementAccess;

  /// No description provided for @onboardingSelfHostActionGuide.
  ///
  /// In en, this message translates to:
  /// **'GUIDE'**
  String get onboardingSelfHostActionGuide;

  /// No description provided for @onboardingSelfHostActionConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get onboardingSelfHostActionConnect;

  /// No description provided for @onboardingSignInPoco.
  ///
  /// In en, this message translates to:
  /// **'Welcome. We’ll set up a server: a small computer that stays online and runs PocketCoder for you.\n\nStart by choosing the email and password you’ll use to sign in when it’s ready.'**
  String get onboardingSignInPoco;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'SET UP YOUR SIGN-IN'**
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
  /// **'CHOOSE A SERVER PROVIDER'**
  String get onboardingProviderTitle;

  /// No description provided for @onboardingProviderChipLinode.
  ///
  /// In en, this message translates to:
  /// **'LINODE'**
  String get onboardingProviderChipLinode;

  /// No description provided for @onboardingProviderChipElestioComingSoon.
  ///
  /// In en, this message translates to:
  /// **'ELESTIO — COMING SOON'**
  String get onboardingProviderChipElestioComingSoon;

  /// No description provided for @onboardingTrialPoco.
  ///
  /// In en, this message translates to:
  /// **'Your server and AI accounts are yours, and each provider bills you directly. PocketCoder helps you connect and set everything up.\n\nPocketCoder Pro includes a {trialDuration}-day free trial. It lets you provision servers and receive notifications from your agents. When the trial ends, your server keeps running exactly as it is.\n\nYour server provider may offer its own trial or credit as well.'**
  String onboardingTrialPoco(int trialDuration);

  /// No description provided for @onboardingTrialChipStart.
  ///
  /// In en, this message translates to:
  /// **'START FREE TRIAL'**
  String get onboardingTrialChipStart;

  /// No description provided for @onboardingTrialChipNotNow.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get onboardingTrialChipNotNow;

  /// No description provided for @onboardingProviderAuthorizationPoco.
  ///
  /// In en, this message translates to:
  /// **'Connect or create your server provider account. The next page will let you sign in or make one.\n\nWhen you authorize PocketCoder, it will provision a server and deploy PocketCoder on your behalf.'**
  String get onboardingProviderAuthorizationPoco;

  /// No description provided for @onboardingProviderAuthorizationTitle.
  ///
  /// In en, this message translates to:
  /// **'CONNECT YOUR SERVER PROVIDER'**
  String get onboardingProviderAuthorizationTitle;

  /// No description provided for @onboardingProviderAuthorizationAction.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get onboardingProviderAuthorizationAction;

  /// No description provided for @onboardingProviderAuthorizationWaiting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING'**
  String get onboardingProviderAuthorizationWaiting;

  /// No description provided for @onboardingProviderAuthorizationError.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION STOPPED'**
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
  /// **'USE CLOUD MODELS'**
  String get onboardingIntentChipCloudModels;

  /// No description provided for @onboardingIntentChipLocalModels.
  ///
  /// In en, this message translates to:
  /// **'RUN A LOCAL MODEL'**
  String get onboardingIntentChipLocalModels;

  /// No description provided for @onboardingPlanPoco.
  ///
  /// In en, this message translates to:
  /// **'Here are the server sizes available from {providerName}.\n\nThe highlighted option is the minimum I recommend for the setup you chose. You can select a larger server at any time.'**
  String onboardingPlanPoco(String providerName);

  /// No description provided for @onboardingPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR SERVER SIZE'**
  String get onboardingPlanTitle;

  /// No description provided for @onboardingRegionConsentPoco.
  ///
  /// In en, this message translates to:
  /// **'I can find server regions near you, if you want.\n\nYour location stays on this phone. I only use it to sort the available regions by distance.'**
  String get onboardingRegionConsentPoco;

  /// No description provided for @onboardingRegionConsentChipUseLocation.
  ///
  /// In en, this message translates to:
  /// **'USE MY LOCATION'**
  String get onboardingRegionConsentChipUseLocation;

  /// No description provided for @onboardingRegionConsentChipChooseMyself.
  ///
  /// In en, this message translates to:
  /// **'I’LL CHOOSE MYSELF'**
  String get onboardingRegionConsentChipChooseMyself;

  /// No description provided for @onboardingRegionPoco.
  ///
  /// In en, this message translates to:
  /// **'A region is the city where your server—and its data—will live. Choose one close to you, or to people who will use PocketCoder most.'**
  String get onboardingRegionPoco;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR SERVER REGION'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingHarnessPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose which coding agents to have ready on your server.\n\nA harness is the connection PocketCoder uses to work with a coding agent. This only installs the software; you’ll connect any required accounts after your server is ready.'**
  String get onboardingHarnessPoco;

  /// No description provided for @onboardingHarnessTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE CODING AGENTS'**
  String get onboardingHarnessTitle;

  /// No description provided for @onboardingOsPoco.
  ///
  /// In en, this message translates to:
  /// **'Now choose the Linux system that will start your server.\n\nLinux is the operating system underneath PocketCoder.'**
  String get onboardingOsPoco;

  /// No description provided for @onboardingOsTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE LINUX SYSTEM'**
  String get onboardingOsTitle;

  /// No description provided for @onboardingOsNixosLabel.
  ///
  /// In en, this message translates to:
  /// **'NIXOS — RECOMMENDED'**
  String get onboardingOsNixosLabel;

  /// No description provided for @onboardingOsNixosDescription.
  ///
  /// In en, this message translates to:
  /// **'Repeatable server setup, easier to recreate and roll back if a system change goes wrong. Estimated about {minutes} min.'**
  String onboardingOsNixosDescription(int minutes);

  /// No description provided for @onboardingOsDebianLabel.
  ///
  /// In en, this message translates to:
  /// **'DEBIAN'**
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
  /// **'REVIEW YOUR SERVER'**
  String get onboardingReviewTitle;

  /// No description provided for @onboardingReviewActionProvision.
  ///
  /// In en, this message translates to:
  /// **'PROVISION SERVER'**
  String get onboardingReviewActionProvision;

  /// No description provided for @onboardingProvisioningPoco.
  ///
  /// In en, this message translates to:
  /// **'Provisioning is underway. While the new server comes online, welcome to PocketCoder Initiative orientation.\n\nI’ll show you what we’re building, one piece at a time.'**
  String get onboardingProvisioningPoco;

  /// No description provided for @onboardingOrientationTitle.
  ///
  /// In en, this message translates to:
  /// **'INITIATIVE ORIENTATION'**
  String get onboardingOrientationTitle;

  /// No description provided for @onboardingOrientationActionSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP ORIENTATION'**
  String get onboardingOrientationActionSkip;

  /// No description provided for @onboardingOrientationActionContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE ORIENTATION'**
  String get onboardingOrientationActionContinue;

  /// No description provided for @onboardingDockerIntroEyebrow.
  ///
  /// In en, this message translates to:
  /// **'INTRODUCTION'**
  String get onboardingDockerIntroEyebrow;

  /// No description provided for @onboardingDockerIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'DOCKER AND CONTAINERS'**
  String get onboardingDockerIntroTitle;

  /// No description provided for @onboardingDockerIntroPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder is made of software components, such as its dashboard and coding agents. Docker runs each component in its own separate container on your server.'**
  String get onboardingDockerIntroPoco;

  /// No description provided for @onboardingDockerIntroActionStart.
  ///
  /// In en, this message translates to:
  /// **'START WALKTHROUGH'**
  String get onboardingDockerIntroActionStart;

  /// No description provided for @onboardingDockerIntroChipComponent.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A COMPONENT?'**
  String get onboardingDockerIntroChipComponent;

  /// No description provided for @onboardingDockerIntroChipContainer.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A CONTAINER?'**
  String get onboardingDockerIntroChipContainer;

  /// No description provided for @onboardingDockerIntroChipSavedData.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS SAVED DATA?'**
  String get onboardingDockerIntroChipSavedData;

  /// No description provided for @onboardingDockerIntroChipConnections.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE CONNECTIONS?'**
  String get onboardingDockerIntroChipConnections;

  /// No description provided for @onboardingReadyPoco.
  ///
  /// In en, this message translates to:
  /// **'Your PocketCoder server is ready.\n\nWelcome to the PocketCoder Initiative, Commander.\n\nYour server is online at its new HTTPS address. Your selected coding harnesses are ready.'**
  String get onboardingReadyPoco;

  /// No description provided for @onboardingReadyActionLogin.
  ///
  /// In en, this message translates to:
  /// **'LOG IN TO POCKETCODER'**
  String get onboardingReadyActionLogin;

  /// No description provided for @onboardingFailureConnectionPoco.
  ///
  /// In en, this message translates to:
  /// **'I couldn’t confirm that PocketCoder finished setting up.\n\nYour server is still available in your {providerName} account.'**
  String onboardingFailureConnectionPoco(String providerName);

  /// No description provided for @onboardingFailureActionRetryConnection.
  ///
  /// In en, this message translates to:
  /// **'RETRY CONNECTION'**
  String get onboardingFailureActionRetryConnection;

  /// No description provided for @onboardingFailureActionViewServerDetails.
  ///
  /// In en, this message translates to:
  /// **'VIEW SERVER DETAILS'**
  String get onboardingFailureActionViewServerDetails;

  /// No description provided for @onboardingFailureCreatePoco.
  ///
  /// In en, this message translates to:
  /// **'The server could not be created.\n\nNothing was deployed. Check your server provider connection, then try again.'**
  String get onboardingFailureCreatePoco;

  /// No description provided for @onboardingFailureActionBackToSetup.
  ///
  /// In en, this message translates to:
  /// **'BACK TO SETUP'**
  String get onboardingFailureActionBackToSetup;

  /// No description provided for @onboardingFailureActionTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'SHOW TECHNICAL DETAILS'**
  String get onboardingFailureActionTechnicalDetails;

  /// No description provided for @walkthroughHeader.
  ///
  /// In en, this message translates to:
  /// **'{os} SERVER SETUP · WALKTHROUGH {current} / {total}'**
  String walkthroughHeader(String os, int current, int total);

  /// No description provided for @walkthroughProgress.
  ///
  /// In en, this message translates to:
  /// **'WALKTHROUGH {current}/{total} · BRIEF {brief}'**
  String walkthroughProgress(int current, int total, String brief);

  /// No description provided for @walkthroughActionShowFullCode.
  ///
  /// In en, this message translates to:
  /// **'SHOW FULL CODE'**
  String get walkthroughActionShowFullCode;

  /// No description provided for @walkthroughActionShowConciseCode.
  ///
  /// In en, this message translates to:
  /// **'SHOW CONCISE CODE'**
  String get walkthroughActionShowConciseCode;

  /// No description provided for @walkthroughCaddyAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR HTTPS ADDRESS'**
  String get walkthroughCaddyAddressTitle;

  /// No description provided for @walkthroughCaddyAddressPoco.
  ///
  /// In en, this message translates to:
  /// **'First, the server finds its public IP address and turns it into an HTTPS address using sslip.io. PocketCoder saves that address so the mobile app knows where to sign in.'**
  String get walkthroughCaddyAddressPoco;

  /// No description provided for @walkthroughCaddyAddressChipIpAddress.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS AN IP ADDRESS?'**
  String get walkthroughCaddyAddressChipIpAddress;

  /// No description provided for @walkthroughCaddyAddressChipHttps.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS HTTPS?'**
  String get walkthroughCaddyAddressChipHttps;

  /// No description provided for @walkthroughCaddyAddressChipSslip.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS SSLIP.IO?'**
  String get walkthroughCaddyAddressChipSslip;

  /// No description provided for @walkthroughCaddyWebEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'THE SECURE WEB ENTRY'**
  String get walkthroughCaddyWebEntryTitle;

  /// No description provided for @walkthroughCaddyWebEntryPoco.
  ///
  /// In en, this message translates to:
  /// **'Caddy runs directly on the server. It sends regular web traffic to HTTPS, shares PocketCoder’s deployment status, and passes app requests to PocketBase without exposing PocketBase’s own port.'**
  String get walkthroughCaddyWebEntryPoco;

  /// No description provided for @walkthroughCaddyWebEntryChipCaddy.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS CADDY?'**
  String get walkthroughCaddyWebEntryChipCaddy;

  /// No description provided for @walkthroughCaddyWebEntryChipPrivatePort.
  ///
  /// In en, this message translates to:
  /// **'WHY IS POCKETBASE\'S PORT PRIVATE?'**
  String get walkthroughCaddyWebEntryChipPrivatePort;

  /// No description provided for @walkthroughNixosStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR SERVER DISK'**
  String get walkthroughNixosStorageTitle;

  /// No description provided for @walkthroughNixosStoragePoco.
  ///
  /// In en, this message translates to:
  /// **'This tells NixOS where PocketCoder’s main disk is and lets it expand to use the full size of the server you chose. Without autoResize, it could stay stuck at the smaller size of its original image.'**
  String get walkthroughNixosStoragePoco;

  /// No description provided for @walkthroughNixosNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'NETWORK BOUNDARIES'**
  String get walkthroughNixosNetworkTitle;

  /// No description provided for @walkthroughNixosNetworkPoco.
  ///
  /// In en, this message translates to:
  /// **'These rules open the three standard entry ports to your server: HTTP and HTTPS for the PocketCoder website, and SSH for secure remote access. Since PocketCoder runs inside Docker, it needs its own specific rules without opening extra entry ports to the internet.'**
  String get walkthroughNixosNetworkPoco;

  /// No description provided for @walkthroughNixosNetworkChipPorts.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE HTTP, HTTPS, AND SSH?'**
  String get walkthroughNixosNetworkChipPorts;

  /// No description provided for @walkthroughNixosNetworkChipDockerRules.
  ///
  /// In en, this message translates to:
  /// **'WHY DOES DOCKER NEED ITS OWN RULES?'**
  String get walkthroughNixosNetworkChipDockerRules;

  /// No description provided for @walkthroughNixosNetworkChipIpVersions.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE IPv4 AND IPv6?'**
  String get walkthroughNixosNetworkChipIpVersions;

  /// No description provided for @walkthroughNixosSshTitle.
  ///
  /// In en, this message translates to:
  /// **'KEY-ONLY SSH'**
  String get walkthroughNixosSshTitle;

  /// No description provided for @walkthroughNixosSshPoco.
  ///
  /// In en, this message translates to:
  /// **'SSH is the secure way to administer a server from another device—even a phone. We accept only your SSH key—not passwords—and temporarily block repeated failed attempts.'**
  String get walkthroughNixosSshPoco;

  /// No description provided for @walkthroughNixosDockerTitle.
  ///
  /// In en, this message translates to:
  /// **'DOCKER'**
  String get walkthroughNixosDockerTitle;

  /// No description provided for @walkthroughNixosDockerPoco.
  ///
  /// In en, this message translates to:
  /// **'This turns on Docker, the system that runs PocketCoder’s containers. It sends their logs to NixOS’s built-in system log, so there is one place to check what happened.'**
  String get walkthroughNixosDockerPoco;

  /// No description provided for @walkthroughServerKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR SERVER KEY'**
  String get walkthroughServerKeyTitle;

  /// No description provided for @walkthroughServerKeyPoco.
  ///
  /// In en, this message translates to:
  /// **'Before PocketCoder starts, this installs your public SSH key on the server. The mobile app keeps the matching private SSH key securely on your phone: the public key is the lock, and the private key is the key that opens it.'**
  String get walkthroughServerKeyPoco;

  /// No description provided for @walkthroughServerKeyChipPrivate.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A PRIVATE SSH KEY?'**
  String get walkthroughServerKeyChipPrivate;

  /// No description provided for @walkthroughServerKeyChipPublic.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A PUBLIC SSH KEY?'**
  String get walkthroughServerKeyChipPublic;

  /// No description provided for @walkthroughServerKeyChipSsh.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS SSH?'**
  String get walkthroughServerKeyChipSsh;

  /// No description provided for @walkthroughVerifiedVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED POCKETCODER VERSION'**
  String get walkthroughVerifiedVersionTitle;

  /// No description provided for @walkthroughVerifiedVersionPoco.
  ///
  /// In en, this message translates to:
  /// **'This downloads the exact PocketCoder version for your server, verifies it, then installs it.'**
  String get walkthroughVerifiedVersionPoco;

  /// No description provided for @walkthroughVerifiedVersionChipVerification.
  ///
  /// In en, this message translates to:
  /// **'HOW IS THE VERSION VERIFIED?'**
  String get walkthroughVerifiedVersionChipVerification;

  /// No description provided for @walkthroughVerifiedVersionChipDownloadFailure.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENS IF THE DOWNLOAD FAILS?'**
  String get walkthroughVerifiedVersionChipDownloadFailure;

  /// No description provided for @walkthroughVerifiedVersionChipUpdates.
  ///
  /// In en, this message translates to:
  /// **'CAN I UPDATE LATER?'**
  String get walkthroughVerifiedVersionChipUpdates;

  /// No description provided for @walkthroughStartPocketCoderTitle.
  ///
  /// In en, this message translates to:
  /// **'START POCKETCODER'**
  String get walkthroughStartPocketCoderTitle;

  /// No description provided for @walkthroughStartPocketCoderPoco.
  ///
  /// In en, this message translates to:
  /// **'This starts the verified PocketCoder version with only the coding harnesses you chose.'**
  String get walkthroughStartPocketCoderPoco;

  /// No description provided for @walkthroughStartPocketCoderChipWhatStarts.
  ///
  /// In en, this message translates to:
  /// **'WHAT STARTS AFTER THIS?'**
  String get walkthroughStartPocketCoderChipWhatStarts;

  /// No description provided for @walkthroughStartPocketCoderChipAddHarness.
  ///
  /// In en, this message translates to:
  /// **'CAN I ADD A HARNESS LATER?'**
  String get walkthroughStartPocketCoderChipAddHarness;

  /// No description provided for @walkthroughNixosDockerRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'DOCKER FIREWALL RULES'**
  String get walkthroughNixosDockerRulesTitle;

  /// No description provided for @walkthroughNixosDockerRulesPoco.
  ///
  /// In en, this message translates to:
  /// **'Docker needs its own rules because it manages a separate path for container traffic. These rules keep the same boundaries without opening extra entry ports.'**
  String get walkthroughNixosDockerRulesPoco;

  /// No description provided for @walkthroughRuntimeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'LOCAL SETTINGS'**
  String get walkthroughRuntimeSettingsTitle;

  /// No description provided for @walkthroughRuntimeSettingsPoco.
  ///
  /// In en, this message translates to:
  /// **'This prepares PocketCoder’s local settings file and locks it so only its administrator—you—can read it. It creates the internal credentials PocketCoder needs to run.'**
  String get walkthroughRuntimeSettingsPoco;

  /// No description provided for @walkthroughRuntimeSettingsChipLocalSettings.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE LOCAL SETTINGS?'**
  String get walkthroughRuntimeSettingsChipLocalSettings;

  /// No description provided for @walkthroughRuntimeVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'RUNNING VERSION'**
  String get walkthroughRuntimeVersionTitle;

  /// No description provided for @walkthroughRuntimeVersionPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder records the version it is running in the same protected settings file.'**
  String get walkthroughRuntimeVersionPoco;

  /// No description provided for @walkthroughActivationPrepareTitle.
  ///
  /// In en, this message translates to:
  /// **'PREPARE THE RELEASE'**
  String get walkthroughActivationPrepareTitle;

  /// No description provided for @walkthroughActivationPreparePoco.
  ///
  /// In en, this message translates to:
  /// **'This checks that the release files match the verified PocketCoder version and prepares them for installation. It also sets up status reporting for the PocketCoder deployment.'**
  String get walkthroughActivationPreparePoco;

  /// No description provided for @walkthroughActivationSelectedSoftwareTitle.
  ///
  /// In en, this message translates to:
  /// **'SELECTED SOFTWARE'**
  String get walkthroughActivationSelectedSoftwareTitle;

  /// No description provided for @walkthroughActivationSelectedSoftwarePoco.
  ///
  /// In en, this message translates to:
  /// **'Next, the server loads PocketCoder and only the coding agents you chose. It checks each software component before Docker runs it.'**
  String get walkthroughActivationSelectedSoftwarePoco;

  /// No description provided for @walkthroughActivationSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'MAKE IT ACTIVE'**
  String get walkthroughActivationSwitchTitle;

  /// No description provided for @walkthroughActivationSwitchPoco.
  ///
  /// In en, this message translates to:
  /// **'This makes the new PocketCoder version active and starts its containers. It uses prebuilt software for faster setup and consistent versioning.'**
  String get walkthroughActivationSwitchPoco;

  /// No description provided for @walkthroughActivationHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'CHECK THE DEPLOYMENT'**
  String get walkthroughActivationHealthTitle;

  /// No description provided for @walkthroughActivationHealthPoco.
  ///
  /// In en, this message translates to:
  /// **'Before calling the deployment complete, PocketCoder checks that its core and optional services are healthy. Only then does it record this version as active.'**
  String get walkthroughActivationHealthPoco;

  /// No description provided for @walkthroughDebianSetupStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'SETUP STATUS'**
  String get walkthroughDebianSetupStatusTitle;

  /// No description provided for @walkthroughDebianSetupStatusPoco.
  ///
  /// In en, this message translates to:
  /// **'This setup script keeps PocketCoder’s deployment status up to date as it runs. If something fails, it records where and cleans up temporary files so it can be checked or safely retried.'**
  String get walkthroughDebianSetupStatusPoco;

  /// No description provided for @walkthroughDebianSetupStatusChipStatus.
  ///
  /// In en, this message translates to:
  /// **'HOW IS DEPLOYMENT STATUS SHOWN?'**
  String get walkthroughDebianSetupStatusChipStatus;

  /// No description provided for @walkthroughDebianSetupStatusChipFailure.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENS IF SETUP FAILS?'**
  String get walkthroughDebianSetupStatusChipFailure;

  /// No description provided for @walkthroughServicesComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'THE DOCKER BLUEPRINT'**
  String get walkthroughServicesComposeTitle;

  /// No description provided for @walkthroughServicesComposePoco.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose is PocketCoder’s blueprint. It keeps your data when we update the software, and gives each component only the connections it needs.'**
  String get walkthroughServicesComposePoco;

  /// No description provided for @walkthroughServicesComposeChipDockerCompose.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS DOCKER COMPOSE?'**
  String get walkthroughServicesComposeChipDockerCompose;

  /// No description provided for @walkthroughServicesComposeChipSavedData.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS SAVED DATA?'**
  String get walkthroughServicesComposeChipSavedData;

  /// No description provided for @walkthroughServicesComposeChipPrivateConnections.
  ///
  /// In en, this message translates to:
  /// **'WHAT ARE PRIVATE CONNECTIONS?'**
  String get walkthroughServicesComposeChipPrivateConnections;

  /// No description provided for @walkthroughServicesPocketBaseTitle.
  ///
  /// In en, this message translates to:
  /// **'POCKETBASE'**
  String get walkthroughServicesPocketBaseTitle;

  /// No description provided for @walkthroughServicesPocketBasePoco.
  ///
  /// In en, this message translates to:
  /// **'PocketBase keeps the information PocketCoder needs to run: your sign-in, skills, prompts, agent connections, and API keys. That information stays on your server, and you reach it through the HTTPS address Caddy just set up.'**
  String get walkthroughServicesPocketBasePoco;

  /// No description provided for @walkthroughServicesPocketBaseChipKeeps.
  ///
  /// In en, this message translates to:
  /// **'WHAT DOES POCKETBASE KEEP?'**
  String get walkthroughServicesPocketBaseChipKeeps;

  /// No description provided for @walkthroughServicesPocketBaseChipSignIn.
  ///
  /// In en, this message translates to:
  /// **'HOW DO I SIGN IN SECURELY?'**
  String get walkthroughServicesPocketBaseChipSignIn;

  /// No description provided for @walkthroughServicesPocketBaseChipUpdates.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENS WHEN POCKETCODER UPDATES?'**
  String get walkthroughServicesPocketBaseChipUpdates;

  /// No description provided for @walkthroughServicesHarnessesTitle.
  ///
  /// In en, this message translates to:
  /// **'CODING HARNESSES'**
  String get walkthroughServicesHarnessesTitle;

  /// No description provided for @walkthroughServicesHarnessesPoco.
  ///
  /// In en, this message translates to:
  /// **'PocketCoder prepares the coding harnesses you selected: {selectedHarnesses}. Each gets its own container, saved workspace, and only the private connections it needs.'**
  String walkthroughServicesHarnessesPoco(String selectedHarnesses);

  /// No description provided for @walkthroughServicesHarnessesChipHarness.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A CODING HARNESS?'**
  String get walkthroughServicesHarnessesChipHarness;

  /// No description provided for @walkthroughServicesHarnessesChipWorkspace.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A SAVED WORKSPACE?'**
  String get walkthroughServicesHarnessesChipWorkspace;

  /// No description provided for @walkthroughServicesHarnessesChipAdd.
  ///
  /// In en, this message translates to:
  /// **'CAN I ADD A HARNESS LATER?'**
  String get walkthroughServicesHarnessesChipAdd;

  /// No description provided for @walkthroughServicesToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'TOOL CONNECTIONS'**
  String get walkthroughServicesToolsTitle;

  /// No description provided for @walkthroughServicesToolsPoco.
  ///
  /// In en, this message translates to:
  /// **'The MCP Gateway is a controlled connection point for extra tools your coding harnesses can use. Its separate Docker proxy grants only the permissions those tools need, while blocking more sensitive actions such as accessing saved data or secrets.'**
  String get walkthroughServicesToolsPoco;

  /// No description provided for @walkthroughServicesToolsChipMcp.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS MCP?'**
  String get walkthroughServicesToolsChipMcp;

  /// No description provided for @walkthroughServicesToolsChipHarnessTools.
  ///
  /// In en, this message translates to:
  /// **'WHAT TOOLS CAN A HARNESS USE?'**
  String get walkthroughServicesToolsChipHarnessTools;

  /// No description provided for @walkthroughServicesToolsChipProxy.
  ///
  /// In en, this message translates to:
  /// **'WHY DOES THIS HAVE A SEPARATE PROXY?'**
  String get walkthroughServicesToolsChipProxy;

  /// No description provided for @walkthroughServicesOllamaTitle.
  ///
  /// In en, this message translates to:
  /// **'LOCAL MODELS'**
  String get walkthroughServicesOllamaTitle;

  /// No description provided for @walkthroughServicesOllamaPoco.
  ///
  /// In en, this message translates to:
  /// **'Ollama is ready to run AI models directly on your server. It appears because you chose a local-model setup; when you later choose a model, PocketCoder downloads it and keeps it as saved data.'**
  String get walkthroughServicesOllamaPoco;

  /// No description provided for @walkthroughServicesOllamaChipLocalModel.
  ///
  /// In en, this message translates to:
  /// **'WHAT IS A LOCAL MODEL?'**
  String get walkthroughServicesOllamaChipLocalModel;

  /// No description provided for @walkthroughServicesOllamaChipDownload.
  ///
  /// In en, this message translates to:
  /// **'WHEN IS A MODEL DOWNLOADED?'**
  String get walkthroughServicesOllamaChipDownload;

  /// No description provided for @walkthroughServicesOllamaChipGpu.
  ///
  /// In en, this message translates to:
  /// **'DOES THIS USE MY SERVER\'S GPU?'**
  String get walkthroughServicesOllamaChipGpu;

  /// No description provided for @walkthroughServicesSqlPageTitle.
  ///
  /// In en, this message translates to:
  /// **'SERVER DASHBOARD'**
  String get walkthroughServicesSqlPageTitle;

  /// No description provided for @walkthroughServicesSqlPagePoco.
  ///
  /// In en, this message translates to:
  /// **'SQLPage is PocketCoder’s built-in dashboard for showing what is happening on your server. It starts after PocketBase is ready and uses saved PocketCoder data to build those pages.'**
  String get walkthroughServicesSqlPagePoco;

  /// No description provided for @walkthroughServicesSqlPageChipContents.
  ///
  /// In en, this message translates to:
  /// **'WHAT CAN THIS DASHBOARD SHOW?'**
  String get walkthroughServicesSqlPageChipContents;

  /// No description provided for @walkthroughServicesSqlPageChipStartOrder.
  ///
  /// In en, this message translates to:
  /// **'WHY DOES IT START AFTER POCKETBASE?'**
  String get walkthroughServicesSqlPageChipStartOrder;

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

  /// No description provided for @harnessAuthCopy.
  ///
  /// In en, this message translates to:
  /// **'[COPY]'**
  String get harnessAuthCopy;

  /// No description provided for @harnessAuthChallengeDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'CODE COPIED'**
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

  /// No description provided for @harnessAuthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get harnessAuthNone;

  /// No description provided for @harnessAuthPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get harnessAuthPoll;

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

  /// No description provided for @agentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'MODE:'**
  String get agentModeLabel;

  /// No description provided for @agentConfigLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIG'**
  String get agentConfigLabel;

  /// No description provided for @pocketCoderUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'\$ CHECKING VERIFIED RELEASE STATUS...'**
  String get pocketCoderUpdateChecking;

  /// No description provided for @pocketCoderUpdateCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'CHECK AGAIN'**
  String get pocketCoderUpdateCheckAgain;

  /// No description provided for @pocketCoderUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'POCKETCODER UPDATE'**
  String get pocketCoderUpdateTitle;

  /// No description provided for @pocketCoderUpdateNoDeployment.
  ///
  /// In en, this message translates to:
  /// **'NO DEPLOYMENT FOUND ON THIS DEVICE.'**
  String get pocketCoderUpdateNoDeployment;

  /// No description provided for @actionDismiss.
  ///
  /// In en, this message translates to:
  /// **'DISMISS'**
  String get actionDismiss;

  /// No description provided for @pocketCoderUpdateWorking.
  ///
  /// In en, this message translates to:
  /// **'UPGRADING...'**
  String get pocketCoderUpdateWorking;

  /// No description provided for @pocketCoderUpdateUpgrade.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE POCKETCODER'**
  String get pocketCoderUpdateUpgrade;

  /// No description provided for @pocketCoderUpdateCommand.
  ///
  /// In en, this message translates to:
  /// **'pocketcoder-release update'**
  String get pocketCoderUpdateCommand;

  /// No description provided for @pocketCoderUpdateOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get pocketCoderUpdateOutput;

  /// No description provided for @pocketCoderUpdateStderr.
  ///
  /// In en, this message translates to:
  /// **'--- STDERR ---'**
  String get pocketCoderUpdateStderr;

  /// No description provided for @pocketCoderUpdateSucceeded.
  ///
  /// In en, this message translates to:
  /// **'UPDATE SUCCEEDED (EXIT 0)'**
  String get pocketCoderUpdateSucceeded;

  /// No description provided for @pocketCoderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'UPDATE FAILED (EXIT {exitCode})'**
  String pocketCoderUpdateFailed(int exitCode);

  /// No description provided for @pocketCoderUpdateReviewDataChange.
  ///
  /// In en, this message translates to:
  /// **'REVIEW DATA CHANGE'**
  String get pocketCoderUpdateReviewDataChange;

  /// No description provided for @pocketCoderUpdateConfirmUpgrade.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM UPGRADE'**
  String get pocketCoderUpdateConfirmUpgrade;

  /// No description provided for @pocketCoderUpdateCurrent.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get pocketCoderUpdateCurrent;

  /// No description provided for @pocketCoderUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get pocketCoderUpdateAvailable;

  /// No description provided for @pocketCoderUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get pocketCoderUpdateDownload;

  /// No description provided for @pocketCoderUpdateRequiredDisk.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED DISK'**
  String get pocketCoderUpdateRequiredDisk;

  /// No description provided for @pocketCoderUpdateCurrentStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ POCKETCODER IS CURRENT'**
  String get pocketCoderUpdateCurrentStatus;

  /// No description provided for @pocketCoderUpdateAvailableStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ UPDATE AVAILABLE'**
  String get pocketCoderUpdateAvailableStatus;

  /// No description provided for @pocketCoderUpdateCriticalStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ CRITICAL RELEASE WARNING'**
  String get pocketCoderUpdateCriticalStatus;

  /// No description provided for @pocketCoderUpdateUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'\$ RELEASE STATUS UNKNOWN'**
  String get pocketCoderUpdateUnknownStatus;

  /// No description provided for @pocketCoderUpdateRollbackWarning.
  ///
  /// In en, this message translates to:
  /// **'AFTER SUCCESS, NORMAL ROLLBACK IS UNAVAILABLE. RESTORING THE PRE-UPGRADE SNAPSHOT WOULD DISCARD DATA CREATED AFTERWARD.'**
  String get pocketCoderUpdateRollbackWarning;

  /// No description provided for @pocketCoderUpdateDataBoundary.
  ///
  /// In en, this message translates to:
  /// **'DATA VERSION {currentVersion} → {availableVersion}'**
  String pocketCoderUpdateDataBoundary(
      int currentVersion, int availableVersion);

  /// No description provided for @errorsOccurred.
  ///
  /// In en, this message translates to:
  /// **'Occurred {count}x'**
  String errorsOccurred(int count);

  /// Label for the reset deployment state action on the config screen recovery section
  ///
  /// In en, this message translates to:
  /// **'RESET'**
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
  /// **'RESET'**
  String get deploymentResetConfirm;

  /// Cancel button label on the reset dialog
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get deploymentResetCancel;

  /// Snack/banner shown after a successful reset
  ///
  /// In en, this message translates to:
  /// **'Local deployment state cleared.'**
  String get deploymentResetComplete;

  /// Label for manually disconnecting the current managed instance
  ///
  /// In en, this message translates to:
  /// **'DISCONNECT'**
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
  /// **'DISCONNECT'**
  String get deploymentDisconnectConfirm;

  /// Cancel button label on the disconnect dialog
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get deploymentDisconnectCancel;

  /// Title of the confirmation dialog for discarding a stuck local deployment record
  ///
  /// In en, this message translates to:
  /// **'DISCARD THIS DEPLOYMENT RECORD?'**
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
  /// **'CANCEL'**
  String get deploymentDiscardAttemptCancel;

  /// Confirm button on the discard-stale-attempt confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'DISCARD'**
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
  /// **'SERVER CONTROLS'**
  String get serverControlTitle;

  /// No description provided for @serverControlConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION DETAILS'**
  String get serverControlConnectionDetails;

  /// No description provided for @serverControlIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP ADDRESS'**
  String get serverControlIpAddress;

  /// No description provided for @serverControlHttpsEndpoint.
  ///
  /// In en, this message translates to:
  /// **'HTTPS ENDPOINT'**
  String get serverControlHttpsEndpoint;

  /// No description provided for @serverControlAdminIdentity.
  ///
  /// In en, this message translates to:
  /// **'ADMIN IDENTITY'**
  String get serverControlAdminIdentity;

  /// No description provided for @serverControlAdminPassword.
  ///
  /// In en, this message translates to:
  /// **'ADMIN PASSWORD'**
  String get serverControlAdminPassword;

  /// No description provided for @serverControlRevealPassword.
  ///
  /// In en, this message translates to:
  /// **'REVEAL PASSWORD'**
  String get serverControlRevealPassword;

  /// No description provided for @serverControlHidePassword.
  ///
  /// In en, this message translates to:
  /// **'HIDE PASSWORD'**
  String get serverControlHidePassword;

  /// No description provided for @serverControlCopy.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get serverControlCopy;

  /// No description provided for @serverControlCopied.
  ///
  /// In en, this message translates to:
  /// **'COPIED'**
  String get serverControlCopied;

  /// No description provided for @serverControlConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM SERVER CONTROL'**
  String get serverControlConfirmTitle;

  /// No description provided for @serverControlConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{operation} will run on your server.'**
  String serverControlConfirmBody(String operation);

  /// No description provided for @serverControlConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get serverControlConfirmCancel;

  /// No description provided for @serverControlConfirmConfirm.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get serverControlConfirmConfirm;

  /// No description provided for @serverControlReleaseChecking.
  ///
  /// In en, this message translates to:
  /// **'RELEASE STATUS: CHECKING'**
  String get serverControlReleaseChecking;

  /// No description provided for @serverControlReleaseStatus.
  ///
  /// In en, this message translates to:
  /// **'RELEASE STATUS: {status}'**
  String serverControlReleaseStatus(String status);

  /// No description provided for @serverControlReleaseCurrent.
  ///
  /// In en, this message translates to:
  /// **'CURRENT: {version}'**
  String serverControlReleaseCurrent(String version);

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

  /// No description provided for @serverControlOpenChat.
  ///
  /// In en, this message translates to:
  /// **'OPEN CHAT'**
  String get serverControlOpenChat;

  /// No description provided for @initializationInstanceId.
  ///
  /// In en, this message translates to:
  /// **'INSTANCE ID'**
  String get initializationInstanceId;

  /// No description provided for @initializationRetryAttempt.
  ///
  /// In en, this message translates to:
  /// **'RETRY ATTEMPT'**
  String get initializationRetryAttempt;
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
