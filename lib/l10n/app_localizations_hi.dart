// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get dashboardKeepSimActive => 'सिम सक्रिय रखें';

  @override
  String get dashboardProtectSimLines => 'अपनी सिम लाइनों को सुरक्षित रखें';

  @override
  String get dashboardManageReminders => 'रिमाइंडर और रिचार्ज प्रबंधित करें';

  @override
  String get dashboardManageSims => 'सिम प्रबंधित करें';

  @override
  String dashboardSimLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सिम लाइनें',
      one: '1 सिम लाइन',
    );
    return '$_temp0';
  }

  @override
  String get dashboardNewFeature => 'नया';

  @override
  String get dashboardWorldwideEsims => 'दुनियाभर की eSIM';

  @override
  String get dashboardExploreSmartCall => 'स्मार्ट कॉल देखें';

  @override
  String get dashboardExploreGlobalOffers => 'वैश्विक ऑफ़र देखें';

  @override
  String get dashboardAddSims => 'सिम जोड़ें';

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'प्राथमिकताएँ और सुरक्षा';

  @override
  String get appAppearance => 'ऐप दिखावट';

  @override
  String get systemTheme => 'सिस्टम';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get lightMode => 'लाइट मोड';

  @override
  String get localizationAndRegional => 'स्थानीयकरण और क्षेत्रीय सेटिंग्स';

  @override
  String get appLanguage => 'ऐप भाषा';

  @override
  String currentlyUsing(String langName) {
    return 'वर्तमान में क्षेत्रीय $langName का उपयोग किया जा रहा है';
  }

  @override
  String get selectAppLanguage => 'ऐप भाषा चुनें';

  @override
  String get securityAndAccessLock => 'सुरक्षा और एक्सेस लॉक';

  @override
  String get biometricSecurity => 'बायोमेट्रिक सुरक्षा';

  @override
  String get biometricDesc => 'Face ID या Touch ID का उपयोग करके साइन इन करें';

  @override
  String get biometricReasonPayment =>
      'भुगतान की पुष्टि के लिए प्रमाणीकृत करें';

  @override
  String get biometricReasonUnlock =>
      'KeepSIMs अनलॉक करने के लिए प्रमाणीकृत करें';

  @override
  String get biometricLockout =>
      'अत्यधिक असफल प्रयासों के कारण बायोमेट्रिक प्रमाणीकरण लॉक हो गया है। कृपया अपने डिवाइस पासकोड का उपयोग करें।';

  @override
  String get biometricNotEnrolled =>
      'इस डिवाइस पर बायोमेट्रिक प्रमाणीकरण सेट नहीं है।';

  @override
  String get biometricAppLockTitle => 'KeepSIMs लॉक है';

  @override
  String get biometricUnlockButton => 'बायोमेट्रिक्स से अनलॉक करें';

  @override
  String get biometricCancel => 'रद्द करें';

  @override
  String get transactionPin => 'ट्रांज़ैक्शन PIN';

  @override
  String get transactionPinDesc => 'रिन्यूअल और निकासी को सुरक्षित करें';

  @override
  String get setup => 'सेटअप';

  @override
  String get pinSuccess => 'ट्रांज़ैक्शन PIN सफलतापूर्वक अपडेट किया गया!';

  @override
  String get pinMismatch => 'PIN मेल नहीं खाते। फिर से कोशिश करें!';

  @override
  String get pinActiveAndSecure => 'PIN सेटअप सक्रिय और सुरक्षित है';

  @override
  String get automatedSummaryAndAlerts => 'स्वचालित सारांश और अलर्ट';

  @override
  String get weeklyDigest => 'साप्ताहिक डाइजेस्ट';

  @override
  String get welcomeBack => 'वापसी पर स्वागत है';

  @override
  String get nextNotify => 'अगली सूचना';

  @override
  String get days => 'दिन';

  @override
  String get showingNearestLine => 'निकटतम लाइन दिखाई जा रही है';

  @override
  String get addSim => 'SIM जोड़ें';

  @override
  String get linesToProtect => 'सुरक्षित करने योग्य लाइनें';

  @override
  String get active => 'सक्रिय';

  @override
  String get upgrade => 'अपग्रेड करें';

  @override
  String get standard => 'स्टैंडर्ड';

  @override
  String get autoNotify => 'ऑटो-नोटिफाई';

  @override
  String get configure => 'कॉन्फ़िगर करें';

  @override
  String get autoRefill => 'ऑटो-रिफिल';

  @override
  String get quickActions => 'त्वरित कार्य';

  @override
  String get navHome => 'होम';

  @override
  String get navSims => 'SIM';

  @override
  String get navMore => 'अधिक';

  @override
  String get protectedSims => 'सुरक्षित SIM';

  @override
  String get mySimCards => 'मेरे SIM कार्ड';

  @override
  String get familySharedSims => 'परिवार द्वारा शेयर किए गए SIM';

  @override
  String get protectAnotherSimLine => 'एक और SIM लाइन सुरक्षित करें';

  @override
  String get keepInfiniteNumbersAlive =>
      'असीमित अंतरराष्ट्रीय नंबरों को सक्रिय रखें';

  @override
  String get bulkActionsConsole => 'बल्क एक्शन कंसोल';

  @override
  String get resume => 'फिर से शुरू करें';

  @override
  String get pause => 'रोकें';

  @override
  String get simulate => 'सिम्युलेट करें';

  @override
  String get noProtectedLines => 'कोई सुरक्षित लाइन नहीं';

  @override
  String get noInternationalSimsAdded =>
      'आपने अभी तक कोई अंतरराष्ट्रीय SIM कार्ड नहीं जोड़ा है। इसे हमेशा सक्रिय रखने के लिए अभी अपना पहला कार्ड सुरक्षित करें।';

  @override
  String get protectNewLine => 'नई लाइन सुरक्षित करें';

  @override
  String get noSharedSimsYet => 'अभी तक कोई शेयर किया गया SIM नहीं';

  @override
  String get inviteFamilyMembers =>
      'अपने परिवार में शामिल होने के लिए सदस्यों को आमंत्रित करें। स्वीकार करने पर, उनकी सुरक्षित SIM लाइनें यहाँ सहयोगी मॉनिटरिंग के लिए दिखाई देंगी।';

  @override
  String get manageHousehold => 'परिवार प्रबंधित करें';

  @override
  String get manageProfileDesc =>
      'अपनी प्रोफ़ाइल, SIM लाइनें, अलर्ट और शेयर की गई प्राथमिकताएँ प्रबंधित करें';

  @override
  String get keepSIMsUser => 'KeepSIMs उपयोगकर्ता';

  @override
  String get pro => 'प्रो';

  @override
  String get homeCountry => 'होम देश: ';

  @override
  String get console => 'कंसोल';

  @override
  String get offlineRefill => 'ऑफ़लाइन रिफिल (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'SMS या WhatsApp के ज़रिए ऑफ़लाइन SIM बैलेंस रिफिल करें';

  @override
  String get wallet => 'वॉलेट';

  @override
  String get manageBalancesDesc =>
      'अपने बैलेंस प्रबंधित करें और ट्रांज़ैक्शन इतिहास देखें';

  @override
  String get alertPreferences => 'अलर्ट प्राथमिकताएँ';

  @override
  String get togglePushEmailDesc =>
      'रिन्यूअल/बैलेंस के लिए पुश और ईमेल सेटिंग्स टॉगल करें';

  @override
  String get referAndEarn => 'रेफर करें और कमाएँ';

  @override
  String get shareKeepSIMsDesc =>
      'KeepSIMs शेयर करें, डायनामिक बैलेंस रिवॉर्ड अनलॉक करें';

  @override
  String get paymentMethods => 'पेमेंट के तरीके';

  @override
  String get addBankCardsDesc =>
      'बैंक कार्ड जोड़ें या ऑटो-विदड्रॉल खाते लिंक करें';

  @override
  String get travelAndGeolocation => 'यात्रा और जियोलोकेशन';

  @override
  String get manageHomeCountryDesc =>
      'होम देश फ्रीज़ नियम और ट्रैवल मोड प्रबंधित करें';

  @override
  String get dataAndPrivacy => 'डेटा और प्राइवेसी';

  @override
  String get manageTrackingConsentDesc =>
      'अपनी ट्रैकिंग सहमति प्रबंधित करें, डेटा एक्सपोर्ट करें, या खाता डिलीट करें';

  @override
  String get powerUser => 'पावर यूज़र';

  @override
  String get accessSystemSimulatorsDesc =>
      'सिस्टम सिम्युलेटर और डीबगिंग टूल्स एक्सेस करें';

  @override
  String get testChecklist => 'टेस्ट चेकलिस्ट';

  @override
  String get manualUiTestingDesc =>
      'क्वालिटी एश्योरेंस के लिए मैनुअल UI टेस्टिंग चेकलिस्ट';

  @override
  String get soon => 'जल्द ही';

  @override
  String featureComingSoon(String feature) {
    return '$feature फ़ीचर जल्द ही आ रहा है!';
  }

  @override
  String get logOut => 'लॉग आउट';

  @override
  String get confirmLogOut =>
      'क्या आप वाकई KeepSIMs से लॉग आउट करना चाहते हैं?';

  @override
  String get walletLedger => 'वॉलेट लेजर';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs प्रीपेड';

  @override
  String get offlineMode => 'ऑफ़लाइन मोड';

  @override
  String get activeBalance => 'सक्रिय बैलेंस';

  @override
  String get criticalBalanceLevel => 'गंभीर बैलेंस स्तर';

  @override
  String get balanceBelow10 =>
      'आपका बैलेंस \$10.00 से कम है। शेड्यूल किए गए SIM टॉपअप जल्द ही फेल हो सकते हैं।';

  @override
  String get depositFunds => 'फंड जमा करें';

  @override
  String get walletDepositsRequireInternet =>
      'वॉलेट में जमा करने के लिए सक्रिय इंटरनेट कनेक्शन आवश्यक है।';

  @override
  String get exportLedger => 'लेजर एक्सपोर्ट करें';

  @override
  String get ledgerHistoryExported =>
      'लेजर इतिहास CSV के रूप में एक्सपोर्ट किया गया।';

  @override
  String get spendAnalysis => 'खर्च विश्लेषण';

  @override
  String get transactionHistory => 'ट्रांज़ैक्शन इतिहास';

  @override
  String itemsCount(int count) {
    return '$count आइटम';
  }

  @override
  String get noTransactionsRecorded =>
      'अभी तक कोई ट्रांज़ैक्शन रिकॉर्ड नहीं हुआ।';

  @override
  String get prepaidMonthlyOutflow => 'प्रीपेड मासिक खर्च';

  @override
  String avgMonthlySpend(String amount) {
    return 'औसत: \$$amount/माह (12M)';
  }

  @override
  String depositViaCard(String last4) {
    return '$last4 पर समाप्त होने वाले कार्ड से जमा करें';
  }

  @override
  String get lineRenewal => 'लाइन रिन्यूअल';

  @override
  String get justNow => 'अभी';

  @override
  String get loadCreditFunds => 'क्रेडिट फंड लोड करें';

  @override
  String get depositAmountUsd => 'जमा राशि (USD)';

  @override
  String get pleaseEnterAmount => 'कृपया एक राशि दर्ज करें';

  @override
  String get enterPositiveNumber => 'एक सकारात्मक संख्या दर्ज करें';

  @override
  String get cardDetails => 'कार्ड विवरण';

  @override
  String get savedCards => 'सेव किए गए कार्ड';

  @override
  String get visaCardNumber => 'Visa कार्ड नंबर';

  @override
  String get pleaseEnterCardNumber => 'कृपया कार्ड नंबर दर्ज करें';

  @override
  String get mustBe16Digits => '16 अंकों का होना चाहिए';

  @override
  String get expiryMmYy => 'समाप्ति (MM/YY)';

  @override
  String get expiryRequired => 'समाप्ति तिथि आवश्यक है';

  @override
  String get invalid => 'अमान्य';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV आवश्यक है';

  @override
  String get verifyingCardSecurity => 'कार्ड सुरक्षा सत्यापित की जा रही है...';

  @override
  String get authorizeDepositFunds => 'फंड जमा को अधिकृत करें';

  @override
  String successfullyDeposited(String amount) {
    return '\$$amount USD सफलतापूर्वक जमा किया गया!';
  }

  @override
  String get failedToDepositFunds =>
      'फंड जमा करने में विफल। कृपया कार्ड कनेक्शन जांचें।';

  @override
  String get noSavedPaymentMethods =>
      'कोई सेव किया गया पेमेंट तरीका नहीं मिला।';

  @override
  String get addPaymentMethod => 'पेमेंट तरीका जोड़ें';

  @override
  String get savedPaymentMethods => 'सेव किए गए पेमेंट तरीके';

  @override
  String get addAnotherPaymentMethod => 'एक और पेमेंट तरीका जोड़ें';

  @override
  String expiresMmYy(String month, String year) {
    return '$month/$year में समाप्त होता है';
  }

  @override
  String get offlineRefillTitle => 'ऑफ़लाइन रिफिल (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'टारगेट SIM लाइन चुनें';

  @override
  String get noRegisteredSimLines => 'कोई रजिस्टर्ड SIM लाइन नहीं मिली।';

  @override
  String get targetSimLine => 'टारगेट SIM लाइन';

  @override
  String get simLine => 'SIM लाइन';

  @override
  String get carrier => 'कैरियर';

  @override
  String get change => 'बदलें';

  @override
  String get offlineRefillProtection => 'ऑफ़लाइन रिफिल सुरक्षा';

  @override
  String get premiumExclusive => 'प्रीमियम विशेष';

  @override
  String get neverGetStrandedDesc =>
      'मोबाइल डेटा के बिना फिर कभी न फंसें। KeepSIMs Premium आपको ज़ीरो इंटरनेट कनेक्शन होने पर भी स्टैंडर्ड लोकल SMS या WhatsApp मैसेज के ज़रिए अपने SIM कार्ड का बैलेंस ऑफ़लाइन रिफिल करने देता है।';

  @override
  String get offlineCapability100 => '100% ऑफ़लाइन क्षमता';

  @override
  String get deductsFromKeepSIMsDesc =>
      'लोकल SMS गेटवे फेलओवर के ज़रिए आपकी लाइन में क्रेडिट करने के लिए आपके KeepSIMs वॉलेट से राशि काटी जाती है।';

  @override
  String get dynamicUssdPlanActivation => 'डायनामिक USSD प्लान एक्टिवेशन';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'ऑफ़लाइन डेटा+कॉल पैकेज एक्टिवेट करने के लिए सटीक कॉपी-पेस्ट डायल कोड (जैसे, *900*1#) प्रदान करता है।';

  @override
  String get dualChannelSupport => 'ड्यूअल-चैनल सपोर्ट';

  @override
  String get textRefillDesc =>
      'उपलब्ध सेलुलर कवरेज के अनुसार स्टैंडर्ड SMS या WhatsApp का उपयोग करके \"REFILL\" टेक्स्ट करें।';

  @override
  String get close => 'बंद करें';

  @override
  String get howToTriggerOfflineRefill => 'ऑफ़लाइन रिफिल कैसे ट्रिगर करें';

  @override
  String get ifZeroMobileDataDesc1 =>
      'यदि आपके पास ज़ीरो मोबाइल डेटा है, तो हमारे सुरक्षित सिस्टम गेटवे को केवल ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' शब्द वाला एक स्टैंडर्ड SMS या WhatsApp मैसेज भेजें:';

  @override
  String get targetSimLineLabel => 'टारगेट SIM लाइन';

  @override
  String get configureCashRefillAmount => 'कैश रिफिल राशि कॉन्फ़िगर करें';

  @override
  String get refillAmount => 'रिफिल राशि';

  @override
  String walletBalanceUsd(String amount) {
    return 'वॉलेट बैलेंस: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ कम बैलेंस';

  @override
  String get localCarrierPlanSuggestions => 'लोकल कैरियर प्लान सुझाव';

  @override
  String get noStandardUssdDialCodes =>
      'इस कैरियर के लिए कोई स्टैंडर्ड USSD डायल कोड नहीं मिला। फिर भी आपकी लाइन पर कैश रिफिल सफलतापूर्वक प्राप्त होगा।';

  @override
  String get dynamicDialCodesPreview => 'डायनामिक डायल कोड पूर्वावलोकन';

  @override
  String get botSuggestDialingCodes =>
      'ऑफ़लाइन रिफिल पूरा होने के बाद, बॉट तुरंत डेटा+कॉल ऑफ़लाइन अनलॉक करने के लिए आपके फ़ोन पर ये सटीक कोड डायल करने का सुझाव देगा:';

  @override
  String costAmount(String amount) {
    return 'लागत: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'WHATSAPP/SMS सेंडर ओवरराइड';

  @override
  String get verificationNumber => 'सत्यापन नंबर';

  @override
  String get triggerRefillsDifferentNumber =>
      'यदि आप अपने मुख्य प्रोफ़ाइल फ़ोन के अलावा किसी अन्य नंबर से रिफिल ट्रिगर करते हैं, तो उसे देश कोड के साथ नीचे दर्ज करें (जैसे 96891234567)।';

  @override
  String get enterPhoneNumberDigits => 'फ़ोन नंबर दर्ज करें (केवल अंक)';

  @override
  String get offlineRefillSettingsSaved =>
      'ऑफ़लाइन रिफिल सेटिंग्स सफलतापूर्वक सेव हुई!';

  @override
  String get saveSettings => 'सेटिंग्स सेव करें';

  @override
  String errorLoadingSettings(String error) {
    return 'सेटिंग्स लोड करने में त्रुटि: $error';
  }

  @override
  String get retry => 'फिर से कोशिश करें';

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
  String get offlineRefillChannelsHeader => 'ऑफ़लाइन रिफ़िल के तरीके';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'अपने वॉलेट से $amount टॉप अप करें';
  }

  @override
  String get offlineRefillWalletFunded => 'आपके वॉलेट से';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee शुल्क';
  }

  @override
  String get offlineRefillMissedCallTitle => 'मिस्ड कॉल दें';

  @override
  String get offlineRefillMissedCallSubtitle => 'बैलेंस या डेटा की ज़रूरत नहीं';

  @override
  String get offlineRefillCallAction => 'रिफ़िल के लिए कॉल करें';

  @override
  String get offlineRefillRetry => 'फिर से आज़माएँ';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return '$secondsसे प्रतीक्षा करें';
  }

  @override
  String get offlineRefillStatusSent => 'भेजा गया — पुष्टि की प्रतीक्षा';

  @override
  String get offlineRefillStatusProcessing => 'आपकी लाइन टॉप अप हो रही है…';

  @override
  String get offlineRefillStatusConfirmed => 'टॉप-अप की पुष्टि हो गई';

  @override
  String get offlineRefillStatusFailed => 'पूरा नहीं हुआ — दूसरा तरीका आज़माएँ';

  @override
  String get offlineRefillStatusTimedOut =>
      'अभी तक कोई जवाब नहीं — दूसरा तरीका आज़माएँ';

  @override
  String get offlineRefillUssdTitle => 'अपने टॉप-अप से ज़्यादा पाएँ';

  @override
  String get offlineRefillUssdSubtitle =>
      'बैलेंस आने के बाद, सबसे अच्छे मूल्य के लिए अपने ऑपरेटर का कोड डायल करें';

  @override
  String get offlineRefillUssdDial => 'डायल करें';

  @override
  String get editProtectedLine => 'सुरक्षित लाइन संपादित करें';

  @override
  String get saveChanges => 'बदलाव सेव करें';

  @override
  String get activateShieldProtection => 'शील्ड सुरक्षा सक्रिय करें';

  @override
  String get phoneNumber => 'फ़ोन नंबर';

  @override
  String get nicknameOptional => 'उपनाम (वैकल्पिक)';

  @override
  String get whatsappAlerts => 'WhatsApp अलर्ट';

  @override
  String get emailAlertsDesc =>
      'Resend के ज़रिए भेजे गए गंभीर डीएक्टिवेशन अलर्ट';

  @override
  String get refillWalletLow => 'जब फंड कम हो जाएँ तो वॉलेट रिफिल करें';

  @override
  String get legalPoliciesDesc =>
      'KeepSIMs का उपयोग करके, आप हमारी शर्तों से सहमत होते हैं। KeepSIMs आपके SIM जीवनचक्र को प्रबंधित करने में मदद करने के लिए टूल प्रदान करता है, लेकिन हम थर्ड-पार्टी टेलीकॉम प्रदाताओं के कारण होने वाले प्रत्यक्ष या अप्रत्यक्ष नुकसान, क्षति, या सेवा में रुकावट के लिए उत्तरदायी नहीं हैं।';

  @override
  String get globalTravelModeDesc =>
      'बॉर्डर-क्रॉसिंग रूटीन सक्रिय करने के लिए स्वचालित जियोफेंसिंग नियमों की अनुमति देता है';

  @override
  String get dataPreferences => 'डेटा प्राथमिकताएँ';

  @override
  String get doNotDisturb => 'डिस्टर्ब न करें';

  @override
  String get linkedCards => 'लिंक किए गए कार्ड';

  @override
  String get analyticsTracking => 'एनालिटिक्स और ट्रैकिंग';

  @override
  String get dubai => 'दुबई';

  @override
  String get flyHome => 'घर वापस जाएँ';

  @override
  String get managePreferencesAndSecurityDesc =>
      'थीम, भाषा और बायोमेट्रिक लॉकआउट प्रबंधित करें';

  @override
  String get autoFundingRulesDesc =>
      'जब बैलेंस बहुत कम हो जाए तो अपने डिफ़ॉल्ट क्रेडिट कार्ड से ऑटोमैटिक टॉप-अप सक्षम करके SIM रिन्यूअल को लगातार चालू रखें';

  @override
  String get pushNotifications => 'पुश नोटिफिकेशन';

  @override
  String get quietHoursSchedule => 'क्वाइट ऑवर्स और शेड्यूल';

  @override
  String get exportMyDataDesc =>
      'अपनी प्रोफ़ाइल और प्राथमिकताओं की एक JSON कॉपी डाउनलोड करें (GDPR एक्सेस का अधिकार)';

  @override
  String get borderSimulatorTitle => 'बॉर्डर क्रॉसिंग सिम्युलेटर';

  @override
  String get yourData => 'आपका डेटा';

  @override
  String get mostImportant => 'सबसे ज़रूरी';

  @override
  String get emailAlerts => 'ईमेल अलर्ट';

  @override
  String get pushNotificationsDesc => 'इस डिवाइस पर तीव्र नेटिव नोटिफिकेशन';

  @override
  String get alertSettingsTitle => 'अलर्ट सेटिंग्स';

  @override
  String get atHome => 'घर पर';

  @override
  String get telegramBotDesc => 'बाउंड इंटरैक्टिव Telegram चैट नोटिफिकेशन';

  @override
  String get alertChannels => 'अलर्ट चैनल';

  @override
  String get london => 'लंदन';

  @override
  String get shieldProtection => 'शील्ड सुरक्षा';

  @override
  String get legalPolicies => 'कानूनी और नीतियाँ';

  @override
  String get supportVisaMastercard =>
      'सुरक्षित Visa और MasterCard डेबिट या क्रेडिट को सपोर्ट करता है';

  @override
  String get exportMyData => 'मेरा डेटा एक्सपोर्ट करें';

  @override
  String get dangerZone => 'डेंजर ज़ोन';

  @override
  String get analyticsTrackingDesc =>
      'अनाम उपयोग डेटा शेयर करके ऐप को बेहतर बनाने में हमारी मदद करें। बंद करने पर ऐप की ज़रूरी कार्यक्षमता प्रभावित नहीं होगी';

  @override
  String get autoFundingRules => 'ऑटो-फंडिंग नियम';

  @override
  String get singapore => 'सिंगापुर';

  @override
  String get weeklySummaryDigest => 'साप्ताहिक सारांश डाइजेस्ट';

  @override
  String get fullyShielded => 'पूरी तरह सुरक्षित';

  @override
  String get dndDesc =>
      'सामान्य अलर्ट शांत समय खत्म होने तक रुकते हैं। महत्वपूर्ण लाइन अलर्ट पहले आ सकते हैं; फ़ोन का डू नॉट डिस्टर्ब लागू रहता है।';

  @override
  String get paymentsAutoFundTitle => 'पेमेंट्स और ऑटो-फंड';

  @override
  String get travelGeolocationTitle => 'यात्रा और जियोलोकेशन';

  @override
  String get telegramBot => 'Telegram बॉट';

  @override
  String get weeklyDigestDesc =>
      'हर रविवार स्थानीय समय सुबह 9:00 बजे साप्ताहिक SIM स्थिति सारांश';

  @override
  String get borderSimulatorDesc =>
      'स्मार्ट फ्रीज़ या एक्टिव कंट्री रिज़्यूमेशन नियमों को ट्रिगर करने के लिए बोर्डिंग सिम्युलेट करें।';

  @override
  String get linkFirstCard => 'अपना पहला पेमेंट कार्ड लिंक करें';

  @override
  String get globalTravelMode => 'ग्लोबल ट्रैवल मोड';

  @override
  String get readPrivacyPolicy => 'पूरी प्राइवेसी पॉलिसी और नियम पढ़ें';

  @override
  String get whatsappAlertsDesc =>
      'रिफिल फेलियर अलर्ट सीधे WhatsApp पर भेजे जाते हैं';

  @override
  String get abroadTraveling => 'विदेश / यात्रा पर';

  @override
  String get freezeAllLines => 'सभी लाइनें फ्रीज़ करें';

  @override
  String get resumeRenewals => 'रिन्यूअल फिर से शुरू करें';

  @override
  String get freezeRecommendationDesc =>
      'हमें पता चला है कि आप अभी अपने होम देश में हैं। अनचाहे वॉलेट बैलेंस की कमी को रोकने के लिए आप अपनी अंतरराष्ट्रीय लाइनों पर रिन्यूअल फ्रीज़ कर सकते हैं।';

  @override
  String get travelDetected => 'यात्रा का पता चला! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'आप विदेश यात्रा पर हैं। निर्बाध मोबाइल नेटवर्क कवरेज सुनिश्चित करने के लिए कृपया अपनी रुकी हुई अंतरराष्ट्रीय SIM रिन्यूअल फिर से शुरू करें।';

  @override
  String get dismiss => 'खारिज करें';

  @override
  String get welcomeHome => 'घर में आपका स्वागत है! 🏡';

  @override
  String get addCard => 'कार्ड जोड़ें';

  @override
  String get noAlertChannelsConfigured =>
      'कोई अलर्ट डिलीवरी चैनल कॉन्फ़िगर नहीं किया गया।';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName सेटिंग्स अपडेट की गईं।';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName लॉक है 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName अलर्ट स्टार्टर और प्रीमियम प्लान की सुविधाएँ हैं। WhatsApp, Telegram और ईमेल अलर्ट अनलॉक करने के लिए अपना प्लान अपग्रेड करें!';
  }

  @override
  String get upsellProtect5Lines => 'एक साथ 5 SIM लाइनों तक सुरक्षित करें';

  @override
  String get upsellUnlockChannels =>
      'WhatsApp, Telegram और ईमेल नोटिफिकेशन अनलॉक करें';

  @override
  String get upsellEnableTravelModes =>
      'ट्रैवल और होम ऑटोमेटेड वैलिडिटी मोड सक्षम करें';

  @override
  String get emailAddressLabel => 'नोटिफिकेशन ईमेल पता';

  @override
  String get emailAddressHint => 'जैसे user@domain.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp नंबर (अंतरराष्ट्रीय फ़ॉर्मेट)';

  @override
  String get whatsappNumberHint => 'जैसे +96891234567';

  @override
  String get whatsappFormatInstruction =>
      '+ से शुरू होने वाला पूरा अंतरराष्ट्रीय फ़ॉर्मेट दर्ज करें (जैसे +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'स्टेटस: बाउंड (चैट ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'स्टेटस: अनबाउंड';

  @override
  String get telegramLinkInstructions =>
      'मुफ़्त, इंटरैक्टिव Telegram अलर्ट पाने के लिए, हमारे Telegram बॉट को अपने खाते से लिंक करें।';

  @override
  String get linkTelegramBot => 'Telegram बॉट लिंक करें';

  @override
  String get emailFreePlanGuarded =>
      'Resend फ्री प्लान सुरक्षित: केवल डीएक्टिवेशन ट्रिगर तक सीमित। कोई प्रोमोशनल स्पैम नहीं।';

  @override
  String get whatsappMetaCloudCapped =>
      'डायरेक्ट Meta Cloud सीमित: प्रति टॉप-अप शेड्यूल अधिकतम 1 मैसेज, केवल तब भेजा जाता है जब ऑटो-रिफिल सक्रिय न हो या फेल हो जाए।';

  @override
  String get failedToLoadPaymentInfo => 'पेमेंट जानकारी लोड करने में विफल';

  @override
  String get defaultCardIndicator => 'डिफ़ॉल्ट';

  @override
  String get cardholder => 'कार्डधारक';

  @override
  String get expires => 'समाप्ति';

  @override
  String get lowBalanceTrigger => 'कम बैलेंस ट्रिगर';

  @override
  String get triggerLowTopUp => 'कम बैलेंस पर टॉप-अप ट्रिगर करें';

  @override
  String get reloadDepositAmount => 'रीलोड जमा राशि';

  @override
  String get amountToLoad => 'लोड करने की राशि';

  @override
  String get linkCreditDebitCard => 'क्रेडिट/डेबिट कार्ड लिंक करें';

  @override
  String get cardNumberLabel => 'कार्ड नंबर';

  @override
  String get expiryDateLabel => 'समाप्ति तिथि';

  @override
  String get cvvCodeLabel => 'CVV कोड';

  @override
  String get securelyLinkCard => 'सुरक्षित रूप से कार्ड लिंक करें';

  @override
  String get pleaseEnterValidCardNumber =>
      'कृपया मान्य 16-अंकीय कार्ड नंबर दर्ज करें।';

  @override
  String get pleaseEnterValidExpiryDate =>
      'कृपया मान्य समाप्ति तिथि दर्ज करें (MM/YY)।';

  @override
  String get invalidExpiryMonth => 'अमान्य समाप्ति माह।';

  @override
  String get cvvMustBe3Digits => 'CVV 3 अंकों का होना चाहिए।';

  @override
  String get cardLinkedSuccessfully =>
      'सुरक्षित बिलिंग कार्ड सफलतापूर्वक लिंक हुआ!';

  @override
  String get defaultPaymentCardUpdated => 'डिफ़ॉल्ट पेमेंट कार्ड अपडेट हुआ!';

  @override
  String get removePaymentCard => 'पेमेंट कार्ड हटाएँ';

  @override
  String get confirmRemoveCardDesc =>
      'क्या आप वाकई इस कार्ड को हटाना चाहते हैं? यदि कोई डिफ़ॉल्ट पेमेंट कार्ड नहीं बचा, तो लिंक्ड ऑटो-फंडिंग फेल हो सकती है।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get remove => 'हटाएँ';

  @override
  String get billingCardSuccessfullyRemoved =>
      'बिलिंग कार्ड सफलतापूर्वक हटाया गया।';

  @override
  String get pleaseAddDefaultCardFirst =>
      'ऑटो-फंडिंग सक्षम करने के लिए कृपया पहले एक डिफ़ॉल्ट पेमेंट कार्ड जोड़ें और चुनें।';

  @override
  String get autoFundPrefsSavedSuccess =>
      'ऑटो-फंडिंग प्राथमिकताएँ सफलतापूर्वक सेव हुई!';

  @override
  String get preparingDataExport => 'डेटा एक्सपोर्ट तैयार किया जा रहा है...';

  @override
  String exportFailed(String error) {
    return 'एक्सपोर्ट विफल: $error';
  }

  @override
  String get deleteAccountWarning =>
      'एक बार खाता डिलीट करने के बाद, इसे वापस नहीं लाया जा सकता। कृपया सुनिश्चित हो जाएँ।';

  @override
  String get deleteAccount => 'खाता डिलीट करें';

  @override
  String get deleteAccountIrreversible =>
      'यह कार्रवाई अपरिवर्तनीय है। आपका सारा डेटा स्थायी रूप से मिटा दिया जाएगा।';

  @override
  String get typeDeleteToConfirm => 'पुष्टि करने के लिए \"DELETE\" टाइप करें:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'सिस्टम डायग्नोस्टिक्स लॉग';

  @override
  String get online => 'ऑनलाइन';

  @override
  String errorLoadingPrefs(String error) {
    return 'प्राथमिकताएँ लोड करने में त्रुटि: $error';
  }

  @override
  String get privacyPolicyLoaded => 'प्राइवेसी पॉलिसी विवरण लोड हुआ।';

  @override
  String get protectionConsole => 'सुरक्षा कंसोल';

  @override
  String get deleteProtectionTooltip => 'सुरक्षा हटाएँ';

  @override
  String get refreshTooltip => 'रीफ्रेश करें';

  @override
  String get failedToLoadDetails => 'विवरण लोड करने में विफल';

  @override
  String get retryConnection => 'कनेक्शन फिर से कोशिश करें';

  @override
  String get healthLabel => 'हेल्थ';

  @override
  String get mySimCardDefault => 'मेरा SIM कार्ड';

  @override
  String get upLabel => 'अप';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'शेयर किया गया: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'गंभीर जोखिम';

  @override
  String get simDeactivationRisk =>
      'कार्रवाई न करने पर SIM निष्क्रिय हो सकता है';

  @override
  String get missingAlertsDesc =>
      'कोई अलर्ट नोटिफिकेशन कॉन्फ़िगर नहीं — 100 पॉइंट्स कम';

  @override
  String get missingAutoRefillDesc =>
      'कोई ऑटो-रिफिल कॉन्फ़िगर नहीं — 50 पॉइंट्स कम';

  @override
  String get missingVerificationDesc =>
      'फ़ोन नंबर सत्यापित नहीं — 25 पॉइंट्स कम';

  @override
  String get missingRecentRefillDesc =>
      'आख़िरी रिफिल 80 दिन से अधिक पहले हुआ था — 25 पॉइंट्स कम';

  @override
  String get quickActionsLabel => 'त्वरित कार्य';

  @override
  String get manualRefillLabel => 'मैनुअल रिफिल';

  @override
  String get chargeFromWalletNow => 'अभी वॉलेट से चार्ज करें';

  @override
  String get rechargeFromFriend => 'दोस्त से रिचार्ज करवाएँ';

  @override
  String get requestViaTelegram => 'Telegram के ज़रिए रिक्वेस्ट करें';

  @override
  String get shareViaWaTg => 'WhatsApp/Telegram के ज़रिए शेयर करें';

  @override
  String get testSimActivity => 'SIM एक्टिविटी टेस्ट करें';

  @override
  String get verifyLineReachable => 'जांचें कि लाइन रीचेबल है';

  @override
  String get checkCompleted1x => '1x जांच पूरी हुई';

  @override
  String get starterPlan1xCompleted =>
      'स्टार्टर प्लान की 1x जांच पूरी हुई। असीमित जांच के लिए प्रीमियम में अपग्रेड करें।';

  @override
  String leaveCountry(String countryName) {
    return '$countryName छोड़ें';
  }

  @override
  String get resumeProtectionLayers => 'सुरक्षा परतें फिर से शुरू करें';

  @override
  String backToCountryMode(String countryName) {
    return '$countryName मोड पर वापस जाएँ';
  }

  @override
  String get pauseWhileVisitingHome => 'होम विज़िट के दौरान रोकें';

  @override
  String get rechargeFromFriendTitle => 'किसी दोस्त से रिचार्ज करवाएँ';

  @override
  String get selectPlatformShare =>
      'अपने दोस्त के साथ रिचार्ज रिक्वेस्ट मैसेज शेयर करने के लिए एक प्लेटफ़ॉर्म चुनें।';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'नमस्ते! मेरा KeepSIMs कार्ड ($phone) जल्द समाप्त हो रहा है। क्या आप कृपया मेरे लिए इसे रिचार्ज कर सकते हैं? धन्यवाद!';
  }

  @override
  String get requestViaWhatsApp => 'WhatsApp के ज़रिए रिक्वेस्ट करें';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return '$platformName लिंक लॉन्च नहीं हो सका: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Telegram लिंक लॉन्च नहीं हो सका: $error';
  }

  @override
  String get protectionLayersLabel => 'सुरक्षा परतें';

  @override
  String get autoNotifyDisabled => 'ऑटो-नोटिफाई: बंद';

  @override
  String get noActiveAlertSchedule =>
      'आपके SIM कार्ड का कोई सक्रिय अलर्ट नोटिफिकेशन शेड्यूल नहीं है। आपको ऑटोमेटिक रिमाइंडर या डीएक्टिवेशन अलर्ट नहीं मिलेंगे।';

  @override
  String get askOwnerConfigureAlerts =>
      'कृपया अलर्ट कॉन्फ़िगर करने के लिए परिवार के मालिक से कहें।';

  @override
  String get configureAutoNotify => 'ऑटो-नोटिफाई कॉन्फ़िगर करें';

  @override
  String get activeLabel => 'सक्रिय';

  @override
  String get pausedHomeMode => 'रुका हुआ (होम मोड)';

  @override
  String get pausedLabel => 'रुका हुआ';

  @override
  String get everyHour => 'हर 1 घंटे में';

  @override
  String everyNDays(int days) {
    return 'हर $days दिन में';
  }

  @override
  String get nextAlertCheck => 'अगली अलर्ट जांच';

  @override
  String get premiumKeepAliveRefill => 'प्रीमियम कीप-अलाइव रिफिल';

  @override
  String autoRefillIncludedText(String date) {
    return 'ऑटो-रिफिल शामिल - ~3.5 USD (टेलीकॉम, VAT शामिल) हर 85 दिन में,\\nअगला रिफिल $date पर';
  }

  @override
  String get premiumKeepAliveDisabled => 'प्रीमियम कीप-अलाइव रिफिल अभी बंद है।';

  @override
  String get customAutoRefill => 'कस्टम ऑटो-रिफिल';

  @override
  String get addAdditionalScheduledRecharge =>
      'अपने SIM पर अतिरिक्त बैलेंस बनाए रखने के लिए एक अतिरिक्त शेड्यूल्ड रिचार्ज राशि जोड़ें।';

  @override
  String get askOwnerConfigureRefill =>
      'कृपया ऑटो-रिफिल कॉन्फ़िगर करने के लिए परिवार के मालिक से कहें।';

  @override
  String get configureCustomAutoRefill => 'कस्टम ऑटो-रिफिल कॉन्फ़िगर करें';

  @override
  String get rechargeAmount => 'रिचार्ज राशि';

  @override
  String get refillInterval => 'रिफिल अंतराल';

  @override
  String get nextRefillDue => 'अगला रिफिल कब है';

  @override
  String get failedRefillAttempts => 'असफल रिफिल प्रयास';

  @override
  String retriesCount(int count) {
    return '$count / 4 पुनः प्रयास';
  }

  @override
  String get editRefillAmount => 'रिफिल राशि संपादित करें';

  @override
  String get refillExecutionsHistory => 'रिफिल निष्पादन इतिहास';

  @override
  String get renewalExecutionsHistory => 'रिन्यूअल निष्पादन इतिहास';

  @override
  String get noHistoricalTopup =>
      'इस लाइन के लिए अभी तक कोई ऐतिहासिक टॉप-अप निष्पादन रिकॉर्ड नहीं हुआ।';

  @override
  String get noHistoricalRenewal =>
      'इस लाइन के लिए अभी तक कोई ऐतिहासिक रिन्यूअल निष्पादन रिकॉर्ड नहीं हुआ।';

  @override
  String get viewAllHistory => 'पूरा इतिहास देखें';

  @override
  String get securityActivityLogs => 'सुरक्षा एक्टिविटी लॉग';

  @override
  String get clearLogs => 'लॉग साफ़ करें';

  @override
  String get noActivityLogsRecorded =>
      'इस लाइन के लिए अभी तक कोई एक्टिविटी लॉग रिकॉर्ड नहीं हुआ।';

  @override
  String get activityLogDeleted => 'एक्टिविटी लॉग एंट्री डिलीट हुई।';

  @override
  String get activityLogsCleared => 'एक्टिविटी लॉग सफलतापूर्वक साफ़ हुए।';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'ऑटो-रिन्यूअल सफलतापूर्वक $status हुआ।';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'शेड्यूल अपडेट करने में विफल: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'प्रीमियम कीप-अलाइव रिफिल सफलतापूर्वक सक्षम हुआ।';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'ऑटो-रिफिल सक्षम करने में विफल: $error';
  }

  @override
  String get removeScheduleTitle => 'शेड्यूल हटाएँ';

  @override
  String get confirmDeleteAutoRefill =>
      'क्या आप वाकई इस ऑटो-रिफिल शेड्यूल को डिलीट करना चाहते हैं? आपका SIM हेल्थ स्कोर काफी गिर जाएगा, जिससे डीएक्टिवेशन का जोखिम बढ़ जाएगा।';

  @override
  String get confirmDeleteAutoRenewal =>
      'क्या आप वाकई इस ऑटो-रिन्यूअल शेड्यूल को डिलीट करना चाहते हैं? आपका SIM हेल्थ स्कोर काफी गिर जाएगा, जिससे डीएक्टिवेशन का जोखिम बढ़ जाएगा।';

  @override
  String get autoRefillRemoved => 'ऑटो-रिफिल शेड्यूल सफलतापूर्वक हटाया गया।';

  @override
  String get autoRenewalRemoved =>
      'ऑटो-रिन्यूअल शेड्यूल सफलतापूर्वक हटाया गया।';

  @override
  String failedToDeleteSchedule(String error) {
    return 'शेड्यूल डिलीट करने में विफल: $error';
  }

  @override
  String get refillRetrySuccess => 'रिफिल पुनः प्रयास सफलतापूर्वक पूरा हुआ!';

  @override
  String get refillRetryQueued =>
      'पुनः प्रयास कतार में जोड़ा गया — रिफिल संसाधित हो रहा है।';

  @override
  String get renewalRetrySuccess =>
      'रिन्यूअल पुनः प्रयास सफलतापूर्वक पूरा हुआ!';

  @override
  String retryFailed(String error) {
    return 'पुनः प्रयास विफल: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'पुनः प्रयास निष्पादन त्रुटि: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'एक्टिविटी लॉग डिलीट करने में विफल: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'एक्टिविटी लॉग साफ़ करने में विफल: $error';
  }

  @override
  String get removeProtectionTitle => 'सुरक्षा हटाएँ';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'क्या आप वाकई $name को सुरक्षित रखना बंद करना चाहते हैं? इस SIM लाइन के लिए शेड्यूल्ड टॉप-अप स्थायी रूप से रद्द हो जाएँगे।';
  }

  @override
  String get simLineProtectionRemoved =>
      'SIM लाइन सुरक्षा सफलतापूर्वक हटाई गई।';

  @override
  String failedToDeleteSimLine(String error) {
    return 'डिलीट करने में विफल: $error';
  }

  @override
  String get editSimNameTitle => 'SIM नाम संपादित करें';

  @override
  String get enterNicknameInstruction =>
      'इस SIM कार्ड लाइन के लिए एक उपनाम दर्ज करें:';

  @override
  String get nicknameExampleHint => 'जैसे मेरा Orange Egypt SIM';

  @override
  String get simNameUpdatedSuccess => 'SIM नाम सफलतापूर्वक अपडेट हुआ।';

  @override
  String failedToUpdateSimName(String error) {
    return 'SIM नाम अपडेट करने में विफल: $error';
  }

  @override
  String get saveButton => 'सेव करें';

  @override
  String get deleteButton => 'डिलीट करें';

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
  String get autoNotifySchedule => 'ऑटो-नोटिफाई शेड्यूल';

  @override
  String get renewalCheckInterval => 'रिन्यूअल जांच अंतराल';

  @override
  String get editNotificationConfig => 'नोटिफिकेशन कॉन्फ़िग संपादित करें';

  @override
  String get openTicket => 'टिकट खोलें';

  @override
  String get offlineRefillLabel => 'ऑफ़लाइन रिफिल';

  @override
  String get categoryLabel => 'श्रेणी';

  @override
  String get techSupportCategory => 'तकनीकी सहायता';

  @override
  String get billingWalletCategory => 'बिलिंग और वॉलेट';

  @override
  String get simLinesCategory => 'SIM लाइन प्रबंधन';

  @override
  String get feedbackOtherCategory => 'फ़ीडबैक और अन्य';

  @override
  String get subjectLabel => 'विषय';

  @override
  String get subjectHint => 'समस्या का संक्षिप्त सारांश';

  @override
  String get descriptionLabel => 'विवरण';

  @override
  String get descriptionHint => 'अपनी समस्या को विस्तार से बताएं...';

  @override
  String get attachmentLabel => 'अटैचमेंट (वैकल्पिक)';

  @override
  String get uploadScreenshot => 'स्क्रीनशॉट अपलोड करें';

  @override
  String get submitTicketButton => 'टिकट सबमिट करें';

  @override
  String get pleaseFillFields => 'कृपया विषय और विवरण दोनों भरें';

  @override
  String get ticketSubmittedSuccess => 'टिकट सफलतापूर्वक सबमिट हुआ!';

  @override
  String get lastRefillLabel => 'आख़िरी रिफिल';

  @override
  String get noRefillYet => 'अभी तक कोई रिफिल नहीं';

  @override
  String get nextAlertLabel => 'अगला अलर्ट';

  @override
  String get protectionLabel => 'सुरक्षा';

  @override
  String get actionRequiredLabel => 'कार्रवाई ज़रूरी';

  @override
  String get protectionOffLabel => 'सुरक्षा बंद';

  @override
  String get notSet => 'सेट नहीं है';

  @override
  String get homeMode => 'होम मोड';

  @override
  String get keepProtectedAtHome => 'घर पर भी सुरक्षा जारी रखें';

  @override
  String get protectionPausesAtHome => 'घर पर सुरक्षा रुक जाती है';

  @override
  String get incidentChannelsTitle => 'इंसिडेंट चैनल';

  @override
  String get topUpSuccessTitle => 'टॉप-अप सफल';

  @override
  String get topUpSuccessDesc =>
      'जब ऑटोमेटिक SIM वैलिडिटी एक्सटेंशन सफलतापूर्वक पूरा हो जाए तो मुझे सूचित करें।';

  @override
  String get topUpFailedTitle => 'टॉप-अप विफल (गंभीर)';

  @override
  String get topUpFailedDesc =>
      'जब कैरियर या वॉलेट समस्याओं के कारण ऑटोमेटिक टॉप-अप विफल हो जाएँ तो गंभीर अलर्ट।';

  @override
  String get walletLowTitle => 'कम वॉलेट बैलेंस';

  @override
  String get walletLowDesc =>
      'जब प्राइमरी बैलेंस सेफ्टी थ्रेशोल्ड से नीचे चला जाए तो मुझे चेतावनी दें।';

  @override
  String get walletDepletedTitle => 'वॉलेट खत्म';

  @override
  String get walletDepletedDesc =>
      'जब वॉलेट बैलेंस पूरी तरह खत्म हो जाए और रिन्यूअल रुक जाएँ तो सस्पेंडेड अलर्ट।';

  @override
  String get lineCriticalTitle => 'वैलिडिटी समाप्ति चेतावनी';

  @override
  String get lineCriticalDesc =>
      'जब SIM वैलिडिटी विंडो 48 घंटों में समाप्त होने वाली हो तो मुझे चेतावनी दें।';

  @override
  String get lineEnteringGraceTitle => 'ग्रेस पीरियड शुरू हो रहा है';

  @override
  String get lineEnteringGraceDesc =>
      'जब कैरियर डीएक्टिवेशन ग्रेस पीरियड का पता चले तो मुझे सूचित करें।';

  @override
  String get geoFenceTriggeredTitle => 'लोकेशन / रोमिंग अलर्ट';

  @override
  String get geoFenceTriggeredDesc =>
      'जब कैरियर रोमिंग क्लस्टर या नेटवर्क नोड बदले तो अलर्ट।';

  @override
  String get welcomeHomeReadyTitle => 'वेलकम होम सिंक';

  @override
  String get welcomeHomeReadyDesc =>
      'जब होम-देश का नेटवर्क नोड ऑटोमेटेड सिंक ट्रिगर करे तो अलर्ट।';

  @override
  String get referralRewardTitle => 'रेफरल और रिवॉर्ड्स';

  @override
  String get referralRewardDesc =>
      'जब दोस्तों के रेफरल से मेरे वॉलेट में प्रोमोशनल बैलेंस जमा हो तो मुझे सूचित करें।';

  @override
  String get systemUpdatesTitle => 'सामान्य सिस्टम अपडेट';

  @override
  String get systemUpdatesDesc =>
      'महत्वपूर्ण इंजन अपडेट, मेंटेनेंस और प्लेटफ़ॉर्म घोषणाएं।';

  @override
  String get walletCreditTitle => 'वॉलेट में राशि जमा';

  @override
  String get walletCreditDesc =>
      'जब मेरे वॉलेट में जमा राशि आए तो मुझे सूचित करें।';

  @override
  String get promoTitle => 'ऑफ़र और प्रचार';

  @override
  String get promoDesc =>
      'सौदों और नई सुविधाओं के बारे में कभी-कभार समाचार। जब तक आप चालू न करें, बंद रहता है।';

  @override
  String get deliverVia => 'इसके द्वारा भेजें';

  @override
  String get channelPushShort => 'पुश';

  @override
  String get channelEmailShort => 'ईमेल';

  @override
  String get channelOffGlobally => 'ऊपर अलर्ट चैनल में बंद है';

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
  String get rechargeNow => 'अभी रिचार्ज करें';

  @override
  String get planFeePaidFromWallet =>
      'प्लान शुल्क आपके वॉलेट बैलेंस से भुगतान किया गया।';

  @override
  String get planFeeNotChargedRetry =>
      'आपका टॉप-अप आ गया, लेकिन प्लान शुल्क नहीं लिया जा सका, इसलिए लाइन नहीं बनाई गई। आपका बैलेंस सुरक्षित है — कृपया फिर से प्रयास करें।';

  @override
  String activityTopupRequested(String amount) {
    return '\$$amount के रिफ़िल अनुरोध प्रस्तुत किया गया';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return '$provider के माध्यम से \$$amount का टॉप-अप पूरा हुआ';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return '\$$amount का टॉप-अप विफल रहा: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return '\$$amount का रिफ़िल वॉलेट में वापस कर दिया गया';
  }

  @override
  String activityTopupCancelled(String amount) {
    return '\$$amount का रिफ़िल अनुरोध रद्द कर दिया गया';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return '\$$amount के रिफ़िल के लिए पुन: प्रयास कतारबद्ध किया गया';
  }

  @override
  String get activityLineCreated => 'SIM लाइन SIM Shield में पंजीकृत';

  @override
  String get activityHealthUpdate => 'SIM लाइन सक्रिय स्थिति सत्यापित';

  @override
  String get activityReminderSent => 'नवीनीकरण अनुस्मारक सूचना भेजी गई';

  @override
  String get supportTicketsTitle => 'सहायता और समर्थन';

  @override
  String get supportTicketsSubtitle =>
      'सहायता अनुरोध सबमिट करें, गतिविधि लॉग संलग्न करें, और सहायता टीम के साथ लाइव चैट करें।';

  @override
  String get supportTicketsEmpty => 'कोई सहायता टिकट नहीं मिला।';

  @override
  String get createSupportTicket => 'टिकट बनाएँ';

  @override
  String get ticketCategoryGeneral => 'सामान्य पूछताछ';

  @override
  String get ticketCategoryBilling => 'बिलिंग और वॉलेट';

  @override
  String get ticketCategoryTechnical => 'तकनीकी समस्या';

  @override
  String get ticketCategoryRefillIssue => 'रिचार्ज समस्या';

  @override
  String get ticketCategoryAccount => 'खाता और सुरक्षा';

  @override
  String get ticketStatusOpen => 'खुला';

  @override
  String get ticketStatusPending => 'उत्तर की प्रतीक्षा';

  @override
  String get ticketStatusResolved => 'हल किया गया';

  @override
  String get ticketStatusClosed => 'बंद';

  @override
  String get ticketSubjectLabel => 'विषय';

  @override
  String get ticketSubjectHint => 'समस्या का संक्षिप्त विवरण';

  @override
  String get ticketCategoryLabel => 'श्रेणी';

  @override
  String get ticketMessageLabel => 'संदेश';

  @override
  String get ticketMessageHint => 'विस्तृत जानकारी प्रदान करें...';

  @override
  String get attachImage => 'छवि संलग्न करें';

  @override
  String get attachActivityLogs => 'लाइन लॉग संलग्न करें';

  @override
  String get submitTicket => 'टिकट सबमिट करें';

  @override
  String get typeMessageHint => 'संदेश लिखें...';

  @override
  String get closeTicketButton => 'टिकट बंद करें';

  @override
  String get ticketClosedNotice => 'यह सहायता टिकट बंद कर दिया गया है।';

  @override
  String get attachedFiles => 'संलग्नक';

  @override
  String get referralsTitle => 'रेफर करें और कमाएं';

  @override
  String get referralsSubtitle =>
      'दोस्तों को आमंत्रित करें, उनके सिम सब्सक्रिप्शन पर अंक कमाएं और वॉलेट क्रेडिट के रूप में रिडीम करें!';

  @override
  String get referralCode => 'आपका रेफरल कोड';

  @override
  String get copyCode => 'कोड कॉपी करें';

  @override
  String get codeCopied => 'रेफरल कोड क्लिपबोर्ड पर कॉपी हो गया!';

  @override
  String get shareCode => 'कोड शेयर करें';

  @override
  String get pointsBalance => 'पॉइंट्स बैलेंस';

  @override
  String get pointsUnit => 'अंक';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return 'अगले \$2.00 इनाम के लिए $pointsNeeded और अंक चाहिए';
  }

  @override
  String get redeemButton => '\$2.00 के लिए 10 अंक रिडीम करें';

  @override
  String get redeemSuccess =>
      '\$2.00 वॉलेट क्रेडिट के लिए 10 अंक सफलतापूर्वक रिडीम किए गए!';

  @override
  String get applyCodeTitle => 'क्या आपके पास रेफरल कोड है?';

  @override
  String get applyCodeHint => 'रेफरल कोड दर्ज करें';

  @override
  String get applyCodeButton => 'कोड लागू करें';

  @override
  String get applyCodeSuccess => 'रेफरल कोड सफलतापूर्वक लागू किया गया!';

  @override
  String get referredFriendsTitle => 'रेफर किए गए मित्र';

  @override
  String get noReferredFriends =>
      'अभी तक कोई मित्र रेफर नहीं किया गया। शुरू करने के लिए अपना कोड शेयर करें!';

  @override
  String get redemptionHistoryTitle => 'रिडेम्प्शन इतिहास';

  @override
  String get noRedemptions => 'अभी तक कोई रिडेम्प्शन नहीं।';

  @override
  String get pointHistoryTitle => 'पॉइंट्स इतिहास';

  @override
  String get noPointsEarned => 'अभी तक कोई अंक नहीं कमाए गए।';

  @override
  String get howItWorksTitle => 'रेफर और अर्न कैसे काम करता है';

  @override
  String get howItWorksStep1 =>
      '1. दोस्तों के साथ अपना अनूठा रेफरल कोड शेयर करें।';

  @override
  String get howItWorksStep2 =>
      '2. जब भी कोई रेफर किया गया मित्र सिम लाइन सब्सक्राइब करता है तो 1 अंक कमाएं।';

  @override
  String get howItWorksStep3 =>
      '3. कभी भी \$2.00 वॉलेट क्रेडिट के लिए 10 अंक रिडीम करें!';

  @override
  String get geoTitle => 'यात्रा और जियोलोकेशन';

  @override
  String get geoSubtitle =>
      'स्वचालित देश का पता लगाना और अंतर्राष्ट्रीय सिम लाइन सुरक्षा';

  @override
  String get currentCountryLabel => 'वर्तमान स्थान';

  @override
  String get travelModeToggle => 'यात्रा मोड';

  @override
  String get travelModeDescription =>
      'अंतर्राष्ट्रीय लाइन सुरक्षा प्रबंधित करने के लिए ऐप खोलते समय देश की जाँच करें';

  @override
  String get geoNotice =>
      'ऐप खोलने पर आईपी लुकअप द्वारा देश की जाँच की जाती है। कोई लोकेशन अनुमति आवश्यक नहीं है।';

  @override
  String get freezeInternationalLines => 'अंतर्राष्ट्रीय लाइनों को फ्रीज करें';

  @override
  String get resumeInternationalLines =>
      'अंतर्राष्ट्रीय लाइनों को फिर से शुरू करें';

  @override
  String get linesFrozenSuccess =>
      'अंतर्राष्ट्रीय सिम लाइनें फ्रीज कर दी गईं और अनुसूचित रीफिल रोक दिए गए!';

  @override
  String get linesResumedSuccess =>
      'अंतर्राष्ट्रीय सिम लाइनें और रीफिल फिर से सक्रिय!';

  @override
  String get alwaysProtectedBadge => 'हमेशा सुरक्षित';

  @override
  String get detectedViaIp => 'आईपी द्वारा पता लगाया गया';

  @override
  String get esimManagerTitle => 'eSIM प्रबंधक';

  @override
  String get esimPlansTitle => 'eSIM प्लान्स';

  @override
  String get searchDestinationHint =>
      'गंतव्य खोजें (जैसे फ्रांस, संयुक्त राज्य अमेरिका)';

  @override
  String get selectDestinationTitle => 'गंतव्य चुनें';

  @override
  String get localTab => 'लोकल';

  @override
  String get regionalTab => 'क्षेत्रीय';

  @override
  String get globalTab => 'ग्लोबल';

  @override
  String get bestValueBadge => 'सर्वोत्तम मूल्य';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days दिन';
  }

  @override
  String get buyPlanButton => 'प्ला खरीदें';

  @override
  String get deviceIncompatibleNotice =>
      'आपका डिवाइस eSIM तकनीक का समर्थन नहीं करता है।';

  @override
  String get activationPolicyTitle => 'सक्रियण नीति';

  @override
  String get activationPolicyNotice =>
      'वैधता तब शुरू होती है जब eSIM आपके गंतव्य पर समर्थित नेटवर्क से जुड़ता है।';

  @override
  String get coveredCountriesTitle => 'शामिल देश';

  @override
  String get sortPriceLowToHigh => 'मूल्य: कम से अधिक';

  @override
  String get sortPricePerGb => 'मूल्य / GB: कम से अधिक';

  @override
  String get sortDataHighToLow => 'डेटा: अधिक से कम';

  @override
  String get filterAll => 'सभी प्लान';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ 15 दिन';

  @override
  String get filterUnlimited => 'अनलिमिटेड';

  @override
  String get purchaseInNextRelease =>
      'खरीद की सुविधा अगले रिलीज़ (C9b) में उपलब्ध होगी।';

  @override
  String get confirmPurchaseTitle => 'eSIM खरीद की पुष्टि करें';

  @override
  String get myEsimsTitle => 'मेरी eSIMs';

  @override
  String get showQrCode => 'QR कोड दिखाएं';

  @override
  String get buyAgain => 'पुनः खरीदें';

  @override
  String get dataRemaining => 'शेष डेटा';

  @override
  String get archivedEsims => 'आर्काइव की गई eSIMs';

  @override
  String rateLimitExceeded(String seconds) {
    return 'बहुत सारे अनुरोध। कृपया पुनः प्रयास करने से पहले $seconds सेकंड प्रतीक्षा करें।';
  }

  @override
  String get confirmDeleteButton => 'हटाने की पुष्टि करें';

  @override
  String get cancelAccountDeletion => 'खाता हटाने को रद्द करें';

  @override
  String get accountScheduledForDeletion => 'खाता हटाने के लिए निर्धारित';

  @override
  String deletionScheduledNotice(String date) {
    return 'आपका खाता फ्रीज कर दिया गया है और $date को स्थायी रूप से हटाने का समय निर्धारित है।';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'आपका वॉलेट बैलेंस (\$$balance) डस्ट सीमा (\$1.00) से अधिक है। कृपया इसे खर्च करें या सहायता से संपर्क करें।';
  }

  @override
  String get payPalCheckoutTitle => 'PayPal चेकआउट';

  @override
  String get payPalWalletTopUp => 'KeepSIMs वॉलेट टॉप-अप';

  @override
  String get payPalPaySecurely => 'PayPal से सुरक्षित भुगतान करें';

  @override
  String get payPalRedirectInfo =>
      'भुगतान अधिकृत करने के लिए आपको PayPal पर पुनः निर्देशित किया जाएगा।';

  @override
  String get payPalCreatingOrder => 'सुरक्षित PayPal ऑर्डर बनाया जा रहा है...';

  @override
  String get payPalAwaitingConfirmation =>
      'PayPal पुष्टि की प्रतीक्षा की जा रही है...';

  @override
  String get payPalCompleteInBrowser =>
      'कृपया खोली गई ब्राउज़र विंडो में भुगतान पूरा करें।';

  @override
  String get payPalPaymentConfirmed => 'भुगतान की पुष्टि हो गई!';

  @override
  String get payPalPaymentFailed => 'भुगतान विफल रहा या रद्द कर दिया गया।';

  @override
  String get payPalForceCaptureButton =>
      'मैंने PayPal पर भुगतान पूरा कर लिया है';

  @override
  String get payPalBrowserOpened => 'PayPal आपके ब्राउज़र में खुला है';

  @override
  String get payPalBrowserOpenedBody =>
      'भुगतान वहीं पूरा करें — यह स्क्रीन खुद अपडेट हो जाएगी।';

  @override
  String get payPalTakingLonger =>
      'इसमें सामान्य से अधिक समय लग रहा है। यदि आपने पहले ही भुगतान कर दिया है, तो नीचे जाँचें।';

  @override
  String get payPalReopenButton => 'PayPal फिर से खोलें';

  @override
  String get payPalVerifying => 'आपके भुगतान की पुष्टि हो रही है…';

  @override
  String get payPalVerifyingBody => 'PayPal से पुष्टि करते समय एक पल रुकें।';

  @override
  String get payPalPaymentCancelled =>
      'भुगतान रद्द कर दिया गया। आपसे कोई शुल्क नहीं लिया गया।';

  @override
  String get payPalDoneButton => 'हो गया';

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
  String get householdTitle => 'परिवार और घर';

  @override
  String get householdTabMyFamily => 'मेरा परिवार';

  @override
  String get householdTabReceived => 'निमंत्रण';

  @override
  String get householdTabJoined => 'शामिल';

  @override
  String get householdInviteMember => 'सदस्य आमंत्रित करें';

  @override
  String get householdEmptyTitle => 'अभी कोई सदस्य नहीं';

  @override
  String get householdEmptyDesc =>
      'ईमेल से किसी को आमंत्रित करें और अपनी प्रीपेड सिम लाइनें व रिन्यूअल साझा करें।';

  @override
  String get householdStatusPending => 'लंबित';

  @override
  String get householdStatusAccepted => 'सक्रिय';

  @override
  String get householdPendingHint => 'उनके स्वीकार करने की प्रतीक्षा';

  @override
  String get householdRoleViewer => 'दर्शक';

  @override
  String get householdRoleManager => 'प्रबंधक';

  @override
  String get householdRoleViewerHint => 'आपकी लाइनें देख सकता है';

  @override
  String get householdRoleManagerHint =>
      'आपकी लाइनें देख और रिचार्ज कर सकता है';

  @override
  String get householdManagerWarning =>
      'प्रबंधक आपकी लाइनें रिचार्ज कर सकता है। वह आपके वॉलेट से तभी खर्च करेगा जब आप सीमा तय करें।';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'मेरे वॉलेट से खर्च · इस माह $cap में से $spent';
  }

  @override
  String get householdPaysOwnWallet => 'अपने वॉलेट से भुगतान करता है';

  @override
  String get householdManagersOnly =>
      'केवल प्रबंधक — दर्शक आपके वॉलेट से खर्च नहीं कर सकता';

  @override
  String get householdChangeLimit => 'सीमा बदलें';

  @override
  String get householdSetLimit => 'सीमा तय करें';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining शेष · $queued कतार में, अभी शुल्क नहीं लिया गया';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return 'इस माह $remaining शेष';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return '$name के लिए खर्च सीमा';
  }

  @override
  String get householdSpendingLimitDesc =>
      'हर कैलेंडर माह वह आपकी लाइनों पर आपके वॉलेट से कितना खर्च कर सकता है। बंद करने के लिए 0 रखें — तब वह अपने वॉलेट से भुगतान करेगा।';

  @override
  String get householdMonthlyLimit => 'मासिक सीमा (USD)';

  @override
  String get householdMaxPerRefill => 'प्रति रिचार्ज अधिकतम (वैकल्पिक)';

  @override
  String get householdSave => 'सहेजें';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name अब हर माह आपके वॉलेट से $cap तक खर्च कर सकता है।';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name फिर से अपने वॉलेट से भुगतान करेगा।';
  }

  @override
  String get householdLimitFailed => 'सीमा अपडेट नहीं हो सकी।';

  @override
  String get householdNoInvitesTitle => 'कोई निमंत्रण नहीं';

  @override
  String get householdNoInvitesDesc =>
      'जब कोई आपको अपने परिवार में आमंत्रित करेगा, वह यहाँ दिखेगा।';

  @override
  String get householdFamilyAccount => 'पारिवारिक खाता';

  @override
  String get householdInvitedYouViewer =>
      'आपको अपनी सिम लाइनें देखने के लिए आमंत्रित किया';

  @override
  String get householdInvitedYouManager =>
      'आपको अपनी सिम लाइनें देखने और रिचार्ज करने के लिए आमंत्रित किया';

  @override
  String get householdAccept => 'स्वीकार करें';

  @override
  String get householdDecline => 'अस्वीकार करें';

  @override
  String get householdNotJoinedTitle => 'आप किसी परिवार में शामिल नहीं हुए';

  @override
  String get householdNotJoinedDesc =>
      'आपको मिलने वाले निमंत्रण निमंत्रण टैब में दिखते हैं।';

  @override
  String get householdSharedHousehold => 'साझा परिवार';

  @override
  String get householdRoleManagerFull => 'प्रबंधक · रिचार्ज कर सकता है';

  @override
  String get householdRoleViewerFull => 'दर्शक · केवल पढ़ें';

  @override
  String get householdLeave => 'छोड़ें';

  @override
  String householdOwnerFunds(String owner) {
    return '$owner आपके रिचार्ज का खर्च उठाते हैं';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'आपने इस माह का पूरा $cap इस्तेमाल कर लिया है। रीसेट होने तक उनकी लाइनों पर रिचार्ज अस्वीकार होंगे।';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return 'इस माह $cap में से $remaining शेष';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · प्रति रिचार्ज अधिकतम $perTxn';
  }

  @override
  String get householdInviteTitle => 'परिवार के सदस्य को आमंत्रित करें';

  @override
  String get householdInviteDesc =>
      'उन्हें ऐप में ही निमंत्रण मिलेगा। स्वीकार करने पर आपकी और उनकी सिम लाइनें साथ दिखेंगी।';

  @override
  String get householdEmailLabel => 'ईमेल पता';

  @override
  String get householdAccessLevel => 'वे क्या कर सकते हैं?';

  @override
  String get householdSendInvite => 'निमंत्रण भेजें';

  @override
  String get householdInvalidEmail => 'कृपया मान्य ईमेल पता दर्ज करें';

  @override
  String householdInviteSent(String email) {
    return '$email को निमंत्रण भेजा गया';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return '$email को निमंत्रण भेजा गया। रजिस्टर करते ही उन्हें दिखेगा।';
  }

  @override
  String get householdInviteAccepted => 'आप परिवार में शामिल हो गए';

  @override
  String get householdInviteDeclined => 'निमंत्रण अस्वीकार किया गया';

  @override
  String get householdRemoveTitle => 'परिवार सदस्य हटाएँ';

  @override
  String householdRemoveConfirm(String name) {
    return '$name तुरंत आपकी सिम लाइनों तक पहुँच और आपकी तय की गई खर्च सीमा खो देगा।';
  }

  @override
  String householdRemoved(String name) {
    return '$name को आपके परिवार से हटा दिया गया';
  }

  @override
  String get householdLeaveTitle => 'परिवार छोड़ें';

  @override
  String householdLeaveConfirm(String owner) {
    return '$owner द्वारा साझा की गई सिम लाइनों तक आपकी पहुँच समाप्त हो जाएगी।';
  }

  @override
  String get householdLeft => 'आपने परिवार छोड़ दिया';

  @override
  String get householdActionFailed => 'यह काम नहीं हुआ। कृपया फिर प्रयास करें।';

  @override
  String get householdOwnerLabel => 'आप (स्वामी)';

  @override
  String get householdSettingsSubtitle =>
      'परिवार के साथ सिम लाइनें साझा करें, खर्च सीमा तय करें';

  @override
  String get householdStatusDeclined => 'अस्वीकृत';

  @override
  String get householdDeclinedHint =>
      'उन्होंने अस्वीकार कर दिया। दोबारा आमंत्रित करने के लिए हटाएँ।';

  @override
  String get carrierActivityFallbackOperator => 'यह कैरियर';

  @override
  String get carrierUsageRequiredTitle =>
      'ऑटो-रिफिल इस लाइन को सुरक्षित नहीं रख सकता';

  @override
  String carrierUsageRequiredBody(String operator) {
    return '$operator तभी अपनी निष्क्रियता की उलटी गिनती दोबारा शुरू करता है जब लाइन से कॉल की जाए, एसएमएस भेजा जाए या डेटा इस्तेमाल हो। बैलेंस जोड़ना इसमें नहीं गिना जाता, इसलिए कोई भी ऑटो टॉप-अप इस नंबर को निष्क्रिय होने से नहीं रोक सकता। स्टैंडर्ड प्लान चुनें — हम आपको समय रहते सूचित कर देंगे ताकि आप खुद लाइन इस्तेमाल कर सकें।';
  }

  @override
  String get carrierMinDenominationTitle =>
      'इस कैरियर को बड़े टॉप-अप की ज़रूरत है';

  @override
  String carrierMinDenominationBody(
    String operator,
    String amount,
    String currency,
  ) {
    return '$operator केवल $amount $currency या उससे अधिक के टॉप-अप पर ही लाइन की वैधता जोड़ता है। इससे कम कोई भी राशि केवल खर्च करने योग्य बैलेंस के रूप में आती है और नंबर फिर भी निष्क्रिय हो सकता है, इसलिए प्रीमियम इस लाइन को $amount $currency पर रिफिल करता है।';
  }

  @override
  String get premiumUnavailableForCarrier =>
      'इस कैरियर के लिए प्रीमियम उपलब्ध नहीं है';

  @override
  String get carrierRulesLinkLabel =>
      'इस कैरियर के नियमों के बारे में और जानें';

  @override
  String get carrierRulesSheetTitle => 'नंबर बंद होने के नियम';

  @override
  String carrierRulesHowTitle(String operator) {
    return '$operator कैसे तय करता है';
  }

  @override
  String carrierRechargeOkBody(String operator) {
    return '$operator हर बार लाइन रिचार्ज होने पर अपनी गिनती दोबारा शुरू कर देता है, राशि चाहे जो हो। इसीलिए यहाँ अपने आप होने वाला रिचार्ज नंबर बचा सकता है।';
  }

  @override
  String get carrierRulesNumbersTitle => 'आँकड़े';

  @override
  String carrierRulesWindowRow(int days) {
    return 'मान्य रिचार्ज के बिना $days दिन बाद नंबर बंद कर दिया जाता है';
  }

  @override
  String carrierRulesGraceRow(int days) {
    return 'उसके बाद वही नंबर वापस पाने के लिए $days दिन';
  }

  @override
  String get carrierRulesNoGraceRow =>
      'वापस पाने का कोई समय नहीं — नंबर तुरंत किसी और को दे दिया जाता है';

  @override
  String carrierRulesMinTopupRow(String amount, String currency) {
    return 'वैधता बढ़ाने वाला सबसे छोटा रिचार्ज $amount $currency है';
  }

  @override
  String carrierRulesCadenceRow(int days, int count) {
    return 'हम हर $days दिन में रिचार्ज करेंगे — साल में $count बार';
  }

  @override
  String get carrierRulesVerdictTitle => 'हम क्या करते';

  @override
  String get carrierVerdictSelfServiceTitle => 'इस लाइन के लिए प्रीमियम न लें';

  @override
  String get carrierVerdictSelfServiceBody =>
      'अपना पैसा बचाइए। हम जो कुछ भी भेज सकते हैं, उससे इस कैरियर की घड़ी दोबारा शुरू नहीं होती; नंबर सिर्फ़ उसे इस्तेमाल करने से ही बचता है।';

  @override
  String get carrierVerdictStandardTitle => 'यहाँ स्टैंडर्ड ही काफ़ी है';

  @override
  String get carrierVerdictStandardBody =>
      'यह कैरियर आपको काफ़ी लंबा समय देता है। तारीख़ पर हम नज़र रखेंगे और आपको बताएँगे; बताने पर ख़ुद रिचार्ज कर लीजिए और सिर्फ़ टॉक-टाइम का पैसा दीजिए।';

  @override
  String get carrierVerdictPremiumWorthTitle => 'प्रीमियम लेना ठीक रहेगा';

  @override
  String get carrierVerdictPremiumWorthBody =>
      'साल में कुछ रिचार्ज, हर एक ऐसी तारीख़ पर जो यहाँ से दिखती नहीं। चाहें तो ख़ुद भी कर सकते हैं — अपने आप कराने का मतलब है इसके बारे में कभी सोचना ही न पड़े।';

  @override
  String get carrierVerdictPremiumMustTitle => 'इसे अपने आप होने दीजिए';

  @override
  String get carrierVerdictPremiumMustBody =>
      'यह कैरियर इतनी जल्दी नंबर बंद करता है कि दूसरे देश से हर बार ख़ुद याद रखना कभी न कभी छूट ही जाएगा — और एक बार छूटना यानी नंबर चला जाना।';

  @override
  String get carrierReasonUsageOnly =>
      'सिर्फ़ कॉल, SMS या डेटा चलाना गिना जाता है। अकेला बैलेंस नहीं।';

  @override
  String carrierReasonQualifying(String amount, String currency) {
    return '$amount $currency से कम का रिचार्ज सिर्फ़ बैलेंस बनकर आता है, वैधता नहीं बढ़ाता।';
  }

  @override
  String carrierReasonShortWindow(int days) {
    return 'दो मान्य रिचार्ज के बीच सिर्फ़ $days दिन।';
  }

  @override
  String carrierReasonLongWindow(int days) {
    return '$days दिन तो लगभग पूरा साल है — एक रिमाइंडर से काम चल जाएगा।';
  }

  @override
  String get carrierReasonNoGrace =>
      'कोई छूट अवधि नहीं है। तारीख़ चूकी तो नंबर गया।';

  @override
  String carrierReasonGrace(int days) {
    return 'तारीख़ के बाद नंबर वापस पाने के लिए आपके पास $days दिन होंगे।';
  }

  @override
  String carrierReasonAutomationCost(
    String self,
    String premium,
    String extra,
  ) {
    return 'अकेले टॉक-टाइम पर साल में लगभग $self लगते हैं। प्रीमियम $premium का है, यानी उसमें से $extra इस सुविधा के हैं।';
  }

  @override
  String carrierSelfServiceTitle(String operator) {
    return 'या सीधे $operator से लीजिए';
  }

  @override
  String get carrierSelfServiceBody =>
      'कैरियर के अपने ऐप से रिचार्ज कीजिए और सिर्फ़ टॉक-टाइम का पैसा दीजिए, और कुछ नहीं।';

  @override
  String carrierSelfServiceCountryLine(String country) {
    return 'नंबर का देश: $country';
  }

  @override
  String carrierSelfServiceAppHint(String app) {
    return 'इसका ऐप आमतौर पर \"$app\" नाम से मिलता है।';
  }

  @override
  String carrierSelfServiceUnverified(String operator) {
    return 'हमने यह ऐप ख़ुद जाँचा नहीं है। स्टोर में खोजिए और कुछ भी इंस्टॉल करने से पहले देख लीजिए कि उसे सचमुच $operator ने ही पब्लिश किया है।';
  }

  @override
  String get carrierSelfServiceSearchStore => 'ऐप स्टोर में खोजें';

  @override
  String get carrierSelfServiceOpenApp => 'कैरियर का ऐप खोलें';

  @override
  String get carrierSelfServiceWeb => 'कैरियर की वेबसाइट से रिचार्ज करें';

  @override
  String carrierSelfServiceUssd(String code) {
    return 'डेटा नहीं है? उसी फ़ोन से $code डायल कीजिए।';
  }

  @override
  String get carrierRulesSourceLink => 'कैरियर की प्रकाशित शर्तें';

  @override
  String get carrierRulesDisclaimer =>
      'कैरियर ये नियम बिना बताए बदल देते हैं। अगर आपके कैरियर ने बदले हों तो सपोर्ट को बताइए, हम दोबारा जाँच लेंगे।';

  @override
  String get carrierActionTitle => 'आपकी ज़रूरत है';

  @override
  String get carrierActionDesc =>
      'जब किसी लाइन को ऐसा कुछ चाहिए जो सिर्फ़ मैं ही कर सकता हूँ — सिम इस्तेमाल करना या कैरियर के अपने ऐप से रिचार्ज करना — तब मुझे बताएँ।';

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
  String compareCoverageLocalCountry(String country) {
    return '$country only';
  }

  @override
  String get compareSpeedLabel => 'Speed';

  @override
  String get compareMaxPriceLabel => 'Max price';

  @override
  String get comparePriceLabel => 'Price';

  @override
  String get compareFiltersTitle => 'Filters';

  @override
  String get compareMoreDetails => 'More details';

  @override
  String get compareDetailsTab => 'Details';

  @override
  String get compareCountriesTab => 'Countries';

  @override
  String get compareNetworkLabel => 'Network';

  @override
  String compareNetworkDesc(int count) {
    return 'Covers $count destinations. High-speed 4G / 5G / LTE networks where available.';
  }

  @override
  String get comparePlanTypeLabel => 'Plan type';

  @override
  String get comparePlanTypeDesc =>
      'Data only. Voice calls and SMS are not included.';

  @override
  String get compareEkycLabel => 'eKYC (Identity verification)';

  @override
  String get compareEkycNotRequired => 'Not required';

  @override
  String get compareDeliveryLabel => 'Delivery & Setup';

  @override
  String get compareDeliveryResaleDesc =>
      'Instant in-app digital delivery. QR code and manual activation code available immediately after purchase.';

  @override
  String get compareDeliveryPartnerDesc =>
      'Partner direct delivery on partner platform.';

  @override
  String get compareOtherInfoLabel => 'Other info';

  @override
  String get compareRoamingNotice =>
      'Data roaming must be enabled in device settings upon arrival.';

  @override
  String get compareApnNotice =>
      'APN is configured automatically by the network.';

  @override
  String get compareSearchCountryHint => 'Search by country name or code...';

  @override
  String get compareNoCountriesMatch => 'No countries match your search.';

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

  @override
  String get mySims => 'मेरे सिम';

  @override
  String get sharedWithMe => 'मेरे साथ साझा';

  @override
  String get searchNameOrNumber => 'नाम या नंबर खोजें';

  @override
  String get allFilter => 'सभी';

  @override
  String get alertSoon => 'शीघ्र चेतावनी';

  @override
  String get showFilters => 'फ़िल्टर दिखाएं';

  @override
  String get hideFilters => 'फ़िल्टर छिपाएं';

  @override
  String get refreshSims => 'सिम रीफ़्रेश करें';

  @override
  String get noMatchingSims => 'कोई मेल खाता सिम नहीं';

  @override
  String get tryDifferentSimSearch => 'कोई अन्य नाम, नंबर या फ़िल्टर आज़माएं।';

  @override
  String get clearSearchAndFilters => 'खोज और फ़िल्टर साफ़ करें';

  @override
  String get setupRefill => 'Setup Refill';

  @override
  String get scheduledRefill => 'Scheduled Refill';

  @override
  String get instantRefill => 'Instant Refill';

  @override
  String get customRefill => 'Custom Refill';

  @override
  String get notifTitleNumberAdded => '✅ Number added';

  @override
  String get notifTitleAutoRechargeScheduled => '✅ Auto-recharge scheduled';

  @override
  String get notifTitleSetupIncomplete => '⚠️ Finish setting up your number';

  @override
  String get notifTitleRechargeSuccessful => '✅ Recharge successful';

  @override
  String get notifTitleRechargeDueToday => '⚠️ Recharge due today';

  @override
  String get notifTitleRechargeFailed => '❌ Recharge failed';

  @override
  String get notifTitleWalletLow => '⚠️ Wallet balance is low';

  @override
  String get notifTitleRechargeNeedsFunds => '⚠️ Recharge needs funds';

  @override
  String get notifTitleLineCritical => '⚠️ Your number needs attention';

  @override
  String get notifChannelConfirmations => 'Setup confirmations';

  @override
  String get notifChannelUpdates => 'Recharge updates';

  @override
  String get notifChannelUrgent => 'Urgent recharge alerts';

  @override
  String get smartCalling => 'Smart Calling';

  @override
  String get keepSimsSmartCalling => 'KeepSIMs Smart Calling';

  @override
  String get smartCall => 'Smart Call';

  @override
  String get freeCall => 'Free Call';

  @override
  String get smartCallSavings => 'Smart Call Savings';

  @override
  String get virtualNumbers => 'Second Number';

  @override
  String get secondNumberSubtitle => 'Calls & call forwarding';

  @override
  String get voicemail => 'Voicemail';

  @override
  String get inspector => 'Inspector';

  @override
  String fxChargesInUsd(String currency) {
    return '$currency में राशि अनुमानित है। शुल्क USD में लिया जाता है।';
  }

  @override
  String get fxCurrencySaveFailed =>
      'प्रदर्शन मुद्रा सहेजी नहीं जा सकी। कृपया फिर से प्रयास करें।';

  @override
  String get fxAnnualProtectionFee => 'वार्षिक सुरक्षा शुल्क';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileWhatsAppNumber => 'WhatsApp number';

  @override
  String get profileTitle => 'My profile';

  @override
  String get profilePersonalAccount => 'Personal account';

  @override
  String get profileContactDetails => 'Contact details';

  @override
  String get profileNotificationEmail => 'Notification email';

  @override
  String get profileCheckStatus => 'Check status';

  @override
  String get profileVerified => 'Verified';

  @override
  String get profileVerify => 'Verify';

  @override
  String get profileSavedStatus => 'Saved';

  @override
  String get profileAddNumber => 'Add a number';

  @override
  String get profileLoadFailed => 'Could not load these details.';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePreferredLanguage => 'Preferred language';

  @override
  String get profileTimeZone => 'Time zone';

  @override
  String get profileDeviceTimeZoneHint =>
      'Times follow this device’s time zone. Change your device settings to update it.';

  @override
  String get profileCurrency => 'Currency';

  @override
  String get profileCurrencyHint =>
      'Choose the currency for estimated prices. Payments are charged in USD.';

  @override
  String get profileCurrencyUnavailable =>
      'Showing USD until your selected currency is available.';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileSavedSims => 'Saved SIMs';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileHomeCountry => 'Home country';

  @override
  String get profileNameRequired => 'Enter your name.';

  @override
  String get profileCountryRequired => 'Select your home country.';

  @override
  String get profileSaveFailed =>
      'Could not save your changes. Please try again.';

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get dashboardExplore => 'Explore KeepSIMs';

  @override
  String get dashboardYourSimLines => 'Your SIM lines';

  @override
  String get dashboardSecondNumberBenefit => 'Receive and forward calls';

  @override
  String get dashboardSetUp => 'Set up';

  @override
  String get dashboardRecharge => 'Recharge';

  @override
  String get dashboardStandard => 'Standard';

  @override
  String get dashboardPremium => 'Premium';

  @override
  String get dashboardAccountOptions => 'Account options';

  @override
  String get dashboardCurrentLocation => 'Current location';

  @override
  String get snMyNumbers => 'My Second Numbers';

  @override
  String get snGetNumber => 'Get Second Number';

  @override
  String get snSubtitle => 'Your numbers and messages, together.';

  @override
  String get snMessages => 'Messages';

  @override
  String get snEmpty =>
      'Get a dedicated number to receive messages in KeepSIMs.';

  @override
  String get snVerification =>
      'Verification codes depend on the sending service. Some services do not accept virtual numbers.';

  @override
  String get snPrivateNotifications =>
      'Message content is hidden in notifications.';

  @override
  String get snRenewal => 'Next renewal';

  @override
  String get snAutoRenew => 'Auto-renew from my wallet';

  @override
  String get snRelease => 'Release this number';

  @override
  String get snReleaseConfirm =>
      'You will lose future calls and messages. Update accounts that use this number for sign-in or recovery. The number may later be assigned to someone else. Release starts immediately and completes after carrier confirmation.';

  @override
  String get snReleasePending => 'Release pending';

  @override
  String get snGrace => 'Payment due — top up before the release deadline';

  @override
  String get snActive => 'Active';

  @override
  String get snReceiveOnly => 'Receive-only SMS inbox';

  @override
  String get snCopyCode => 'Copy code';

  @override
  String get snCopied => 'Copied to clipboard';

  @override
  String get snNoMessages => 'No messages yet';

  @override
  String get snInboxUnavailable =>
      'Could not load messages. Check your connection and retry.';

  @override
  String get snRetry => 'Retry';

  @override
  String get snSetupPending => 'Setting up your number';

  @override
  String get snRefresh => 'Refresh status';

  @override
  String get snManage => 'Manage number';

  @override
  String get snChooseCountry => 'Choose a country';

  @override
  String get snNoCoverage =>
      'Numbers are not available yet. US and UK coverage and prices are being validated.';

  @override
  String get snChooseNumber => 'Choose your number';

  @override
  String get snReview => 'Review your number';

  @override
  String get snNumberFee => 'Number fee';

  @override
  String get snServiceFee => 'KeepSIMs Service Fee';

  @override
  String get snSetupFee => 'Setup fee';

  @override
  String get snTotal => 'Total due today';

  @override
  String get snUsage => 'Usage terms';

  @override
  String get snActivate => 'Activate number';

  @override
  String get snPurchasePending =>
      'Your order is being confirmed. Funds are reserved. Check its status here; do not buy a replacement number.';

  @override
  String get snPurchaseFailed =>
      'The carrier could not complete this order. Your reserved funds were released.';

  @override
  String get snCopyNumber => 'Copy number';

  @override
  String get snOpenInbox => 'Open inbox';

  @override
  String get snMarkRead => 'Mark as read';

  @override
  String get snForwardSetup => 'Set up SIM call forwarding';

  @override
  String get snIdentity => 'Identity status';

  @override
  String get snUnverifiedSender => 'Sender identity not verified';

  @override
  String get snQuoteExpired => 'This quote expired. Refresh available numbers.';

  @override
  String get snCheckStatus => 'Check order status';

  @override
  String get snWalletBalance => 'Wallet balance';

  @override
  String get snPaidUntil => 'Paid until';

  @override
  String get snCancel => 'Cancel';

  @override
  String get snTopUp => 'Top up wallet';

  @override
  String get snNoStock =>
      'No eligible numbers are available. Try again or choose another country.';

  @override
  String get snMobile => 'Mobile';

  @override
  String get snLocal => 'Local';

  @override
  String get snCalls => 'Calls';

  @override
  String get snCodeCandidate => 'Code found in message';

  @override
  String get snRead => 'Read';

  @override
  String get snError =>
      'Second Number is temporarily unavailable. Please retry.';

  @override
  String snEveryDays(int days) {
    return 'Every $days days';
  }

  @override
  String get snRenewalReview =>
      'Renewal settings need review before automatic billing can begin.';
}
