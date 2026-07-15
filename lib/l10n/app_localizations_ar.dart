// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'التفضيلات والأمان';

  @override
  String get appAppearance => 'مظهر التطبيق';

  @override
  String get systemTheme => 'النظام';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get localizationAndRegional => 'اللغة والمنطقة';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String currentlyUsing(String langName) {
    return 'تستخدم حالياً $langName';
  }

  @override
  String get selectAppLanguage => 'اختر لغة التطبيق';

  @override
  String get securityAndAccessLock => 'الأمان وقفل الوصول';

  @override
  String get biometricSecurity => 'البصمة البيومترية';

  @override
  String get biometricDesc => 'تسجيل الدخول باستخدام الوجه أو البصمة';

  @override
  String get transactionPin => 'رمز PIN للعمليات';

  @override
  String get transactionPinDesc => 'تأمين التجديدات والسحوبات';

  @override
  String get setup => 'إعداد';

  @override
  String get pinSuccess => 'تم تحديث رمز PIN بنجاح!';

  @override
  String get pinMismatch => 'رمز PIN غير متطابق. حاول مرة أخرى!';

  @override
  String get pinActiveAndSecure => 'إعداد PIN نشط وآمن';

  @override
  String get automatedSummaryAndAlerts => 'الملخص التلقائي والتنبيهات';

  @override
  String get weeklyDigest => 'الملخص الأسبوعي';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get nextNotify => 'التنبيه القادم';

  @override
  String get days => 'أيام';

  @override
  String get showingNearestLine => 'عرض الخط الأقرب';

  @override
  String get addSim => 'إضافة شريحة';

  @override
  String get linesToProtect => 'الخطوط المحمية';

  @override
  String get active => 'نشط';

  @override
  String get upgrade => 'ترقية';

  @override
  String get standard => 'أساسي';

  @override
  String get autoNotify => 'تنبيه تلقائي';

  @override
  String get configure => 'إعداد';

  @override
  String get autoRefill => 'شحن تلقائي';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSims => 'الشرائح';

  @override
  String get navMore => 'المزيد';

  @override
  String get protectedSims => 'الشرائح المحمية';

  @override
  String get mySimCards => 'شرائحي';

  @override
  String get familySharedSims => 'شرائح العائلة المشتركة';

  @override
  String get protectAnotherSimLine => 'حماية خط شريحة آخر';

  @override
  String get keepInfiniteNumbersAlive =>
      'حافظ على عدد غير محدود من الأرقام الدولية نشطة';

  @override
  String get bulkActionsConsole => 'وحدة التحكم في الإجراءات الجماعية';

  @override
  String get resume => 'استئناف';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get simulate => 'محاكاة';

  @override
  String get noProtectedLines => 'لا توجد خطوط محمية';

  @override
  String get noInternationalSimsAdded =>
      'ليس لديك أي شرائح دولية مضافة بعد. قم بحماية شريحتك الأولى الآن لإبقائها نشطة إلى الأبد.';

  @override
  String get protectNewLine => 'حماية خط جديد';

  @override
  String get noSharedSimsYet => 'لا توجد شرائح مشتركة بعد';

  @override
  String get inviteFamilyMembers =>
      'قم بدعوة أفراد العائلة للانضمام إلى أسرتك. بمجرد قبولهم، ستظهر خطوط الشرائح المحمية الخاصة بهم هنا للمراقبة التعاونية.';

  @override
  String get manageHousehold => 'إدارة الأسرة';

  @override
  String get manageProfileDesc =>
      'إدارة ملفك الشخصي، وخطوط الشرائح، والتنبيهات، والتفضيلات المشتركة';

  @override
  String get keepSIMsUser => 'مستخدم KeepSIMs';

  @override
  String get pro => 'محترف';

  @override
  String get homeCountry => 'البلد الأم: ';

  @override
  String get console => 'وحدة التحكم';

  @override
  String get offlineRefill => 'تعبئة الرصيد دون اتصال (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'تعبئة رصيد الشريحة دون اتصال عبر رسائل SMS أو واتساب';

  @override
  String get wallet => 'المحفظة';

  @override
  String get manageBalancesDesc => 'إدارة أرصدتك وعرض سجل المعاملات';

  @override
  String get alertPreferences => 'تفضيلات التنبيهات';

  @override
  String get togglePushEmailDesc =>
      'تبديل إعدادات التنبيهات الفورية والبريد الإلكتروني للتجديدات/الأرصدة';

  @override
  String get referAndEarn => 'أحِل واكسب';

  @override
  String get shareKeepSIMsDesc => 'شارك KeepSIMs وافتح مكافآت الرصيد المتغيرة';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get addBankCardsDesc => 'أضف بطاقات بنكية أو اربط حسابات السحب الآلي';

  @override
  String get travelAndGeolocation => 'السفر والموقع الجغرافي';

  @override
  String get manageHomeCountryDesc =>
      'إدارة قواعد التجميد في البلد الأم ووضع السفر';

  @override
  String get dataAndPrivacy => 'البيانات والخصوصية';

  @override
  String get manageTrackingConsentDesc =>
      'إدارة موافقتك على التتبع، تصدير البيانات، أو حذف الحساب';

  @override
  String get powerUser => 'مستخدم متقدم';

  @override
  String get accessSystemSimulatorsDesc =>
      'الوصول إلى محاكيات النظام وأدوات التصحيح';

  @override
  String get testChecklist => 'قائمة اختبار التحقق';

  @override
  String get manualUiTestingDesc =>
      'قائمة التحقق اليدوية لاختبار واجهة المستخدم لضمان الجودة';

  @override
  String get soon => 'قريباً';

  @override
  String featureComingSoon(String feature) {
    return 'ميزة $feature قادمة قريباً!';
  }

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get confirmLogOut =>
      'هل أنت متأكد من أنك تريد تسجيل الخروج من KeepSIMs؟';

  @override
  String get walletLedger => 'سجل المحفظة';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs مسبق الدفع';

  @override
  String get offlineMode => 'وضع دون اتصال';

  @override
  String get activeBalance => 'الرصيد النشط';

  @override
  String get criticalBalanceLevel => 'مستوى الرصيد حرج';

  @override
  String get balanceBelow10 =>
      'رصيدك أقل من 10.00\$. قد تفشل عمليات شحن الشرائح المجدولة قريباً.';

  @override
  String get depositFunds => 'إيداع الأموال';

  @override
  String get walletDepositsRequireInternet =>
      'تتطلب عمليات إيداع المحفظة اتصالاً نشطاً بالإنترنت.';

  @override
  String get exportLedger => 'تصدير السجل';

  @override
  String get ledgerHistoryExported => 'تم تصدير سجل المعاملات كملف CSV.';

  @override
  String get spendAnalysis => 'تحليل الإنفاق';

  @override
  String get transactionHistory => 'سجل المعاملات';

  @override
  String itemsCount(int count) {
    return '$count عناصر';
  }

  @override
  String get noTransactionsRecorded => 'لم يتم تسجيل أي معاملات بعد.';

  @override
  String get prepaidMonthlyOutflow => 'الإنفاق الشهري مسبق الدفع';

  @override
  String avgMonthlySpend(String amount) {
    return 'المتوسط: \$$amount/شهر (12 شهر)';
  }

  @override
  String depositViaCard(String last4) {
    return 'إيداع عبر بطاقة تنتهي بـ $last4';
  }

  @override
  String get lineRenewal => 'تجديد الخط';

  @override
  String get justNow => 'الآن';

  @override
  String get loadCreditFunds => 'تحميل رصيد';

  @override
  String get depositAmountUsd => 'مبلغ الإيداع (بالدولار)';

  @override
  String get pleaseEnterAmount => 'الرجاء إدخال المبلغ';

  @override
  String get enterPositiveNumber => 'أدخل رقماً موجباً';

  @override
  String get cardDetails => 'تفاصيل البطاقة';

  @override
  String get savedCards => 'البطاقات المحفوظة';

  @override
  String get visaCardNumber => 'رقم بطاقة فيزا';

  @override
  String get pleaseEnterCardNumber => 'الرجاء إدخال رقم البطاقة';

  @override
  String get mustBe16Digits => 'يجب أن يكون 16 رقماً';

  @override
  String get expiryMmYy => 'الانتهاء (شهر/سنة)';

  @override
  String get expiryRequired => 'تاريخ الانتهاء مطلوب';

  @override
  String get invalid => 'غير صالح';

  @override
  String get cvv => 'رمز التحقق (CVV)';

  @override
  String get cvvRequired => 'رمز التحقق مطلوب';

  @override
  String get verifyingCardSecurity => 'جاري التحقق من أمان البطاقة...';

  @override
  String get authorizeDepositFunds => 'تفويض إيداع الأموال';

  @override
  String successfullyDeposited(String amount) {
    return 'تم إيداع \$$amount دولار بنجاح!';
  }

  @override
  String get failedToDepositFunds =>
      'فشل إيداع الأموال. يرجى التحقق من اتصال البطاقة.';

  @override
  String get noSavedPaymentMethods => 'لم يتم العثور على طرق دفع محفوظة.';

  @override
  String get addPaymentMethod => 'إضافة طريقة دفع';

  @override
  String get savedPaymentMethods => 'طرق الدفع المحفوظة';

  @override
  String get addAnotherPaymentMethod => 'إضافة طريقة دفع أخرى';

  @override
  String expiresMmYy(String month, String year) {
    return 'ينتهي في $month/$year';
  }

  @override
  String get offlineRefillTitle => 'تعبئة الرصيد دون اتصال (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'اختر خط الشريحة المستهدف';

  @override
  String get noRegisteredSimLines => 'لم يتم العثور على أي خطوط شرائح مسجلة.';

  @override
  String get targetSimLine => 'خط الشريحة المستهدف';

  @override
  String get simLine => 'خط الشريحة';

  @override
  String get carrier => 'شركة الاتصالات';

  @override
  String get change => 'تغيير';

  @override
  String get offlineRefillProtection => 'حماية تعبئة الرصيد دون اتصال';

  @override
  String get premiumExclusive => 'حصري لـ بريميوم';

  @override
  String get neverGetStrandedDesc =>
      'لن تنقطع أبداً بدون بيانات الجوال مرة أخرى. يتيح لك KeepSIMs بريميوم تعبئة رصيد شريحتك دون اتصال بالإنترنت عبر رسائل SMS المحلية أو واتساب عند انقطاع الاتصال بالإنترنت تماماً.';

  @override
  String get offlineCapability100 => 'إمكانية العمل بنسبة 100% دون اتصال';

  @override
  String get deductsFromKeepSIMsDesc =>
      'يخصم من محفظة KeepSIMs الخاصة بك لإضافة رصيد لخطك عبر بوابات رسائل SMS المحلية الاحتياطية.';

  @override
  String get dynamicUssdPlanActivation => 'تفعيل خطط USSD الديناميكي';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'يوفر أكواد اتصال دقيقة يمكن نسخها ولصقها (مثل *900*1#) لتفعيل باقات البيانات والمكالمات دون اتصال.';

  @override
  String get dualChannelSupport => 'دعم ثنائي القنوات';

  @override
  String get textRefillDesc =>
      'أرسل كلمة \"REFILL\" باستخدام رسائل SMS القياسية أو واتساب بناءً على تغطية الشبكة الخلوية المتاحة.';

  @override
  String get close => 'إغلاق';

  @override
  String get howToTriggerOfflineRefill => 'كيفية تفعيل التعبئة دون اتصال';

  @override
  String get ifZeroMobileDataDesc1 =>
      'إذا لم يكن لديك بيانات جوال، أرسل رسالة SMS قياسية أو رسالة واتساب تحتوي فقط على ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 => ' إلى بوابتنا الآمنة للنظام:';

  @override
  String get targetSimLineLabel => 'خط الشريحة المستهدف';

  @override
  String get configureCashRefillAmount => 'إعداد مبلغ تعبئة الرصيد';

  @override
  String get refillAmount => 'مبلغ التعبئة';

  @override
  String walletBalanceUsd(String amount) {
    return 'رصيد المحفظة: \$$amount دولار';
  }

  @override
  String get lowBalanceWarning => '⚠️ رصيد منخفض';

  @override
  String get localCarrierPlanSuggestions =>
      'اقتراحات باقات شركات الاتصالات المحلية';

  @override
  String get noStandardUssdDialCodes =>
      'لم يتم العثور على أكواد USSD قياسية لشركة الاتصالات هذه. ستظل تتلقى رصيد التعبئة بنجاح على خطك.';

  @override
  String get dynamicDialCodesPreview => 'معاينة أكواد الاتصال الديناميكية';

  @override
  String get botSuggestDialingCodes =>
      'بعد اكتمال التعبئة دون اتصال، سيقترح البوت الاتصال بهذه الأكواد الدقيقة على هاتفك لفتح البيانات والمكالمات فوراً دون اتصال:';

  @override
  String costAmount(String amount) {
    return 'التكلفة: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'تجاوز رقم مرسل رسائل واتساب/SMS';

  @override
  String get verificationNumber => 'رقم التحقق';

  @override
  String get triggerRefillsDifferentNumber =>
      'إذا قمت بتفعيل التعبئة من رقم مختلف عن هاتف ملفك الشخصي الأساسي، أدخله أدناه مع رمز الدولة (مثل 96891234567).';

  @override
  String get enterPhoneNumberDigits => 'أدخل رقم الهاتف (أرقام فقط)';

  @override
  String get offlineRefillSettingsSaved =>
      'تم حفظ إعدادات تعبئة الرصيد دون اتصال بنجاح!';

  @override
  String get saveSettings => 'حفظ الإعدادات';

  @override
  String errorLoadingSettings(String error) {
    return 'خطأ في تحميل الإعدادات: $error';
  }

  @override
  String get retry => 'إعادة المحاولة';

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
  String get editProtectedLine => 'تعديل الخط المحمي';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get activateShieldProtection => 'تفعيل حماية الدرع';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get nicknameOptional => 'الاسم المستعار (اختياري)';

  @override
  String get whatsappAlerts => 'تنبيهات واتساب';

  @override
  String get emailAlertsDesc =>
      'تنبيهات إيقاف التشغيل الحرجة المرسلة عبر Resend';

  @override
  String get refillWalletLow => 'إعادة تعبئة المحفظة عندما ينخفض الرصيد';

  @override
  String get legalPoliciesDesc =>
      'باستخدام KeepSIMs، فإنك توافق على شروطنا. توفر KeepSIMs أدوات للمساعدة في إدارة دورة حياة شريحتك، ولكننا لسنا مسؤولين عن أي خسائر مباشرة أو غير مباشرة أو أضرار أو انقطاع في الخدمة تسببه شركات الاتصالات الخارجية.';

  @override
  String get globalTravelModeDesc =>
      'يسمح لقواعد الجدار الجغرافي التلقائية بتنشيط إجراءات عبور الحدود';

  @override
  String get dataPreferences => 'تفضيلات البيانات';

  @override
  String get doNotDisturb => 'الرجاء عدم الإزعاج';

  @override
  String get linkedCards => 'البطاقات المرتبطة';

  @override
  String get analyticsTracking => 'التحليلات والتتبع';

  @override
  String get dubai => 'دبي';

  @override
  String get flyHome => 'العودة للوطن';

  @override
  String get managePreferencesAndSecurityDesc =>
      'إدارة السمة واللغة وقفل البصمة';

  @override
  String get autoFundingRulesDesc =>
      'حافظ على استمرار تجديد بطاقة SIM من خلال تمكين عمليات التعبئة التلقائية من بطاقتك الائتمانية الافتراضية عندما ينخفض الرصيد بشكل كبير';

  @override
  String get pushNotifications => 'إشعارات الهاتف';

  @override
  String get quietHoursSchedule => 'ساعات الهدوء والجدولة';

  @override
  String get exportMyDataDesc =>
      'تنزيل نسخة JSON من ملفك الشخصي وتفضيلاتك (حق الوصول بموجب GDPR)';

  @override
  String get borderSimulatorTitle => 'محاكي عبور الحدود';

  @override
  String get yourData => 'بياناتك';

  @override
  String get mostImportant => 'الأهم';

  @override
  String get emailAlerts => 'تنبيهات البريد الإلكتروني';

  @override
  String get pushNotificationsDesc => 'إشعارات أصلية فورية على هذا الجهاز';

  @override
  String get alertSettingsTitle => 'إعدادات التنبيهات';

  @override
  String get atHome => 'في الوطن';

  @override
  String get telegramBotDesc => 'إشعارات دردشة تيليجرام التفاعلية المرتبطة';

  @override
  String get alertChannels => 'قنوات التنبيه';

  @override
  String get london => 'لندن';

  @override
  String get shieldProtection => 'حماية الدرع';

  @override
  String get legalPolicies => 'القوانين والسياسات';

  @override
  String get supportVisaMastercard =>
      'يدعم بطاقات الدفع أو الائتمان الآمنة من فيزا وماستركارد';

  @override
  String get exportMyData => 'تصدير بياناتي';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get analyticsTrackingDesc =>
      'ساعدنا في تحسين التطبيق من خلال مشاركة بيانات الاستخدام المجهولة. لن تتأثر وظائف التطبيق الأساسية في حال التعطيل';

  @override
  String get autoFundingRules => 'قواعد التمويل التلقائي';

  @override
  String get singapore => 'سنغافورة';

  @override
  String get weeklySummaryDigest => 'ملخص التقرير الأسبوعي';

  @override
  String get fullyShielded => 'محمي بالكامل';

  @override
  String get dndDesc => 'كتم إشعارات الدفع خلال ساعات النوم المحددة';

  @override
  String get paymentsAutoFundTitle => 'المدفوعات والتمويل التلقائي';

  @override
  String get travelGeolocationTitle => 'السفر والموقع الجغرافي';

  @override
  String get telegramBot => 'بوت تيليجرام';

  @override
  String get weeklyDigestDesc =>
      'تقرير مجمع لحالة جميع بطاقات SIM كل أحد الساعة 9:00 صباحًا';

  @override
  String get borderSimulatorDesc =>
      'محاكاة صعود الطائرة لتفعيل قواعد التجميد الذكي أو استئناف الدولة النشطة.';

  @override
  String get linkFirstCard => 'ربط بطاقتك الدفع الأولى';

  @override
  String get globalTravelMode => 'وضع السفر العالمي';

  @override
  String get readPrivacyPolicy => 'قراءة سياسة الخصوصية والشروط الكاملة';

  @override
  String get whatsappAlertsDesc =>
      'تنبيهات فشل إعادة التعبئة المرسلة مباشرة إلى واتساب';

  @override
  String get abroadTraveling => 'خارج البلاد / مسافر';

  @override
  String get freezeAllLines => 'تجميد كافة الخطوط';

  @override
  String get resumeRenewals => 'استئناف التجديد';

  @override
  String get freezeRecommendationDesc =>
      'لقد اكتشفنا أنك حالياً في بلدك الأم. يمكنك تجميد تجديد خطوطك الدولية لتجنب استهلاك رصيد المحفظة.';

  @override
  String get travelDetected => 'تم اكتشاف السفر! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'أنت مسافر إلى الخارج. يرجى استئناف تجديد شرائح SIM الدولية لضمان تغطية مستمرة لشبكة الهاتف.';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get welcomeHome => 'مرحباً بك في وطنك! 🏡';

  @override
  String get addCard => 'إضافة بطاقة';

  @override
  String get noAlertChannelsConfigured =>
      'لم يتم تكوين قنوات لتسليم التنبيهات.';

  @override
  String channelSettingsUpdated(String channelName) {
    return 'تم تحديث إعدادات $channelName.';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName مقفلة 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return 'تنبيهات $channelName هي ميزات باقتي البداية والمتميزة. قم بترقية باقتك لفتح تنبيهات واتساب، تليجرام والبريد الإلكتروني!';
  }

  @override
  String get upsellProtect5Lines => 'حماية ما يصل إلى 5 خطوط SIM في نفس الوقت';

  @override
  String get upsellUnlockChannels =>
      'فتح إشعارات واتساب، تليجرام والبريد الإلكتروني';

  @override
  String get upsellEnableTravelModes =>
      'تفعيل أوضاع صلاحية السفر والمنزل التلقائية';

  @override
  String get emailAddressLabel => 'عنوان البريد الإلكتروني للإشعارات';

  @override
  String get emailAddressHint => 'مثال: user@domain.com';

  @override
  String get whatsappNumberLabel => 'رقم واتساب (صيغة دولية)';

  @override
  String get whatsappNumberHint => 'مثال: +96891234567';

  @override
  String get whatsappFormatInstruction =>
      'أدخل الصيغة الدولية الكاملة بدءًا بـ + (مثال: +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'الحالة: مرتبط (معرف الدردشة: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'الحالة: غير مرتبط';

  @override
  String get telegramLinkInstructions =>
      'لتلقي تنبيهات تليجرام مجانية وتفاعلية، قم بربط بوت تليجرام الخاص بنا بحسابك.';

  @override
  String get linkTelegramBot => 'ربط بوت تليجرام';

  @override
  String get emailFreePlanGuarded =>
      'حماية باقة إرسال المجانية: تقتصر على محفزات إلغاء التفعيل فقط. لا يوجد بريد ترويجي مزعج.';

  @override
  String get whatsappMetaCloudCapped =>
      'حدود سحابة ميتا المباشرة: رسالة واحدة كحد أقصى لكل جدول تعبئة، تُرسل فقط إذا لم تكن التعبئة التلقائية مفعلة أو فشلت.';

  @override
  String get failedToLoadPaymentInfo => 'فشل تحميل معلومات الدفع';

  @override
  String get defaultCardIndicator => 'الافتراضية';

  @override
  String get cardholder => 'صاحب البطاقة';

  @override
  String get expires => 'تنتهي';

  @override
  String get lowBalanceTrigger => 'محفز الرصيد المنخفض';

  @override
  String get triggerLowTopUp => 'تفعيل التعبئة عند الانخفاض';

  @override
  String get reloadDepositAmount => 'مبلغ إعادة الشحن';

  @override
  String get amountToLoad => 'المبلغ المراد شحنه';

  @override
  String get linkCreditDebitCard => 'ربط بطاقة ائتمان/خصم مباشر';

  @override
  String get cardNumberLabel => 'رقم البطاقة';

  @override
  String get expiryDateLabel => 'تاريخ الانتهاء';

  @override
  String get cvvCodeLabel => 'رمز CVV';

  @override
  String get securelyLinkCard => 'ربط البطاقة بأمان';

  @override
  String get pleaseEnterValidCardNumber =>
      'يرجى إدخال رقم بطاقة صالح مكون من 16 رقمًا.';

  @override
  String get pleaseEnterValidExpiryDate =>
      'يرجى إدخال تاريخ انتهاء صالح (MM/YY).';

  @override
  String get invalidExpiryMonth => 'شهر الانتهاء غير صالح.';

  @override
  String get cvvMustBe3Digits => 'يجب أن يتكون رمز CVV من 3 أرقام.';

  @override
  String get cardLinkedSuccessfully => 'تم ربط بطاقة الفواتير الآمنة بنجاح!';

  @override
  String get defaultPaymentCardUpdated => 'تم تحديث بطاقة الدفع الافتراضية!';

  @override
  String get removePaymentCard => 'إزالة بطاقة الدفع';

  @override
  String get confirmRemoveCardDesc =>
      'هل أنت متأكد من رغبتك في إزالة هذه البطاقة؟ قد تفشل التعبئة التلقائية المرتبطة إذا لم تتبق أي بطاقة دفع افتراضية.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get remove => 'إزالة';

  @override
  String get billingCardSuccessfullyRemoved =>
      'تمت إزالة بطاقة الفواتير بنجاح.';

  @override
  String get pleaseAddDefaultCardFirst =>
      'يرجى إضافة وتحديد بطاقة دفع افتراضية أولاً لتمكين التعبئة التلقائية.';

  @override
  String get autoFundPrefsSavedSuccess =>
      'تم حفظ تفضيلات التعبئة التلقائية بنجاح!';

  @override
  String get preparingDataExport => 'يتم تجهيز تصدير البيانات...';

  @override
  String exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get deleteAccountWarning =>
      'بمجرد حذف حسابك، لن يكون هناك مجال للتراجع. يرجى التأكد التام.';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountIrreversible =>
      'هذا الإجراء لا رجعة فيه. سيتم مسح جميع بياناتك بشكل دائم.';

  @override
  String get typeDeleteToConfirm => 'اكتب \"DELETE\" للتأكيد:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'سجلات تشخيص النظام';

  @override
  String get online => 'متصل';

  @override
  String errorLoadingPrefs(String error) {
    return 'خطأ في تحميل التفضيلات: $error';
  }

  @override
  String get privacyPolicyLoaded => 'تم تحميل تفاصيل سياسة الخصوصية.';

  @override
  String get protectionConsole => 'لوحة التحكم بالحماية';

  @override
  String get deleteProtectionTooltip => 'حذف الحماية';

  @override
  String get refreshTooltip => 'تحديث';

  @override
  String get failedToLoadDetails => 'فشل تحميل التفاصيل';

  @override
  String get retryConnection => 'إعادة محاولة الاتصال';

  @override
  String get healthLabel => 'الصحة';

  @override
  String get mySimCardDefault => 'بطاقة SIM الخاصة بي';

  @override
  String get upLabel => 'ترقية';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'مشاركة بواسطة: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'خطر حرج';

  @override
  String get simDeactivationRisk => 'قد يتم إلغاء تنشيط بطاقة SIM بدون إجراء';

  @override
  String get missingAlertsDesc => 'لم يتم تكوين إشعارات التنبيه — نقص 100 نقطة';

  @override
  String get missingAutoRefillDesc =>
      'لم يتم تكوين التعبئة التلقائية — نقص 50 نقطة';

  @override
  String get missingVerificationDesc => 'رقم الهاتف غير موثق — نقص 25 نقطة';

  @override
  String get missingRecentRefillDesc =>
      'كانت آخر تعبئة قبل أكثر من 80 يومًا — نقص 25 نقطة';

  @override
  String get quickActionsLabel => 'إجراءات سريعة';

  @override
  String get manualRefillLabel => 'تعبئة يدوية';

  @override
  String get chargeFromWalletNow => 'شحن من المحفظة الآن';

  @override
  String get rechargeFromFriend => 'إعادة الشحن من صديق';

  @override
  String get requestViaTelegram => 'طلب عبر تليجرام';

  @override
  String get shareViaWaTg => 'مشاركة عبر واتساب/تليجرام';

  @override
  String get testSimActivity => 'اختبار نشاط بطاقة SIM';

  @override
  String get verifyLineReachable => 'التحقق من إمكانية الوصول للخط';

  @override
  String get checkCompleted1x => 'تم الفحص مرة واحدة';

  @override
  String get starterPlan1xCompleted =>
      'اكتمل فحص الخطة الأساسية لمرة واحدة. قم بالترقية إلى بريميوم للحصول على فحوصات غير محدودة.';

  @override
  String leaveCountry(String countryName) {
    return 'غادر $countryName';
  }

  @override
  String get resumeProtectionLayers => 'استئناف طبقات الحماية';

  @override
  String backToCountryMode(String countryName) {
    return 'العودة إلى وضع $countryName';
  }

  @override
  String get pauseWhileVisitingHome => 'إيقاف مؤقت أثناء زيارة الوطن';

  @override
  String get rechargeFromFriendTitle => 'إعادة الشحن من صديق';

  @override
  String get selectPlatformShare =>
      'اختر منصة لمشاركة رسالة طلب إعادة الشحن مع صديقك.';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'مرحباً! بطاقة KeepSIMs الخاصة بي ($phone) ستنتهي صلاحيتها قريباً. هل يمكنك إعادة شحنها لي من فضلك؟. شكرًا لك!';
  }

  @override
  String get requestViaWhatsApp => 'طلب عبر واتساب';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return 'تعذر فتح رابط $platformName: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'تعذر فتح رابط تليجرام: $error';
  }

  @override
  String get protectionLayersLabel => 'طبقات الحماية';

  @override
  String get autoNotifyDisabled => 'التنبيه التلقائي: معطل';

  @override
  String get noActiveAlertSchedule =>
      'لا يوجد جدول نشط لإشعارات التنبيه لبطاقة SIM الخاصة بك. لن تتلقى تذكيرات تلقائية أو تنبيهات بإلغاء التنشيط.';

  @override
  String get askOwnerConfigureAlerts =>
      'يرجى الطلب من مالك الحساب الرئيسي تكوين التنبيهات.';

  @override
  String get configureAutoNotify => 'تكوين التنبيه التلقائي';

  @override
  String get activeLabel => 'نشط';

  @override
  String get pausedHomeMode => 'متوقف مؤقتاً (وضع الوطن)';

  @override
  String get pausedLabel => 'متوقف مؤقتاً';

  @override
  String get everyHour => 'كل ساعة';

  @override
  String everyNDays(int days) {
    return 'كل $days يوم';
  }

  @override
  String get nextAlertCheck => 'فحص التنبيه القادم';

  @override
  String get premiumKeepAliveRefill => 'شحن الحفاظ على الخط نشطاً (بريميوم)';

  @override
  String autoRefillIncludedText(String date) {
    return 'التعبئة التلقائية متضمنة - حوالي 3.5 دولار (الاتصالات والضريبة متضمنة) كل 85 يومًا، التعبئة التالية في $date';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'شحن الحفاظ على الخط نشطاً معطل حالياً.';

  @override
  String get customAutoRefill => 'تعبئة تلقائية مخصصة';

  @override
  String get addAdditionalScheduledRecharge =>
      'أضف مبلغ شحن مجدول إضافي للاحتفاظ برصيد إضافي على بطاقة SIM الخاصة بك.';

  @override
  String get askOwnerConfigureRefill =>
      'يرجى الطلب من مالك الحساب الرئيسي تكوين التعبئة التلقائية.';

  @override
  String get configureCustomAutoRefill => 'تكوين التعبئة التلقائية المخصصة';

  @override
  String get rechargeAmount => 'مبلغ إعادة الشحن';

  @override
  String get refillInterval => 'فاصل التعبئة';

  @override
  String get nextRefillDue => 'تاريخ التعبئة القادمة';

  @override
  String get failedRefillAttempts => 'محاولات التعبئة الفاشلة';

  @override
  String retriesCount(int count) {
    return '$count / 4 محاولات';
  }

  @override
  String get editRefillAmount => 'تعديل مبلغ التعبئة';

  @override
  String get refillExecutionsHistory => 'سجل عمليات التعبئة';

  @override
  String get renewalExecutionsHistory => 'سجل عمليات التجديد';

  @override
  String get noHistoricalTopup =>
      'لم يتم تسجيل أي عمليات شحن سابقة لهذا الخط بعد.';

  @override
  String get noHistoricalRenewal =>
      'لم يتم تسجيل أي عمليات تجديد سابقة لهذا الخط بعد.';

  @override
  String get viewAllHistory => 'عرض السجل بالكامل';

  @override
  String get securityActivityLogs => 'سجلات الأنشطة الأمنية';

  @override
  String get clearLogs => 'مسح السجلات';

  @override
  String get noActivityLogsRecorded =>
      'لم يتم تسجيل أي سجلات أنشطة لهذا الخط بعد.';

  @override
  String get activityLogDeleted => 'تم حذف إدخال سجل النشاط.';

  @override
  String get activityLogsCleared => 'تم مسح سجلات الأنشطة بنجاح.';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'تم تحديث التجديد التلقائي بنجاح إلى: $status.';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'فشل تحديث الجدول: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'تم تمكين شحن الحفاظ على الخط نشطاً بنجاح.';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'فشل تمكين التعبئة التلقائية: $error';
  }

  @override
  String get removeScheduleTitle => 'إزالة الجدول';

  @override
  String get confirmDeleteAutoRefill =>
      'هل أنت متأكد من رغبتك في حذف جدول التعبئة التلقائية هذا؟ ستنخفض درجة صحة بطاقة SIM الخاصة بك بشكل كبير، مما يعرضها لخطر إلغاء التنشيط.';

  @override
  String get confirmDeleteAutoRenewal =>
      'هل أنت متأكد من رغبتك في حذف جدول التجديد التلقائي هذا؟ ستنخفض درجة صحة بطاقة SIM الخاصة بك بشكل كبير، مما يعرضها لخطر إلغاء التنشيط.';

  @override
  String get autoRefillRemoved => 'تمت إزالة جدول التعبئة التلقائية بنجاح.';

  @override
  String get autoRenewalRemoved => 'تمت إزالة جدول التجديد التلقائي بنجاح.';

  @override
  String failedToDeleteSchedule(String error) {
    return 'فشل حذف الجدول: $error';
  }

  @override
  String get refillRetrySuccess => 'تمت إعادة محاولة التعبئة بنجاح!';

  @override
  String get renewalRetrySuccess => 'تمت إعادة محاولة التجديد بنجاح!';

  @override
  String retryFailed(String error) {
    return 'فشلت إعادة المحاولة: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'خطأ أثناء إعادة المحاولة: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'فشل حذف سجل النشاط: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'فشل مسح سجلات الأنشطة: $error';
  }

  @override
  String get removeProtectionTitle => 'إزالة الحماية';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'هل أنت متأكد من رغبتك في إيقاف حماية $name؟ سيتم إلغاء عمليات الشحن المجدولة لخط SIM هذا بشكل دائم.';
  }

  @override
  String get simLineProtectionRemoved => 'تمت إزالة حماية خط SIM بنجاح.';

  @override
  String failedToDeleteSimLine(String error) {
    return 'فشلت الإزالة: $error';
  }

  @override
  String get editSimNameTitle => 'تعديل اسم الـ SIM';

  @override
  String get enterNicknameInstruction =>
      'أدخل اسماً مستعاراً لخط بطاقة SIM هذا:';

  @override
  String get nicknameExampleHint => 'على سبيل المثال: SIM أورانج مصر الخاصة بي';

  @override
  String get simNameUpdatedSuccess => 'تم تحديث اسم الـ SIM بنجاح.';

  @override
  String failedToUpdateSimName(String error) {
    return 'فشل تحديث اسم الـ SIM: $error';
  }

  @override
  String get saveButton => 'حفظ';

  @override
  String get deleteButton => 'حذف';

  @override
  String get autoNotifySchedule => 'جدول التنبيه التلقائي';

  @override
  String get renewalCheckInterval => 'فاصل فحص التجديد';

  @override
  String get editNotificationConfig => 'تعديل تكوين التنبيه';

  @override
  String get openTicket => 'فتح تذكرة';

  @override
  String get offlineRefillLabel => 'شحن بدون إنترنت';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get techSupportCategory => 'الدعم الفني';

  @override
  String get billingWalletCategory => 'الفواتير والمحفظة';

  @override
  String get simLinesCategory => 'إدارة خطوط الـ SIM';

  @override
  String get feedbackOtherCategory => 'الملاحظات وأخرى';

  @override
  String get subjectLabel => 'الموضوع';

  @override
  String get subjectHint => 'ملخص موجز للمشكلة';

  @override
  String get descriptionLabel => 'الوصف';

  @override
  String get descriptionHint => 'صف مشكلتك بالتفصيل...';

  @override
  String get attachmentLabel => 'المرفقات (اختياري)';

  @override
  String get uploadScreenshot => 'تحميل لقطة الشاشة';

  @override
  String get submitTicketButton => 'إرسال التذكرة';

  @override
  String get pleaseFillFields => 'يرجى ملء الموضوع والوصف معاً';

  @override
  String get ticketSubmittedSuccess => 'تم إرسال التذكرة بنجاح!';

  @override
  String get lastRefillLabel => 'آخر شحن';

  @override
  String get noRefillYet => 'لا يوجد شحن بعد';

  @override
  String get nextAlertLabel => 'التنبيه التالي';

  @override
  String get protectionLabel => 'الحماية';

  @override
  String get actionRequiredLabel => 'مطلوب إجراء';

  @override
  String get protectionOffLabel => 'الحماية متوقفة';

  @override
  String get notSet => 'غير محدد';

  @override
  String get homeMode => 'وضع الوطن';

  @override
  String get incidentChannelsTitle => 'قنوات التنبيه';

  @override
  String get topUpSuccessTitle => 'نجاح عملية الشحن';

  @override
  String get topUpSuccessDesc =>
      'إشعار عند إتمام تمديد صلاحية الشريحة تلقائياً بنجاح.';

  @override
  String get topUpFailedTitle => 'فشل عملية الشحن (حرج)';

  @override
  String get topUpFailedDesc =>
      'تنبيهات حرجة عند فشل الشحن التلقائي بسبب مشاكل الشبكة أو المحفظة.';

  @override
  String get walletLowTitle => 'رصيد المحفظة منخفض';

  @override
  String get walletLowDesc => 'تحذير عندما ينخفض الرصيد الأساسي عن حد الأمان.';

  @override
  String get walletDepletedTitle => 'نفاد رصيد المحفظة';

  @override
  String get walletDepletedDesc =>
      'تنبيهات إيقاف مؤقت عند نفاد رصيد المحفظة بالكامل وتوقف التجديد.';

  @override
  String get lineCriticalTitle => 'تحذير انتهاء صلاحية الصلاحية';

  @override
  String get lineCriticalDesc =>
      'تحذير عند اقتراب انتهاء صلاحية الشريحة خلال 48 ساعة.';

  @override
  String get lineEnteringGraceTitle => 'دخول فترة السماح';

  @override
  String get lineEnteringGraceDesc =>
      'إشعار عند بدء فترة السماح قبل إلغاء تفعيل الشريحة من قبل الشبكة.';

  @override
  String get geoFenceTriggeredTitle => 'تنبيهات الموقع والتجوال';

  @override
  String get geoFenceTriggeredDesc =>
      'تنبيهات عندما تغير الشبكة مجموعات التجوال أو عقد الاتصال.';

  @override
  String get welcomeHomeReadyTitle => 'مزامنة العودة للوطن';

  @override
  String get welcomeHomeReadyDesc =>
      'تنبيهات عندما تقوم عقدة شبكة البلد الأم بتشغيل عمليات المزامنة الآلية.';

  @override
  String get referralRewardTitle => 'الإحالات والمكافآت';

  @override
  String get referralRewardDesc =>
      'إشعار عند قيام إحالات الأصدقاء بإيداع أرصدة ترويجية في محفظتي.';

  @override
  String get systemUpdatesTitle => 'تحديثات النظام العامة';

  @override
  String get systemUpdatesDesc =>
      'تحديثات المحرك الحيوية والصيانة وإعلانات المنصة.';

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
}
