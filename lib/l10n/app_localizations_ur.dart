// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'ترجیحات اور سیکیورٹی';

  @override
  String get appAppearance => 'ایپ کی ظاہری شکل';

  @override
  String get systemTheme => 'سسٹم';

  @override
  String get darkMode => 'ڈارک موڈ';

  @override
  String get lightMode => 'لائٹ موڈ';

  @override
  String get localizationAndRegional => 'مقامی کاری اور علاقائی ترتیبات';

  @override
  String get appLanguage => 'ایپ کی زبان';

  @override
  String currentlyUsing(String langName) {
    return 'فی الحال علاقائی $langName استعمال کی جا رہی ہے';
  }

  @override
  String get selectAppLanguage => 'ایپ کی زبان منتخب کریں';

  @override
  String get securityAndAccessLock => 'سیکیورٹی اور ایکسیس لاک';

  @override
  String get biometricSecurity => 'بائیومیٹرک سیکیورٹی';

  @override
  String get biometricDesc =>
      'Face ID یا Touch ID کا استعمال کرتے ہوئے سائن ان کریں';

  @override
  String get biometricReasonPayment =>
      'ادائیگی کی تصدیق کے لیے بائیومیٹرک تصدیق کریں';

  @override
  String get biometricReasonUnlock => 'KeepSIMs انلاک کرنے کے لیے تصدیق کریں';

  @override
  String get biometricLockout =>
      'بہت زیادہ ناكام کوششوں کی وجہ سے بائیومیٹرک تصدیق لاک ہو گئی ہے۔ براہ کرم اپنے ڈیوائس پاس کوڈ کا استعمال کریں۔';

  @override
  String get biometricNotEnrolled =>
      'اس ڈیوائس پر بائیومیٹرک تصدیق سیٹ نہیں ہے۔';

  @override
  String get biometricAppLockTitle => 'KeepSIMs لاک ہے';

  @override
  String get biometricUnlockButton => 'بائیومیٹرک سے انلاک کریں';

  @override
  String get biometricCancel => 'منسوخ کریں';

  @override
  String get transactionPin => 'ٹرانزیکشن PIN';

  @override
  String get transactionPinDesc => 'تجدید اور رقم نکالنے کو محفوظ بنائیں';

  @override
  String get setup => 'سیٹ اپ';

  @override
  String get pinSuccess => 'ٹرانزیکشن PIN کامیابی سے اپڈیٹ ہو گیا!';

  @override
  String get pinMismatch => 'PIN میچ نہیں ہوئے۔ دوبارہ کوشش کریں!';

  @override
  String get pinActiveAndSecure => 'PIN سیٹ اپ فعال اور محفوظ ہے';

  @override
  String get automatedSummaryAndAlerts => 'خودکار خلاصہ اور الرٹس';

  @override
  String get weeklyDigest => 'ہفتہ وار ڈائجسٹ';

  @override
  String get welcomeBack => 'خوش آمدید';

  @override
  String get nextNotify => 'اگلا نوٹیفکیشن';

  @override
  String get days => 'دن';

  @override
  String get showingNearestLine => 'قریب ترین لائن دکھائی جا رہی ہے';

  @override
  String get addSim => 'SIM شامل کریں';

  @override
  String get linesToProtect => 'محفوظ کرنے کے لیے لائنیں';

  @override
  String get active => 'فعال';

  @override
  String get upgrade => 'اپ گریڈ کریں';

  @override
  String get standard => 'اسٹینڈرڈ';

  @override
  String get autoNotify => 'آٹو-نوٹیفائی';

  @override
  String get configure => 'کنفیگر کریں';

  @override
  String get autoRefill => 'آٹو-ریفل';

  @override
  String get quickActions => 'فوری اقدامات';

  @override
  String get navHome => 'ہوم';

  @override
  String get navSims => 'SIMs';

  @override
  String get navMore => 'مزید';

  @override
  String get protectedSims => 'محفوظ SIMs';

  @override
  String get mySimCards => 'میرے SIM کارڈز';

  @override
  String get familySharedSims => 'خاندان کے ساتھ شیئر کیے گئے SIM';

  @override
  String get protectAnotherSimLine => 'ایک اور SIM لائن محفوظ کریں';

  @override
  String get keepInfiniteNumbersAlive =>
      'لامحدود بین الاقوامی نمبروں کو فعال رکھیں';

  @override
  String get bulkActionsConsole => 'بلک ایکشنز کنسول';

  @override
  String get resume => 'دوبارہ شروع کریں';

  @override
  String get pause => 'روکیں';

  @override
  String get simulate => 'سیمولیٹ کریں';

  @override
  String get noProtectedLines => 'کوئی محفوظ لائن نہیں';

  @override
  String get noInternationalSimsAdded =>
      'آپ نے ابھی تک کوئی بین الاقوامی SIM کارڈ شامل نہیں کیا۔ اسے ہمیشہ فعال رکھنے کے لیے ابھی اپنا پہلا کارڈ محفوظ کریں۔';

  @override
  String get protectNewLine => 'نئی لائن محفوظ کریں';

  @override
  String get noSharedSimsYet => 'ابھی تک کوئی شیئر کردہ SIM نہیں';

  @override
  String get inviteFamilyMembers =>
      'اپنے گھرانے میں شامل ہونے کے لیے خاندان کے افراد کو دعوت دیں۔ قبول کرنے پر، ان کی محفوظ SIM لائنیں باہمی نگرانی کے لیے یہاں نظر آئیں گی۔';

  @override
  String get manageHousehold => 'گھرانہ منظم کریں';

  @override
  String get manageProfileDesc =>
      'اپنی پروفائل، SIM لائنز، الرٹس اور شیئر کردہ ترجیحات کا انتظام کریں';

  @override
  String get keepSIMsUser => 'KeepSIMs صارف';

  @override
  String get pro => 'پرو';

  @override
  String get homeCountry => 'ہوم کنٹری: ';

  @override
  String get console => 'کنسول';

  @override
  String get offlineRefill => 'آف لائن ریفل (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'SMS یا WhatsApp کے ذریعے آف لائن SIM بیلنس ریفل کریں';

  @override
  String get wallet => 'والیٹ';

  @override
  String get manageBalancesDesc =>
      'اپنے بیلنس کا انتظام کریں اور ٹرانزیکشن ہسٹری دیکھیں';

  @override
  String get alertPreferences => 'الرٹ ترجیحات';

  @override
  String get togglePushEmailDesc =>
      'تجدید/بیلنس کے لیے پش اور ای میل سیٹنگز ٹوگل کریں';

  @override
  String get referAndEarn => 'ریفر کریں اور کمائیں';

  @override
  String get shareKeepSIMsDesc =>
      'KeepSIMs شیئر کریں، ڈائنامک بیلنس ریوارڈز ان لاک کریں';

  @override
  String get paymentMethods => 'ادائیگی کے طریقے';

  @override
  String get addBankCardsDesc =>
      'بینک کارڈز شامل کریں یا آٹو-ودڈرال اکاؤنٹس لنک کریں';

  @override
  String get travelAndGeolocation => 'سفر اور جیو لوکیشن';

  @override
  String get manageHomeCountryDesc =>
      'ہوم کنٹری فریز رولز اور ٹریول موڈ کا انتظام کریں';

  @override
  String get dataAndPrivacy => 'ڈیٹا اور پرائیویسی';

  @override
  String get manageTrackingConsentDesc =>
      'اپنی ٹریکنگ رضامندی کا انتظام کریں، ڈیٹا ایکسپورٹ کریں، یا اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get powerUser => 'پاور یوزر';

  @override
  String get accessSystemSimulatorsDesc =>
      'سسٹم سیمولیٹرز اور ڈیبگنگ ٹولز تک رسائی حاصل کریں';

  @override
  String get testChecklist => 'ٹیسٹ چیک لسٹ';

  @override
  String get manualUiTestingDesc =>
      'کوالٹی اشورینس کے لیے مینوئل UI ٹیسٹنگ چیک لسٹ';

  @override
  String get soon => 'جلد آ رہا ہے';

  @override
  String featureComingSoon(String feature) {
    return '$feature فیچر جلد آ رہا ہے!';
  }

  @override
  String get logOut => 'لاگ آؤٹ';

  @override
  String get confirmLogOut =>
      'کیا آپ واقعی KeepSIMs سے لاگ آؤٹ کرنا چاہتے ہیں؟';

  @override
  String get walletLedger => 'والیٹ لیجر';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs پری پیڈ';

  @override
  String get offlineMode => 'آف لائن موڈ';

  @override
  String get activeBalance => 'فعال بیلنس';

  @override
  String get criticalBalanceLevel => 'نازک بیلنس کی سطح';

  @override
  String get balanceBelow10 =>
      'آپ کا بیلنس \$10.00 سے کم ہے۔ شیڈول کردہ SIM ٹاپ اپس جلد ناکام ہو سکتے ہیں۔';

  @override
  String get depositFunds => 'فنڈز جمع کریں';

  @override
  String get walletDepositsRequireInternet =>
      'والیٹ میں جمع کرنے کے لیے فعال انٹرنیٹ کنکشن درکار ہے۔';

  @override
  String get exportLedger => 'لیجر ایکسپورٹ کریں';

  @override
  String get ledgerHistoryExported =>
      'لیجر ہسٹری CSV کے طور پر ایکسپورٹ ہو گئی۔';

  @override
  String get spendAnalysis => 'خرچ کا تجزیہ';

  @override
  String get transactionHistory => 'ٹرانزیکشن ہسٹری';

  @override
  String itemsCount(int count) {
    return '$count آئٹمز';
  }

  @override
  String get noTransactionsRecorded =>
      'ابھی تک کوئی ٹرانزیکشن ریکارڈ نہیں ہوئی۔';

  @override
  String get prepaidMonthlyOutflow => 'پری پیڈ ماہانہ اخراجات';

  @override
  String avgMonthlySpend(String amount) {
    return 'اوسط: \$$amount/ماہ (12M)';
  }

  @override
  String depositViaCard(String last4) {
    return '$last4 پر ختم ہونے والے کارڈ کے ذریعے جمع کریں';
  }

  @override
  String get lineRenewal => 'لائن تجدید';

  @override
  String get justNow => 'ابھی';

  @override
  String get loadCreditFunds => 'کریڈٹ فنڈز لوڈ کریں';

  @override
  String get depositAmountUsd => 'جمع کی رقم (USD)';

  @override
  String get pleaseEnterAmount => 'براہ کرم ایک رقم درج کریں';

  @override
  String get enterPositiveNumber => 'ایک مثبت نمبر درج کریں';

  @override
  String get cardDetails => 'کارڈ کی تفصیلات';

  @override
  String get savedCards => 'محفوظ شدہ کارڈز';

  @override
  String get visaCardNumber => 'Visa کارڈ نمبر';

  @override
  String get pleaseEnterCardNumber => 'براہ کرم کارڈ نمبر درج کریں';

  @override
  String get mustBe16Digits => '16 ہندسوں کا ہونا چاہیے';

  @override
  String get expiryMmYy => 'میعاد ختم (MM/YY)';

  @override
  String get expiryRequired => 'میعاد ختم ہونے کی تاریخ درکار ہے';

  @override
  String get invalid => 'غلط';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV درکار ہے';

  @override
  String get verifyingCardSecurity => 'کارڈ سیکیورٹی کی تصدیق کی جا رہی ہے...';

  @override
  String get authorizeDepositFunds => 'فنڈز جمع کرنے کی اجازت دیں';

  @override
  String successfullyDeposited(String amount) {
    return '\$$amount USD کامیابی سے جمع ہو گئے!';
  }

  @override
  String get failedToDepositFunds =>
      'فنڈز جمع کرنے میں ناکامی۔ براہ کرم کارڈ کنکشن چیک کریں۔';

  @override
  String get noSavedPaymentMethods =>
      'کوئی محفوظ شدہ ادائیگی کا طریقہ نہیں ملا۔';

  @override
  String get addPaymentMethod => 'ادائیگی کا طریقہ شامل کریں';

  @override
  String get savedPaymentMethods => 'محفوظ شدہ ادائیگی کے طریقے';

  @override
  String get addAnotherPaymentMethod => 'ایک اور ادائیگی کا طریقہ شامل کریں';

  @override
  String expiresMmYy(String month, String year) {
    return '$month/$year میں ختم ہوتا ہے';
  }

  @override
  String get offlineRefillTitle => 'آف لائن ریفل (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'ٹارگٹ SIM لائن منتخب کریں';

  @override
  String get noRegisteredSimLines => 'کوئی رجسٹرڈ SIM لائن نہیں ملی۔';

  @override
  String get targetSimLine => 'ٹارگٹ SIM لائن';

  @override
  String get simLine => 'SIM لائن';

  @override
  String get carrier => 'کیریئر';

  @override
  String get change => 'تبدیل کریں';

  @override
  String get offlineRefillProtection => 'آف لائن ریفل پروٹیکشن';

  @override
  String get premiumExclusive => 'پریمیم خاص';

  @override
  String get neverGetStrandedDesc =>
      'موبائل ڈیٹا کے بغیر دوبارہ کبھی نہ پھنسیں۔ KeepSIMs Premium آپ کو زیرو انٹرنیٹ کنکشن کی صورت میں بھی معیاری مقامی SMS یا WhatsApp پیغامات کے ذریعے اپنے SIM کارڈ کا بیلنس آف لائن ریفل کرنے دیتا ہے۔';

  @override
  String get offlineCapability100 => '100% آف لائن صلاحیت';

  @override
  String get deductsFromKeepSIMsDesc =>
      'مقامی SMS گیٹ وے فیل اوور کے ذریعے آپ کی لائن کو کریڈٹ کرنے کے لیے آپ کے KeepSIMs والیٹ سے رقم کٹتی ہے۔';

  @override
  String get dynamicUssdPlanActivation => 'ڈائنامک USSD پلان ایکٹیویشن';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'آف لائن ڈیٹا+کال پیکجز ایکٹیویٹ کرنے کے لیے درست کاپی-پیسٹ ڈائل کوڈز (مثلاً، *900*1#) فراہم کرتا ہے۔';

  @override
  String get dualChannelSupport => 'ڈوئل-چینل سپورٹ';

  @override
  String get textRefillDesc =>
      'دستیاب سیلولر کوریج کے مطابق معیاری SMS یا WhatsApp استعمال کرتے ہوئے \"REFILL\" ٹیکسٹ کریں۔';

  @override
  String get close => 'بند کریں';

  @override
  String get howToTriggerOfflineRefill => 'آف لائن ریفل کیسے ٹرگر کریں';

  @override
  String get ifZeroMobileDataDesc1 =>
      'اگر آپ کے پاس زیرو موبائل ڈیٹا ہے تو ہمارے محفوظ سسٹم گیٹ وے کو صرف ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' لفظ والا ایک معیاری SMS یا WhatsApp پیغام بھیجیں:';

  @override
  String get targetSimLineLabel => 'ٹارگٹ SIM لائن';

  @override
  String get configureCashRefillAmount => 'کیش ریفل کی رقم کنفیگر کریں';

  @override
  String get refillAmount => 'ریفل کی رقم';

  @override
  String walletBalanceUsd(String amount) {
    return 'والیٹ بیلنس: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ کم بیلنس';

  @override
  String get localCarrierPlanSuggestions => 'مقامی کیریئر پلان تجاویز';

  @override
  String get noStandardUssdDialCodes =>
      'اس کیریئر کے لیے کوئی معیاری USSD ڈائل کوڈ نہیں ملا۔ پھر بھی آپ کی لائن پر کیش ریفل کامیابی سے موصول ہو جائے گا۔';

  @override
  String get dynamicDialCodesPreview => 'ڈائنامک ڈائل کوڈز پیش منظر';

  @override
  String get botSuggestDialingCodes =>
      'آف لائن ریفل مکمل ہونے کے بعد، بوٹ آپ کے فون پر یہ درست کوڈز ڈائل کرنے کی تجویز دے گا تاکہ فوری طور پر ڈیٹا+کالز آف لائن ان لاک ہو جائیں:';

  @override
  String costAmount(String amount) {
    return 'لاگت: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'WHATSAPP/SMS سینڈر اوور رائیڈ';

  @override
  String get verificationNumber => 'تصدیقی نمبر';

  @override
  String get triggerRefillsDifferentNumber =>
      'اگر آپ اپنی مین پروفائل فون کے بجائے کسی دوسرے نمبر سے ریفل ٹرگر کرتے ہیں تو اسے کنٹری کوڈ کے ساتھ نیچے درج کریں (مثلاً 96891234567)۔';

  @override
  String get enterPhoneNumberDigits => 'فون نمبر درج کریں (صرف ہندسے)';

  @override
  String get offlineRefillSettingsSaved =>
      'آف لائن ریفل سیٹنگز کامیابی سے محفوظ ہو گئیں!';

  @override
  String get saveSettings => 'سیٹنگز محفوظ کریں';

  @override
  String errorLoadingSettings(String error) {
    return 'سیٹنگز لوڈ کرنے میں خرابی: $error';
  }

  @override
  String get retry => 'دوبارہ کوشش کریں';

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
  String get offlineRefillChannelsHeader => 'آف لائن ری فل کے طریقے';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'اپنے والٹ سے $amount ٹاپ اپ کریں';
  }

  @override
  String get offlineRefillWalletFunded => 'آپ کے والٹ سے';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee فیس';
  }

  @override
  String get offlineRefillMissedCallTitle => 'مسڈ کال دیں';

  @override
  String get offlineRefillMissedCallSubtitle => 'بیلنس یا ڈیٹا کی ضرورت نہیں';

  @override
  String get offlineRefillCallAction => 'ری فل کے لیے کال کریں';

  @override
  String get offlineRefillRetry => 'دوبارہ کوشش کریں';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return '$seconds سیکنڈ انتظار کریں';
  }

  @override
  String get offlineRefillStatusSent => 'بھیج دیا — تصدیق کا انتظار ہے';

  @override
  String get offlineRefillStatusProcessing => 'آپ کی لائن ٹاپ اپ ہو رہی ہے…';

  @override
  String get offlineRefillStatusConfirmed => 'ٹاپ اپ کی تصدیق ہو گئی';

  @override
  String get offlineRefillStatusFailed =>
      'کامیاب نہیں ہوا — کوئی اور طریقہ آزمائیں';

  @override
  String get offlineRefillStatusTimedOut =>
      'ابھی تک کوئی جواب نہیں — کوئی اور طریقہ آزمائیں';

  @override
  String get offlineRefillUssdTitle => 'اپنے ٹاپ اپ سے زیادہ فائدہ اٹھائیں';

  @override
  String get offlineRefillUssdSubtitle =>
      'بیلنس آنے کے بعد، بہترین ویلیو کے لیے اپنے آپریٹر کا کوڈ ڈائل کریں';

  @override
  String get offlineRefillUssdDial => 'ڈائل کریں';

  @override
  String get editProtectedLine => 'محفوظ لائن میں ترمیم کریں';

  @override
  String get saveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get activateShieldProtection => 'شیلڈ پروٹیکشن فعال کریں';

  @override
  String get phoneNumber => 'فون نمبر';

  @override
  String get nicknameOptional => 'عرفیت (اختیاری)';

  @override
  String get whatsappAlerts => 'WhatsApp الرٹس';

  @override
  String get emailAlertsDesc =>
      'Resend کے ذریعے بھیجے گئے نازک ڈی ایکٹیویشن الرٹس';

  @override
  String get refillWalletLow => 'جب فنڈز کم ہو جائیں تو والیٹ ریفل کریں';

  @override
  String get legalPoliciesDesc =>
      'KeepSIMs استعمال کرنے سے، آپ ہماری شرائط سے اتفاق کرتے ہیں۔ KeepSIMs آپ کے SIM لائف سائیکل کے انتظام میں مدد کے لیے ٹولز فراہم کرتا ہے، لیکن ہم تھرڈ پارٹی ٹیلی کام فراہم کنندگان کی وجہ سے ہونے والے براہ راست یا بالواسطہ نقصانات، تباہی، یا سروس میں خلل کے ذمہ دار نہیں ہیں۔';

  @override
  String get globalTravelModeDesc =>
      'بارڈر کراسنگ روٹینز کو ایکٹیویٹ کرنے کے لیے خودکار جیو فینسنگ رولز کی اجازت دیتا ہے';

  @override
  String get dataPreferences => 'ڈیٹا ترجیحات';

  @override
  String get doNotDisturb => 'ڈسٹرب نہ کریں';

  @override
  String get linkedCards => 'لنک شدہ کارڈز';

  @override
  String get analyticsTracking => 'اینالیٹکس اور ٹریکنگ';

  @override
  String get dubai => 'دبئی';

  @override
  String get flyHome => 'گھر واپس جائیں';

  @override
  String get managePreferencesAndSecurityDesc =>
      'تھیم، زبان اور بائیومیٹرک لاک آؤٹس کا انتظام کریں';

  @override
  String get autoFundingRulesDesc =>
      'جب بیلنس بہت کم ہو جائے تو اپنے ڈیفالٹ کریڈٹ کارڈ سے خودکار ٹاپ اپس فعال کر کے SIM تجدید کو مستقل طور پر چلتا رکھیں';

  @override
  String get pushNotifications => 'پش نوٹیفکیشنز';

  @override
  String get quietHoursSchedule => 'خاموش اوقات اور شیڈول';

  @override
  String get exportMyDataDesc =>
      'اپنی پروفائل اور ترجیحات کی JSON کاپی ڈاؤن لوڈ کریں (GDPR رسائی کا حق)';

  @override
  String get borderSimulatorTitle => 'بارڈر کراسنگ سیمولیٹر';

  @override
  String get yourData => 'آپ کا ڈیٹا';

  @override
  String get mostImportant => 'سب سے اہم';

  @override
  String get emailAlerts => 'ای میل الرٹس';

  @override
  String get pushNotificationsDesc => 'اس ڈیوائس پر سخت نیٹیو نوٹیفکیشنز';

  @override
  String get alertSettingsTitle => 'الرٹ سیٹنگز';

  @override
  String get atHome => 'گھر پر';

  @override
  String get telegramBotDesc => 'بانڈڈ انٹرایکٹو Telegram چیٹ نوٹیفکیشنز';

  @override
  String get alertChannels => 'الرٹ چینلز';

  @override
  String get london => 'لندن';

  @override
  String get shieldProtection => 'شیلڈ پروٹیکشن';

  @override
  String get legalPolicies => 'قانونی اور پالیسیاں';

  @override
  String get supportVisaMastercard =>
      'محفوظ Visa اور MasterCard ڈیبٹ یا کریڈٹ سپورٹ کرتا ہے';

  @override
  String get exportMyData => 'میرا ڈیٹا ایکسپورٹ کریں';

  @override
  String get dangerZone => 'ڈینجر زون';

  @override
  String get analyticsTrackingDesc =>
      'گمنام استعمال کا ڈیٹا شیئر کر کے ایپ کو بہتر بنانے میں ہماری مدد کریں۔ بند کرنے پر ایپ کی بنیادی فعالیت متاثر نہیں ہوگی';

  @override
  String get autoFundingRules => 'آٹو-فنڈنگ رولز';

  @override
  String get singapore => 'سنگاپور';

  @override
  String get weeklySummaryDigest => 'ہفتہ وار خلاصہ ڈائجسٹ';

  @override
  String get fullyShielded => 'مکمل طور پر محفوظ';

  @override
  String get dndDesc => 'مخصوص نیند کے اوقات میں پش نوٹیفکیشنز خاموش کریں';

  @override
  String get paymentsAutoFundTitle => 'ادائیگیاں اور آٹو-فنڈ';

  @override
  String get travelGeolocationTitle => 'سفر اور جیو لوکیشن';

  @override
  String get telegramBot => 'Telegram بوٹ';

  @override
  String get weeklyDigestDesc =>
      'ہر اتوار صبح 9:00 بجے تمام SIM کارڈز کی مرتب شدہ سٹیٹس رپورٹ';

  @override
  String get borderSimulatorDesc =>
      'اسمارٹ فریز یا ایکٹو کنٹری ریزیومپشن رولز کو ٹرگر کرنے کے لیے بورڈنگز سیمولیٹ کریں۔';

  @override
  String get linkFirstCard => 'اپنا پہلا ادائیگی کارڈ لنک کریں';

  @override
  String get globalTravelMode => 'گلوبل ٹریول موڈ';

  @override
  String get readPrivacyPolicy => 'مکمل پرائیویسی پالیسی اور شرائط پڑھیں';

  @override
  String get whatsappAlertsDesc =>
      'ریفل ناکامی کے الرٹس براہ راست WhatsApp پر بھیجے جاتے ہیں';

  @override
  String get abroadTraveling => 'بیرون ملک / سفر پر';

  @override
  String get freezeAllLines => 'تمام لائنز فریز کریں';

  @override
  String get resumeRenewals => 'تجدیدات دوبارہ شروع کریں';

  @override
  String get freezeRecommendationDesc =>
      'ہمیں پتہ چلا ہے کہ آپ فی الحال اپنے ہوم کنٹری میں ہیں۔ غیر مطلوبہ والیٹ بیلنس کی کمی کو روکنے کے لیے آپ اپنی بین الاقوامی لائنز پر تجدیدات فریز کر سکتے ہیں۔';

  @override
  String get travelDetected => 'سفر کا پتہ چلا! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'آپ بیرون ملک سفر پر ہیں۔ بلا تعطل موبائل نیٹ ورک کوریج کو یقینی بنانے کے لیے براہ کرم اپنی رکی ہوئی بین الاقوامی SIM تجدیدات دوبارہ شروع کریں۔';

  @override
  String get dismiss => 'مسترد کریں';

  @override
  String get welcomeHome => 'گھر آنے پر خوش آمدید! 🏡';

  @override
  String get addCard => 'کارڈ شامل کریں';

  @override
  String get noAlertChannelsConfigured =>
      'کوئی الرٹ ڈیلیوری چینل کنفیگر نہیں کیا گیا۔';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName سیٹنگز اپڈیٹ ہو گئیں۔';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName لاک ہے 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName الرٹس اسٹارٹر اور پریمیم پلان کی خصوصیات ہیں۔ WhatsApp، Telegram، اور ای میل الرٹس ان لاک کرنے کے لیے اپنا پلان اپ گریڈ کریں!';
  }

  @override
  String get upsellProtect5Lines => 'ایک ساتھ 5 SIM لائنز تک محفوظ کریں';

  @override
  String get upsellUnlockChannels =>
      'WhatsApp، Telegram اور ای میل نوٹیفکیشنز ان لاک کریں';

  @override
  String get upsellEnableTravelModes =>
      'ٹریول اور ہوم خودکار ویلیڈیٹی موڈز فعال کریں';

  @override
  String get emailAddressLabel => 'نوٹیفکیشن ای میل ایڈریس';

  @override
  String get emailAddressHint => 'مثلاً user@domain.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp نمبر (بین الاقوامی فارمیٹ)';

  @override
  String get whatsappNumberHint => 'مثلاً +96891234567';

  @override
  String get whatsappFormatInstruction =>
      '+ سے شروع ہونے والا مکمل بین الاقوامی فارمیٹ درج کریں (مثلاً +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'سٹیٹس: بانڈڈ (چیٹ ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'سٹیٹس: ان بانڈڈ';

  @override
  String get telegramLinkInstructions =>
      'مفت، انٹرایکٹو Telegram الرٹس حاصل کرنے کے لیے، ہمارے Telegram بوٹ کو اپنے اکاؤنٹ سے لنک کریں۔';

  @override
  String get linkTelegramBot => 'Telegram بوٹ لنک کریں';

  @override
  String get emailFreePlanGuarded =>
      'Resend فری پلان محفوظ: صرف ڈی ایکٹیویشن ٹرگرز تک محدود۔ کوئی پروموشنل اسپام نہیں۔';

  @override
  String get whatsappMetaCloudCapped =>
      'ڈائریکٹ Meta Cloud محدود: ہر ٹاپ اپ شیڈول میں زیادہ سے زیادہ 1 پیغام، صرف اس صورت میں بھیجا جاتا ہے جب آٹو-ریفل فعال نہ ہو یا ناکام ہو جائے۔';

  @override
  String get failedToLoadPaymentInfo =>
      'ادائیگی کی معلومات لوڈ کرنے میں ناکامی';

  @override
  String get defaultCardIndicator => 'ڈیفالٹ';

  @override
  String get cardholder => 'کارڈ ہولڈر';

  @override
  String get expires => 'میعاد ختم';

  @override
  String get lowBalanceTrigger => 'کم بیلنس ٹرگر';

  @override
  String get triggerLowTopUp => 'کم بیلنس پر ٹاپ اپ ٹرگر کریں';

  @override
  String get reloadDepositAmount => 'ری لوڈ جمع کی رقم';

  @override
  String get amountToLoad => 'لوڈ کرنے کی رقم';

  @override
  String get linkCreditDebitCard => 'کریڈٹ/ڈیبٹ کارڈ لنک کریں';

  @override
  String get cardNumberLabel => 'کارڈ نمبر';

  @override
  String get expiryDateLabel => 'میعاد ختم ہونے کی تاریخ';

  @override
  String get cvvCodeLabel => 'CVV کوڈ';

  @override
  String get securelyLinkCard => 'محفوظ طریقے سے کارڈ لنک کریں';

  @override
  String get pleaseEnterValidCardNumber =>
      'براہ کرم ایک درست 16 ہندسوں کا کارڈ نمبر درج کریں۔';

  @override
  String get pleaseEnterValidExpiryDate =>
      'براہ کرم درست میعاد ختم ہونے کی تاریخ درج کریں (MM/YY)۔';

  @override
  String get invalidExpiryMonth => 'غلط میعاد ختم ہونے کا مہینہ۔';

  @override
  String get cvvMustBe3Digits => 'CVV 3 ہندسوں کا ہونا چاہیے۔';

  @override
  String get cardLinkedSuccessfully => 'محفوظ بلنگ کارڈ کامیابی سے لنک ہو گیا!';

  @override
  String get defaultPaymentCardUpdated => 'ڈیفالٹ ادائیگی کارڈ اپڈیٹ ہو گیا!';

  @override
  String get removePaymentCard => 'ادائیگی کارڈ ہٹائیں';

  @override
  String get confirmRemoveCardDesc =>
      'کیا آپ واقعی اس کارڈ کو ہٹانا چاہتے ہیں؟ اگر کوئی ڈیفالٹ ادائیگی کارڈ باقی نہ رہا تو لنک شدہ آٹو-فنڈنگ ناکام ہو سکتی ہے۔';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get remove => 'ہٹائیں';

  @override
  String get billingCardSuccessfullyRemoved =>
      'بلنگ کارڈ کامیابی سے ہٹا دیا گیا۔';

  @override
  String get pleaseAddDefaultCardFirst =>
      'آٹو-فنڈنگ فعال کرنے کے لیے براہ کرم پہلے ایک ڈیفالٹ ادائیگی کارڈ شامل کریں اور منتخب کریں۔';

  @override
  String get autoFundPrefsSavedSuccess =>
      'آٹو-فنڈنگ ترجیحات کامیابی سے محفوظ ہو گئیں!';

  @override
  String get preparingDataExport => 'ڈیٹا ایکسپورٹ تیار کیا جا رہا ہے...';

  @override
  String exportFailed(String error) {
    return 'ایکسپورٹ ناکام: $error';
  }

  @override
  String get deleteAccountWarning =>
      'ایک بار اکاؤنٹ ڈیلیٹ کرنے کے بعد، واپسی ممکن نہیں۔ براہ کرم یقینی بنائیں۔';

  @override
  String get deleteAccount => 'اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deleteAccountIrreversible =>
      'یہ عمل ناقابل واپسی ہے۔ آپ کا تمام ڈیٹا مستقل طور پر ختم کر دیا جائے گا۔';

  @override
  String get typeDeleteToConfirm => 'تصدیق کے لیے \"DELETE\" ٹائپ کریں:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'سسٹم ڈائیگناسٹکس لاگز';

  @override
  String get online => 'آن لائن';

  @override
  String errorLoadingPrefs(String error) {
    return 'ترجیحات لوڈ کرنے میں خرابی: $error';
  }

  @override
  String get privacyPolicyLoaded => 'پرائیویسی پالیسی کی تفصیلات لوڈ ہو گئیں۔';

  @override
  String get protectionConsole => 'پروٹیکشن کنسول';

  @override
  String get deleteProtectionTooltip => 'پروٹیکشن ڈیلیٹ کریں';

  @override
  String get refreshTooltip => 'ریفریش کریں';

  @override
  String get failedToLoadDetails => 'تفصیلات لوڈ کرنے میں ناکامی';

  @override
  String get retryConnection => 'کنکشن دوبارہ کوشش کریں';

  @override
  String get healthLabel => 'ہیلتھ';

  @override
  String get mySimCardDefault => 'میرا SIM کارڈ';

  @override
  String get upLabel => 'اپ';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'شیئر کردہ از: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'نازک خطرہ';

  @override
  String get simDeactivationRisk =>
      'کارروائی نہ کرنے پر SIM غیر فعال ہو سکتا ہے';

  @override
  String get missingAlertsDesc =>
      'کوئی الرٹ نوٹیفکیشن کنفیگر نہیں — 100 پوائنٹس کم';

  @override
  String get missingAutoRefillDesc =>
      'کوئی آٹو-ریفل کنفیگر نہیں — 50 پوائنٹس کم';

  @override
  String get missingVerificationDesc =>
      'فون نمبر تصدیق شدہ نہیں — 25 پوائنٹس کم';

  @override
  String get missingRecentRefillDesc =>
      'آخری ریفل 80 دن سے زیادہ پہلے ہوا تھا — 25 پوائنٹس کم';

  @override
  String get quickActionsLabel => 'فوری اقدامات';

  @override
  String get manualRefillLabel => 'مینوئل ریفل';

  @override
  String get chargeFromWalletNow => 'ابھی والیٹ سے چارج کریں';

  @override
  String get rechargeFromFriend => 'دوست سے ریچارج کروائیں';

  @override
  String get requestViaTelegram => 'Telegram کے ذریعے درخواست کریں';

  @override
  String get shareViaWaTg => 'WhatsApp/Telegram کے ذریعے شیئر کریں';

  @override
  String get testSimActivity => 'SIM سرگرمی ٹیسٹ کریں';

  @override
  String get verifyLineReachable => 'تصدیق کریں کہ لائن قابل رسائی ہے';

  @override
  String get checkCompleted1x => '1x چیک مکمل ہوا';

  @override
  String get starterPlan1xCompleted =>
      'اسٹارٹر پلان کا 1x چیک مکمل ہوا۔ غیر محدود چیکس کے لیے پریمیم میں اپ گریڈ کریں۔';

  @override
  String leaveCountry(String countryName) {
    return '$countryName چھوڑیں';
  }

  @override
  String get resumeProtectionLayers => 'پروٹیکشن لیئرز دوبارہ شروع کریں';

  @override
  String backToCountryMode(String countryName) {
    return '$countryName موڈ پر واپس جائیں';
  }

  @override
  String get pauseWhileVisitingHome => 'گھر آنے کے دوران روکیں';

  @override
  String get rechargeFromFriendTitle => 'کسی دوست سے ریچارج کروائیں';

  @override
  String get selectPlatformShare =>
      'اپنے دوست کے ساتھ ریچارج درخواست کا پیغام شیئر کرنے کے لیے ایک پلیٹ فارم منتخب کریں۔';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'ہیلو! میرا KeepSIMs کارڈ ($phone) جلد ختم ہو رہا ہے۔ کیا آپ براہ کرم میرے لیے اسے ریچارج کر سکتے ہیں؟ شکریہ!';
  }

  @override
  String get requestViaWhatsApp => 'WhatsApp کے ذریعے درخواست کریں';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return '$platformName لنک لانچ نہیں ہو سکا: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Telegram لنک لانچ نہیں ہو سکا: $error';
  }

  @override
  String get protectionLayersLabel => 'پروٹیکشن لیئرز';

  @override
  String get autoNotifyDisabled => 'آٹو-نوٹیفائی: غیر فعال';

  @override
  String get noActiveAlertSchedule =>
      'آپ کے SIM کارڈ کا کوئی فعال الرٹ نوٹیفکیشن شیڈول نہیں ہے۔ آپ کو خودکار یاد دہانیاں یا ڈی ایکٹیویشن الرٹس موصول نہیں ہوں گے۔';

  @override
  String get askOwnerConfigureAlerts =>
      'براہ کرم گھرانے کے مالک سے الرٹس کنفیگر کرنے کے لیے کہیں۔';

  @override
  String get configureAutoNotify => 'آٹو-نوٹیفائی کنفیگر کریں';

  @override
  String get activeLabel => 'فعال';

  @override
  String get pausedHomeMode => 'رکا ہوا (ہوم موڈ)';

  @override
  String get pausedLabel => 'رکا ہوا';

  @override
  String get everyHour => 'ہر 1 گھنٹے میں';

  @override
  String everyNDays(int days) {
    return 'ہر $days دن میں';
  }

  @override
  String get nextAlertCheck => 'اگلا الرٹ چیک';

  @override
  String get premiumKeepAliveRefill => 'پریمیم کیپ-الائیو ریفل';

  @override
  String autoRefillIncludedText(String date) {
    return 'آٹو-ریفل شامل ہے - ~3.5 USD (ٹیلی کام، VAT شامل) ہر 85 دن میں،\\nاگلا ریفل $date پر';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'پریمیم کیپ-الائیو ریفل فی الحال غیر فعال ہے۔';

  @override
  String get customAutoRefill => 'کسٹم آٹو-ریفل';

  @override
  String get addAdditionalScheduledRecharge =>
      'اپنے SIM پر اضافی بیلنس برقرار رکھنے کے لیے ایک اضافی شیڈولڈ ریچارج رقم شامل کریں۔';

  @override
  String get askOwnerConfigureRefill =>
      'براہ کرم گھرانے کے مالک سے آٹو-ریفل کنفیگر کرنے کے لیے کہیں۔';

  @override
  String get configureCustomAutoRefill => 'کسٹم آٹو-ریفل کنفیگر کریں';

  @override
  String get rechargeAmount => 'ریچارج کی رقم';

  @override
  String get refillInterval => 'ریفل کا وقفہ';

  @override
  String get nextRefillDue => 'اگلا ریفل کب ہے';

  @override
  String get failedRefillAttempts => 'ناکام ریفل کوششیں';

  @override
  String retriesCount(int count) {
    return '$count / 4 دوبارہ کوششیں';
  }

  @override
  String get editRefillAmount => 'ریفل کی رقم میں ترمیم کریں';

  @override
  String get refillExecutionsHistory => 'ریفل ایگزیکیوشنز ہسٹری';

  @override
  String get renewalExecutionsHistory => 'تجدید ایگزیکیوشنز ہسٹری';

  @override
  String get noHistoricalTopup =>
      'اس لائن کے لیے ابھی تک کوئی سابقہ ٹاپ اپ ایگزیکیوشن ریکارڈ نہیں ہوئی۔';

  @override
  String get noHistoricalRenewal =>
      'اس لائن کے لیے ابھی تک کوئی سابقہ تجدید ایگزیکیوشن ریکارڈ نہیں ہوئی۔';

  @override
  String get viewAllHistory => 'تمام ہسٹری دیکھیں';

  @override
  String get securityActivityLogs => 'سیکیورٹی ایکٹیویٹی لاگز';

  @override
  String get clearLogs => 'لاگز صاف کریں';

  @override
  String get noActivityLogsRecorded =>
      'اس لائن کے لیے ابھی تک کوئی ایکٹیویٹی لاگ ریکارڈ نہیں ہوئی۔';

  @override
  String get activityLogDeleted => 'ایکٹیویٹی لاگ اندراج ڈیلیٹ ہو گیا۔';

  @override
  String get activityLogsCleared => 'ایکٹیویٹی لاگز کامیابی سے صاف ہو گئیں۔';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'آٹو-تجدید کامیابی سے $status ہوئی۔';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'شیڈول اپڈیٹ کرنے میں ناکامی: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'پریمیم کیپ-الائیو ریفل کامیابی سے فعال ہو گیا۔';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'آٹو-ریفل فعال کرنے میں ناکامی: $error';
  }

  @override
  String get removeScheduleTitle => 'شیڈول ہٹائیں';

  @override
  String get confirmDeleteAutoRefill =>
      'کیا آپ واقعی اس آٹو-ریفل شیڈول کو ڈیلیٹ کرنا چاہتے ہیں؟ آپ کا SIM ہیلتھ سکور نمایاں طور پر گر جائے گا، جس سے غیر فعال ہونے کا خطرہ بڑھ جائے گا۔';

  @override
  String get confirmDeleteAutoRenewal =>
      'کیا آپ واقعی اس آٹو-تجدید شیڈول کو ڈیلیٹ کرنا چاہتے ہیں؟ آپ کا SIM ہیلتھ سکور نمایاں طور پر گر جائے گا، جس سے غیر فعال ہونے کا خطرہ بڑھ جائے گا۔';

  @override
  String get autoRefillRemoved => 'آٹو-ریفل شیڈول کامیابی سے ہٹا دیا گیا۔';

  @override
  String get autoRenewalRemoved => 'آٹو-تجدید شیڈول کامیابی سے ہٹا دیا گیا۔';

  @override
  String failedToDeleteSchedule(String error) {
    return 'شیڈول ڈیلیٹ کرنے میں ناکامی: $error';
  }

  @override
  String get refillRetrySuccess => 'ریفل دوبارہ کوشش کامیابی سے مکمل ہوئی!';

  @override
  String get refillRetryQueued =>
      'دوبارہ کوشش قطار میں شامل کر دی گئی — ریفل پر کارروائی جاری ہے۔';

  @override
  String get renewalRetrySuccess => 'تجدید دوبارہ کوشش کامیابی سے مکمل ہوئی!';

  @override
  String retryFailed(String error) {
    return 'دوبارہ کوشش ناکام: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'دوبارہ کوشش ایگزیکیوشن خرابی: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'ایکٹیویٹی لاگ ڈیلیٹ کرنے میں ناکامی: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'ایکٹیویٹی لاگز صاف کرنے میں ناکامی: $error';
  }

  @override
  String get removeProtectionTitle => 'پروٹیکشن ہٹائیں';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'کیا آپ واقعی $name کو محفوظ رکھنا بند کرنا چاہتے ہیں؟ اس SIM لائن کے لیے شیڈولڈ ٹاپ اپس مستقل طور پر منسوخ ہو جائیں گے۔';
  }

  @override
  String get simLineProtectionRemoved =>
      'SIM لائن پروٹیکشن کامیابی سے ہٹا دی گئی۔';

  @override
  String failedToDeleteSimLine(String error) {
    return 'ڈیلیٹ کرنے میں ناکامی: $error';
  }

  @override
  String get editSimNameTitle => 'SIM کا نام ترمیم کریں';

  @override
  String get enterNicknameInstruction =>
      'اس SIM کارڈ لائن کے لیے ایک عرفیت درج کریں:';

  @override
  String get nicknameExampleHint => 'مثلاً میرا Orange Egypt SIM';

  @override
  String get simNameUpdatedSuccess => 'SIM کا نام کامیابی سے اپڈیٹ ہو گیا۔';

  @override
  String failedToUpdateSimName(String error) {
    return 'SIM کا نام اپڈیٹ کرنے میں ناکامی: $error';
  }

  @override
  String get saveButton => 'محفوظ کریں';

  @override
  String get deleteButton => 'ڈیلیٹ کریں';

  @override
  String get autoNotifySchedule => 'آٹو-نوٹیفائی شیڈول';

  @override
  String get renewalCheckInterval => 'تجدید چیک کا وقفہ';

  @override
  String get editNotificationConfig => 'نوٹیفکیشن کنفیگ میں ترمیم کریں';

  @override
  String get openTicket => 'ٹکٹ کھولیں';

  @override
  String get offlineRefillLabel => 'آف لائن ریفل';

  @override
  String get categoryLabel => 'زمرہ';

  @override
  String get techSupportCategory => 'تکنیکی معاونت';

  @override
  String get billingWalletCategory => 'بلنگ اور والیٹ';

  @override
  String get simLinesCategory => 'SIM لائنز کا انتظام';

  @override
  String get feedbackOtherCategory => 'فیڈبیک اور دیگر';

  @override
  String get subjectLabel => 'موضوع';

  @override
  String get subjectHint => 'مسئلے کا مختصر خلاصہ';

  @override
  String get descriptionLabel => 'تفصیل';

  @override
  String get descriptionHint => 'اپنے مسئلے کو تفصیل سے بیان کریں...';

  @override
  String get attachmentLabel => 'اٹیچمنٹ (اختیاری)';

  @override
  String get uploadScreenshot => 'اسکرین شاٹ اپ لوڈ کریں';

  @override
  String get submitTicketButton => 'ٹکٹ جمع کریں';

  @override
  String get pleaseFillFields => 'براہ کرم موضوع اور تفصیل دونوں پُر کریں';

  @override
  String get ticketSubmittedSuccess => 'ٹکٹ کامیابی سے جمع ہو گیا!';

  @override
  String get lastRefillLabel => 'آخری ریفل';

  @override
  String get noRefillYet => 'ابھی تک کوئی ریفل نہیں';

  @override
  String get nextAlertLabel => 'اگلا الرٹ';

  @override
  String get protectionLabel => 'پروٹیکشن';

  @override
  String get actionRequiredLabel => 'کارروائی درکار';

  @override
  String get protectionOffLabel => 'پروٹیکشن آف';

  @override
  String get notSet => 'سیٹ نہیں';

  @override
  String get homeMode => 'ہوم موڈ';

  @override
  String get keepProtectedAtHome => 'گھر پر بھی تحفظ جاری رکھیں';

  @override
  String get protectionPausesAtHome => 'گھر پر تحفظ عارضی طور پر رک جاتا ہے';

  @override
  String get incidentChannelsTitle => 'انسیڈنٹ چینلز';

  @override
  String get topUpSuccessTitle => 'ٹاپ اپ کامیاب';

  @override
  String get topUpSuccessDesc =>
      'جب خودکار SIM ویلیڈیٹی توسیع کامیابی سے مکمل ہو جائے تو مجھے مطلع کریں۔';

  @override
  String get topUpFailedTitle => 'ٹاپ اپ ناکام (نازک)';

  @override
  String get topUpFailedDesc =>
      'جب کیریئر یا والیٹ کے مسائل کی وجہ سے خودکار ٹاپ اپس ناکام ہو جائیں تو نازک الرٹس۔';

  @override
  String get walletLowTitle => 'کم والیٹ بیلنس';

  @override
  String get walletLowDesc =>
      'جب بنیادی بیلنس حفاظتی حد سے نیچے چلا جائے تو مجھے خبردار کریں۔';

  @override
  String get walletDepletedTitle => 'والیٹ ختم';

  @override
  String get walletDepletedDesc =>
      'جب والیٹ بیلنس مکمل طور پر ختم ہو جائے اور تجدیدات رک جائیں تو معطل شدہ الرٹس۔';

  @override
  String get lineCriticalTitle => 'ویلیڈیٹی ختم ہونے کی وارننگ';

  @override
  String get lineCriticalDesc =>
      'جب SIM ویلیڈیٹی ونڈو 48 گھنٹوں میں ختم ہونے والی ہو تو مجھے خبردار کریں۔';

  @override
  String get lineEnteringGraceTitle => 'گریس پیریڈ شروع ہو رہا ہے';

  @override
  String get lineEnteringGraceDesc =>
      'جب کیریئر ڈی ایکٹیویشن گریس پیریڈز کا پتہ چلے تو مجھے مطلع کریں۔';

  @override
  String get geoFenceTriggeredTitle => 'لوکیشن / رومنگ الرٹس';

  @override
  String get geoFenceTriggeredDesc =>
      'جب کیریئر رومنگ کلسٹرز یا نیٹ ورک نوڈز تبدیل کرے تو الرٹس۔';

  @override
  String get welcomeHomeReadyTitle => 'ویلکم ہوم سنک';

  @override
  String get welcomeHomeReadyDesc =>
      'جب ہوم-کنٹری نیٹ ورک نوڈ خودکار سنک ٹرگر کرے تو الرٹس۔';

  @override
  String get referralRewardTitle => 'ریفرل اور ریوارڈز';

  @override
  String get referralRewardDesc =>
      'جب دوستوں کے ریفرلز میرے والیٹ میں پروموشنل بیلنس جمع کریں تو مجھے مطلع کریں۔';

  @override
  String get systemUpdatesTitle => 'عمومی سسٹم اپڈیٹس';

  @override
  String get systemUpdatesDesc =>
      'اہم انجن اپڈیٹس، مینٹیننس، اور پلیٹ فارم اعلانات۔';

  @override
  String get walletCreditTitle => 'والٹ میں رقم جمع';

  @override
  String get walletCreditDesc =>
      'جب میرے والٹ میں رقم جمع ہو تو مجھے اطلاع دیں۔';

  @override
  String get promoTitle => 'پیشکشیں اور پروموشنز';

  @override
  String get promoDesc =>
      'سودوں اور نئی خصوصیات کے بارے میں کبھی کبھار خبریں۔ جب تک آپ آن نہ کریں بند رہتا ہے۔';

  @override
  String get deliverVia => 'اس کے ذریعے بھیجیں';

  @override
  String get channelPushShort => 'پش';

  @override
  String get channelEmailShort => 'ای میل';

  @override
  String get channelOffGlobally => 'اوپر الرٹ چینلز میں بند ہے';

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
  String get rechargeNow => 'ابھی ریچارج کریں';

  @override
  String get planFeePaidFromWallet =>
      'پلان کی فیس آپ کے والٹ بیلنس سے ادا کر دی گئی۔';

  @override
  String activityTopupRequested(String amount) {
    return '\$$amount کے لیے ری فل کی درخواست جمع کر دی گئی';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return '$provider کے ذریعے \$$amount کا ٹاپ اپ مکمل ہو گیا';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return '\$$amount کا ٹاپ اپ ناکام ہو گیا: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return '\$$amount کا ری فل والٹ میں واپس کر دیا گیا';
  }

  @override
  String activityTopupCancelled(String amount) {
    return '\$$amount کے ری فل کی درخواست منسوخ کر دی گئی';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return '\$$amount کے ری فل کی دوبارہ کوشش صف میں شامل کر دی گئی';
  }

  @override
  String get activityLineCreated => 'سم لائن SIM Shield میں رجسٹر ہو گئی';

  @override
  String get activityHealthUpdate => 'سم لائن کی فعال حیثیت کی تصدیق ہو گئی';

  @override
  String get activityReminderSent =>
      'تجدید کی یاد دہانی کا نوٹیفکیشن بھیج دیا گیا';

  @override
  String get supportTicketsTitle => 'مدد اور معاونت';

  @override
  String get supportTicketsSubtitle =>
      'مدد کی درخواستیں جمع کرائیں، سرگرمی کے لاگز منسلک کریں، اور ہماری سپورٹ ٹیم کے ساتھ براہ راست بات چیت کریں۔';

  @override
  String get supportTicketsEmpty => 'کوئی سپورٹ ٹکٹ نہیں ملا۔';

  @override
  String get createSupportTicket => 'ٹکٹ بنائیں';

  @override
  String get ticketCategoryGeneral => 'عام پوچھ گچھ';

  @override
  String get ticketCategoryBilling => 'بلنگ اور والٹ';

  @override
  String get ticketCategoryTechnical => 'تکنیکی مسئلہ';

  @override
  String get ticketCategoryRefillIssue => 'ری فل کا مسئلہ';

  @override
  String get ticketCategoryAccount => 'اکاؤنٹ اور سیکیورٹی';

  @override
  String get ticketStatusOpen => 'کھلا ہوا';

  @override
  String get ticketStatusPending => 'جواب کا منتظر';

  @override
  String get ticketStatusResolved => 'حل ہو گیا';

  @override
  String get ticketStatusClosed => 'بند';

  @override
  String get ticketSubjectLabel => 'موضوع';

  @override
  String get ticketSubjectHint => 'مسئلے کی مختصر تفصیل';

  @override
  String get ticketCategoryLabel => 'زمرہ';

  @override
  String get ticketMessageLabel => 'پیغام';

  @override
  String get ticketMessageHint => 'تفصیلی معلومات فراہم کریں...';

  @override
  String get attachImage => 'تصویر منسلک کریں';

  @override
  String get attachActivityLogs => 'لائن لاگز منسلک کریں';

  @override
  String get submitTicket => 'ٹکٹ جمع کرائیں';

  @override
  String get typeMessageHint => 'پیغام لکھیں...';

  @override
  String get closeTicketButton => 'ٹکٹ بند کریں';

  @override
  String get ticketClosedNotice => 'یہ سپورٹ ٹکٹ بند کر دیا گیا ہے۔';

  @override
  String get attachedFiles => 'منسلکات';

  @override
  String get referralsTitle => 'ریفر کریں اور کمائیں';

  @override
  String get referralsSubtitle =>
      'دوستوں کو مدعو کریں، ان کے سم سبسکرپشنز پر پوائنٹس کمائیں اور والٹ کریڈٹ کے لیے ریڈیم کریں!';

  @override
  String get referralCode => 'آپ کا ریفرل کوڈ';

  @override
  String get copyCode => 'کوڈ کاپی کریں';

  @override
  String get codeCopied => 'ریفرل کوڈ کلپ بورڈ پر کاپی ہو گیا!';

  @override
  String get shareCode => 'کوڈ شیئر کریں';

  @override
  String get pointsBalance => 'پوائنٹس کا بیلنس';

  @override
  String get pointsUnit => 'پوائنٹس';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return 'اگلے \$2.00 انعام کے لیے مزید $pointsNeeded پوائنٹس درکار ہیں';
  }

  @override
  String get redeemButton => '\$2.00 کے لیے 10 پوائنٹس ریڈیم کریں';

  @override
  String get redeemSuccess =>
      '\$2.00 والٹ کریڈٹ کے لیے 10 پوائنٹس کامیابی سے ریڈیم ہو گئے!';

  @override
  String get applyCodeTitle => 'کیا آپ کے پاس ریفرل کوڈ ہے؟';

  @override
  String get applyCodeHint => 'ریفرل کوڈ درج کریں';

  @override
  String get applyCodeButton => 'کوڈ اپلائی کریں';

  @override
  String get applyCodeSuccess => 'ریفرل کوڈ کامیابی سے اپلائی ہو گیا!';

  @override
  String get referredFriendsTitle => 'ریفر کیے گئے دوست';

  @override
  String get noReferredFriends =>
      'ابھی تک کوئی دوست ریفر نہیں کیا گیا۔ شروع کرنے کے لیے اپنا کوڈ شیئر کریں!';

  @override
  String get redemptionHistoryTitle => 'ریڈیمپشن کی ہسٹری';

  @override
  String get noRedemptions => 'ابھی تک کوئی ریڈیمپشن نہیں۔';

  @override
  String get pointHistoryTitle => 'پوائنٹس کی ہسٹری';

  @override
  String get noPointsEarned => 'ابھی تک کوئی پوائنٹس نہیں کمائے گئے۔';

  @override
  String get howItWorksTitle => 'ریفر اور ارن کیسے کام کرتا ہے';

  @override
  String get howItWorksStep1 =>
      '1. دوستوں کے ساتھ اپنا منفرد ریفرل کوڈ شیئر کریں۔';

  @override
  String get howItWorksStep2 =>
      '2. جب بھی کوئی ریفر کیا گیا دوست سم لائن سبسکرائب کرے تو 1 پوائنٹ کمائیں۔';

  @override
  String get howItWorksStep3 =>
      '3. کسی بھی وقت \$2.00 والٹ کریڈٹ کے لیے 10 پوائنٹس ریڈیم کریں!';

  @override
  String get geoTitle => 'سفر اور جیو لوکیشن';

  @override
  String get geoSubtitle =>
      'خودکار ملک کی نشاندہی اور بین الاقوامی سم لائن کی تحفظ';

  @override
  String get currentCountryLabel => 'موجودہ مقام';

  @override
  String get travelModeToggle => 'ٹریول موڈ';

  @override
  String get travelModeDescription =>
      'بین الاقوامی لائن کے تحفظ کو منظم کرنے کے لیے ایپ کھولتے وقت ملک چیک کریں';

  @override
  String get geoNotice =>
      'ایپ کھولنے پر IP تلاش کے ذریعے ملک کی تصدیق کی جاتی ہے۔ لوکیشن کی اجازت درکار نہیں۔';

  @override
  String get freezeInternationalLines => 'بین الاقوامی لائنیں منجمد کریں';

  @override
  String get resumeInternationalLines => 'بین الاقوامی لائنیں دوبارہ فعال کریں';

  @override
  String get linesFrozenSuccess =>
      'بین الاقوامی سم لائنیں منجمد ہو گئیں اور ری فلز کو روک دیا گیا!';

  @override
  String get linesResumedSuccess =>
      'بین الاقوامی سم لائنیں اور ری فلز دوبارہ فعال ہو گئے!';

  @override
  String get alwaysProtectedBadge => 'ہمیشہ محفوظ';

  @override
  String get detectedViaIp => 'IP کے ذریعے نشاندہی کی گئی';

  @override
  String get esimManagerTitle => 'eSIM منیجر';

  @override
  String get esimPlansTitle => 'eSIM پلانز';

  @override
  String get searchDestinationHint => 'منزل تلاش کریں (مثلاً فرانس، امریکہ)';

  @override
  String get selectDestinationTitle => 'منزل منتخب کریں';

  @override
  String get localTab => 'مقامی';

  @override
  String get regionalTab => 'علاقائی';

  @override
  String get globalTab => 'عالمی';

  @override
  String get bestValueBadge => 'بہترین قیمت';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days دن';
  }

  @override
  String get buyPlanButton => 'پلان خریدیں';

  @override
  String get deviceIncompatibleNotice =>
      'آپ کا آلہ eSIM ٹیکنالوجی کو سپورٹ نہیں کرتا۔';

  @override
  String get activationPolicyTitle => 'ایکٹیویشن پالیسی';

  @override
  String get activationPolicyNotice =>
      'میعاد کی شروعات تب ہوتی ہے جب eSIM آپ کی منزل پر سپورٹ شدہ نیٹ ورک سے منسلک ہوتا ہے۔';

  @override
  String get coveredCountriesTitle => 'شامل ممالک';

  @override
  String get sortPriceLowToHigh => 'قیمت: کم سے زیادہ';

  @override
  String get sortPricePerGb => 'قیمت / GB: کم سے زیادہ';

  @override
  String get sortDataHighToLow => 'ڈیٹا: زیادہ سے کم';

  @override
  String get filterAll => 'تمام پلانز';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ 15 دن';

  @override
  String get filterUnlimited => 'لامحدود';

  @override
  String get purchaseInNextRelease =>
      'Purchase flow will land in the next release (C9b).';

  @override
  String get confirmPurchaseTitle => 'eSIM خریداری کی تصدیق کریں';

  @override
  String get myEsimsTitle => 'میری eSIMs';

  @override
  String get showQrCode => 'کیو آر کوڈ دکھائیں';

  @override
  String get buyAgain => 'دوبارہ خریدیں';

  @override
  String get dataRemaining => 'بقیہ ڈیٹا';

  @override
  String get archivedEsims => 'محفوظ شدہ eSIMs';

  @override
  String rateLimitExceeded(String seconds) {
    return 'بہت سی درخواستیں۔ دوبارہ کوشش کرنے سے پہلے براہ کرم $seconds سیکنڈ انتظار کریں۔';
  }

  @override
  String get confirmDeleteButton => 'منسوخی کی تصدیق کریں';

  @override
  String get cancelAccountDeletion => 'کھاتہ منسوخی منسوخ کریں';

  @override
  String get accountScheduledForDeletion => 'کھاتہ منسوخ کرنے کا شیڈول ہے';

  @override
  String deletionScheduledNotice(String date) {
    return 'آپ کا اکاؤنٹ منجمد کر دیا گیا ہے اور $date کو مستقل طور پر حذف کرنے کا شیڈول ہے۔';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'آپ کا والٹ بیلنس (\$$balance) حد (\$1.00) سے زیادہ ہے۔ برائے مہربانی اسے خرچ کریں یا سپورٹ سے رابطہ کریں۔';
  }

  @override
  String get payPalCheckoutTitle => 'PayPal چیک آؤٹ';

  @override
  String get payPalWalletTopUp => 'KeepSIMs والٹ ٹاپ اپ';

  @override
  String get payPalPaySecurely => 'PayPal کے ساتھ محفوظ ادائیگی کریں';

  @override
  String get payPalRedirectInfo =>
      'ادائیگی کی توثیق کے لیے آپ کو PayPal پر بھیجا جائے گا۔';

  @override
  String get payPalCreatingOrder => 'محفوظ PayPal آرڈر بنایا جا رہا ہے...';

  @override
  String get payPalAwaitingConfirmation => 'PayPal کی تصدیق کا انتظار ہے...';

  @override
  String get payPalCompleteInBrowser =>
      'براہ کرم کھلی ہوئی براؤزر ونڈو میں ادائیگی مکمل کریں۔';

  @override
  String get payPalPaymentConfirmed => 'ادائیگی کی تصدیق ہو گئی!';

  @override
  String get payPalPaymentFailed => 'ادائیگی ناکام ہو گئی یا منسوخ کر دی گئی۔';

  @override
  String get payPalForceCaptureButton =>
      'میں نے PayPal پر ادائیگی مکمل کر لی ہے';

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
  String get householdTitle => 'گھرانہ اور خاندان';

  @override
  String get householdTabMyFamily => 'میرا خاندان';

  @override
  String get householdTabReceived => 'دعوت نامے';

  @override
  String get householdTabJoined => 'شامل شدہ';

  @override
  String get householdInviteMember => 'رکن کو مدعو کریں';

  @override
  String get householdEmptyTitle => 'ابھی کوئی رکن نہیں';

  @override
  String get householdEmptyDesc =>
      'ای میل کے ذریعے کسی کو مدعو کریں اور اپنی پری پیڈ سم لائنیں اور تجدید شیئر کریں۔';

  @override
  String get householdStatusPending => 'زیر التوا';

  @override
  String get householdStatusAccepted => 'فعال';

  @override
  String get householdPendingHint => 'ان کے قبول کرنے کا انتظار';

  @override
  String get householdRoleViewer => 'ناظر';

  @override
  String get householdRoleManager => 'منتظم';

  @override
  String get householdRoleViewerHint => 'آپ کی لائنیں دیکھ سکتا ہے';

  @override
  String get householdRoleManagerHint =>
      'آپ کی لائنیں دیکھ اور ری چارج کر سکتا ہے';

  @override
  String get householdManagerWarning =>
      'منتظم آپ کی لائنیں ری چارج کر سکتا ہے۔ وہ آپ کے والٹ سے تبھی خرچ کرے گا جب آپ حد مقرر کریں۔';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'میرے والٹ سے خرچ · اس ماہ $cap میں سے $spent';
  }

  @override
  String get householdPaysOwnWallet => 'اپنے والٹ سے ادائیگی کرتا ہے';

  @override
  String get householdManagersOnly =>
      'صرف منتظم — ناظر آپ کے والٹ سے خرچ نہیں کر سکتا';

  @override
  String get householdChangeLimit => 'حد تبدیل کریں';

  @override
  String get householdSetLimit => 'حد مقرر کریں';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining باقی · $queued قطار میں، ابھی وصول نہیں';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return 'اس ماہ $remaining باقی';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return '$name کے لیے خرچ کی حد';
  }

  @override
  String get householdSpendingLimitDesc =>
      'ہر کیلنڈر ماہ وہ آپ کی لائنوں پر آپ کے والٹ سے کتنا خرچ کر سکتا ہے۔ بند کرنے کے لیے 0 رکھیں — پھر وہ اپنے والٹ سے ادائیگی کرے گا۔';

  @override
  String get householdMonthlyLimit => 'ماہانہ حد (USD)';

  @override
  String get householdMaxPerRefill => 'فی ری چارج زیادہ سے زیادہ (اختیاری)';

  @override
  String get householdSave => 'محفوظ کریں';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name اب ہر ماہ آپ کے والٹ سے $cap تک خرچ کر سکتا ہے۔';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name دوبارہ اپنے والٹ سے ادائیگی کرے گا۔';
  }

  @override
  String get householdLimitFailed => 'حد اپ ڈیٹ نہیں ہو سکی۔';

  @override
  String get householdNoInvitesTitle => 'کوئی دعوت نہیں';

  @override
  String get householdNoInvitesDesc =>
      'جب کوئی آپ کو اپنے گھرانے میں مدعو کرے گا تو یہاں دکھائی دے گا۔';

  @override
  String get householdFamilyAccount => 'خاندانی اکاؤنٹ';

  @override
  String get householdInvitedYouViewer =>
      'آپ کو اپنی سم لائنیں دیکھنے کی دعوت دی';

  @override
  String get householdInvitedYouManager =>
      'آپ کو اپنی سم لائنیں دیکھنے اور ری چارج کرنے کی دعوت دی';

  @override
  String get householdAccept => 'قبول کریں';

  @override
  String get householdDecline => 'مسترد کریں';

  @override
  String get householdNotJoinedTitle => 'آپ کسی گھرانے میں شامل نہیں ہوئے';

  @override
  String get householdNotJoinedDesc =>
      'آپ کو موصول دعوتیں دعوت نامے ٹیب میں دکھائی دیتی ہیں۔';

  @override
  String get householdSharedHousehold => 'مشترکہ گھرانہ';

  @override
  String get householdRoleManagerFull => 'منتظم · ری چارج کر سکتا ہے';

  @override
  String get householdRoleViewerFull => 'ناظر · صرف پڑھنے کے لیے';

  @override
  String get householdLeave => 'چھوڑ دیں';

  @override
  String householdOwnerFunds(String owner) {
    return '$owner آپ کے ری چارج کا خرچ اٹھاتے ہیں';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'آپ نے اس ماہ کا پورا $cap استعمال کر لیا ہے۔ ری سیٹ ہونے تک ان کی لائنوں پر ری چارج مسترد ہوں گے۔';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return 'اس ماہ $cap میں سے $remaining باقی';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · فی ری چارج زیادہ سے زیادہ $perTxn';
  }

  @override
  String get householdInviteTitle => 'خاندان کے رکن کو مدعو کریں';

  @override
  String get householdInviteDesc =>
      'انہیں ایپ کے اندر ہی دعوت ملے گی۔ قبول کرنے پر آپ کی اور ان کی سم لائنیں ایک ساتھ دکھائی دیں گی۔';

  @override
  String get householdEmailLabel => 'ای میل ایڈریس';

  @override
  String get householdAccessLevel => 'وہ کیا کر سکتے ہیں؟';

  @override
  String get householdSendInvite => 'دعوت بھیجیں';

  @override
  String get householdInvalidEmail => 'براہ کرم درست ای میل ایڈریس درج کریں';

  @override
  String householdInviteSent(String email) {
    return '$email کو دعوت بھیج دی گئی';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return '$email کو دعوت بھیج دی گئی۔ رجسٹر ہوتے ہی انہیں نظر آ جائے گی۔';
  }

  @override
  String get householdInviteAccepted => 'آپ گھرانے میں شامل ہو گئے';

  @override
  String get householdInviteDeclined => 'دعوت مسترد کر دی گئی';

  @override
  String get householdRemoveTitle => 'خاندانی رکن ہٹائیں';

  @override
  String householdRemoveConfirm(String name) {
    return '$name فوراً آپ کی سم لائنوں تک رسائی اور مقرر کردہ خرچ کی حد کھو دے گا۔';
  }

  @override
  String householdRemoved(String name) {
    return '$name کو آپ کے گھرانے سے ہٹا دیا گیا';
  }

  @override
  String get householdLeaveTitle => 'گھرانہ چھوڑ دیں';

  @override
  String householdLeaveConfirm(String owner) {
    return '$owner کی شیئر کردہ سم لائنوں تک آپ کی رسائی ختم ہو جائے گی۔';
  }

  @override
  String get householdLeft => 'آپ نے گھرانہ چھوڑ دیا';

  @override
  String get householdActionFailed =>
      'یہ کام نہیں ہوا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get householdOwnerLabel => 'آپ (مالک)';

  @override
  String get householdSettingsSubtitle =>
      'اپنی سم لائنیں خاندان کے ساتھ شیئر کریں، خرچ کی حد مقرر کریں';

  @override
  String get householdStatusDeclined => 'مسترد شدہ';

  @override
  String get householdDeclinedHint =>
      'انہوں نے مسترد کر دیا۔ دوبارہ مدعو کرنے کے لیے ہٹائیں۔';
}
