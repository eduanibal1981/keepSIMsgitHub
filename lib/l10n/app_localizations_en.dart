// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'Preferences & Security';

  @override
  String get appAppearance => 'App Appearance';

  @override
  String get systemTheme => 'System';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get localizationAndRegional => 'Localization & Regional';

  @override
  String get appLanguage => 'App Language';

  @override
  String currentlyUsing(String langName) {
    return 'Currently using regional $langName';
  }

  @override
  String get selectAppLanguage => 'Select App Language';

  @override
  String get securityAndAccessLock => 'Security & Access Lock';

  @override
  String get biometricSecurity => 'Biometric Security';

  @override
  String get biometricDesc => 'Sign in using Face ID or Touch ID';

  @override
  String get biometricReasonPayment => 'Authenticate to confirm payment';

  @override
  String get biometricReasonUnlock => 'Authenticate to unlock KeepSIMs';

  @override
  String get biometricLockout =>
      'Biometric authentication locked due to too many failed attempts. Please use your device passcode to unlock.';

  @override
  String get biometricNotEnrolled =>
      'Biometric authentication is not set up on this device.';

  @override
  String get biometricAppLockTitle => 'KeepSIMs is Locked';

  @override
  String get biometricUnlockButton => 'Unlock with Biometrics';

  @override
  String get biometricCancel => 'Cancel';

  @override
  String get transactionPin => 'Transaction PIN';

  @override
  String get transactionPinDesc => 'Secure renewals and withdrawals';

  @override
  String get setup => 'SETUP';

  @override
  String get pinSuccess => 'Transaction PIN successfully updated!';

  @override
  String get pinMismatch => 'PINs do not match. Try again!';

  @override
  String get pinActiveAndSecure => 'PIN setup is active and secure';

  @override
  String get automatedSummaryAndAlerts => 'Automated Summary & Alerts';

  @override
  String get weeklyDigest => 'Weekly Digest';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get nextNotify => 'NEXT NOTIFY';

  @override
  String get days => 'days';

  @override
  String get showingNearestLine => 'Showing nearest line';

  @override
  String get addSim => 'Add SIM';

  @override
  String get linesToProtect => 'Lines to Protect';

  @override
  String get active => 'Active';

  @override
  String get upgrade => 'UPGRADE';

  @override
  String get standard => 'STANDARD';

  @override
  String get autoNotify => 'Auto-Notify';

  @override
  String get configure => 'Configure';

  @override
  String get autoRefill => 'Auto-Refill';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get navHome => 'Home';

  @override
  String get navSims => 'SIMs';

  @override
  String get navMore => 'More';

  @override
  String get protectedSims => 'Protected SIMs';

  @override
  String get mySimCards => 'My SIM Cards';

  @override
  String get familySharedSims => 'Family Shared SIMs';

  @override
  String get protectAnotherSimLine => 'Protect Another SIM Line';

  @override
  String get keepInfiniteNumbersAlive =>
      'Keep infinite international numbers alive';

  @override
  String get bulkActionsConsole => 'Bulk Actions Console';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get simulate => 'Simulate';

  @override
  String get noProtectedLines => 'No Protected Lines';

  @override
  String get noInternationalSimsAdded =>
      'You don\'t have any international SIM cards added yet. Protect your first card now to keep it active forever.';

  @override
  String get protectNewLine => 'Protect New Line';

  @override
  String get noSharedSimsYet => 'No Shared SIMs yet';

  @override
  String get inviteFamilyMembers =>
      'Invite family members to join your Household. Once they accept, their protected SIM lines will appear here for collaborative monitoring.';

  @override
  String get manageHousehold => 'Manage Household';

  @override
  String get manageProfileDesc =>
      'Manage your profile, SIM lines, alerts, and shared preferences';

  @override
  String get keepSIMsUser => 'KeepSIMs User';

  @override
  String get pro => 'PRO';

  @override
  String get homeCountry => 'Home Country: ';

  @override
  String get console => 'Console';

  @override
  String get offlineRefill => 'Offline Refill (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'Refill SIM balance offline via SMS or WhatsApp';

  @override
  String get wallet => 'Wallet';

  @override
  String get manageBalancesDesc =>
      'Manage your balances and view transaction history';

  @override
  String get alertPreferences => 'Alert Preferences';

  @override
  String get togglePushEmailDesc =>
      'Toggle push & email settings for renewals/balances';

  @override
  String get referAndEarn => 'Refer & Earn';

  @override
  String get shareKeepSIMsDesc =>
      'Share KeepSIMs, unlock dynamic balance rewards';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get addBankCardsDesc =>
      'Add bank cards or link auto-withdrawal accounts';

  @override
  String get travelAndGeolocation => 'Travel & Geolocation';

  @override
  String get manageHomeCountryDesc =>
      'Manage home country freeze rules & travel mode';

  @override
  String get dataAndPrivacy => 'Data & Privacy';

  @override
  String get manageTrackingConsentDesc =>
      'Manage your tracking consent, export data, or delete account';

  @override
  String get powerUser => 'Power User';

  @override
  String get accessSystemSimulatorsDesc =>
      'Access system simulators and debugging tools';

  @override
  String get testChecklist => 'Test Checklist';

  @override
  String get manualUiTestingDesc =>
      'Manual UI testing checklist for quality assurance';

  @override
  String get soon => 'SOON';

  @override
  String featureComingSoon(String feature) {
    return '$feature feature is coming soon!';
  }

  @override
  String get logOut => 'Log Out';

  @override
  String get confirmLogOut => 'Are you sure you want to log out of KeepSIMs?';

  @override
  String get walletLedger => 'Wallet Ledger';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs PREPAID';

  @override
  String get offlineMode => 'OFFLINE MODE';

  @override
  String get activeBalance => 'Active Balance';

  @override
  String get criticalBalanceLevel => 'Critical Balance Level';

  @override
  String get balanceBelow10 =>
      'Your balance is below \$10.00. Scheduled SIM topups may fail soon.';

  @override
  String get depositFunds => 'Deposit Funds';

  @override
  String get walletDepositsRequireInternet =>
      'Wallet deposits require an active internet connection.';

  @override
  String get exportLedger => 'Export Ledger';

  @override
  String get ledgerHistoryExported => 'Ledger history exported as CSV.';

  @override
  String get spendAnalysis => 'Spend Analysis';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get noTransactionsRecorded => 'No transactions recorded yet.';

  @override
  String get prepaidMonthlyOutflow => 'Prepaid Monthly Outflow';

  @override
  String avgMonthlySpend(String amount) {
    return 'Avg: \$$amount/mo (12M)';
  }

  @override
  String depositViaCard(String last4) {
    return 'Deposit via Card ending in $last4';
  }

  @override
  String get lineRenewal => 'Line Renewal';

  @override
  String get justNow => 'Just now';

  @override
  String get loadCreditFunds => 'Load Credit Funds';

  @override
  String get depositAmountUsd => 'Deposit Amount (USD)';

  @override
  String get pleaseEnterAmount => 'Please enter an amount';

  @override
  String get enterPositiveNumber => 'Enter a positive number';

  @override
  String get cardDetails => 'Card Details';

  @override
  String get savedCards => 'Saved Cards';

  @override
  String get visaCardNumber => 'Visa Card Number';

  @override
  String get pleaseEnterCardNumber => 'Please enter card number';

  @override
  String get mustBe16Digits => 'Must be 16 digits';

  @override
  String get expiryMmYy => 'Expiry (MM/YY)';

  @override
  String get expiryRequired => 'Expiry required';

  @override
  String get invalid => 'Invalid';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV required';

  @override
  String get verifyingCardSecurity => 'Verifying Card Security...';

  @override
  String get authorizeDepositFunds => 'Authorize Deposit Funds';

  @override
  String successfullyDeposited(String amount) {
    return 'Successfully deposited \$$amount USD!';
  }

  @override
  String get failedToDepositFunds =>
      'Failed to deposit funds. Please check card connection.';

  @override
  String get noSavedPaymentMethods => 'No saved payment methods found.';

  @override
  String get addPaymentMethod => 'Add Payment Method';

  @override
  String get savedPaymentMethods => 'Saved Payment Methods';

  @override
  String get addAnotherPaymentMethod => 'Add another payment method';

  @override
  String expiresMmYy(String month, String year) {
    return 'Expires $month/$year';
  }

  @override
  String get offlineRefillTitle => 'Offline refill';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'Select Target SIM Line';

  @override
  String get noRegisteredSimLines => 'No registered SIM lines found.';

  @override
  String get targetSimLine => 'Target SIM Line';

  @override
  String get simLine => 'SIM Line';

  @override
  String get carrier => 'CARRIER';

  @override
  String get change => 'Change';

  @override
  String get offlineRefillProtection => 'Offline Refill Protection';

  @override
  String get premiumExclusive => 'PREMIUM EXCLUSIVE';

  @override
  String get neverGetStrandedDesc =>
      'Never get stranded without mobile data again. KeepSIMs Premium allows you to refill your SIM card balance offline over standard local SMS or WhatsApp messages when you have zero internet connection.';

  @override
  String get offlineCapability100 => '100% Offline Capability';

  @override
  String get deductsFromKeepSIMsDesc =>
      'Deducts from your KeepSIMs wallet to credit your line via local SMS gateway failovers.';

  @override
  String get dynamicUssdPlanActivation => 'Dynamic USSD Plan Activation';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'Provides exact copy-paste dial codes (e.g., *900*1#) to activate Data+Call packages offline.';

  @override
  String get dualChannelSupport => 'Dual-Channel Support';

  @override
  String get textRefillDesc =>
      'Text \"REFILL\" using standard SMS or WhatsApp depending on what cellular coverage is available.';

  @override
  String get close => 'Close';

  @override
  String get howToTriggerOfflineRefill => 'How to Trigger Offline Refill';

  @override
  String get ifZeroMobileDataDesc1 =>
      'If you have zero mobile data, send a standard SMS or WhatsApp message containing only ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 => ' to our secure system gateway:';

  @override
  String get targetSimLineLabel => 'TARGET SIM LINE';

  @override
  String get configureCashRefillAmount => 'CONFIGURE CASH REFILL AMOUNT';

  @override
  String get refillAmount => 'Refill Amount';

  @override
  String walletBalanceUsd(String amount) {
    return 'Wallet Balance: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ Low Balance';

  @override
  String get localCarrierPlanSuggestions => 'LOCAL CARRIER PLAN SUGGESTIONS';

  @override
  String get noStandardUssdDialCodes =>
      'No standard USSD dial codes found for this carrier. You will still receive the cash refill successfully on your line.';

  @override
  String get dynamicDialCodesPreview => 'Dynamic Dial Codes Preview';

  @override
  String get botSuggestDialingCodes =>
      'After the offline refill completes, the bot will suggest dialing these exact codes on your phone to instantly unlock Data+Calls offline:';

  @override
  String costAmount(String amount) {
    return 'Cost: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'WHATSAPP/SMS SENDER OVERRIDE';

  @override
  String get verificationNumber => 'Verification Number';

  @override
  String get triggerRefillsDifferentNumber =>
      'If you trigger refills from a different number than your main profile phone, enter it below with country code (e.g. 96891234567).';

  @override
  String get enterPhoneNumberDigits => 'Enter phone number (digits only)';

  @override
  String get offlineRefillSettingsSaved =>
      'Offline Refill settings saved successfully!';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String errorLoadingSettings(String error) {
    return 'Error loading settings: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String offlineRefillLinked(String phone) {
    return '$phone is linked';
  }

  @override
  String offlineRefillWalletInfo(String carrier, String balance) {
    return '$carrier line · Wallet balance \$$balance';
  }

  @override
  String get offlineRefillNoFunds => 'Wallet balance too low';

  @override
  String offlineRefillNoFundsSub(String phone, String balance) {
    return '$phone is linked · Balance \$$balance';
  }

  @override
  String get offlineRefillNotLinked => 'This number isn\'t linked yet';

  @override
  String get offlineRefillNotLinkedSub => 'No KeepSIMs line is selected';

  @override
  String get offlineRefillFastest => 'Fastest · Free';

  @override
  String get offlineRefillNeedsFunds => 'Needs wallet funds';

  @override
  String get offlineRefillNotSetUp => 'Not set up';

  @override
  String get offlineRefillCallToTrigger => 'Call to trigger refill';

  @override
  String get offlineRefillAddFunds => 'Add funds to enable';

  @override
  String get offlineRefillLinkFirst => 'Link this number first';

  @override
  String get offlineRefillAddsToNumber => 'Adds to the number you call from';

  @override
  String get offlineRefillFinePrintReady =>
      'We only detect the ring. The call is never answered, so it never costs you anything — even at zero balance.';

  @override
  String get offlineRefillFinePrintNoFunds =>
      'Add balance to your wallet first — an offline refill still needs funds to send.';

  @override
  String get offlineRefillFinePrintUnreg =>
      'Offline refill only works for numbers already added under My Numbers.';

  @override
  String get offlineRefillCopied => 'Copied';

  @override
  String get offlineRefillOtherWays => 'Other ways in';

  @override
  String get offlineRefillIvrTitle => 'Pick your amount';

  @override
  String get offlineRefillIvrSubtitle =>
      'Choose \$5, \$10 or \$25 by key press';

  @override
  String get offlineRefillIvrCost => '~\$0.15/call';

  @override
  String get offlineRefillSmsTitle => 'Text a code';

  @override
  String get offlineRefillSmsSubtitle =>
      'Send REFILL 5, REFILL 10 or REFILL 25';

  @override
  String get offlineRefillSmsCost => 'local SMS rate';

  @override
  String get offlineRefillSmsAction => 'Text \"REFILL 5\"';

  @override
  String get offlineRefillWaTitle => 'Message on WhatsApp';

  @override
  String get offlineRefillWaSubtitle => 'Works on zero-rated data plans';

  @override
  String get offlineRefillWaCost => 'free*';

  @override
  String get offlineRefillWaAction => 'Message \"REFILL\"';

  @override
  String get offlineRefillCallThisNumber => 'Call this number';

  @override
  String get offlineRefillDisclaimer =>
      'Every method matches the refill to the phone number that called, texted, or messaged in. Make sure that\'s the SIM you want topped up. *Only free where your carrier zero-rates WhatsApp data.';

  @override
  String offlineRefillTimelineRinging(String number) {
    return 'Ringing $number';
  }

  @override
  String offlineRefillTimelineDetected(String phone) {
    return 'Missed call detected from $phone';
  }

  @override
  String offlineRefillTimelineSent(String amount, String phone) {
    return '$amount sent to $phone';
  }

  @override
  String get offlineRefillJustNow => 'just now';

  @override
  String get offlineRefillSelectNumber => 'Select a number';

  @override
  String get offlineRefillChannelsHeader => 'Ways to refill offline';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'Top up $amount from your wallet';
  }

  @override
  String get offlineRefillWalletFunded => 'From your wallet';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee fee';
  }

  @override
  String get offlineRefillMissedCallTitle => 'Give a missed call';

  @override
  String get offlineRefillMissedCallSubtitle => 'No balance or data needed';

  @override
  String get offlineRefillCallAction => 'Call to refill';

  @override
  String get offlineRefillRetry => 'Try again';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return 'Wait ${seconds}s';
  }

  @override
  String get offlineRefillStatusSent => 'Sent — awaiting confirmation';

  @override
  String get offlineRefillStatusProcessing => 'Topping up your line…';

  @override
  String get offlineRefillStatusConfirmed => 'Top-up confirmed';

  @override
  String get offlineRefillStatusFailed =>
      'Didn\'t go through — try another way';

  @override
  String get offlineRefillStatusTimedOut => 'No response yet — try another way';

  @override
  String get offlineRefillUssdTitle => 'Get more from your top-up';

  @override
  String get offlineRefillUssdSubtitle =>
      'After the balance lands, dial your carrier\'s code for the best value';

  @override
  String get offlineRefillUssdDial => 'Dial';

  @override
  String get editProtectedLine => 'Edit Protected Line';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get activateShieldProtection => 'Activate Shield Protection';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get nicknameOptional => 'Nickname (Optional)';

  @override
  String get whatsappAlerts => 'WhatsApp Alerts';

  @override
  String get emailAlertsDesc => 'Critical deactivation alerts sent via Resend';

  @override
  String get refillWalletLow => 'Refill wallet when funds drop low';

  @override
  String get legalPoliciesDesc =>
      'By using KeepSIMs, you agree to our terms. KeepSIMs provides tools to help manage your SIM lifecycle, but we are not liable for direct or indirect losses, damages, or service interruptions caused by third-party telecommunication providers.';

  @override
  String get globalTravelModeDesc =>
      'Allows automated geofencing rules to activate border-crossing routines';

  @override
  String get dataPreferences => 'Data Preferences';

  @override
  String get doNotDisturb => 'Do Not Disturb';

  @override
  String get linkedCards => 'Linked Cards';

  @override
  String get analyticsTracking => 'Analytics & Tracking';

  @override
  String get dubai => 'Dubai';

  @override
  String get flyHome => 'Fly Home';

  @override
  String get managePreferencesAndSecurityDesc =>
      'Manage theme, language, and biometric lockouts';

  @override
  String get autoFundingRulesDesc =>
      'Keep SIM renewal running continuously by enabling automatic top-ups from your default credit card when the balance drops too low';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get quietHoursSchedule => 'Quiet Hours & Schedule';

  @override
  String get exportMyDataDesc =>
      'Download a JSON copy of your profile and preferences (GDPR Right to Access)';

  @override
  String get borderSimulatorTitle => 'Border Crossing Simulator';

  @override
  String get yourData => 'Your Data';

  @override
  String get mostImportant => 'Most Important';

  @override
  String get emailAlerts => 'Email Alerts';

  @override
  String get pushNotificationsDesc =>
      'Aggressive native notifications on this device';

  @override
  String get alertSettingsTitle => 'Alert Settings';

  @override
  String get atHome => 'AT HOME';

  @override
  String get telegramBotDesc => 'Bound interactive Telegram chat notifications';

  @override
  String get alertChannels => 'Alert Channels';

  @override
  String get london => 'London';

  @override
  String get shieldProtection => 'Shield Protection';

  @override
  String get legalPolicies => 'Legal & Policies';

  @override
  String get supportVisaMastercard =>
      'Supports secure Visa & MasterCard debit or credit';

  @override
  String get exportMyData => 'Export My Data';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get analyticsTrackingDesc =>
      'Help us improve the app by sharing anonymous usage data. Essential app functionality will not be affected if disabled';

  @override
  String get autoFundingRules => 'Auto-Funding Rules';

  @override
  String get singapore => 'Singapore';

  @override
  String get weeklySummaryDigest => 'Weekly Summary Digest';

  @override
  String get fullyShielded => 'Fully Shielded';

  @override
  String get dndDesc => 'Mute push notifications during specified sleep hours';

  @override
  String get paymentsAutoFundTitle => 'Payments & Auto-Fund';

  @override
  String get travelGeolocationTitle => 'Travel & Geolocation';

  @override
  String get telegramBot => 'Telegram Bot';

  @override
  String get weeklyDigestDesc =>
      'Compiled status report of all SIM cards every Sunday at 9:00 AM';

  @override
  String get borderSimulatorDesc =>
      'Simulate boardings to trigger smart freeze or active country resumption rules.';

  @override
  String get linkFirstCard => 'Link your first payment card';

  @override
  String get globalTravelMode => 'Global Travel Mode';

  @override
  String get readPrivacyPolicy => 'Read Full Privacy Policy & Terms';

  @override
  String get whatsappAlertsDesc =>
      'Refill failure alerts pushed directly to WhatsApp';

  @override
  String get abroadTraveling => 'ABROAD / TRAVELING';

  @override
  String get freezeAllLines => 'Freeze All Lines';

  @override
  String get resumeRenewals => 'Resume Renewals';

  @override
  String get freezeRecommendationDesc =>
      'We detected you are currently in your Home Country. You can freeze renewals on your international lines to prevent unwanted wallet balance depletion.';

  @override
  String get travelDetected => 'Travel Detected! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'You are traveling abroad. Please resume your paused international SIM renewals to ensure uninterrupted mobile network coverage.';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get welcomeHome => 'Welcome Home! 🏡';

  @override
  String get addCard => 'Add Card';

  @override
  String get noAlertChannelsConfigured =>
      'No alert delivery channels configured.';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName settings updated.';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName Locked 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName alerts are Starter and Premium plan features. Upgrade your plan to unlock WhatsApp, Telegram, and Email alerts!';
  }

  @override
  String get upsellProtect5Lines => 'Protect up to 5 SIM lines simultaneously';

  @override
  String get upsellUnlockChannels =>
      'Unlock WhatsApp, Telegram & Email notifications';

  @override
  String get upsellEnableTravelModes =>
      'Enable Travel & Home automated validity modes';

  @override
  String get emailAddressLabel => 'Notification Email Address';

  @override
  String get emailAddressHint => 'e.g. user@domain.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp Number (Int\'l Format)';

  @override
  String get whatsappNumberHint => 'e.g. +96891234567';

  @override
  String get whatsappFormatInstruction =>
      'Enter full international format starting with + (e.g. +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'Status: Bound (Chat ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'Status: Unbound';

  @override
  String get telegramLinkInstructions =>
      'To receive free, interactive Telegram alerts, link our Telegram Bot with your account.';

  @override
  String get linkTelegramBot => 'Link Telegram Bot';

  @override
  String get emailFreePlanGuarded =>
      'Resend Free Plan Guarded: Capped to deactivation triggers only. No promotional spam.';

  @override
  String get whatsappMetaCloudCapped =>
      'Direct Meta Cloud Capped: Maximum 1 message per top-up schedule, sent ONLY if auto-refill is not active or fails.';

  @override
  String get failedToLoadPaymentInfo => 'Failed to load payment info';

  @override
  String get defaultCardIndicator => 'DEFAULT';

  @override
  String get cardholder => 'CARDHOLDER';

  @override
  String get expires => 'EXPIRES';

  @override
  String get lowBalanceTrigger => 'Low Balance Trigger';

  @override
  String get triggerLowTopUp => 'Trigger low top-up';

  @override
  String get reloadDepositAmount => 'Reload Deposit Amount';

  @override
  String get amountToLoad => 'Amount to load';

  @override
  String get linkCreditDebitCard => 'Link Credit/Debit Card';

  @override
  String get cardNumberLabel => 'CARD NUMBER';

  @override
  String get expiryDateLabel => 'EXPIRY DATE';

  @override
  String get cvvCodeLabel => 'CVV CODE';

  @override
  String get securelyLinkCard => 'Securely Link Card';

  @override
  String get pleaseEnterValidCardNumber =>
      'Please enter a valid 16-digit card number.';

  @override
  String get pleaseEnterValidExpiryDate =>
      'Please enter a valid expiry date (MM/YY).';

  @override
  String get invalidExpiryMonth => 'Invalid expiry month.';

  @override
  String get cvvMustBe3Digits => 'CVV must be 3 digits.';

  @override
  String get cardLinkedSuccessfully =>
      'Secure billing card linked successfully!';

  @override
  String get defaultPaymentCardUpdated => 'Default payment card updated!';

  @override
  String get removePaymentCard => 'Remove Payment Card';

  @override
  String get confirmRemoveCardDesc =>
      'Are you sure you want to remove this card? Linked auto-funding might fail if no default payment card remains.';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get billingCardSuccessfullyRemoved =>
      'Billing card successfully removed.';

  @override
  String get pleaseAddDefaultCardFirst =>
      'Please add and select a default payment card first to enable auto-funding.';

  @override
  String get autoFundPrefsSavedSuccess =>
      'Auto-Funding preferences saved successfully!';

  @override
  String get preparingDataExport => 'Preparing data export...';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get deleteAccountWarning =>
      'Once you delete your account, there is no going back. Please be certain.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountIrreversible =>
      'This action is irreversible. All your data will be permanently purged.';

  @override
  String get typeDeleteToConfirm => 'Type \"DELETE\" to confirm:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'SYSTEM DIAGNOSTICS LOGS';

  @override
  String get online => 'ONLINE';

  @override
  String errorLoadingPrefs(String error) {
    return 'Error loading preferences: $error';
  }

  @override
  String get privacyPolicyLoaded => 'Privacy Policy details loaded.';

  @override
  String get protectionConsole => 'Protection Console';

  @override
  String get deleteProtectionTooltip => 'Delete Protection';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get failedToLoadDetails => 'Failed to load details';

  @override
  String get retryConnection => 'Retry Connection';

  @override
  String get healthLabel => 'health';

  @override
  String get mySimCardDefault => 'My SIM Card';

  @override
  String get upLabel => 'UP';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'Shared by: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'Critical risk';

  @override
  String get simDeactivationRisk => 'SIM may deactivate without action';

  @override
  String get missingAlertsDesc =>
      'No alert notifications configured — missing 100 pts';

  @override
  String get missingAutoRefillDesc =>
      'No auto-refill configured — missing 50 pts';

  @override
  String get missingVerificationDesc =>
      'Phone number not verified — missing 25 pts';

  @override
  String get missingRecentRefillDesc =>
      'Last refill was over 80 days ago — missing 25 pts';

  @override
  String get quickActionsLabel => 'Quick Actions';

  @override
  String get manualRefillLabel => 'Manual Refill';

  @override
  String get chargeFromWalletNow => 'Charge from wallet now';

  @override
  String get rechargeFromFriend => 'Recharge from Friend';

  @override
  String get requestViaTelegram => 'Request via Telegram';

  @override
  String get shareViaWaTg => 'Share via WhatsApp/Telegram';

  @override
  String get testSimActivity => 'Test SIM Activity';

  @override
  String get verifyLineReachable => 'Verify line is reachable';

  @override
  String get checkCompleted1x => '1x Check Completed';

  @override
  String get starterPlan1xCompleted =>
      'Starter plan 1x check completed. Upgrade to Premium for unlimited checks.';

  @override
  String leaveCountry(String countryName) {
    return 'Leave $countryName';
  }

  @override
  String get resumeProtectionLayers => 'Resume protection layers';

  @override
  String backToCountryMode(String countryName) {
    return 'Back to $countryName mode';
  }

  @override
  String get pauseWhileVisitingHome => 'Pause while visiting home';

  @override
  String get rechargeFromFriendTitle => 'Recharge from a Friend';

  @override
  String get selectPlatformShare =>
      'Select a platform to share a recharge request message with your friend.';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'Hi! My KeepSIMs card ($phone) is expiring soon. Could you please recharge it for me?. Thank you!';
  }

  @override
  String get requestViaWhatsApp => 'Request via WhatsApp';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return 'Could not launch $platformName link: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Could not launch Telegram link: $error';
  }

  @override
  String get protectionLayersLabel => 'Protection Layers';

  @override
  String get autoNotifyDisabled => 'Auto-Notify: Disabled';

  @override
  String get noActiveAlertSchedule =>
      'Your SIM card has no active alert notification schedule. You will not receive automatic reminders or deactivation alerts.';

  @override
  String get askOwnerConfigureAlerts =>
      'Please ask the household owner to configure alerts.';

  @override
  String get configureAutoNotify => 'Configure Auto-Notify';

  @override
  String get activeLabel => 'ACTIVE';

  @override
  String get pausedHomeMode => 'PAUSED (HOME MODE)';

  @override
  String get pausedLabel => 'PAUSED';

  @override
  String get everyHour => 'Every 1 hour';

  @override
  String everyNDays(int days) {
    return 'Every $days days';
  }

  @override
  String get nextAlertCheck => 'Next Alert Check';

  @override
  String get premiumKeepAliveRefill => 'Premium Keep-Alive Refill';

  @override
  String autoRefillIncludedText(String date) {
    return 'Auto-refill included - ~3.5 USD (telecom, VAT included) every 85 days,\\nnext refill on $date';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'Premium keep-alive refill is currently disabled.';

  @override
  String get customAutoRefill => 'Custom Auto-Refill';

  @override
  String get addAdditionalScheduledRecharge =>
      'Add an additional scheduled recharge amount to keep an extra balance on your SIM.';

  @override
  String get askOwnerConfigureRefill =>
      'Please ask the household owner to configure Auto-Refill.';

  @override
  String get configureCustomAutoRefill => 'Configure Custom Auto-Refill';

  @override
  String get rechargeAmount => 'Recharge Amount';

  @override
  String get refillInterval => 'Refill Interval';

  @override
  String get nextRefillDue => 'Next Refill Due';

  @override
  String get failedRefillAttempts => 'Failed Refill Attempts';

  @override
  String retriesCount(int count) {
    return '$count / 4 retries';
  }

  @override
  String get editRefillAmount => 'Edit Refill Amount';

  @override
  String get refillExecutionsHistory => 'Refill Executions History';

  @override
  String get renewalExecutionsHistory => 'Renewal Executions History';

  @override
  String get noHistoricalTopup =>
      'No historical top-up executions recorded for this line yet.';

  @override
  String get noHistoricalRenewal =>
      'No historical renewal executions recorded for this line yet.';

  @override
  String get viewAllHistory => 'View All History';

  @override
  String get securityActivityLogs => 'Security Activity Logs';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get noActivityLogsRecorded =>
      'No activity logs recorded for this line yet.';

  @override
  String get activityLogDeleted => 'Activity log entry deleted.';

  @override
  String get activityLogsCleared => 'Activity logs cleared successfully.';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'Auto-Renewal successfully $status.';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'Failed to update schedule: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'Premium keep-alive refill enabled successfully.';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'Failed to enable auto-refill: $error';
  }

  @override
  String get removeScheduleTitle => 'Remove Schedule';

  @override
  String get confirmDeleteAutoRefill =>
      'Are you sure you want to delete this auto-refill schedule? Your SIM health score will drop significantly, risking deactivation.';

  @override
  String get confirmDeleteAutoRenewal =>
      'Are you sure you want to delete this auto-renewal schedule? Your SIM health score will drop significantly, risking deactivation.';

  @override
  String get autoRefillRemoved => 'Auto-refill schedule removed successfully.';

  @override
  String get autoRenewalRemoved =>
      'Auto-renewal schedule removed successfully.';

  @override
  String failedToDeleteSchedule(String error) {
    return 'Failed to delete schedule: $error';
  }

  @override
  String get refillRetrySuccess => 'Refill retry completed successfully!';

  @override
  String get refillRetryQueued =>
      'Retry queued — the refill is being processed.';

  @override
  String get renewalRetrySuccess => 'Renewal retry completed successfully!';

  @override
  String retryFailed(String error) {
    return 'Retry failed: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'Retry execution error: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'Failed to delete activity log: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'Failed to clear activity logs: $error';
  }

  @override
  String get removeProtectionTitle => 'Remove Protection';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'Are you sure you want to stop keeping $name protected? Scheduled top-ups for this SIM line will be permanently cancelled.';
  }

  @override
  String get simLineProtectionRemoved =>
      'SIM line protection removed successfully.';

  @override
  String failedToDeleteSimLine(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get editSimNameTitle => 'Edit SIM Name';

  @override
  String get enterNicknameInstruction =>
      'Enter a nickname for this SIM card line:';

  @override
  String get nicknameExampleHint => 'e.g. My Orange Egypt SIM';

  @override
  String get simNameUpdatedSuccess => 'SIM name updated successfully.';

  @override
  String failedToUpdateSimName(String error) {
    return 'Failed to update SIM name: $error';
  }

  @override
  String get saveButton => 'Save';

  @override
  String get deleteButton => 'Delete';

  @override
  String get confirmDeletionTitle => 'Confirm deletion';

  @override
  String noDeviceLockConfirmBody(String token) {
    return 'This device has no fingerprint or screen lock set up. Type $token to confirm.';
  }

  @override
  String typeToConfirmHint(String token) {
    return 'Type $token';
  }

  @override
  String get deletionNotVerified =>
      'Deletion cancelled - identity not verified.';

  @override
  String get autoNotifySchedule => 'Auto-Notify Schedule';

  @override
  String get renewalCheckInterval => 'Renewal Check Interval';

  @override
  String get editNotificationConfig => 'Edit Notification Config';

  @override
  String get openTicket => 'Open Ticket';

  @override
  String get offlineRefillLabel => 'Offline Refill';

  @override
  String get categoryLabel => 'Category';

  @override
  String get techSupportCategory => 'Technical Support';

  @override
  String get billingWalletCategory => 'Billing & Wallet';

  @override
  String get simLinesCategory => 'SIM Lines Management';

  @override
  String get feedbackOtherCategory => 'Feedback & Other';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get subjectHint => 'Brief summary of the issue';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint => 'Describe your issue in detail...';

  @override
  String get attachmentLabel => 'Attachment (Optional)';

  @override
  String get uploadScreenshot => 'Upload Screenshot';

  @override
  String get submitTicketButton => 'Submit Ticket';

  @override
  String get pleaseFillFields => 'Please fill in both subject and description';

  @override
  String get ticketSubmittedSuccess => 'Ticket submitted successfully!';

  @override
  String get lastRefillLabel => 'Last Refill';

  @override
  String get noRefillYet => 'No refill yet';

  @override
  String get nextAlertLabel => 'Next Alert';

  @override
  String get protectionLabel => 'PROTECTION';

  @override
  String get actionRequiredLabel => 'Action Req.';

  @override
  String get protectionOffLabel => 'Protection Off';

  @override
  String get notSet => 'Not set';

  @override
  String get homeMode => 'Home Mode';

  @override
  String get keepProtectedAtHome => 'Keep protected at home';

  @override
  String get protectionPausesAtHome => 'Protection pauses at home';

  @override
  String get incidentChannelsTitle => 'Incident Channels';

  @override
  String get topUpSuccessTitle => 'Top-up Successful';

  @override
  String get topUpSuccessDesc =>
      'Notify me when an automatic SIM validity extension is completed successfully.';

  @override
  String get topUpFailedTitle => 'Top-up Failed (Critical)';

  @override
  String get topUpFailedDesc =>
      'Critical alerts when automatic top-ups fail due to carrier or wallet issues.';

  @override
  String get walletLowTitle => 'Low Wallet Balance';

  @override
  String get walletLowDesc =>
      'Warn me when primary balance drops below the safety threshold.';

  @override
  String get walletDepletedTitle => 'Wallet Depleted';

  @override
  String get walletDepletedDesc =>
      'Suspended alerts when wallet balance is fully exhausted and renewals halt.';

  @override
  String get lineCriticalTitle => 'Validity Expiry Warning';

  @override
  String get lineCriticalDesc =>
      'Warn me when a SIM validity window is ending within 48 hours.';

  @override
  String get lineEnteringGraceTitle => 'Entering Grace Period';

  @override
  String get lineEnteringGraceDesc =>
      'Notify me when carrier deactivation grace periods are detected.';

  @override
  String get geoFenceTriggeredTitle => 'Location / Roaming Alerts';

  @override
  String get geoFenceTriggeredDesc =>
      'Alerts when carrier switches roaming clusters or network nodes.';

  @override
  String get welcomeHomeReadyTitle => 'Welcome Home Sync';

  @override
  String get welcomeHomeReadyDesc =>
      'Alerts when home-country network node triggers automated syncs.';

  @override
  String get referralRewardTitle => 'Referral & Rewards';

  @override
  String get referralRewardDesc =>
      'Notify me when friend referrals deposit promotional balances into my wallet.';

  @override
  String get systemUpdatesTitle => 'General System Updates';

  @override
  String get systemUpdatesDesc =>
      'Vital engine updates, maintenance, and platform announcements.';

  @override
  String get walletCreditTitle => 'Wallet Credited';

  @override
  String get walletCreditDesc => 'Notify me when a deposit lands in my wallet.';

  @override
  String get promoTitle => 'Offers & Promotions';

  @override
  String get promoDesc =>
      'Occasional news about deals and new features. Stays off until you turn it on.';

  @override
  String get deliverVia => 'Deliver via';

  @override
  String get channelPushShort => 'Push';

  @override
  String get channelEmailShort => 'Email';

  @override
  String get channelOffGlobally => 'Off in Alert Channels above';

  @override
  String get rescheduleRefill => 'Reschedule Refill';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get confirmResetRefill =>
      'Are you sure you want to reset the scheduled refill date to default?';

  @override
  String get refillDateUpdated => 'Scheduled refill date updated successfully';

  @override
  String failedToUpdateRefillDate(String error) {
    return 'Failed to update scheduled refill date: $error';
  }

  @override
  String get changeDate => 'Change Date';

  @override
  String get reset => 'Reset';

  @override
  String get refillScheduleConfig => 'Refill Schedule Config';

  @override
  String refillExecutionNum(int number) {
    return 'Refill $number';
  }

  @override
  String get ok => 'OK';

  @override
  String get rechargeNow => 'Recharge Now';

  @override
  String get planFeePaidFromWallet => 'Plan fee paid from your wallet balance.';

  @override
  String get planFeeNotChargedRetry =>
      'Your top-up arrived but the plan fee could not be charged, so the line was not created. Your balance is safe — please try again.';

  @override
  String activityTopupRequested(String amount) {
    return 'Refill request submitted for \$$amount';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return 'Top-up of \$$amount completed via $provider';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return 'Top-up of \$$amount failed: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return 'Refill of \$$amount refunded to wallet';
  }

  @override
  String activityTopupCancelled(String amount) {
    return 'Refill request of \$$amount cancelled';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return 'Retry queued for refill of \$$amount';
  }

  @override
  String get activityLineCreated => 'SIM Line registered in SIM Shield';

  @override
  String get activityHealthUpdate => 'SIM Line active status verified';

  @override
  String get activityReminderSent => 'Renewal reminder notification sent';

  @override
  String get supportTicketsTitle => 'Help & Support';

  @override
  String get supportTicketsSubtitle =>
      'Submit support requests, attach activity logs, and chat live with our support team.';

  @override
  String get supportTicketsEmpty => 'No support tickets found.';

  @override
  String get createSupportTicket => 'Create Ticket';

  @override
  String get ticketCategoryGeneral => 'General Inquiry';

  @override
  String get ticketCategoryBilling => 'Billing & Wallet';

  @override
  String get ticketCategoryTechnical => 'Technical Issue';

  @override
  String get ticketCategoryRefillIssue => 'Refill Issue';

  @override
  String get ticketCategoryAccount => 'Account & Security';

  @override
  String get ticketStatusOpen => 'Open';

  @override
  String get ticketStatusPending => 'Pending Reply';

  @override
  String get ticketStatusResolved => 'Resolved';

  @override
  String get ticketStatusClosed => 'Closed';

  @override
  String get ticketSubjectLabel => 'Subject';

  @override
  String get ticketSubjectHint => 'Brief description of the issue';

  @override
  String get ticketCategoryLabel => 'Category';

  @override
  String get ticketMessageLabel => 'Message';

  @override
  String get ticketMessageHint => 'Provide detailed information...';

  @override
  String get attachImage => 'Attach Image';

  @override
  String get attachActivityLogs => 'Attach Line Logs';

  @override
  String get submitTicket => 'Submit Ticket';

  @override
  String get typeMessageHint => 'Type a message...';

  @override
  String get closeTicketButton => 'Close Ticket';

  @override
  String get ticketClosedNotice => 'This support ticket has been closed.';

  @override
  String get attachedFiles => 'Attachments';

  @override
  String get referralsTitle => 'Refer & Earn';

  @override
  String get referralsSubtitle =>
      'Invite friends, earn points on SIM subscriptions, and redeem for wallet credits!';

  @override
  String get referralCode => 'Your Referral Code';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get codeCopied => 'Referral code copied to clipboard!';

  @override
  String get shareCode => 'Share Code';

  @override
  String get pointsBalance => 'Points Balance';

  @override
  String get pointsUnit => 'points';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return '$pointsNeeded more points until next \$2.00 reward';
  }

  @override
  String get redeemButton => 'Redeem 10 Points for \$2.00';

  @override
  String get redeemSuccess =>
      'Successfully redeemed 10 points for \$2.00 wallet credit!';

  @override
  String get applyCodeTitle => 'Have a Referral Code?';

  @override
  String get applyCodeHint => 'Enter referral code';

  @override
  String get applyCodeButton => 'Apply Code';

  @override
  String get applyCodeSuccess => 'Referral code applied successfully!';

  @override
  String get referredFriendsTitle => 'Referred Friends';

  @override
  String get noReferredFriends =>
      'No friends referred yet. Share your code to get started!';

  @override
  String get redemptionHistoryTitle => 'Redemption History';

  @override
  String get noRedemptions => 'No redemptions yet.';

  @override
  String get pointHistoryTitle => 'Points History';

  @override
  String get noPointsEarned => 'No points earned yet.';

  @override
  String get howItWorksTitle => 'How Refer & Earn Works';

  @override
  String get howItWorksStep1 =>
      '1. Share your unique referral code with friends.';

  @override
  String get howItWorksStep2 =>
      '2. Earn 1 point whenever a referred friend subscribes a SIM line.';

  @override
  String get howItWorksStep3 =>
      '3. Redeem 10 points for \$2.00 spendable wallet credit anytime!';

  @override
  String get geoTitle => 'Travel & Geolocation';

  @override
  String get geoSubtitle =>
      'Automatic country detection and international SIM line protection';

  @override
  String get currentCountryLabel => 'Current Location';

  @override
  String get travelModeToggle => 'Travel Mode';

  @override
  String get travelModeDescription =>
      'Check country when opening the app to manage international line protection';

  @override
  String get geoNotice =>
      'Country is checked via IP lookup when you open the app. No location permissions required.';

  @override
  String get freezeInternationalLines => 'Freeze International Lines';

  @override
  String get resumeInternationalLines => 'Resume International Lines';

  @override
  String get linesFrozenSuccess =>
      'International SIM lines frozen and scheduled refills paused!';

  @override
  String get linesResumedSuccess =>
      'International SIM lines and refills reactivated!';

  @override
  String get alwaysProtectedBadge => 'Always Protected';

  @override
  String get detectedViaIp => 'Detected via IP';

  @override
  String get esimManagerTitle => 'eSIM Manager';

  @override
  String get esimPlansTitle => 'eSIM Plans';

  @override
  String get searchDestinationHint =>
      'Search destination (e.g. France, United States)';

  @override
  String get selectDestinationTitle => 'Select Destination';

  @override
  String get localTab => 'Local';

  @override
  String get regionalTab => 'Regional';

  @override
  String get globalTab => 'Global';

  @override
  String get bestValueBadge => 'BEST VALUE';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days Days';
  }

  @override
  String get buyPlanButton => 'Buy Plan';

  @override
  String get deviceIncompatibleNotice =>
      'Your device does not support eSIM functionality.';

  @override
  String get activationPolicyTitle => 'Activation Policy';

  @override
  String get activationPolicyNotice =>
      'Validity starts when the eSIM connects to a supported network at your destination.';

  @override
  String get coveredCountriesTitle => 'Covered Countries';

  @override
  String get sortPriceLowToHigh => 'Price: Low to High';

  @override
  String get sortPricePerGb => 'Price / GB: Low to High';

  @override
  String get sortDataHighToLow => 'Data: High to Low';

  @override
  String get filterAll => 'All Plans';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ 15 Days';

  @override
  String get filterUnlimited => 'Unlimited';

  @override
  String get purchaseInNextRelease =>
      'Purchase flow will land in the next release (C9b).';

  @override
  String get confirmPurchaseTitle => 'Confirm eSIM Purchase';

  @override
  String get myEsimsTitle => 'My eSIMs';

  @override
  String get showQrCode => 'Show QR Code';

  @override
  String get buyAgain => 'Buy Again';

  @override
  String get dataRemaining => 'Data Remaining';

  @override
  String get archivedEsims => 'Archived eSIMs';

  @override
  String rateLimitExceeded(String seconds) {
    return 'Too many requests. Please wait $seconds seconds before trying again.';
  }

  @override
  String get confirmDeleteButton => 'Confirm Delete';

  @override
  String get cancelAccountDeletion => 'Cancel Account Deletion';

  @override
  String get accountScheduledForDeletion => 'Account Scheduled for Deletion';

  @override
  String deletionScheduledNotice(String date) {
    return 'Your account is frozen and scheduled for permanent deletion on $date.';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'Your wallet balance (\$$balance) exceeds dust limit (\$1.00). Please spend it or contact support for payout.';
  }

  @override
  String get payPalCheckoutTitle => 'PayPal Checkout';

  @override
  String get payPalWalletTopUp => 'KeepSIMs Wallet Top-up';

  @override
  String get payPalPaySecurely => 'Pay Securely with PayPal';

  @override
  String get payPalRedirectInfo =>
      'You will be redirected to PayPal to authorize your payment.';

  @override
  String get payPalCreatingOrder => 'Creating secure PayPal order...';

  @override
  String get payPalAwaitingConfirmation => 'Awaiting PayPal Confirmation...';

  @override
  String get payPalCompleteInBrowser =>
      'Please complete payment in the opened browser window.';

  @override
  String get payPalPaymentConfirmed => 'Payment Confirmed!';

  @override
  String get payPalPaymentFailed => 'Payment failed or was cancelled.';

  @override
  String get payPalForceCaptureButton => 'I\'ve Completed Payment on PayPal';

  @override
  String get payPalBrowserOpened => 'PayPal is open in your browser';

  @override
  String get payPalBrowserOpenedBody =>
      'Finish paying there — this screen updates on its own.';

  @override
  String get payPalTakingLonger =>
      'This is taking longer than usual. If you have already paid, check the payment below.';

  @override
  String get payPalReopenButton => 'Reopen PayPal';

  @override
  String get payPalVerifying => 'Verifying your payment…';

  @override
  String get payPalVerifyingBody => 'One moment while we confirm with PayPal.';

  @override
  String get payPalPaymentCancelled =>
      'Payment cancelled. You have not been charged.';

  @override
  String get payPalDoneButton => 'Done';

  @override
  String get yourDevices => 'Your devices';

  @override
  String get manageDevicesDesc =>
      'See where you are signed in and sign out a device';

  @override
  String get devicesExplainer =>
      'These are the app installations signed in to your account. Signing one out stops notifications reaching it and asks it to sign in again.';

  @override
  String get devicesEmpty =>
      'No devices recorded yet. This one will appear the next time you sign in.';

  @override
  String get devicesLoadFailed =>
      'Could not load your devices. Please try again.';

  @override
  String get devicesUnknownPlatform => 'Unknown device';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String get devicesSignedOut => 'Signed out';

  @override
  String get devicesSignOut => 'Sign out';

  @override
  String get devicesSignOutTitle => 'Sign out this device?';

  @override
  String get devicesSignOutBody =>
      'It will stop receiving notifications and will need to sign in again. Your data is not deleted.';

  @override
  String get devicesJustNow => 'active just now';

  @override
  String devicesHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String devicesDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String devicesMetaLine(String shortId, String version, String lastSeen) {
    return '…$shortId · v$version · $lastSeen';
  }

  @override
  String get deviceBlockedTitle => 'Payment stopped';

  @override
  String get deviceBlockedMessage =>
      'A security check on this device stopped this payment. If this is a mistake, contact support and we will sort it out.';

  @override
  String get householdTitle => 'Household & Family';

  @override
  String get householdTabMyFamily => 'My family';

  @override
  String get householdTabReceived => 'Invitations';

  @override
  String get householdTabJoined => 'Joined';

  @override
  String get householdInviteMember => 'Invite member';

  @override
  String get householdEmptyTitle => 'No family members yet';

  @override
  String get householdEmptyDesc =>
      'Invite someone by email to share your prepaid SIM lines and renewals with them.';

  @override
  String get householdStatusPending => 'PENDING';

  @override
  String get householdStatusAccepted => 'ACTIVE';

  @override
  String get householdPendingHint => 'Waiting for them to accept';

  @override
  String get householdRoleViewer => 'Viewer';

  @override
  String get householdRoleManager => 'Manager';

  @override
  String get householdRoleViewerHint => 'Can see your lines';

  @override
  String get householdRoleManagerHint => 'Can see and top up your lines';

  @override
  String get householdManagerWarning =>
      'A manager can top up your lines. They only spend your wallet if you set them a limit.';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'Spends my wallet · $spent of $cap this month';
  }

  @override
  String get householdPaysOwnWallet => 'Pays with their own wallet';

  @override
  String get householdManagersOnly =>
      'Managers only — a viewer cannot spend your wallet';

  @override
  String get householdChangeLimit => 'Change limit';

  @override
  String get householdSetLimit => 'Set a limit';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining left · $queued queued, not yet charged';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return '$remaining left this month';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return 'Spending limit for $name';
  }

  @override
  String get householdSpendingLimitDesc =>
      'How much of YOUR wallet they may spend on your SIM lines each calendar month. Set 0 to switch it off — they will go back to paying with their own wallet.';

  @override
  String get householdMonthlyLimit => 'Monthly limit (USD)';

  @override
  String get householdMaxPerRefill => 'Max per refill (optional)';

  @override
  String get householdSave => 'Save';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name can now spend up to $cap of your wallet a month.';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name pays with their own wallet again.';
  }

  @override
  String get householdLimitFailed => 'Could not update the limit.';

  @override
  String get householdNoInvitesTitle => 'No invitations';

  @override
  String get householdNoInvitesDesc =>
      'When someone invites you to their household, it will show up here.';

  @override
  String get householdFamilyAccount => 'Family account';

  @override
  String get householdInvitedYouViewer => 'Invited you to view their SIM lines';

  @override
  String get householdInvitedYouManager =>
      'Invited you to view and top up their SIM lines';

  @override
  String get householdAccept => 'Accept';

  @override
  String get householdDecline => 'Decline';

  @override
  String get householdNotJoinedTitle => 'You have not joined a household';

  @override
  String get householdNotJoinedDesc =>
      'Invitations you receive appear under the Invitations tab.';

  @override
  String get householdSharedHousehold => 'Shared household';

  @override
  String get householdRoleManagerFull => 'MANAGER · CAN TOP UP';

  @override
  String get householdRoleViewerFull => 'VIEWER · READ-ONLY';

  @override
  String get householdLeave => 'Leave';

  @override
  String householdOwnerFunds(String owner) {
    return '$owner funds your refills';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'You have used the whole $cap for this month. Refills on their lines will be refused until it resets.';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return '$remaining of $cap left this month';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · max $perTxn per refill';
  }

  @override
  String get householdInviteTitle => 'Invite a family member';

  @override
  String get householdInviteDesc =>
      'They get the invitation inside the app. Once they accept, your SIM lines and theirs appear together.';

  @override
  String get householdEmailLabel => 'Email address';

  @override
  String get householdAccessLevel => 'What may they do?';

  @override
  String get householdSendInvite => 'Send invite';

  @override
  String get householdInvalidEmail => 'Please enter a valid email address';

  @override
  String householdInviteSent(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return 'Invitation sent to $email. They will see it as soon as they register.';
  }

  @override
  String get householdInviteAccepted => 'You joined the household';

  @override
  String get householdInviteDeclined => 'Invitation declined';

  @override
  String get householdRemoveTitle => 'Remove family member';

  @override
  String householdRemoveConfirm(String name) {
    return '$name will immediately lose access to your SIM lines, along with any spending limit you set.';
  }

  @override
  String householdRemoved(String name) {
    return '$name was removed from your household';
  }

  @override
  String get householdLeaveTitle => 'Leave household';

  @override
  String householdLeaveConfirm(String owner) {
    return 'You will lose access to the SIM lines shared by $owner.';
  }

  @override
  String get householdLeft => 'You left the household';

  @override
  String get householdActionFailed => 'That did not work. Please try again.';

  @override
  String get householdOwnerLabel => 'You (owner)';

  @override
  String get householdSettingsSubtitle =>
      'Share your SIM lines with family, set spending limits';

  @override
  String get householdStatusDeclined => 'DECLINED';

  @override
  String get householdDeclinedHint =>
      'They declined. Remove them to invite again.';

  @override
  String get carrierActivityFallbackOperator => 'This carrier';

  @override
  String get carrierUsageRequiredTitle =>
      'Auto-refill cannot protect this line';

  @override
  String carrierUsageRequiredBody(String operator) {
    return '$operator only restarts its inactivity countdown when the line makes a call, sends an SMS, or uses data. Adding credit does not count, so no automatic top-up can stop this number being deactivated. Choose Standard and we will alert you in time to use the line yourself.';
  }

  @override
  String get carrierMinDenominationTitle =>
      'This carrier needs a larger top-up';

  @override
  String carrierMinDenominationBody(
    String operator,
    String amount,
    String currency,
  ) {
    return '$operator only adds line validity for top-ups of $amount $currency or more. Anything smaller arrives as spendable credit and the number can still be deactivated, so Premium refills this line at $amount $currency.';
  }

  @override
  String get premiumUnavailableForCarrier =>
      'Premium is not available for this carrier';

  @override
  String get carrierRulesLinkLabel => 'More about this carrier\'s rules';

  @override
  String get carrierRulesSheetTitle => 'Deactivation rules';

  @override
  String carrierRulesHowTitle(String operator) {
    return 'How $operator decides';
  }

  @override
  String carrierRechargeOkBody(String operator) {
    return '$operator restarts its countdown every time the line is topped up, whatever the amount. That is what lets an automatic refill hold the number.';
  }

  @override
  String get carrierRulesNumbersTitle => 'The numbers';

  @override
  String carrierRulesWindowRow(int days) {
    return 'Deactivated after $days days without a qualifying top-up';
  }

  @override
  String carrierRulesGraceRow(int days) {
    return '$days days afterwards to recover the same number';
  }

  @override
  String get carrierRulesNoGraceRow =>
      'No recovery window — the number is released straight away';

  @override
  String carrierRulesMinTopupRow(String amount, String currency) {
    return '$amount $currency is the smallest top-up that adds validity';
  }

  @override
  String carrierRulesCadenceRow(int days, int count) {
    return 'We would refill every $days days — $count times a year';
  }

  @override
  String get carrierRulesVerdictTitle => 'What we would do';

  @override
  String get carrierVerdictSelfServiceTitle =>
      'Do not buy Premium for this line';

  @override
  String get carrierVerdictSelfServiceBody =>
      'Keep your money. Nothing we can send resets this carrier\'s clock, so the only thing that keeps the number is using it.';

  @override
  String get carrierVerdictStandardTitle => 'Standard is enough here';

  @override
  String get carrierVerdictStandardBody =>
      'This carrier gives you a long runway. Let us watch the date and tell you; top up yourself when we do, and you pay only the airtime.';

  @override
  String get carrierVerdictPremiumWorthTitle => 'Premium is worth it';

  @override
  String get carrierVerdictPremiumWorthBody =>
      'A few top-ups a year, each on a date you cannot see from here. Doing it by hand is realistic if you prefer — automating it means you never have to think about it.';

  @override
  String get carrierVerdictPremiumMustTitle => 'Automate this one';

  @override
  String get carrierVerdictPremiumMustBody =>
      'This carrier moves fast enough that remembering by hand, from another country, will eventually slip — and one slip is the number.';

  @override
  String get carrierReasonUsageOnly =>
      'Only a call, an SMS or a data session counts. Credit alone does not.';

  @override
  String carrierReasonQualifying(String amount, String currency) {
    return 'A top-up under $amount $currency arrives as credit and buys no validity.';
  }

  @override
  String carrierReasonShortWindow(int days) {
    return 'Only $days days between qualifying top-ups.';
  }

  @override
  String carrierReasonLongWindow(int days) {
    return '$days days is close to a full year — one reminder covers it.';
  }

  @override
  String get carrierReasonNoGrace =>
      'There is no grace period. Miss the date and the number is gone.';

  @override
  String carrierReasonGrace(int days) {
    return 'You would have $days days after the date to recover the number.';
  }

  @override
  String carrierReasonAutomationCost(
    String self,
    String premium,
    String extra,
  ) {
    return 'The airtime alone is about $self a year. Premium is $premium, so $extra of it buys the automation.';
  }

  @override
  String carrierSelfServiceTitle(String operator) {
    return 'Or buy it from $operator directly';
  }

  @override
  String get carrierSelfServiceBody =>
      'Top up in the operator\'s own app and you pay the airtime and nothing else.';

  @override
  String carrierSelfServiceCountryLine(String country) {
    return 'Home country: $country';
  }

  @override
  String carrierSelfServiceAppHint(String app) {
    return 'Its app is usually published as \"$app\".';
  }

  @override
  String carrierSelfServiceUnverified(String operator) {
    return 'We have not checked this listing ourselves. Search the store and make sure the publisher really is $operator before you install anything.';
  }

  @override
  String get carrierSelfServiceSearchStore => 'Search the app store';

  @override
  String get carrierSelfServiceOpenApp => 'Open the operator\'s app';

  @override
  String get carrierSelfServiceWeb => 'Top up on the operator\'s website';

  @override
  String carrierSelfServiceUssd(String code) {
    return 'No data? Dial $code on the handset itself.';
  }

  @override
  String get carrierRulesSourceLink => 'The carrier\'s published terms';

  @override
  String get carrierRulesDisclaimer =>
      'Carriers change these rules without announcing it. If yours has, tell support and we will re-check.';

  @override
  String get carrierActionTitle => 'Carrier Action Needed';

  @override
  String get carrierActionDesc =>
      'Tell me when a line needs something only I can do — using the SIM, or topping it up in my operator\'s own app.';

  @override
  String get compareDestinationLabel => 'Destination';

  @override
  String comparePlansFound(int count) {
    return '$count plans';
  }

  @override
  String get compareCountriesSuffix => 'countries';

  @override
  String get compareDaysSuffix => 'days';

  @override
  String get compareDataLabel => 'Data';

  @override
  String get compareValidityLabel => 'Validity';

  @override
  String get compareCoverageLabel => 'Coverage';

  @override
  String get compareSpeedLabel => 'Speed';

  @override
  String get compareMaxPriceLabel => 'Max price';

  @override
  String get comparePriceLabel => 'Price';

  @override
  String get compareFiltersTitle => 'Filters';

  @override
  String get compareReset => 'Reset';

  @override
  String get compareShowResults => 'Show results';

  @override
  String get compareSortDuration => 'Validity: Longest first';

  @override
  String get compareModeAll => 'All';

  @override
  String get compareModeRange => 'Range';

  @override
  String get compareModePickDays => 'Pick days';

  @override
  String get compareModePickSizes => 'Pick sizes';

  @override
  String get compareModeUnlimited => 'Unlimited';

  @override
  String compareRangeDays(int min, int max) {
    return '$min – $max days';
  }

  @override
  String compareRangeData(String min, String max) {
    return '$min – $max';
  }

  @override
  String get compareMeteredOnlyNote =>
      'Sizes and ranges match plans with a set amount of data. For plans with no cap, choose Unlimited.';

  @override
  String get comparePriceMinHint => 'Min';

  @override
  String get comparePriceMaxHint => 'Max';

  @override
  String comparePriceRangeHelp(String min, String max) {
    return 'Leave a box empty for no limit. Plans here run from $min to $max.';
  }

  @override
  String get comparePriceRangeHelpPlain =>
      'Leave the first box empty to start at zero, or the second empty to include the highest price available.';

  @override
  String get compareBoundsUnavailable =>
      'We couldn\'t read what this destination sells, so only “All” is available.';

  @override
  String get compareBuyInApp => 'Buy in app';

  @override
  String get comparePartnerSite => 'Partner site';

  @override
  String get compareViewDeal => 'View deal';

  @override
  String get comparePriceAtPartner => 'Price on partner site';

  @override
  String compareCouponCopied(String code) {
    return 'Code $code copied';
  }

  @override
  String get compareAffiliateDisclosure =>
      'Deals marked “Partner site” open another company\'s checkout. KeepSIMs may earn a commission — it never changes the price you pay.';

  @override
  String get compareOpenFailed =>
      'That deal couldn\'t be opened. Please try again.';

  @override
  String get compareNoResults => 'No plans match your filters';

  @override
  String get compareLoadFailed => 'We couldn\'t load plans right now.';

  @override
  String get compareRetry => 'Try again';

  @override
  String get compareViewAll => 'View all';

  @override
  String get comparePriceWatchTooltip => 'Watch prices for this destination';

  @override
  String comparePriceWatchOn(String country) {
    return 'Watching $country — we\'ll tell you if the best price drops.';
  }

  @override
  String comparePriceWatchOff(String country) {
    return 'Stopped watching $country.';
  }

  @override
  String get roamOrEsimTooltip => 'Roam or eSIM? Compare with your carrier';

  @override
  String get travelTomorrowLabel =>
      'If you travel tomorrow, switch this on to help you prepare';

  @override
  String get buyEsimLabel => 'Buy eSIM';

  @override
  String get buyCheapestPackageLabel => 'Buy Cheapest Package';

  @override
  String get voucherCardTitle => 'Emergency top-up PIN';

  @override
  String get voucherCardSubtitle =>
      'Works with no data, no credit and no signal';

  @override
  String voucherSealedBody(String amount) {
    return 'A $amount recharge PIN is stored on this phone. Reveal it when you cannot top up any other way.';
  }

  @override
  String get voucherRevealAction => 'Reveal my PIN';

  @override
  String get voucherRevealConfirmTitle => 'Use your emergency PIN?';

  @override
  String voucherRevealConfirmBody(String face, String due) {
    return 'This gives you $face of credit right now, as a gift. When you are back online we will ask you for $due from your wallet — and once that is settled you get a new PIN for next time.';
  }

  @override
  String get voucherRevealConfirmAction => 'Show the PIN';

  @override
  String get voucherYourPin => 'YOUR RECHARGE PIN';

  @override
  String get voucherSerial => 'Serial';

  @override
  String get voucherPinCopied => 'PIN copied';

  @override
  String voucherDialAction(String code) {
    return 'Dial $code';
  }

  @override
  String voucherOwedTitle(String amount) {
    return '$amount due for your emergency PIN';
  }

  @override
  String get voucherOwedBody =>
      'Settle it to get a new PIN for the next time you are offline.';

  @override
  String voucherSettleAction(String amount) {
    return 'Pay $amount from wallet';
  }

  @override
  String get voucherSettledToast => 'Settled — a new PIN will be ready shortly';

  @override
  String voucherSettleNoFunds(String due, String balance) {
    return 'You need $due but your wallet has $balance.';
  }

  @override
  String get voucherSettleFailed =>
      'Could not settle right now. Please try again.';

  @override
  String get voucherCollectBody =>
      'Store a recharge PIN on this phone now, while you have signal. You will be able to use it even with no data and no credit.';

  @override
  String get voucherCollectAction => 'Store a PIN on this phone';

  @override
  String get voucherCollectedToast => 'PIN stored securely on this phone';

  @override
  String get voucherCollectFailed =>
      'Could not store a PIN right now. Please try again.';

  @override
  String get voucherPreparingTitle => 'Being prepared';

  @override
  String get voucherPreparingBody =>
      'We are getting an emergency PIN ready for this number.';

  @override
  String voucherPreparingBodyBy(String date) {
    return 'We are getting an emergency PIN ready for this number, expected by $date.';
  }

  @override
  String get voucherPremiumOnly =>
      'Emergency PINs are part of the Premium plan.';

  @override
  String get voucherNeedsConnection =>
      'Connect to the internet once to store a PIN for offline use.';

  @override
  String get voucherUnavailableOffline =>
      'Connect once to set up your emergency PIN.';

  @override
  String get voucherExpiredTitle => 'This PIN has expired';

  @override
  String get voucherExpiredBody =>
      'Connect to the internet and we will store a fresh one.';
}
