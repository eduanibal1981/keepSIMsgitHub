import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ne.dart';
import 'app_localizations_si.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('hi'),
    Locale('ne'),
    Locale('si'),
    Locale('tr'),
    Locale('ur'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'KeepSIMs'**
  String get appName;

  /// No description provided for @preferencesAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Preferences & Security'**
  String get preferencesAndSecurity;

  /// No description provided for @appAppearance.
  ///
  /// In en, this message translates to:
  /// **'App Appearance'**
  String get appAppearance;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @localizationAndRegional.
  ///
  /// In en, this message translates to:
  /// **'Localization & Regional'**
  String get localizationAndRegional;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @currentlyUsing.
  ///
  /// In en, this message translates to:
  /// **'Currently using regional {langName}'**
  String currentlyUsing(String langName);

  /// No description provided for @selectAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select App Language'**
  String get selectAppLanguage;

  /// No description provided for @securityAndAccessLock.
  ///
  /// In en, this message translates to:
  /// **'Security & Access Lock'**
  String get securityAndAccessLock;

  /// No description provided for @biometricSecurity.
  ///
  /// In en, this message translates to:
  /// **'Biometric Security'**
  String get biometricSecurity;

  /// No description provided for @biometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in using Face ID or Touch ID'**
  String get biometricDesc;

  /// No description provided for @biometricReasonPayment.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to confirm payment'**
  String get biometricReasonPayment;

  /// No description provided for @biometricReasonUnlock.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock KeepSIMs'**
  String get biometricReasonUnlock;

  /// No description provided for @biometricLockout.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication locked due to too many failed attempts. Please use your device passcode to unlock.'**
  String get biometricLockout;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not set up on this device.'**
  String get biometricNotEnrolled;

  /// No description provided for @biometricAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'KeepSIMs is Locked'**
  String get biometricAppLockTitle;

  /// No description provided for @biometricUnlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Biometrics'**
  String get biometricUnlockButton;

  /// No description provided for @biometricCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get biometricCancel;

  /// No description provided for @transactionPin.
  ///
  /// In en, this message translates to:
  /// **'Transaction PIN'**
  String get transactionPin;

  /// No description provided for @transactionPinDesc.
  ///
  /// In en, this message translates to:
  /// **'Secure renewals and withdrawals'**
  String get transactionPinDesc;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'SETUP'**
  String get setup;

  /// No description provided for @pinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transaction PIN successfully updated!'**
  String get pinSuccess;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Try again!'**
  String get pinMismatch;

  /// No description provided for @pinActiveAndSecure.
  ///
  /// In en, this message translates to:
  /// **'PIN setup is active and secure'**
  String get pinActiveAndSecure;

  /// No description provided for @automatedSummaryAndAlerts.
  ///
  /// In en, this message translates to:
  /// **'Automated Summary & Alerts'**
  String get automatedSummaryAndAlerts;

  /// No description provided for @weeklyDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get weeklyDigest;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @nextNotify.
  ///
  /// In en, this message translates to:
  /// **'NEXT NOTIFY'**
  String get nextNotify;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @showingNearestLine.
  ///
  /// In en, this message translates to:
  /// **'Showing nearest line'**
  String get showingNearestLine;

  /// No description provided for @addSim.
  ///
  /// In en, this message translates to:
  /// **'Add SIM'**
  String get addSim;

  /// No description provided for @linesToProtect.
  ///
  /// In en, this message translates to:
  /// **'Lines to Protect'**
  String get linesToProtect;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE'**
  String get upgrade;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'STANDARD'**
  String get standard;

  /// No description provided for @autoNotify.
  ///
  /// In en, this message translates to:
  /// **'Auto-Notify'**
  String get autoNotify;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @autoRefill.
  ///
  /// In en, this message translates to:
  /// **'Auto-Refill'**
  String get autoRefill;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSims.
  ///
  /// In en, this message translates to:
  /// **'SIMs'**
  String get navSims;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @protectedSims.
  ///
  /// In en, this message translates to:
  /// **'Protected SIMs'**
  String get protectedSims;

  /// No description provided for @mySimCards.
  ///
  /// In en, this message translates to:
  /// **'My SIM Cards'**
  String get mySimCards;

  /// No description provided for @familySharedSims.
  ///
  /// In en, this message translates to:
  /// **'Family Shared SIMs'**
  String get familySharedSims;

  /// No description provided for @protectAnotherSimLine.
  ///
  /// In en, this message translates to:
  /// **'Protect Another SIM Line'**
  String get protectAnotherSimLine;

  /// No description provided for @keepInfiniteNumbersAlive.
  ///
  /// In en, this message translates to:
  /// **'Keep infinite international numbers alive'**
  String get keepInfiniteNumbersAlive;

  /// No description provided for @bulkActionsConsole.
  ///
  /// In en, this message translates to:
  /// **'Bulk Actions Console'**
  String get bulkActionsConsole;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @simulate.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get simulate;

  /// No description provided for @noProtectedLines.
  ///
  /// In en, this message translates to:
  /// **'No Protected Lines'**
  String get noProtectedLines;

  /// No description provided for @noInternationalSimsAdded.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any international SIM cards added yet. Protect your first card now to keep it active forever.'**
  String get noInternationalSimsAdded;

  /// No description provided for @protectNewLine.
  ///
  /// In en, this message translates to:
  /// **'Protect New Line'**
  String get protectNewLine;

  /// No description provided for @noSharedSimsYet.
  ///
  /// In en, this message translates to:
  /// **'No Shared SIMs yet'**
  String get noSharedSimsYet;

  /// No description provided for @inviteFamilyMembers.
  ///
  /// In en, this message translates to:
  /// **'Invite family members to join your Household. Once they accept, their protected SIM lines will appear here for collaborative monitoring.'**
  String get inviteFamilyMembers;

  /// No description provided for @manageHousehold.
  ///
  /// In en, this message translates to:
  /// **'Manage Household'**
  String get manageHousehold;

  /// No description provided for @manageProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile, SIM lines, alerts, and shared preferences'**
  String get manageProfileDesc;

  /// No description provided for @keepSIMsUser.
  ///
  /// In en, this message translates to:
  /// **'KeepSIMs User'**
  String get keepSIMsUser;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro;

  /// No description provided for @homeCountry.
  ///
  /// In en, this message translates to:
  /// **'Home Country: '**
  String get homeCountry;

  /// No description provided for @console.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get console;

  /// No description provided for @offlineRefill.
  ///
  /// In en, this message translates to:
  /// **'Offline Refill (SMS/WA)'**
  String get offlineRefill;

  /// No description provided for @refillSimOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'Refill SIM balance offline via SMS or WhatsApp'**
  String get refillSimOfflineDesc;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @manageBalancesDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your balances and view transaction history'**
  String get manageBalancesDesc;

  /// No description provided for @alertPreferences.
  ///
  /// In en, this message translates to:
  /// **'Alert Preferences'**
  String get alertPreferences;

  /// No description provided for @togglePushEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'Toggle push & email settings for renewals/balances'**
  String get togglePushEmailDesc;

  /// No description provided for @referAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referAndEarn;

  /// No description provided for @shareKeepSIMsDesc.
  ///
  /// In en, this message translates to:
  /// **'Share KeepSIMs, unlock dynamic balance rewards'**
  String get shareKeepSIMsDesc;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @addBankCardsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add bank cards or link auto-withdrawal accounts'**
  String get addBankCardsDesc;

  /// No description provided for @travelAndGeolocation.
  ///
  /// In en, this message translates to:
  /// **'Travel & Geolocation'**
  String get travelAndGeolocation;

  /// No description provided for @manageHomeCountryDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage home country freeze rules & travel mode'**
  String get manageHomeCountryDesc;

  /// No description provided for @dataAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get dataAndPrivacy;

  /// No description provided for @manageTrackingConsentDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your tracking consent, export data, or delete account'**
  String get manageTrackingConsentDesc;

  /// No description provided for @powerUser.
  ///
  /// In en, this message translates to:
  /// **'Power User'**
  String get powerUser;

  /// No description provided for @accessSystemSimulatorsDesc.
  ///
  /// In en, this message translates to:
  /// **'Access system simulators and debugging tools'**
  String get accessSystemSimulatorsDesc;

  /// No description provided for @testChecklist.
  ///
  /// In en, this message translates to:
  /// **'Test Checklist'**
  String get testChecklist;

  /// No description provided for @manualUiTestingDesc.
  ///
  /// In en, this message translates to:
  /// **'Manual UI testing checklist for quality assurance'**
  String get manualUiTestingDesc;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'SOON'**
  String get soon;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} feature is coming soon!'**
  String featureComingSoon(String feature);

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @confirmLogOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of KeepSIMs?'**
  String get confirmLogOut;

  /// No description provided for @walletLedger.
  ///
  /// In en, this message translates to:
  /// **'Wallet Ledger'**
  String get walletLedger;

  /// No description provided for @keepSIMsPrepaid.
  ///
  /// In en, this message translates to:
  /// **'KeepSIMs PREPAID'**
  String get keepSIMsPrepaid;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE MODE'**
  String get offlineMode;

  /// No description provided for @activeBalance.
  ///
  /// In en, this message translates to:
  /// **'Active Balance'**
  String get activeBalance;

  /// No description provided for @criticalBalanceLevel.
  ///
  /// In en, this message translates to:
  /// **'Critical Balance Level'**
  String get criticalBalanceLevel;

  /// No description provided for @balanceBelow10.
  ///
  /// In en, this message translates to:
  /// **'Your balance is below \$10.00. Scheduled SIM topups may fail soon.'**
  String get balanceBelow10;

  /// No description provided for @depositFunds.
  ///
  /// In en, this message translates to:
  /// **'Deposit Funds'**
  String get depositFunds;

  /// No description provided for @walletDepositsRequireInternet.
  ///
  /// In en, this message translates to:
  /// **'Wallet deposits require an active internet connection.'**
  String get walletDepositsRequireInternet;

  /// No description provided for @exportLedger.
  ///
  /// In en, this message translates to:
  /// **'Export Ledger'**
  String get exportLedger;

  /// No description provided for @ledgerHistoryExported.
  ///
  /// In en, this message translates to:
  /// **'Ledger history exported as CSV.'**
  String get ledgerHistoryExported;

  /// No description provided for @spendAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Spend Analysis'**
  String get spendAnalysis;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @noTransactionsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded yet.'**
  String get noTransactionsRecorded;

  /// No description provided for @prepaidMonthlyOutflow.
  ///
  /// In en, this message translates to:
  /// **'Prepaid Monthly Outflow'**
  String get prepaidMonthlyOutflow;

  /// No description provided for @avgMonthlySpend.
  ///
  /// In en, this message translates to:
  /// **'Avg: \${amount}/mo (12M)'**
  String avgMonthlySpend(String amount);

  /// No description provided for @depositViaCard.
  ///
  /// In en, this message translates to:
  /// **'Deposit via Card ending in {last4}'**
  String depositViaCard(String last4);

  /// No description provided for @lineRenewal.
  ///
  /// In en, this message translates to:
  /// **'Line Renewal'**
  String get lineRenewal;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @loadCreditFunds.
  ///
  /// In en, this message translates to:
  /// **'Load Credit Funds'**
  String get loadCreditFunds;

  /// No description provided for @depositAmountUsd.
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount (USD)'**
  String get depositAmountUsd;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get pleaseEnterAmount;

  /// No description provided for @enterPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get enterPositiveNumber;

  /// No description provided for @cardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card Details'**
  String get cardDetails;

  /// No description provided for @savedCards.
  ///
  /// In en, this message translates to:
  /// **'Saved Cards'**
  String get savedCards;

  /// No description provided for @visaCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Visa Card Number'**
  String get visaCardNumber;

  /// No description provided for @pleaseEnterCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter card number'**
  String get pleaseEnterCardNumber;

  /// No description provided for @mustBe16Digits.
  ///
  /// In en, this message translates to:
  /// **'Must be 16 digits'**
  String get mustBe16Digits;

  /// No description provided for @expiryMmYy.
  ///
  /// In en, this message translates to:
  /// **'Expiry (MM/YY)'**
  String get expiryMmYy;

  /// No description provided for @expiryRequired.
  ///
  /// In en, this message translates to:
  /// **'Expiry required'**
  String get expiryRequired;

  /// No description provided for @invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get invalid;

  /// No description provided for @cvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get cvv;

  /// No description provided for @cvvRequired.
  ///
  /// In en, this message translates to:
  /// **'CVV required'**
  String get cvvRequired;

  /// No description provided for @verifyingCardSecurity.
  ///
  /// In en, this message translates to:
  /// **'Verifying Card Security...'**
  String get verifyingCardSecurity;

  /// No description provided for @authorizeDepositFunds.
  ///
  /// In en, this message translates to:
  /// **'Authorize Deposit Funds'**
  String get authorizeDepositFunds;

  /// No description provided for @successfullyDeposited.
  ///
  /// In en, this message translates to:
  /// **'Successfully deposited \${amount} USD!'**
  String successfullyDeposited(String amount);

  /// No description provided for @failedToDepositFunds.
  ///
  /// In en, this message translates to:
  /// **'Failed to deposit funds. Please check card connection.'**
  String get failedToDepositFunds;

  /// No description provided for @noSavedPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No saved payment methods found.'**
  String get noSavedPaymentMethods;

  /// No description provided for @addPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get addPaymentMethod;

  /// No description provided for @savedPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Saved Payment Methods'**
  String get savedPaymentMethods;

  /// No description provided for @addAnotherPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add another payment method'**
  String get addAnotherPaymentMethod;

  /// No description provided for @expiresMmYy.
  ///
  /// In en, this message translates to:
  /// **'Expires {month}/{year}'**
  String expiresMmYy(String month, String year);

  /// No description provided for @offlineRefillTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline refill'**
  String get offlineRefillTitle;

  /// No description provided for @offlineRefillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger a top-up with no data and no credit'**
  String get offlineRefillSubtitle;

  /// No description provided for @selectTargetSimLine.
  ///
  /// In en, this message translates to:
  /// **'Select Target SIM Line'**
  String get selectTargetSimLine;

  /// No description provided for @noRegisteredSimLines.
  ///
  /// In en, this message translates to:
  /// **'No registered SIM lines found.'**
  String get noRegisteredSimLines;

  /// No description provided for @targetSimLine.
  ///
  /// In en, this message translates to:
  /// **'Target SIM Line'**
  String get targetSimLine;

  /// No description provided for @simLine.
  ///
  /// In en, this message translates to:
  /// **'SIM Line'**
  String get simLine;

  /// No description provided for @carrier.
  ///
  /// In en, this message translates to:
  /// **'CARRIER'**
  String get carrier;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @offlineRefillProtection.
  ///
  /// In en, this message translates to:
  /// **'Offline Refill Protection'**
  String get offlineRefillProtection;

  /// No description provided for @premiumExclusive.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM EXCLUSIVE'**
  String get premiumExclusive;

  /// No description provided for @neverGetStrandedDesc.
  ///
  /// In en, this message translates to:
  /// **'Never get stranded without mobile data again. KeepSIMs Premium allows you to refill your SIM card balance offline over standard local SMS or WhatsApp messages when you have zero internet connection.'**
  String get neverGetStrandedDesc;

  /// No description provided for @offlineCapability100.
  ///
  /// In en, this message translates to:
  /// **'100% Offline Capability'**
  String get offlineCapability100;

  /// No description provided for @deductsFromKeepSIMsDesc.
  ///
  /// In en, this message translates to:
  /// **'Deducts from your KeepSIMs wallet to credit your line via local SMS gateway failovers.'**
  String get deductsFromKeepSIMsDesc;

  /// No description provided for @dynamicUssdPlanActivation.
  ///
  /// In en, this message translates to:
  /// **'Dynamic USSD Plan Activation'**
  String get dynamicUssdPlanActivation;

  /// No description provided for @exactCopyPasteDialCodesDesc.
  ///
  /// In en, this message translates to:
  /// **'Provides exact copy-paste dial codes (e.g., *900*1#) to activate Data+Call packages offline.'**
  String get exactCopyPasteDialCodesDesc;

  /// No description provided for @dualChannelSupport.
  ///
  /// In en, this message translates to:
  /// **'Dual-Channel Support'**
  String get dualChannelSupport;

  /// No description provided for @textRefillDesc.
  ///
  /// In en, this message translates to:
  /// **'Text \"REFILL\" using standard SMS or WhatsApp depending on what cellular coverage is available.'**
  String get textRefillDesc;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @howToTriggerOfflineRefill.
  ///
  /// In en, this message translates to:
  /// **'How to Trigger Offline Refill'**
  String get howToTriggerOfflineRefill;

  /// No description provided for @ifZeroMobileDataDesc1.
  ///
  /// In en, this message translates to:
  /// **'If you have zero mobile data, send a standard SMS or WhatsApp message containing only '**
  String get ifZeroMobileDataDesc1;

  /// No description provided for @refill.
  ///
  /// In en, this message translates to:
  /// **'REFILL'**
  String get refill;

  /// No description provided for @toOurSecureGatewayDesc2.
  ///
  /// In en, this message translates to:
  /// **' to our secure system gateway:'**
  String get toOurSecureGatewayDesc2;

  /// No description provided for @targetSimLineLabel.
  ///
  /// In en, this message translates to:
  /// **'TARGET SIM LINE'**
  String get targetSimLineLabel;

  /// No description provided for @configureCashRefillAmount.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE CASH REFILL AMOUNT'**
  String get configureCashRefillAmount;

  /// No description provided for @refillAmount.
  ///
  /// In en, this message translates to:
  /// **'Refill Amount'**
  String get refillAmount;

  /// No description provided for @walletBalanceUsd.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance: \${amount} USD'**
  String walletBalanceUsd(String amount);

  /// No description provided for @lowBalanceWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Low Balance'**
  String get lowBalanceWarning;

  /// No description provided for @localCarrierPlanSuggestions.
  ///
  /// In en, this message translates to:
  /// **'LOCAL CARRIER PLAN SUGGESTIONS'**
  String get localCarrierPlanSuggestions;

  /// No description provided for @noStandardUssdDialCodes.
  ///
  /// In en, this message translates to:
  /// **'No standard USSD dial codes found for this carrier. You will still receive the cash refill successfully on your line.'**
  String get noStandardUssdDialCodes;

  /// No description provided for @dynamicDialCodesPreview.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Dial Codes Preview'**
  String get dynamicDialCodesPreview;

  /// No description provided for @botSuggestDialingCodes.
  ///
  /// In en, this message translates to:
  /// **'After the offline refill completes, the bot will suggest dialing these exact codes on your phone to instantly unlock Data+Calls offline:'**
  String get botSuggestDialingCodes;

  /// No description provided for @costAmount.
  ///
  /// In en, this message translates to:
  /// **'Cost: \${amount}'**
  String costAmount(String amount);

  /// No description provided for @whatsappSmsSenderOverride.
  ///
  /// In en, this message translates to:
  /// **'WHATSAPP/SMS SENDER OVERRIDE'**
  String get whatsappSmsSenderOverride;

  /// No description provided for @verificationNumber.
  ///
  /// In en, this message translates to:
  /// **'Verification Number'**
  String get verificationNumber;

  /// No description provided for @triggerRefillsDifferentNumber.
  ///
  /// In en, this message translates to:
  /// **'If you trigger refills from a different number than your main profile phone, enter it below with country code (e.g. 96891234567).'**
  String get triggerRefillsDifferentNumber;

  /// No description provided for @enterPhoneNumberDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number (digits only)'**
  String get enterPhoneNumberDigits;

  /// No description provided for @offlineRefillSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Offline Refill settings saved successfully!'**
  String get offlineRefillSettingsSaved;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @errorLoadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Error loading settings: {error}'**
  String errorLoadingSettings(String error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @offlineRefillLinked.
  ///
  /// In en, this message translates to:
  /// **'{phone} is linked'**
  String offlineRefillLinked(String phone);

  /// No description provided for @offlineRefillWalletInfo.
  ///
  /// In en, this message translates to:
  /// **'{carrier} line · Wallet balance \${balance}'**
  String offlineRefillWalletInfo(String carrier, String balance);

  /// No description provided for @offlineRefillNoFunds.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance too low'**
  String get offlineRefillNoFunds;

  /// No description provided for @offlineRefillNoFundsSub.
  ///
  /// In en, this message translates to:
  /// **'{phone} is linked · Balance \${balance}'**
  String offlineRefillNoFundsSub(String phone, String balance);

  /// No description provided for @offlineRefillNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This number isn\'t linked yet'**
  String get offlineRefillNotLinked;

  /// No description provided for @offlineRefillNotLinkedSub.
  ///
  /// In en, this message translates to:
  /// **'No KeepSIMs line is selected'**
  String get offlineRefillNotLinkedSub;

  /// No description provided for @offlineRefillFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest · Free'**
  String get offlineRefillFastest;

  /// No description provided for @offlineRefillNeedsFunds.
  ///
  /// In en, this message translates to:
  /// **'Needs wallet funds'**
  String get offlineRefillNeedsFunds;

  /// No description provided for @offlineRefillNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get offlineRefillNotSetUp;

  /// No description provided for @offlineRefillCallToTrigger.
  ///
  /// In en, this message translates to:
  /// **'Call to trigger refill'**
  String get offlineRefillCallToTrigger;

  /// No description provided for @offlineRefillAddFunds.
  ///
  /// In en, this message translates to:
  /// **'Add funds to enable'**
  String get offlineRefillAddFunds;

  /// No description provided for @offlineRefillLinkFirst.
  ///
  /// In en, this message translates to:
  /// **'Link this number first'**
  String get offlineRefillLinkFirst;

  /// No description provided for @offlineRefillAddsToNumber.
  ///
  /// In en, this message translates to:
  /// **'Adds to the number you call from'**
  String get offlineRefillAddsToNumber;

  /// No description provided for @offlineRefillFinePrintReady.
  ///
  /// In en, this message translates to:
  /// **'We only detect the ring. The call is never answered, so it never costs you anything — even at zero balance.'**
  String get offlineRefillFinePrintReady;

  /// No description provided for @offlineRefillFinePrintNoFunds.
  ///
  /// In en, this message translates to:
  /// **'Add balance to your wallet first — an offline refill still needs funds to send.'**
  String get offlineRefillFinePrintNoFunds;

  /// No description provided for @offlineRefillFinePrintUnreg.
  ///
  /// In en, this message translates to:
  /// **'Offline refill only works for numbers already added under My Numbers.'**
  String get offlineRefillFinePrintUnreg;

  /// No description provided for @offlineRefillCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get offlineRefillCopied;

  /// No description provided for @offlineRefillOtherWays.
  ///
  /// In en, this message translates to:
  /// **'Other ways in'**
  String get offlineRefillOtherWays;

  /// No description provided for @offlineRefillIvrTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your amount'**
  String get offlineRefillIvrTitle;

  /// No description provided for @offlineRefillIvrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose \$5, \$10 or \$25 by key press'**
  String get offlineRefillIvrSubtitle;

  /// No description provided for @offlineRefillIvrCost.
  ///
  /// In en, this message translates to:
  /// **'~\$0.15/call'**
  String get offlineRefillIvrCost;

  /// No description provided for @offlineRefillSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Text a code'**
  String get offlineRefillSmsTitle;

  /// No description provided for @offlineRefillSmsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send REFILL 5, REFILL 10 or REFILL 25'**
  String get offlineRefillSmsSubtitle;

  /// No description provided for @offlineRefillSmsCost.
  ///
  /// In en, this message translates to:
  /// **'local SMS rate'**
  String get offlineRefillSmsCost;

  /// No description provided for @offlineRefillSmsAction.
  ///
  /// In en, this message translates to:
  /// **'Text \"REFILL 5\"'**
  String get offlineRefillSmsAction;

  /// No description provided for @offlineRefillWaTitle.
  ///
  /// In en, this message translates to:
  /// **'Message on WhatsApp'**
  String get offlineRefillWaTitle;

  /// No description provided for @offlineRefillWaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Works on zero-rated data plans'**
  String get offlineRefillWaSubtitle;

  /// No description provided for @offlineRefillWaCost.
  ///
  /// In en, this message translates to:
  /// **'free*'**
  String get offlineRefillWaCost;

  /// No description provided for @offlineRefillWaAction.
  ///
  /// In en, this message translates to:
  /// **'Message \"REFILL\"'**
  String get offlineRefillWaAction;

  /// No description provided for @offlineRefillCallThisNumber.
  ///
  /// In en, this message translates to:
  /// **'Call this number'**
  String get offlineRefillCallThisNumber;

  /// No description provided for @offlineRefillDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Every method matches the refill to the phone number that called, texted, or messaged in. Make sure that\'s the SIM you want topped up. *Only free where your carrier zero-rates WhatsApp data.'**
  String get offlineRefillDisclaimer;

  /// No description provided for @offlineRefillTimelineRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing {number}'**
  String offlineRefillTimelineRinging(String number);

  /// No description provided for @offlineRefillTimelineDetected.
  ///
  /// In en, this message translates to:
  /// **'Missed call detected from {phone}'**
  String offlineRefillTimelineDetected(String phone);

  /// No description provided for @offlineRefillTimelineSent.
  ///
  /// In en, this message translates to:
  /// **'{amount} sent to {phone}'**
  String offlineRefillTimelineSent(String amount, String phone);

  /// No description provided for @offlineRefillJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get offlineRefillJustNow;

  /// No description provided for @offlineRefillSelectNumber.
  ///
  /// In en, this message translates to:
  /// **'Select a number'**
  String get offlineRefillSelectNumber;

  /// No description provided for @offlineRefillChannelsHeader.
  ///
  /// In en, this message translates to:
  /// **'Ways to refill offline'**
  String get offlineRefillChannelsHeader;

  /// No description provided for @offlineRefillTopUpFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Top up {amount} from your wallet'**
  String offlineRefillTopUpFromWallet(String amount);

  /// No description provided for @offlineRefillWalletFunded.
  ///
  /// In en, this message translates to:
  /// **'From your wallet'**
  String get offlineRefillWalletFunded;

  /// No description provided for @offlineRefillServiceFee.
  ///
  /// In en, this message translates to:
  /// **'+{fee} fee'**
  String offlineRefillServiceFee(String fee);

  /// No description provided for @offlineRefillMissedCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Give a missed call'**
  String get offlineRefillMissedCallTitle;

  /// No description provided for @offlineRefillMissedCallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No balance or data needed'**
  String get offlineRefillMissedCallSubtitle;

  /// No description provided for @offlineRefillCallAction.
  ///
  /// In en, this message translates to:
  /// **'Call to refill'**
  String get offlineRefillCallAction;

  /// No description provided for @offlineRefillRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get offlineRefillRetry;

  /// No description provided for @offlineRefillWaitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds}s'**
  String offlineRefillWaitSeconds(int seconds);

  /// No description provided for @offlineRefillStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent — awaiting confirmation'**
  String get offlineRefillStatusSent;

  /// No description provided for @offlineRefillStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Topping up your line…'**
  String get offlineRefillStatusProcessing;

  /// No description provided for @offlineRefillStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Top-up confirmed'**
  String get offlineRefillStatusConfirmed;

  /// No description provided for @offlineRefillStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t go through — try another way'**
  String get offlineRefillStatusFailed;

  /// No description provided for @offlineRefillStatusTimedOut.
  ///
  /// In en, this message translates to:
  /// **'No response yet — try another way'**
  String get offlineRefillStatusTimedOut;

  /// No description provided for @offlineRefillUssdTitle.
  ///
  /// In en, this message translates to:
  /// **'Get more from your top-up'**
  String get offlineRefillUssdTitle;

  /// No description provided for @offlineRefillUssdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'After the balance lands, dial your carrier\'s code for the best value'**
  String get offlineRefillUssdSubtitle;

  /// No description provided for @offlineRefillUssdDial.
  ///
  /// In en, this message translates to:
  /// **'Dial'**
  String get offlineRefillUssdDial;

  /// No description provided for @editProtectedLine.
  ///
  /// In en, this message translates to:
  /// **'Edit Protected Line'**
  String get editProtectedLine;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @activateShieldProtection.
  ///
  /// In en, this message translates to:
  /// **'Activate Shield Protection'**
  String get activateShieldProtection;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @nicknameOptional.
  ///
  /// In en, this message translates to:
  /// **'Nickname (Optional)'**
  String get nicknameOptional;

  /// No description provided for @whatsappAlerts.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Alerts'**
  String get whatsappAlerts;

  /// No description provided for @emailAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Critical deactivation alerts sent via Resend'**
  String get emailAlertsDesc;

  /// No description provided for @refillWalletLow.
  ///
  /// In en, this message translates to:
  /// **'Refill wallet when funds drop low'**
  String get refillWalletLow;

  /// No description provided for @legalPoliciesDesc.
  ///
  /// In en, this message translates to:
  /// **'By using KeepSIMs, you agree to our terms. KeepSIMs provides tools to help manage your SIM lifecycle, but we are not liable for direct or indirect losses, damages, or service interruptions caused by third-party telecommunication providers.'**
  String get legalPoliciesDesc;

  /// No description provided for @globalTravelModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Allows automated geofencing rules to activate border-crossing routines'**
  String get globalTravelModeDesc;

  /// No description provided for @dataPreferences.
  ///
  /// In en, this message translates to:
  /// **'Data Preferences'**
  String get dataPreferences;

  /// No description provided for @doNotDisturb.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb'**
  String get doNotDisturb;

  /// No description provided for @linkedCards.
  ///
  /// In en, this message translates to:
  /// **'Linked Cards'**
  String get linkedCards;

  /// No description provided for @analyticsTracking.
  ///
  /// In en, this message translates to:
  /// **'Analytics & Tracking'**
  String get analyticsTracking;

  /// No description provided for @dubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get dubai;

  /// No description provided for @flyHome.
  ///
  /// In en, this message translates to:
  /// **'Fly Home'**
  String get flyHome;

  /// No description provided for @managePreferencesAndSecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage theme, language, and biometric lockouts'**
  String get managePreferencesAndSecurityDesc;

  /// No description provided for @autoFundingRulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep SIM renewal running continuously by enabling automatic top-ups from your default credit card when the balance drops too low'**
  String get autoFundingRulesDesc;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @quietHoursSchedule.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours & Schedule'**
  String get quietHoursSchedule;

  /// No description provided for @exportMyDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Download a JSON copy of your profile and preferences (GDPR Right to Access)'**
  String get exportMyDataDesc;

  /// No description provided for @borderSimulatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Border Crossing Simulator'**
  String get borderSimulatorTitle;

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get yourData;

  /// No description provided for @mostImportant.
  ///
  /// In en, this message translates to:
  /// **'Most Important'**
  String get mostImportant;

  /// No description provided for @emailAlerts.
  ///
  /// In en, this message translates to:
  /// **'Email Alerts'**
  String get emailAlerts;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Aggressive native notifications on this device'**
  String get pushNotificationsDesc;

  /// No description provided for @alertSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert Settings'**
  String get alertSettingsTitle;

  /// No description provided for @atHome.
  ///
  /// In en, this message translates to:
  /// **'AT HOME'**
  String get atHome;

  /// No description provided for @telegramBotDesc.
  ///
  /// In en, this message translates to:
  /// **'Bound interactive Telegram chat notifications'**
  String get telegramBotDesc;

  /// No description provided for @alertChannels.
  ///
  /// In en, this message translates to:
  /// **'Alert Channels'**
  String get alertChannels;

  /// No description provided for @london.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get london;

  /// No description provided for @shieldProtection.
  ///
  /// In en, this message translates to:
  /// **'Shield Protection'**
  String get shieldProtection;

  /// No description provided for @legalPolicies.
  ///
  /// In en, this message translates to:
  /// **'Legal & Policies'**
  String get legalPolicies;

  /// No description provided for @supportVisaMastercard.
  ///
  /// In en, this message translates to:
  /// **'Supports secure Visa & MasterCard debit or credit'**
  String get supportVisaMastercard;

  /// No description provided for @exportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyData;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @analyticsTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'Help us improve the app by sharing anonymous usage data. Essential app functionality will not be affected if disabled'**
  String get analyticsTrackingDesc;

  /// No description provided for @autoFundingRules.
  ///
  /// In en, this message translates to:
  /// **'Auto-Funding Rules'**
  String get autoFundingRules;

  /// No description provided for @singapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get singapore;

  /// No description provided for @weeklySummaryDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary Digest'**
  String get weeklySummaryDigest;

  /// No description provided for @fullyShielded.
  ///
  /// In en, this message translates to:
  /// **'Fully Shielded'**
  String get fullyShielded;

  /// No description provided for @dndDesc.
  ///
  /// In en, this message translates to:
  /// **'Mute push notifications during specified sleep hours'**
  String get dndDesc;

  /// No description provided for @paymentsAutoFundTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments & Auto-Fund'**
  String get paymentsAutoFundTitle;

  /// No description provided for @travelGeolocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel & Geolocation'**
  String get travelGeolocationTitle;

  /// No description provided for @telegramBot.
  ///
  /// In en, this message translates to:
  /// **'Telegram Bot'**
  String get telegramBot;

  /// No description provided for @weeklyDigestDesc.
  ///
  /// In en, this message translates to:
  /// **'Compiled status report of all SIM cards every Sunday at 9:00 AM'**
  String get weeklyDigestDesc;

  /// No description provided for @borderSimulatorDesc.
  ///
  /// In en, this message translates to:
  /// **'Simulate boardings to trigger smart freeze or active country resumption rules.'**
  String get borderSimulatorDesc;

  /// No description provided for @linkFirstCard.
  ///
  /// In en, this message translates to:
  /// **'Link your first payment card'**
  String get linkFirstCard;

  /// No description provided for @globalTravelMode.
  ///
  /// In en, this message translates to:
  /// **'Global Travel Mode'**
  String get globalTravelMode;

  /// No description provided for @readPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read Full Privacy Policy & Terms'**
  String get readPrivacyPolicy;

  /// No description provided for @whatsappAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Refill failure alerts pushed directly to WhatsApp'**
  String get whatsappAlertsDesc;

  /// No description provided for @abroadTraveling.
  ///
  /// In en, this message translates to:
  /// **'ABROAD / TRAVELING'**
  String get abroadTraveling;

  /// No description provided for @freezeAllLines.
  ///
  /// In en, this message translates to:
  /// **'Freeze All Lines'**
  String get freezeAllLines;

  /// No description provided for @resumeRenewals.
  ///
  /// In en, this message translates to:
  /// **'Resume Renewals'**
  String get resumeRenewals;

  /// No description provided for @freezeRecommendationDesc.
  ///
  /// In en, this message translates to:
  /// **'We detected you are currently in your Home Country. You can freeze renewals on your international lines to prevent unwanted wallet balance depletion.'**
  String get freezeRecommendationDesc;

  /// No description provided for @travelDetected.
  ///
  /// In en, this message translates to:
  /// **'Travel Detected! ✈️'**
  String get travelDetected;

  /// No description provided for @resumeRecommendationDesc.
  ///
  /// In en, this message translates to:
  /// **'You are traveling abroad. Please resume your paused international SIM renewals to ensure uninterrupted mobile network coverage.'**
  String get resumeRecommendationDesc;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @welcomeHome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Home! 🏡'**
  String get welcomeHome;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @noAlertChannelsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No alert delivery channels configured.'**
  String get noAlertChannelsConfigured;

  /// No description provided for @channelSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'{channelName} settings updated.'**
  String channelSettingsUpdated(String channelName);

  /// No description provided for @channelLocked.
  ///
  /// In en, this message translates to:
  /// **'{channelName} Locked 🔒'**
  String channelLocked(String channelName);

  /// No description provided for @lockedAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{channelName} alerts are Starter and Premium plan features. Upgrade your plan to unlock WhatsApp, Telegram, and Email alerts!'**
  String lockedAlertSubtitle(String channelName);

  /// No description provided for @upsellProtect5Lines.
  ///
  /// In en, this message translates to:
  /// **'Protect up to 5 SIM lines simultaneously'**
  String get upsellProtect5Lines;

  /// No description provided for @upsellUnlockChannels.
  ///
  /// In en, this message translates to:
  /// **'Unlock WhatsApp, Telegram & Email notifications'**
  String get upsellUnlockChannels;

  /// No description provided for @upsellEnableTravelModes.
  ///
  /// In en, this message translates to:
  /// **'Enable Travel & Home automated validity modes'**
  String get upsellEnableTravelModes;

  /// No description provided for @emailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Email Address'**
  String get emailAddressLabel;

  /// No description provided for @emailAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. user@domain.com'**
  String get emailAddressHint;

  /// No description provided for @whatsappNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Number (Int\'l Format)'**
  String get whatsappNumberLabel;

  /// No description provided for @whatsappNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +96891234567'**
  String get whatsappNumberHint;

  /// No description provided for @whatsappFormatInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter full international format starting with + (e.g. +96893990492)'**
  String get whatsappFormatInstruction;

  /// No description provided for @telegramStatusBound.
  ///
  /// In en, this message translates to:
  /// **'Status: Bound (Chat ID: {chatId})'**
  String telegramStatusBound(String chatId);

  /// No description provided for @telegramStatusUnbound.
  ///
  /// In en, this message translates to:
  /// **'Status: Unbound'**
  String get telegramStatusUnbound;

  /// No description provided for @telegramLinkInstructions.
  ///
  /// In en, this message translates to:
  /// **'To receive free, interactive Telegram alerts, link our Telegram Bot with your account.'**
  String get telegramLinkInstructions;

  /// No description provided for @linkTelegramBot.
  ///
  /// In en, this message translates to:
  /// **'Link Telegram Bot'**
  String get linkTelegramBot;

  /// No description provided for @emailFreePlanGuarded.
  ///
  /// In en, this message translates to:
  /// **'Resend Free Plan Guarded: Capped to deactivation triggers only. No promotional spam.'**
  String get emailFreePlanGuarded;

  /// No description provided for @whatsappMetaCloudCapped.
  ///
  /// In en, this message translates to:
  /// **'Direct Meta Cloud Capped: Maximum 1 message per top-up schedule, sent ONLY if auto-refill is not active or fails.'**
  String get whatsappMetaCloudCapped;

  /// No description provided for @failedToLoadPaymentInfo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load payment info'**
  String get failedToLoadPaymentInfo;

  /// No description provided for @defaultCardIndicator.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get defaultCardIndicator;

  /// No description provided for @cardholder.
  ///
  /// In en, this message translates to:
  /// **'CARDHOLDER'**
  String get cardholder;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get expires;

  /// No description provided for @lowBalanceTrigger.
  ///
  /// In en, this message translates to:
  /// **'Low Balance Trigger'**
  String get lowBalanceTrigger;

  /// No description provided for @triggerLowTopUp.
  ///
  /// In en, this message translates to:
  /// **'Trigger low top-up'**
  String get triggerLowTopUp;

  /// No description provided for @reloadDepositAmount.
  ///
  /// In en, this message translates to:
  /// **'Reload Deposit Amount'**
  String get reloadDepositAmount;

  /// No description provided for @amountToLoad.
  ///
  /// In en, this message translates to:
  /// **'Amount to load'**
  String get amountToLoad;

  /// No description provided for @linkCreditDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Link Credit/Debit Card'**
  String get linkCreditDebitCard;

  /// No description provided for @cardNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'CARD NUMBER'**
  String get cardNumberLabel;

  /// No description provided for @expiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'EXPIRY DATE'**
  String get expiryDateLabel;

  /// No description provided for @cvvCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'CVV CODE'**
  String get cvvCodeLabel;

  /// No description provided for @securelyLinkCard.
  ///
  /// In en, this message translates to:
  /// **'Securely Link Card'**
  String get securelyLinkCard;

  /// No description provided for @pleaseEnterValidCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 16-digit card number.'**
  String get pleaseEnterValidCardNumber;

  /// No description provided for @pleaseEnterValidExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid expiry date (MM/YY).'**
  String get pleaseEnterValidExpiryDate;

  /// No description provided for @invalidExpiryMonth.
  ///
  /// In en, this message translates to:
  /// **'Invalid expiry month.'**
  String get invalidExpiryMonth;

  /// No description provided for @cvvMustBe3Digits.
  ///
  /// In en, this message translates to:
  /// **'CVV must be 3 digits.'**
  String get cvvMustBe3Digits;

  /// No description provided for @cardLinkedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Secure billing card linked successfully!'**
  String get cardLinkedSuccessfully;

  /// No description provided for @defaultPaymentCardUpdated.
  ///
  /// In en, this message translates to:
  /// **'Default payment card updated!'**
  String get defaultPaymentCardUpdated;

  /// No description provided for @removePaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Remove Payment Card'**
  String get removePaymentCard;

  /// No description provided for @confirmRemoveCardDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this card? Linked auto-funding might fail if no default payment card remains.'**
  String get confirmRemoveCardDesc;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @billingCardSuccessfullyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Billing card successfully removed.'**
  String get billingCardSuccessfullyRemoved;

  /// No description provided for @pleaseAddDefaultCardFirst.
  ///
  /// In en, this message translates to:
  /// **'Please add and select a default payment card first to enable auto-funding.'**
  String get pleaseAddDefaultCardFirst;

  /// No description provided for @autoFundPrefsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto-Funding preferences saved successfully!'**
  String get autoFundPrefsSavedSuccess;

  /// No description provided for @preparingDataExport.
  ///
  /// In en, this message translates to:
  /// **'Preparing data export...'**
  String get preparingDataExport;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Once you delete your account, there is no going back. Please be certain.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your data will be permanently purged.'**
  String get deleteAccountIrreversible;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type \"DELETE\" to confirm:'**
  String get typeDeleteToConfirm;

  /// No description provided for @deleteWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteWord;

  /// No description provided for @systemDiagnosticsLogs.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM DIAGNOSTICS LOGS'**
  String get systemDiagnosticsLogs;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get online;

  /// No description provided for @errorLoadingPrefs.
  ///
  /// In en, this message translates to:
  /// **'Error loading preferences: {error}'**
  String errorLoadingPrefs(String error);

  /// No description provided for @privacyPolicyLoaded.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy details loaded.'**
  String get privacyPolicyLoaded;

  /// No description provided for @protectionConsole.
  ///
  /// In en, this message translates to:
  /// **'Protection Console'**
  String get protectionConsole;

  /// No description provided for @deleteProtectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Protection'**
  String get deleteProtectionTooltip;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @failedToLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load details'**
  String get failedToLoadDetails;

  /// No description provided for @retryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// No description provided for @healthLabel.
  ///
  /// In en, this message translates to:
  /// **'health'**
  String get healthLabel;

  /// No description provided for @mySimCardDefault.
  ///
  /// In en, this message translates to:
  /// **'My SIM Card'**
  String get mySimCardDefault;

  /// No description provided for @upLabel.
  ///
  /// In en, this message translates to:
  /// **'UP'**
  String get upLabel;

  /// No description provided for @sharedByFamily.
  ///
  /// In en, this message translates to:
  /// **'Shared by: {ownerName} ({role})'**
  String sharedByFamily(String ownerName, String role);

  /// No description provided for @criticalRisk.
  ///
  /// In en, this message translates to:
  /// **'Critical risk'**
  String get criticalRisk;

  /// No description provided for @simDeactivationRisk.
  ///
  /// In en, this message translates to:
  /// **'SIM may deactivate without action'**
  String get simDeactivationRisk;

  /// No description provided for @missingAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'No alert notifications configured — missing 100 pts'**
  String get missingAlertsDesc;

  /// No description provided for @missingAutoRefillDesc.
  ///
  /// In en, this message translates to:
  /// **'No auto-refill configured — missing 50 pts'**
  String get missingAutoRefillDesc;

  /// No description provided for @missingVerificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Phone number not verified — missing 25 pts'**
  String get missingVerificationDesc;

  /// No description provided for @missingRecentRefillDesc.
  ///
  /// In en, this message translates to:
  /// **'Last refill was over 80 days ago — missing 25 pts'**
  String get missingRecentRefillDesc;

  /// No description provided for @quickActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActionsLabel;

  /// No description provided for @manualRefillLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual Refill'**
  String get manualRefillLabel;

  /// No description provided for @chargeFromWalletNow.
  ///
  /// In en, this message translates to:
  /// **'Charge from wallet now'**
  String get chargeFromWalletNow;

  /// No description provided for @rechargeFromFriend.
  ///
  /// In en, this message translates to:
  /// **'Recharge from Friend'**
  String get rechargeFromFriend;

  /// No description provided for @requestViaTelegram.
  ///
  /// In en, this message translates to:
  /// **'Request via Telegram'**
  String get requestViaTelegram;

  /// No description provided for @shareViaWaTg.
  ///
  /// In en, this message translates to:
  /// **'Share via WhatsApp/Telegram'**
  String get shareViaWaTg;

  /// No description provided for @testSimActivity.
  ///
  /// In en, this message translates to:
  /// **'Test SIM Activity'**
  String get testSimActivity;

  /// No description provided for @verifyLineReachable.
  ///
  /// In en, this message translates to:
  /// **'Verify line is reachable'**
  String get verifyLineReachable;

  /// No description provided for @checkCompleted1x.
  ///
  /// In en, this message translates to:
  /// **'1x Check Completed'**
  String get checkCompleted1x;

  /// No description provided for @starterPlan1xCompleted.
  ///
  /// In en, this message translates to:
  /// **'Starter plan 1x check completed. Upgrade to Premium for unlimited checks.'**
  String get starterPlan1xCompleted;

  /// No description provided for @leaveCountry.
  ///
  /// In en, this message translates to:
  /// **'Leave {countryName}'**
  String leaveCountry(String countryName);

  /// No description provided for @resumeProtectionLayers.
  ///
  /// In en, this message translates to:
  /// **'Resume protection layers'**
  String get resumeProtectionLayers;

  /// No description provided for @backToCountryMode.
  ///
  /// In en, this message translates to:
  /// **'Back to {countryName} mode'**
  String backToCountryMode(String countryName);

  /// No description provided for @pauseWhileVisitingHome.
  ///
  /// In en, this message translates to:
  /// **'Pause while visiting home'**
  String get pauseWhileVisitingHome;

  /// No description provided for @rechargeFromFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Recharge from a Friend'**
  String get rechargeFromFriendTitle;

  /// No description provided for @selectPlatformShare.
  ///
  /// In en, this message translates to:
  /// **'Select a platform to share a recharge request message with your friend.'**
  String get selectPlatformShare;

  /// No description provided for @rechargeRequestTemplate.
  ///
  /// In en, this message translates to:
  /// **'Hi! My KeepSIMs card ({phone}) is expiring soon. Could you please recharge it for me?. Thank you!'**
  String rechargeRequestTemplate(String phone);

  /// No description provided for @requestViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Request via WhatsApp'**
  String get requestViaWhatsApp;

  /// No description provided for @couldNotLaunchLink.
  ///
  /// In en, this message translates to:
  /// **'Could not launch {platformName} link: {error}'**
  String couldNotLaunchLink(String platformName, String error);

  /// No description provided for @couldNotLaunchTelegram.
  ///
  /// In en, this message translates to:
  /// **'Could not launch Telegram link: {error}'**
  String couldNotLaunchTelegram(String error);

  /// No description provided for @protectionLayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Protection Layers'**
  String get protectionLayersLabel;

  /// No description provided for @autoNotifyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-Notify: Disabled'**
  String get autoNotifyDisabled;

  /// No description provided for @noActiveAlertSchedule.
  ///
  /// In en, this message translates to:
  /// **'Your SIM card has no active alert notification schedule. You will not receive automatic reminders or deactivation alerts.'**
  String get noActiveAlertSchedule;

  /// No description provided for @askOwnerConfigureAlerts.
  ///
  /// In en, this message translates to:
  /// **'Please ask the household owner to configure alerts.'**
  String get askOwnerConfigureAlerts;

  /// No description provided for @configureAutoNotify.
  ///
  /// In en, this message translates to:
  /// **'Configure Auto-Notify'**
  String get configureAutoNotify;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeLabel;

  /// No description provided for @pausedHomeMode.
  ///
  /// In en, this message translates to:
  /// **'PAUSED (HOME MODE)'**
  String get pausedHomeMode;

  /// No description provided for @pausedLabel.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get pausedLabel;

  /// No description provided for @everyHour.
  ///
  /// In en, this message translates to:
  /// **'Every 1 hour'**
  String get everyHour;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days'**
  String everyNDays(int days);

  /// No description provided for @nextAlertCheck.
  ///
  /// In en, this message translates to:
  /// **'Next Alert Check'**
  String get nextAlertCheck;

  /// No description provided for @premiumKeepAliveRefill.
  ///
  /// In en, this message translates to:
  /// **'Premium Keep-Alive Refill'**
  String get premiumKeepAliveRefill;

  /// No description provided for @autoRefillIncludedText.
  ///
  /// In en, this message translates to:
  /// **'Auto-refill included - ~3.5 USD (telecom, VAT included) every 85 days,\\nnext refill on {date}'**
  String autoRefillIncludedText(String date);

  /// No description provided for @premiumKeepAliveDisabled.
  ///
  /// In en, this message translates to:
  /// **'Premium keep-alive refill is currently disabled.'**
  String get premiumKeepAliveDisabled;

  /// No description provided for @customAutoRefill.
  ///
  /// In en, this message translates to:
  /// **'Custom Auto-Refill'**
  String get customAutoRefill;

  /// No description provided for @addAdditionalScheduledRecharge.
  ///
  /// In en, this message translates to:
  /// **'Add an additional scheduled recharge amount to keep an extra balance on your SIM.'**
  String get addAdditionalScheduledRecharge;

  /// No description provided for @askOwnerConfigureRefill.
  ///
  /// In en, this message translates to:
  /// **'Please ask the household owner to configure Auto-Refill.'**
  String get askOwnerConfigureRefill;

  /// No description provided for @configureCustomAutoRefill.
  ///
  /// In en, this message translates to:
  /// **'Configure Custom Auto-Refill'**
  String get configureCustomAutoRefill;

  /// No description provided for @rechargeAmount.
  ///
  /// In en, this message translates to:
  /// **'Recharge Amount'**
  String get rechargeAmount;

  /// No description provided for @refillInterval.
  ///
  /// In en, this message translates to:
  /// **'Refill Interval'**
  String get refillInterval;

  /// No description provided for @nextRefillDue.
  ///
  /// In en, this message translates to:
  /// **'Next Refill Due'**
  String get nextRefillDue;

  /// No description provided for @failedRefillAttempts.
  ///
  /// In en, this message translates to:
  /// **'Failed Refill Attempts'**
  String get failedRefillAttempts;

  /// No description provided for @retriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / 4 retries'**
  String retriesCount(int count);

  /// No description provided for @editRefillAmount.
  ///
  /// In en, this message translates to:
  /// **'Edit Refill Amount'**
  String get editRefillAmount;

  /// No description provided for @refillExecutionsHistory.
  ///
  /// In en, this message translates to:
  /// **'Refill Executions History'**
  String get refillExecutionsHistory;

  /// No description provided for @renewalExecutionsHistory.
  ///
  /// In en, this message translates to:
  /// **'Renewal Executions History'**
  String get renewalExecutionsHistory;

  /// No description provided for @noHistoricalTopup.
  ///
  /// In en, this message translates to:
  /// **'No historical top-up executions recorded for this line yet.'**
  String get noHistoricalTopup;

  /// No description provided for @noHistoricalRenewal.
  ///
  /// In en, this message translates to:
  /// **'No historical renewal executions recorded for this line yet.'**
  String get noHistoricalRenewal;

  /// No description provided for @viewAllHistory.
  ///
  /// In en, this message translates to:
  /// **'View All History'**
  String get viewAllHistory;

  /// No description provided for @securityActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'Security Activity Logs'**
  String get securityActivityLogs;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @noActivityLogsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No activity logs recorded for this line yet.'**
  String get noActivityLogsRecorded;

  /// No description provided for @activityLogDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity log entry deleted.'**
  String get activityLogDeleted;

  /// No description provided for @activityLogsCleared.
  ///
  /// In en, this message translates to:
  /// **'Activity logs cleared successfully.'**
  String get activityLogsCleared;

  /// No description provided for @autoRenewalStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Auto-Renewal successfully {status}.'**
  String autoRenewalStatusUpdated(String status);

  /// No description provided for @failedToUpdateSchedule.
  ///
  /// In en, this message translates to:
  /// **'Failed to update schedule: {error}'**
  String failedToUpdateSchedule(String error);

  /// No description provided for @premiumRefillEnabled.
  ///
  /// In en, this message translates to:
  /// **'Premium keep-alive refill enabled successfully.'**
  String get premiumRefillEnabled;

  /// No description provided for @failedToEnableAutoRefill.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable auto-refill: {error}'**
  String failedToEnableAutoRefill(String error);

  /// No description provided for @removeScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Schedule'**
  String get removeScheduleTitle;

  /// No description provided for @confirmDeleteAutoRefill.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this auto-refill schedule? Your SIM health score will drop significantly, risking deactivation.'**
  String get confirmDeleteAutoRefill;

  /// No description provided for @confirmDeleteAutoRenewal.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this auto-renewal schedule? Your SIM health score will drop significantly, risking deactivation.'**
  String get confirmDeleteAutoRenewal;

  /// No description provided for @autoRefillRemoved.
  ///
  /// In en, this message translates to:
  /// **'Auto-refill schedule removed successfully.'**
  String get autoRefillRemoved;

  /// No description provided for @autoRenewalRemoved.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal schedule removed successfully.'**
  String get autoRenewalRemoved;

  /// No description provided for @failedToDeleteSchedule.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete schedule: {error}'**
  String failedToDeleteSchedule(String error);

  /// No description provided for @refillRetrySuccess.
  ///
  /// In en, this message translates to:
  /// **'Refill retry completed successfully!'**
  String get refillRetrySuccess;

  /// No description provided for @refillRetryQueued.
  ///
  /// In en, this message translates to:
  /// **'Retry queued — the refill is being processed.'**
  String get refillRetryQueued;

  /// No description provided for @renewalRetrySuccess.
  ///
  /// In en, this message translates to:
  /// **'Renewal retry completed successfully!'**
  String get renewalRetrySuccess;

  /// No description provided for @retryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {error}'**
  String retryFailed(String error);

  /// No description provided for @retryExecutionError.
  ///
  /// In en, this message translates to:
  /// **'Retry execution error: {error}'**
  String retryExecutionError(String error);

  /// No description provided for @failedToDeleteActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete activity log: {error}'**
  String failedToDeleteActivityLog(String error);

  /// No description provided for @failedToClearActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear activity logs: {error}'**
  String failedToClearActivityLogs(String error);

  /// No description provided for @removeProtectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Protection'**
  String get removeProtectionTitle;

  /// No description provided for @confirmRemoveProtectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop keeping {name} protected? Scheduled top-ups for this SIM line will be permanently cancelled.'**
  String confirmRemoveProtectionDesc(String name);

  /// No description provided for @simLineProtectionRemoved.
  ///
  /// In en, this message translates to:
  /// **'SIM line protection removed successfully.'**
  String get simLineProtectionRemoved;

  /// No description provided for @failedToDeleteSimLine.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDeleteSimLine(String error);

  /// No description provided for @editSimNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit SIM Name'**
  String get editSimNameTitle;

  /// No description provided for @enterNicknameInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname for this SIM card line:'**
  String get enterNicknameInstruction;

  /// No description provided for @nicknameExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. My Orange Egypt SIM'**
  String get nicknameExampleHint;

  /// No description provided for @simNameUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'SIM name updated successfully.'**
  String get simNameUpdatedSuccess;

  /// No description provided for @failedToUpdateSimName.
  ///
  /// In en, this message translates to:
  /// **'Failed to update SIM name: {error}'**
  String failedToUpdateSimName(String error);

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @autoNotifySchedule.
  ///
  /// In en, this message translates to:
  /// **'Auto-Notify Schedule'**
  String get autoNotifySchedule;

  /// No description provided for @renewalCheckInterval.
  ///
  /// In en, this message translates to:
  /// **'Renewal Check Interval'**
  String get renewalCheckInterval;

  /// No description provided for @editNotificationConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit Notification Config'**
  String get editNotificationConfig;

  /// No description provided for @openTicket.
  ///
  /// In en, this message translates to:
  /// **'Open Ticket'**
  String get openTicket;

  /// No description provided for @offlineRefillLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline Refill'**
  String get offlineRefillLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @techSupportCategory.
  ///
  /// In en, this message translates to:
  /// **'Technical Support'**
  String get techSupportCategory;

  /// No description provided for @billingWalletCategory.
  ///
  /// In en, this message translates to:
  /// **'Billing & Wallet'**
  String get billingWalletCategory;

  /// No description provided for @simLinesCategory.
  ///
  /// In en, this message translates to:
  /// **'SIM Lines Management'**
  String get simLinesCategory;

  /// No description provided for @feedbackOtherCategory.
  ///
  /// In en, this message translates to:
  /// **'Feedback & Other'**
  String get feedbackOtherCategory;

  /// No description provided for @subjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectLabel;

  /// No description provided for @subjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of the issue'**
  String get subjectHint;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue in detail...'**
  String get descriptionHint;

  /// No description provided for @attachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment (Optional)'**
  String get attachmentLabel;

  /// No description provided for @uploadScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Upload Screenshot'**
  String get uploadScreenshot;

  /// No description provided for @submitTicketButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicketButton;

  /// No description provided for @pleaseFillFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in both subject and description'**
  String get pleaseFillFields;

  /// No description provided for @ticketSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ticket submitted successfully!'**
  String get ticketSubmittedSuccess;

  /// No description provided for @lastRefillLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Refill'**
  String get lastRefillLabel;

  /// No description provided for @noRefillYet.
  ///
  /// In en, this message translates to:
  /// **'No refill yet'**
  String get noRefillYet;

  /// No description provided for @nextAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Alert'**
  String get nextAlertLabel;

  /// No description provided for @protectionLabel.
  ///
  /// In en, this message translates to:
  /// **'PROTECTION'**
  String get protectionLabel;

  /// No description provided for @actionRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Action Req.'**
  String get actionRequiredLabel;

  /// No description provided for @protectionOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Protection Off'**
  String get protectionOffLabel;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @homeMode.
  ///
  /// In en, this message translates to:
  /// **'Home Mode'**
  String get homeMode;

  /// No description provided for @keepProtectedAtHome.
  ///
  /// In en, this message translates to:
  /// **'Keep protected at home'**
  String get keepProtectedAtHome;

  /// No description provided for @protectionPausesAtHome.
  ///
  /// In en, this message translates to:
  /// **'Protection pauses at home'**
  String get protectionPausesAtHome;

  /// No description provided for @incidentChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Incident Channels'**
  String get incidentChannelsTitle;

  /// No description provided for @topUpSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up Successful'**
  String get topUpSuccessTitle;

  /// No description provided for @topUpSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify me when an automatic SIM validity extension is completed successfully.'**
  String get topUpSuccessDesc;

  /// No description provided for @topUpFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up Failed (Critical)'**
  String get topUpFailedTitle;

  /// No description provided for @topUpFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts when automatic top-ups fail due to carrier or wallet issues.'**
  String get topUpFailedDesc;

  /// No description provided for @walletLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Wallet Balance'**
  String get walletLowTitle;

  /// No description provided for @walletLowDesc.
  ///
  /// In en, this message translates to:
  /// **'Warn me when primary balance drops below the safety threshold.'**
  String get walletLowDesc;

  /// No description provided for @walletDepletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Depleted'**
  String get walletDepletedTitle;

  /// No description provided for @walletDepletedDesc.
  ///
  /// In en, this message translates to:
  /// **'Suspended alerts when wallet balance is fully exhausted and renewals halt.'**
  String get walletDepletedDesc;

  /// No description provided for @lineCriticalTitle.
  ///
  /// In en, this message translates to:
  /// **'Validity Expiry Warning'**
  String get lineCriticalTitle;

  /// No description provided for @lineCriticalDesc.
  ///
  /// In en, this message translates to:
  /// **'Warn me when a SIM validity window is ending within 48 hours.'**
  String get lineCriticalDesc;

  /// No description provided for @lineEnteringGraceTitle.
  ///
  /// In en, this message translates to:
  /// **'Entering Grace Period'**
  String get lineEnteringGraceTitle;

  /// No description provided for @lineEnteringGraceDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify me when carrier deactivation grace periods are detected.'**
  String get lineEnteringGraceDesc;

  /// No description provided for @geoFenceTriggeredTitle.
  ///
  /// In en, this message translates to:
  /// **'Location / Roaming Alerts'**
  String get geoFenceTriggeredTitle;

  /// No description provided for @geoFenceTriggeredDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts when carrier switches roaming clusters or network nodes.'**
  String get geoFenceTriggeredDesc;

  /// No description provided for @welcomeHomeReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Home Sync'**
  String get welcomeHomeReadyTitle;

  /// No description provided for @welcomeHomeReadyDesc.
  ///
  /// In en, this message translates to:
  /// **'Alerts when home-country network node triggers automated syncs.'**
  String get welcomeHomeReadyDesc;

  /// No description provided for @referralRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Referral & Rewards'**
  String get referralRewardTitle;

  /// No description provided for @referralRewardDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify me when friend referrals deposit promotional balances into my wallet.'**
  String get referralRewardDesc;

  /// No description provided for @systemUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'General System Updates'**
  String get systemUpdatesTitle;

  /// No description provided for @systemUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Vital engine updates, maintenance, and platform announcements.'**
  String get systemUpdatesDesc;

  /// No description provided for @walletCreditTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Credited'**
  String get walletCreditTitle;

  /// No description provided for @walletCreditDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify me when a deposit lands in my wallet.'**
  String get walletCreditDesc;

  /// No description provided for @promoTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers & Promotions'**
  String get promoTitle;

  /// No description provided for @promoDesc.
  ///
  /// In en, this message translates to:
  /// **'Occasional news about deals and new features. Stays off until you turn it on.'**
  String get promoDesc;

  /// No description provided for @deliverVia.
  ///
  /// In en, this message translates to:
  /// **'Deliver via'**
  String get deliverVia;

  /// No description provided for @channelPushShort.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get channelPushShort;

  /// No description provided for @channelEmailShort.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get channelEmailShort;

  /// No description provided for @channelOffGlobally.
  ///
  /// In en, this message translates to:
  /// **'Off in Alert Channels above'**
  String get channelOffGlobally;

  /// No description provided for @rescheduleRefill.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Refill'**
  String get rescheduleRefill;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @confirmResetRefill.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset the scheduled refill date to default?'**
  String get confirmResetRefill;

  /// No description provided for @refillDateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Scheduled refill date updated successfully'**
  String get refillDateUpdated;

  /// No description provided for @failedToUpdateRefillDate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update scheduled refill date: {error}'**
  String failedToUpdateRefillDate(String error);

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change Date'**
  String get changeDate;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @refillScheduleConfig.
  ///
  /// In en, this message translates to:
  /// **'Refill Schedule Config'**
  String get refillScheduleConfig;

  /// No description provided for @refillExecutionNum.
  ///
  /// In en, this message translates to:
  /// **'Refill {number}'**
  String refillExecutionNum(int number);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @rechargeNow.
  ///
  /// In en, this message translates to:
  /// **'Recharge Now'**
  String get rechargeNow;

  /// No description provided for @planFeePaidFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Plan fee paid from your wallet balance.'**
  String get planFeePaidFromWallet;

  /// No description provided for @activityTopupRequested.
  ///
  /// In en, this message translates to:
  /// **'Refill request submitted for \${amount}'**
  String activityTopupRequested(String amount);

  /// No description provided for @activityTopupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Top-up of \${amount} completed via {provider}'**
  String activityTopupSuccess(String amount, String provider);

  /// No description provided for @activityTopupFailed.
  ///
  /// In en, this message translates to:
  /// **'Top-up of \${amount} failed: {reason}'**
  String activityTopupFailed(String amount, String reason);

  /// No description provided for @activityTopupRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refill of \${amount} refunded to wallet'**
  String activityTopupRefunded(String amount);

  /// No description provided for @activityTopupCancelled.
  ///
  /// In en, this message translates to:
  /// **'Refill request of \${amount} cancelled'**
  String activityTopupCancelled(String amount);

  /// No description provided for @activityTopupRetryQueued.
  ///
  /// In en, this message translates to:
  /// **'Retry queued for refill of \${amount}'**
  String activityTopupRetryQueued(String amount);

  /// No description provided for @activityLineCreated.
  ///
  /// In en, this message translates to:
  /// **'SIM Line registered in SIM Shield'**
  String get activityLineCreated;

  /// No description provided for @activityHealthUpdate.
  ///
  /// In en, this message translates to:
  /// **'SIM Line active status verified'**
  String get activityHealthUpdate;

  /// No description provided for @activityReminderSent.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminder notification sent'**
  String get activityReminderSent;

  /// No description provided for @supportTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get supportTicketsTitle;

  /// No description provided for @supportTicketsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit support requests, attach activity logs, and chat live with our support team.'**
  String get supportTicketsSubtitle;

  /// No description provided for @supportTicketsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No support tickets found.'**
  String get supportTicketsEmpty;

  /// No description provided for @createSupportTicket.
  ///
  /// In en, this message translates to:
  /// **'Create Ticket'**
  String get createSupportTicket;

  /// No description provided for @ticketCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Inquiry'**
  String get ticketCategoryGeneral;

  /// No description provided for @ticketCategoryBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing & Wallet'**
  String get ticketCategoryBilling;

  /// No description provided for @ticketCategoryTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical Issue'**
  String get ticketCategoryTechnical;

  /// No description provided for @ticketCategoryRefillIssue.
  ///
  /// In en, this message translates to:
  /// **'Refill Issue'**
  String get ticketCategoryRefillIssue;

  /// No description provided for @ticketCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get ticketCategoryAccount;

  /// No description provided for @ticketStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get ticketStatusOpen;

  /// No description provided for @ticketStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Reply'**
  String get ticketStatusPending;

  /// No description provided for @ticketStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get ticketStatusResolved;

  /// No description provided for @ticketStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get ticketStatusClosed;

  /// No description provided for @ticketSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get ticketSubjectLabel;

  /// No description provided for @ticketSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the issue'**
  String get ticketSubjectHint;

  /// No description provided for @ticketCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ticketCategoryLabel;

  /// No description provided for @ticketMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get ticketMessageLabel;

  /// No description provided for @ticketMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Provide detailed information...'**
  String get ticketMessageHint;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach Image'**
  String get attachImage;

  /// No description provided for @attachActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'Attach Line Logs'**
  String get attachActivityLogs;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicket;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessageHint;

  /// No description provided for @closeTicketButton.
  ///
  /// In en, this message translates to:
  /// **'Close Ticket'**
  String get closeTicketButton;

  /// No description provided for @ticketClosedNotice.
  ///
  /// In en, this message translates to:
  /// **'This support ticket has been closed.'**
  String get ticketClosedNotice;

  /// No description provided for @attachedFiles.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachedFiles;

  /// No description provided for @referralsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referralsTitle;

  /// No description provided for @referralsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends, earn points on SIM subscriptions, and redeem for wallet credits!'**
  String get referralsSubtitle;

  /// No description provided for @referralCode.
  ///
  /// In en, this message translates to:
  /// **'Your Referral Code'**
  String get referralCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied to clipboard!'**
  String get codeCopied;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get shareCode;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Points Balance'**
  String get pointsBalance;

  /// No description provided for @pointsUnit.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsUnit;

  /// No description provided for @progressToNextRedemption.
  ///
  /// In en, this message translates to:
  /// **'{pointsNeeded} more points until next \$2.00 reward'**
  String progressToNextRedemption(Object pointsNeeded);

  /// No description provided for @redeemButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem 10 Points for \$2.00'**
  String get redeemButton;

  /// No description provided for @redeemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully redeemed 10 points for \$2.00 wallet credit!'**
  String get redeemSuccess;

  /// No description provided for @applyCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Have a Referral Code?'**
  String get applyCodeTitle;

  /// No description provided for @applyCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter referral code'**
  String get applyCodeHint;

  /// No description provided for @applyCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Apply Code'**
  String get applyCodeButton;

  /// No description provided for @applyCodeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Referral code applied successfully!'**
  String get applyCodeSuccess;

  /// No description provided for @referredFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Referred Friends'**
  String get referredFriendsTitle;

  /// No description provided for @noReferredFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends referred yet. Share your code to get started!'**
  String get noReferredFriends;

  /// No description provided for @redemptionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Redemption History'**
  String get redemptionHistoryTitle;

  /// No description provided for @noRedemptions.
  ///
  /// In en, this message translates to:
  /// **'No redemptions yet.'**
  String get noRedemptions;

  /// No description provided for @pointHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Points History'**
  String get pointHistoryTitle;

  /// No description provided for @noPointsEarned.
  ///
  /// In en, this message translates to:
  /// **'No points earned yet.'**
  String get noPointsEarned;

  /// No description provided for @howItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How Refer & Earn Works'**
  String get howItWorksTitle;

  /// No description provided for @howItWorksStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Share your unique referral code with friends.'**
  String get howItWorksStep1;

  /// No description provided for @howItWorksStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Earn 1 point whenever a referred friend subscribes a SIM line.'**
  String get howItWorksStep2;

  /// No description provided for @howItWorksStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Redeem 10 points for \$2.00 spendable wallet credit anytime!'**
  String get howItWorksStep3;

  /// No description provided for @geoTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel & Geolocation'**
  String get geoTitle;

  /// No description provided for @geoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic country detection and international SIM line protection'**
  String get geoSubtitle;

  /// No description provided for @currentCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentCountryLabel;

  /// No description provided for @travelModeToggle.
  ///
  /// In en, this message translates to:
  /// **'Travel Mode'**
  String get travelModeToggle;

  /// No description provided for @travelModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Check country when opening the app to manage international line protection'**
  String get travelModeDescription;

  /// No description provided for @geoNotice.
  ///
  /// In en, this message translates to:
  /// **'Country is checked via IP lookup when you open the app. No location permissions required.'**
  String get geoNotice;

  /// No description provided for @freezeInternationalLines.
  ///
  /// In en, this message translates to:
  /// **'Freeze International Lines'**
  String get freezeInternationalLines;

  /// No description provided for @resumeInternationalLines.
  ///
  /// In en, this message translates to:
  /// **'Resume International Lines'**
  String get resumeInternationalLines;

  /// No description provided for @linesFrozenSuccess.
  ///
  /// In en, this message translates to:
  /// **'International SIM lines frozen and scheduled refills paused!'**
  String get linesFrozenSuccess;

  /// No description provided for @linesResumedSuccess.
  ///
  /// In en, this message translates to:
  /// **'International SIM lines and refills reactivated!'**
  String get linesResumedSuccess;

  /// No description provided for @alwaysProtectedBadge.
  ///
  /// In en, this message translates to:
  /// **'Always Protected'**
  String get alwaysProtectedBadge;

  /// No description provided for @detectedViaIp.
  ///
  /// In en, this message translates to:
  /// **'Detected via IP'**
  String get detectedViaIp;

  /// No description provided for @esimManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'eSIM Manager'**
  String get esimManagerTitle;

  /// No description provided for @esimPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'eSIM Plans'**
  String get esimPlansTitle;

  /// No description provided for @searchDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Search destination (e.g. France, United States)'**
  String get searchDestinationHint;

  /// No description provided for @selectDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Destination'**
  String get selectDestinationTitle;

  /// No description provided for @localTab.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localTab;

  /// No description provided for @regionalTab.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get regionalTab;

  /// No description provided for @globalTab.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalTab;

  /// No description provided for @bestValueBadge.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get bestValueBadge;

  /// No description provided for @perGb.
  ///
  /// In en, this message translates to:
  /// **'/ GB'**
  String get perGb;

  /// No description provided for @validityDays.
  ///
  /// In en, this message translates to:
  /// **'{days} Days'**
  String validityDays(Object days);

  /// No description provided for @buyPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Buy Plan'**
  String get buyPlanButton;

  /// No description provided for @deviceIncompatibleNotice.
  ///
  /// In en, this message translates to:
  /// **'Your device does not support eSIM functionality.'**
  String get deviceIncompatibleNotice;

  /// No description provided for @activationPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Activation Policy'**
  String get activationPolicyTitle;

  /// No description provided for @activationPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'Validity starts when the eSIM connects to a supported network at your destination.'**
  String get activationPolicyNotice;

  /// No description provided for @coveredCountriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Covered Countries'**
  String get coveredCountriesTitle;

  /// No description provided for @sortPriceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get sortPriceLowToHigh;

  /// No description provided for @sortPricePerGb.
  ///
  /// In en, this message translates to:
  /// **'Price / GB: Low to High'**
  String get sortPricePerGb;

  /// No description provided for @sortDataHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Data: High to Low'**
  String get sortDataHighToLow;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All Plans'**
  String get filterAll;

  /// No description provided for @filterMin5Gb.
  ///
  /// In en, this message translates to:
  /// **'≥ 5 GB'**
  String get filterMin5Gb;

  /// No description provided for @filterMin15Days.
  ///
  /// In en, this message translates to:
  /// **'≥ 15 Days'**
  String get filterMin15Days;

  /// No description provided for @filterUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get filterUnlimited;

  /// No description provided for @purchaseInNextRelease.
  ///
  /// In en, this message translates to:
  /// **'Purchase flow will land in the next release (C9b).'**
  String get purchaseInNextRelease;

  /// No description provided for @confirmPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm eSIM Purchase'**
  String get confirmPurchaseTitle;

  /// No description provided for @myEsimsTitle.
  ///
  /// In en, this message translates to:
  /// **'My eSIMs'**
  String get myEsimsTitle;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get showQrCode;

  /// No description provided for @buyAgain.
  ///
  /// In en, this message translates to:
  /// **'Buy Again'**
  String get buyAgain;

  /// No description provided for @dataRemaining.
  ///
  /// In en, this message translates to:
  /// **'Data Remaining'**
  String get dataRemaining;

  /// No description provided for @archivedEsims.
  ///
  /// In en, this message translates to:
  /// **'Archived eSIMs'**
  String get archivedEsims;

  /// Error message when rate limit is exceeded
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait {seconds} seconds before trying again.'**
  String rateLimitExceeded(String seconds);

  /// No description provided for @confirmDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDeleteButton;

  /// No description provided for @cancelAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Cancel Account Deletion'**
  String get cancelAccountDeletion;

  /// No description provided for @accountScheduledForDeletion.
  ///
  /// In en, this message translates to:
  /// **'Account Scheduled for Deletion'**
  String get accountScheduledForDeletion;

  /// Notice for scheduled deletion date
  ///
  /// In en, this message translates to:
  /// **'Your account is frozen and scheduled for permanent deletion on {date}.'**
  String deletionScheduledNotice(String date);

  /// Notice when balance exceeds dust limit
  ///
  /// In en, this message translates to:
  /// **'Your wallet balance (\${balance}) exceeds dust limit (\$1.00). Please spend it or contact support for payout.'**
  String walletBalanceBlockedNotice(String balance);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'en',
    'es',
    'hi',
    'ne',
    'si',
    'tr',
    'ur',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'ne':
      return AppLocalizationsNe();
    case 'si':
      return AppLocalizationsSi();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
