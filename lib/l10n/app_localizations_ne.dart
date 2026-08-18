// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'प्राथमिकता & सुरक्षा';

  @override
  String get appAppearance => 'एपको रूपरेखा';

  @override
  String get systemTheme => 'प्रणाली';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get lightMode => 'लाइट मोड';

  @override
  String get localizationAndRegional => 'स्थानीयकरण & क्षेत्रीय';

  @override
  String get appLanguage => 'एपको भाषा';

  @override
  String currentlyUsing(String langName) {
    return 'हाल क्षेत्रीय $langName प्रयोग भइरहेको छ';
  }

  @override
  String get selectAppLanguage => 'एपको भाषा छान्नुहोस्';

  @override
  String get securityAndAccessLock => 'सुरक्षा & पहुँच लक';

  @override
  String get biometricSecurity => 'बायोमेट्रिक सुरक्षा';

  @override
  String get biometricDesc =>
      'Face ID वा Touch ID प्रयोग गरी साइन इन गर्नुहोस्';

  @override
  String get biometricReasonPayment =>
      'भुक्तानी पुष्टि गर्न प्रमाणीकरण गर्नुहोस्';

  @override
  String get biometricReasonUnlock => 'KeepSIMs अनलक गर्न प्रमाणीकरण गर्नुहोस्';

  @override
  String get biometricLockout =>
      'धेरै पटक असफल प्रयास भएकाले बायोमेट्रिक प्रमाणीकरण लक गरिएको छ। कृपया आफ्नो उपकरणको पासकोड प्रयोग गर्नुहोस्।';

  @override
  String get biometricNotEnrolled =>
      'यस उपकरणमा बायोमेट्रिक प्रमाणीकरण सेट गरिएको छैन।';

  @override
  String get biometricAppLockTitle => 'KeepSIMs लक छ';

  @override
  String get biometricUnlockButton => 'बायोमेट्रिक्सबाट अनलक गर्नुहोस्';

  @override
  String get biometricCancel => 'रद्द गर्नुहोस्';

  @override
  String get transactionPin => 'कारोबार PIN';

  @override
  String get transactionPinDesc => 'नवीकरण र निकासी सुरक्षित गर्नुहोस्';

  @override
  String get setup => 'सेटअप';

  @override
  String get pinSuccess => 'कारोबार PIN सफलतापूर्वक अपडेट भयो!';

  @override
  String get pinMismatch => 'PIN मेल खाएन। फेरि प्रयास गर्नुहोस्!';

  @override
  String get pinActiveAndSecure => 'PIN सेटअप सक्रिय र सुरक्षित छ';

  @override
  String get automatedSummaryAndAlerts => 'स्वचालित सारांश & सूचनाहरू';

  @override
  String get weeklyDigest => 'साप्ताहिक डाइजेस्ट';

  @override
  String get welcomeBack => 'फिर्ता स्वागत छ';

  @override
  String get nextNotify => 'अर्को सूचना';

  @override
  String get days => 'दिन';

  @override
  String get showingNearestLine => 'नजिकको लाइन देखाइँदैछ';

  @override
  String get addSim => 'SIM थप्नुहोस्';

  @override
  String get linesToProtect => 'सुरक्षित गर्ने लाइनहरू';

  @override
  String get active => 'सक्रिय';

  @override
  String get upgrade => 'अपग्रेड';

  @override
  String get standard => 'मानक';

  @override
  String get autoNotify => 'स्वत:-सूचना';

  @override
  String get configure => 'कन्फिगर गर्नुहोस्';

  @override
  String get autoRefill => 'स्वत:-रिफिल';

  @override
  String get quickActions => 'द्रुत कार्यहरू';

  @override
  String get navHome => 'गृहपृष्ठ';

  @override
  String get navSims => 'SIM हरू';

  @override
  String get navMore => 'थप';

  @override
  String get protectedSims => 'सुरक्षित SIM हरू';

  @override
  String get mySimCards => 'मेरा SIM कार्डहरू';

  @override
  String get familySharedSims => 'परिवार साझा SIM हरू';

  @override
  String get protectAnotherSimLine => 'अर्को SIM लाइन सुरक्षित गर्नुहोस्';

  @override
  String get keepInfiniteNumbersAlive =>
      'असीमित अन्तर्राष्ट्रिय नम्बरहरू सक्रिय राख्नुहोस्';

  @override
  String get bulkActionsConsole => 'बल्क कार्य कन्सोल';

  @override
  String get resume => 'पुनः सुरु गर्नुहोस्';

  @override
  String get pause => 'रोक्नुहोस्';

  @override
  String get simulate => 'सिमुलेट गर्नुहोस्';

  @override
  String get noProtectedLines => 'कुनै सुरक्षित लाइन छैन';

  @override
  String get noInternationalSimsAdded =>
      'तपाईंले अहिलेसम्म कुनै अन्तर्राष्ट्रिय SIM कार्ड थप्नुभएको छैन। यसलाई सधैंका लागि सक्रिय राख्न अहिले नै आफ्नो पहिलो कार्ड सुरक्षित गर्नुहोस्।';

  @override
  String get protectNewLine => 'नयाँ लाइन सुरक्षित गर्नुहोस्';

  @override
  String get noSharedSimsYet => 'अहिलेसम्म कुनै साझा SIM छैन';

  @override
  String get inviteFamilyMembers =>
      'आफ्ना परिवारका सदस्यहरूलाई घरायसी समूहमा सामेल हुन आमन्त्रण दिनुहोस्। उनीहरूले स्वीकार गरेपछि उनीहरूका सुरक्षित SIM लाइनहरू सहकारी अनुगमनका लागि यहाँ देखिनेछन्।';

  @override
  String get manageHousehold => 'घरायसी व्यवस्थापन गर्नुहोस्';

  @override
  String get manageProfileDesc =>
      'आफ्नो प्रोफाइल, SIM लाइन, सूचना र साझा प्राथमिकताहरू व्यवस्थापन गर्नुहोस्';

  @override
  String get keepSIMsUser => 'KeepSIMs प्रयोगकर्ता';

  @override
  String get pro => 'PRO';

  @override
  String get homeCountry => 'गृह देश: ';

  @override
  String get console => 'कन्सोल';

  @override
  String get offlineRefill => 'अफलाइन रिफिल (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'SMS वा WhatsApp मार्फत अफलाइनमा SIM ब्यालेन्स रिफिल गर्नुहोस्';

  @override
  String get wallet => 'वालेट';

  @override
  String get manageBalancesDesc =>
      'आफ्नो ब्यालेन्स व्यवस्थापन गर्नुहोस् र कारोबार इतिहास हेर्नुहोस्';

  @override
  String get alertPreferences => 'सूचना प्राथमिकताहरू';

  @override
  String get togglePushEmailDesc =>
      'नवीकरण/ब्यालेन्सका लागि पुश & इमेल सेटिङ टगल गर्नुहोस्';

  @override
  String get referAndEarn => 'रेफर गर्नुहोस् & कमाउनुहोस्';

  @override
  String get shareKeepSIMsDesc =>
      'KeepSIMs साझा गर्नुहोस्, गतिशील ब्यालेन्स पुरस्कारहरू अनलक गर्नुहोस्';

  @override
  String get paymentMethods => 'भुक्तानी तरिकाहरू';

  @override
  String get addBankCardsDesc =>
      'बैंक कार्डहरू थप्नुहोस् वा स्वत:-निकासी खाताहरू लिङ्क गर्नुहोस्';

  @override
  String get travelAndGeolocation => 'यात्रा & भू-स्थान';

  @override
  String get manageHomeCountryDesc =>
      'गृह देश फ्रिज नियम & ट्राभेल मोड व्यवस्थापन गर्नुहोस्';

  @override
  String get dataAndPrivacy => 'डेटा & गोपनीयता';

  @override
  String get manageTrackingConsentDesc =>
      'आफ्नो ट्र्याकिङ सहमति व्यवस्थापन गर्नुहोस्, डेटा निर्यात गर्नुहोस् वा खाता मेटाउनुहोस्';

  @override
  String get powerUser => 'पावर प्रयोगकर्ता';

  @override
  String get accessSystemSimulatorsDesc =>
      'प्रणाली सिमुलेटर र डिबगिङ उपकरणहरू पहुँच गर्नुहोस्';

  @override
  String get testChecklist => 'परीक्षण जाँचसूची';

  @override
  String get manualUiTestingDesc =>
      'गुणस्तर आश्वासनका लागि म्यानुअल UI परीक्षण जाँचसूची';

  @override
  String get soon => 'चाँडै';

  @override
  String featureComingSoon(String feature) {
    return '$feature सुविधा चाँडै आउँदैछ!';
  }

  @override
  String get logOut => 'लग आउट';

  @override
  String get confirmLogOut => 'के तपाईं KeepSIMs बाट लग आउट गर्न चाहनुहुन्छ?';

  @override
  String get walletLedger => 'वालेट लेजर';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs प्रिपेड';

  @override
  String get offlineMode => 'अफलाइन मोड';

  @override
  String get activeBalance => 'सक्रिय ब्यालेन्स';

  @override
  String get criticalBalanceLevel => 'गम्भीर ब्यालेन्स स्तर';

  @override
  String get balanceBelow10 =>
      'तपाईंको ब्यालेन्स \$10.00 भन्दा कम छ। निर्धारित SIM टपअपहरू चाँडै असफल हुन सक्छन्।';

  @override
  String get depositFunds => 'रकम जम्मा गर्नुहोस्';

  @override
  String get walletDepositsRequireInternet =>
      'वालेट जम्माका लागि सक्रिय इन्टरनेट जडान आवश्यक छ।';

  @override
  String get exportLedger => 'लेजर निर्यात गर्नुहोस्';

  @override
  String get ledgerHistoryExported => 'लेजर इतिहास CSV को रूपमा निर्यात भयो।';

  @override
  String get spendAnalysis => 'खर्च विश्लेषण';

  @override
  String get transactionHistory => 'कारोबार इतिहास';

  @override
  String itemsCount(int count) {
    return '$count वटा वस्तुहरू';
  }

  @override
  String get noTransactionsRecorded =>
      'अहिलेसम्म कुनै कारोबार रेकर्ड भएको छैन।';

  @override
  String get prepaidMonthlyOutflow => 'प्रिपेड मासिक खर्च';

  @override
  String avgMonthlySpend(String amount) {
    return 'औसत: \$$amount/महिना (१२ महिना)';
  }

  @override
  String depositViaCard(String last4) {
    return '$last4 मा समाप्त हुने कार्डमार्फत जम्मा';
  }

  @override
  String get lineRenewal => 'लाइन नवीकरण';

  @override
  String get justNow => 'भर्खर';

  @override
  String get loadCreditFunds => 'क्रेडिट रकम लोड गर्नुहोस्';

  @override
  String get depositAmountUsd => 'जम्मा रकम (USD)';

  @override
  String get pleaseEnterAmount => 'कृपया रकम प्रविष्ट गर्नुहोस्';

  @override
  String get enterPositiveNumber => 'धनात्मक संख्या प्रविष्ट गर्नुहोस्';

  @override
  String get cardDetails => 'कार्डको विवरण';

  @override
  String get savedCards => 'सुरक्षित कार्डहरू';

  @override
  String get visaCardNumber => 'Visa कार्ड नम्बर';

  @override
  String get pleaseEnterCardNumber => 'कृपया कार्ड नम्बर प्रविष्ट गर्नुहोस्';

  @override
  String get mustBe16Digits => '१६ अंक हुनुपर्छ';

  @override
  String get expiryMmYy => 'म्याद (MM/YY)';

  @override
  String get expiryRequired => 'म्याद आवश्यक छ';

  @override
  String get invalid => 'अमान्य';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV आवश्यक छ';

  @override
  String get verifyingCardSecurity => 'कार्ड सुरक्षा प्रमाणित गर्दैछ...';

  @override
  String get authorizeDepositFunds => 'जम्मा रकम अधिकृत गर्नुहोस्';

  @override
  String successfullyDeposited(String amount) {
    return '\$$amount USD सफलतापूर्वक जम्मा भयो!';
  }

  @override
  String get failedToDepositFunds =>
      'रकम जम्मा गर्न असफल भयो। कार्ड जडान जाँच गर्नुहोस्।';

  @override
  String get noSavedPaymentMethods => 'कुनै सुरक्षित भुक्तानी तरिका फेला परेन।';

  @override
  String get addPaymentMethod => 'भुक्तानी तरिका थप्नुहोस्';

  @override
  String get savedPaymentMethods => 'सुरक्षित भुक्तानी तरिकाहरू';

  @override
  String get addAnotherPaymentMethod => 'अर्को भुक्तानी तरिका थप्नुहोस्';

  @override
  String expiresMmYy(String month, String year) {
    return 'म्याद समाप्त $month/$year';
  }

  @override
  String get offlineRefillTitle => 'अफलाइन रिफिल (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'लक्षित SIM लाइन छान्नुहोस्';

  @override
  String get noRegisteredSimLines => 'कुनै दर्ता भएको SIM लाइन फेला परेन।';

  @override
  String get targetSimLine => 'लक्षित SIM लाइन';

  @override
  String get simLine => 'SIM लाइन';

  @override
  String get carrier => 'क्यारियर';

  @override
  String get change => 'परिवर्तन गर्नुहोस्';

  @override
  String get offlineRefillProtection => 'अफलाइन रिफिल सुरक्षा';

  @override
  String get premiumExclusive => 'प्रिमियम एक्सक्लुसिभ';

  @override
  String get neverGetStrandedDesc =>
      'मोबाइल डेटा बिना फसिनुपर्ने स्थिति कहिल्यै नहोस्। KeepSIMs Premium ले इन्टरनेट जडान नभएको बेला स्थानीय SMS वा WhatsApp सन्देशमार्फत अफलाइनमा SIM कार्ड ब्यालेन्स रिफिल गर्न दिन्छ।';

  @override
  String get offlineCapability100 => '१००% अफलाइन क्षमता';

  @override
  String get deductsFromKeepSIMsDesc =>
      'स्थानीय SMS गेटवे फेलओभरमार्फत तपाईंको SIM लाइनमा क्रेडिट गर्न KeepSIMs वालेटबाट काटिन्छ।';

  @override
  String get dynamicUssdPlanActivation => 'गतिशील USSD योजना सक्रियकरण';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'अफलाइनमा डेटा+कल प्याकेज सक्रिय गर्न सटीक कपी-पेस्ट डायल कोडहरू (जस्तै *900*1#) प्रदान गर्दछ।';

  @override
  String get dualChannelSupport => 'दोहोरो-च्यानल समर्थन';

  @override
  String get textRefillDesc =>
      'उपलब्ध सेलुलर कभरेजका आधारमा मानक SMS वा WhatsApp प्रयोग गरी \\\"REFILL\\\" टेक्स्ट गर्नुहोस्।';

  @override
  String get close => 'बन्द गर्नुहोस्';

  @override
  String get howToTriggerOfflineRefill => 'अफलाइन रिफिल कसरी ट्रिगर गर्ने';

  @override
  String get ifZeroMobileDataDesc1 =>
      'यदि तपाईंको मोबाइल डेटा शून्य छ भने, मात्र ';

  @override
  String get refill => 'रिफिल';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' हाम्रो सुरक्षित प्रणाली गेटवेमा पठाउनुहोस्:';

  @override
  String get targetSimLineLabel => 'लक्षित SIM लाइन';

  @override
  String get configureCashRefillAmount => 'नगद रिफिल रकम कन्फिगर गर्नुहोस्';

  @override
  String get refillAmount => 'रिफिल रकम';

  @override
  String walletBalanceUsd(String amount) {
    return 'वालेट ब्यालेन्स: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ कम ब्यालेन्स';

  @override
  String get localCarrierPlanSuggestions => 'स्थानीय क्यारियर योजना सुझावहरू';

  @override
  String get noStandardUssdDialCodes =>
      'यस क्यारियरका लागि कुनै मानक USSD डायल कोड फेला परेन। तपाईंको लाइनमा नगद रिफिल सफलतापूर्वक प्राप्त हुनेछ।';

  @override
  String get dynamicDialCodesPreview => 'गतिशील डायल कोड पूर्वावलोकन';

  @override
  String get botSuggestDialingCodes =>
      'अफलाइन रिफिल पूरा भएपछि, बटले अफलाइनमा डेटा+कल तत्काल अनलक गर्न तपाईंको फोनमा यी सटीक कोडहरू डायल गर्न सुझाव दिनेछ:';

  @override
  String costAmount(String amount) {
    return 'लागत: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'WHATSAPP/SMS प्रेषक ओभरराइड';

  @override
  String get verificationNumber => 'प्रमाणीकरण नम्बर';

  @override
  String get triggerRefillsDifferentNumber =>
      'यदि तपाईं आफ्नो मुख्य प्रोफाइल फोन बाहेक फरक नम्बरबाट रिफिल ट्रिगर गर्नुहुन्छ भने, देशको कोडसहित तल प्रविष्ट गर्नुहोस् (जस्तै 96891234567)।';

  @override
  String get enterPhoneNumberDigits =>
      'फोन नम्बर प्रविष्ट गर्नुहोस् (अंकहरू मात्र)';

  @override
  String get offlineRefillSettingsSaved =>
      'अफलाइन रिफिल सेटिङहरू सफलतापूर्वक सुरक्षित भयो!';

  @override
  String get saveSettings => 'सेटिङहरू सुरक्षित गर्नुहोस्';

  @override
  String errorLoadingSettings(String error) {
    return 'सेटिङहरू लोड गर्दा त्रुटि: $error';
  }

  @override
  String get retry => 'पुनः प्रयास गर्नुहोस्';

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
  String get offlineRefillChannelsHeader => 'अफलाइन रिफिलका तरिका';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'आफ्नो वालेटबाट $amount टप अप गर्नुहोस्';
  }

  @override
  String get offlineRefillWalletFunded => 'तपाईंको वालेटबाट';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee शुल्क';
  }

  @override
  String get offlineRefillMissedCallTitle => 'मिस्ड कल दिनुहोस्';

  @override
  String get offlineRefillMissedCallSubtitle => 'ब्यालेन्स वा डेटा आवश्यक छैन';

  @override
  String get offlineRefillCallAction => 'रिफिल गर्न कल गर्नुहोस्';

  @override
  String get offlineRefillRetry => 'फेरि प्रयास गर्नुहोस्';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return '$secondsसे पर्खनुहोस्';
  }

  @override
  String get offlineRefillStatusSent => 'पठाइयो — पुष्टिको प्रतीक्षामा';

  @override
  String get offlineRefillStatusProcessing => 'तपाईंको लाइन टप अप हुँदैछ…';

  @override
  String get offlineRefillStatusConfirmed => 'टप-अप पुष्टि भयो';

  @override
  String get offlineRefillStatusFailed =>
      'सफल भएन — अर्को तरिका प्रयास गर्नुहोस्';

  @override
  String get offlineRefillStatusTimedOut =>
      'अझै कुनै जवाफ छैन — अर्को तरिका प्रयास गर्नुहोस्';

  @override
  String get offlineRefillUssdTitle => 'आफ्नो टप-अपबाट धेरै लाभ लिनुहोस्';

  @override
  String get offlineRefillUssdSubtitle =>
      'ब्यालेन्स आएपछि, उत्तम मूल्यको लागि आफ्नो अपरेटरको कोड डायल गर्नुहोस्';

  @override
  String get offlineRefillUssdDial => 'डायल गर्नुहोस्';

  @override
  String get editProtectedLine => 'सुरक्षित लाइन सम्पादन गर्नुहोस्';

  @override
  String get saveChanges => 'परिवर्तनहरू सुरक्षित गर्नुहोस्';

  @override
  String get activateShieldProtection => 'शिल्ड सुरक्षा सक्रिय गर्नुहोस्';

  @override
  String get phoneNumber => 'फोन नम्बर';

  @override
  String get nicknameOptional => 'उपनाम (ऐच्छिक)';

  @override
  String get whatsappAlerts => 'WhatsApp सूचनाहरू';

  @override
  String get emailAlertsDesc =>
      'Resend मार्फत पठाइएको गम्भीर निष्क्रियकरण सूचनाहरू';

  @override
  String get refillWalletLow => 'रकम कम भएमा वालेट रिफिल गर्नुहोस्';

  @override
  String get legalPoliciesDesc =>
      'KeepSIMs प्रयोग गरेर तपाईं हाम्रा सर्तहरूमा सहमत हुनुहुन्छ। KeepSIMs ले तपाईंको SIM जीवनचक्र व्यवस्थापन गर्न मद्दत गर्ने उपकरणहरू प्रदान गर्दछ, तर तेस्रो पक्षका दूरसञ्चार प्रदायकहरूका कारण प्रत्यक्ष वा अप्रत्यक्ष हानि, क्षति वा सेवा अवरोधका लागि हामी जिम्मेवार छैनौं।';

  @override
  String get globalTravelModeDesc =>
      'स्वचालित जियोफेन्सिङ नियमहरूले सिमाना-पार दिनचर्या सक्रिय गर्न अनुमति दिन्छ';

  @override
  String get dataPreferences => 'डेटा प्राथमिकताहरू';

  @override
  String get doNotDisturb => 'बाधा नगर्नुहोस्';

  @override
  String get linkedCards => 'लिङ्क गरिएका कार्डहरू';

  @override
  String get analyticsTracking => 'विश्लेषण & ट्र्याकिङ';

  @override
  String get dubai => 'दुबई';

  @override
  String get flyHome => 'घर उड्नुहोस्';

  @override
  String get managePreferencesAndSecurityDesc =>
      'थिम, भाषा र बायोमेट्रिक लकआउट व्यवस्थापन गर्नुहोस्';

  @override
  String get autoFundingRulesDesc =>
      'ब्यालेन्स धेरै कम भएमा पूर्वनिर्धारित क्रेडिट कार्डबाट स्वचालित टपअप सक्षम गरेर SIM नवीकरण निरन्तर चलाउनुहोस्';

  @override
  String get pushNotifications => 'पुश सूचनाहरू';

  @override
  String get quietHoursSchedule => 'शान्त समय & तालिका';

  @override
  String get exportMyDataDesc =>
      'आफ्नो प्रोफाइल र प्राथमिकताहरूको JSON प्रतिलिपि डाउनलोड गर्नुहोस् (GDPR पहुँच अधिकार)';

  @override
  String get borderSimulatorTitle => 'सिमाना पार सिमुलेटर';

  @override
  String get yourData => 'तपाईंको डेटा';

  @override
  String get mostImportant => 'सबैभन्दा महत्त्वपूर्ण';

  @override
  String get emailAlerts => 'इमेल सूचनाहरू';

  @override
  String get pushNotificationsDesc => 'यस यन्त्रमा आक्रामक नेटिभ सूचनाहरू';

  @override
  String get alertSettingsTitle => 'सूचना सेटिङहरू';

  @override
  String get atHome => 'घरमा';

  @override
  String get telegramBotDesc =>
      'बाँधिएको अन्तरक्रियात्मक Telegram च्याट सूचनाहरू';

  @override
  String get alertChannels => 'सूचना च्यानलहरू';

  @override
  String get london => 'लन्डन';

  @override
  String get shieldProtection => 'शिल्ड सुरक्षा';

  @override
  String get legalPolicies => 'कानुनी & नीतिहरू';

  @override
  String get supportVisaMastercard =>
      'सुरक्षित Visa & MasterCard डेबिट वा क्रेडिट समर्थन गर्दछ';

  @override
  String get exportMyData => 'मेरो डेटा निर्यात गर्नुहोस्';

  @override
  String get dangerZone => 'खतरा क्षेत्र';

  @override
  String get analyticsTrackingDesc =>
      'अज्ञात प्रयोग डेटा साझा गरेर एप सुधार गर्न मद्दत गर्नुहोस्। अक्षम गरे आवश्यक एप कार्यक्षमता प्रभावित हुनेछैन';

  @override
  String get autoFundingRules => 'स्वत:-कोष नियमहरू';

  @override
  String get singapore => 'सिंगापुर';

  @override
  String get weeklySummaryDigest => 'साप्ताहिक सारांश डाइजेस्ट';

  @override
  String get fullyShielded => 'पूर्णरूपमा सुरक्षित';

  @override
  String get dndDesc => 'निर्दिष्ट निद्रा समयमा पुश सूचनाहरू म्युट गर्नुहोस्';

  @override
  String get paymentsAutoFundTitle => 'भुक्तानी & स्वत:-कोष';

  @override
  String get travelGeolocationTitle => 'यात्रा & भू-स्थान';

  @override
  String get telegramBot => 'Telegram बट';

  @override
  String get weeklyDigestDesc =>
      'हरेक आइतबार बिहान ९:०० बजे सबै SIM कार्डहरूको संकलित स्थिति रिपोर्ट';

  @override
  String get borderSimulatorDesc =>
      'स्मार्ट फ्रिज वा सक्रिय देश पुनरारम्भ नियमहरू ट्रिगर गर्न बोर्डिङ सिमुलेट गर्नुहोस्।';

  @override
  String get linkFirstCard => 'आफ्नो पहिलो भुक्तानी कार्ड लिङ्क गर्नुहोस्';

  @override
  String get globalTravelMode => 'ग्लोबल ट्राभेल मोड';

  @override
  String get readPrivacyPolicy => 'पूर्ण गोपनीयता नीति & सर्तहरू पढ्नुहोस्';

  @override
  String get whatsappAlertsDesc =>
      'सिधै WhatsApp मा पठाइएको रिफिल असफलता सूचनाहरू';

  @override
  String get abroadTraveling => 'विदेश / यात्रामा';

  @override
  String get freezeAllLines => 'सबै लाइनहरू फ्रिज गर्नुहोस्';

  @override
  String get resumeRenewals => 'नवीकरणहरू पुनः सुरु गर्नुहोस्';

  @override
  String get freezeRecommendationDesc =>
      'हामीले पत्ता लगायौं कि तपाईं हाल आफ्नो गृह देशमा हुनुहुन्छ। अनावश्यक वालेट ब्यालेन्स घटाउनबाट रोक्न तपाईं आफ्नो अन्तर्राष्ट्रिय लाइनहरूमा नवीकरण फ्रिज गर्न सक्नुहुन्छ।';

  @override
  String get travelDetected => 'यात्रा पत्ता लाग्यो! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'तपाईं विदेशमा यात्रा गर्दै हुनुहुन्छ। निर्बाध मोबाइल नेटवर्क कभरेज सुनिश्चित गर्न आफ्नो रोकिएका अन्तर्राष्ट्रिय SIM नवीकरणहरू पुनः सुरु गर्नुहोस्।';

  @override
  String get dismiss => 'खारेज गर्नुहोस्';

  @override
  String get welcomeHome => 'घरमा स्वागत छ! 🏡';

  @override
  String get addCard => 'कार्ड थप्नुहोस्';

  @override
  String get noAlertChannelsConfigured =>
      'कुनै सूचना वितरण च्यानल कन्फिगर गरिएको छैन।';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName सेटिङहरू अपडेट भयो।';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName लक भयो 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName सूचनाहरू स्टार्टर र प्रिमियम योजनाका सुविधाहरू हुन्। WhatsApp, Telegram र इमेल सूचनाहरू अनलक गर्न आफ्नो योजना अपग्रेड गर्नुहोस्!';
  }

  @override
  String get upsellProtect5Lines =>
      'एकैसाथ ५ वटासम्म SIM लाइनहरू सुरक्षित गर्नुहोस्';

  @override
  String get upsellUnlockChannels =>
      'WhatsApp, Telegram & इमेल सूचनाहरू अनलक गर्नुहोस्';

  @override
  String get upsellEnableTravelModes =>
      'यात्रा & गृह स्वचालित वैधता मोडहरू सक्षम गर्नुहोस्';

  @override
  String get emailAddressLabel => 'सूचना इमेल ठेगाना';

  @override
  String get emailAddressHint => 'जस्तै user@domain.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp नम्बर (अन्तर्राष्ट्रिय ढाँचा)';

  @override
  String get whatsappNumberHint => 'जस्तै +96891234567';

  @override
  String get whatsappFormatInstruction =>
      '+ बाट सुरु हुने पूर्ण अन्तर्राष्ट्रिय ढाँचामा प्रविष्ट गर्नुहोस् (जस्तै +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'स्थिति: बाँधिएको (च्याट आइडी: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'स्थिति: नबाँधिएको';

  @override
  String get telegramLinkInstructions =>
      'निःशुल्क, अन्तरक्रियात्मक Telegram सूचनाहरू पाउन हाम्रो Telegram बटलाई आफ्नो खातासँग लिङ्क गर्नुहोस्।';

  @override
  String get linkTelegramBot => 'Telegram बट लिङ्क गर्नुहोस्';

  @override
  String get emailFreePlanGuarded =>
      'Resend निःशुल्क योजना सुरक्षित: निष्क्रियकरण ट्रिगरमा मात्र सीमित। कुनै प्रचारात्मक स्प्याम छैन।';

  @override
  String get whatsappMetaCloudCapped =>
      'प्रत्यक्ष Meta क्लाउड सीमित: प्रति टपअप तालिकामा अधिकतम १ सन्देश, केवल यदि स्वत:-रिफिल सक्रिय छैन वा असफल भएमा।';

  @override
  String get failedToLoadPaymentInfo => 'भुक्तानी जानकारी लोड गर्न असफल भयो';

  @override
  String get defaultCardIndicator => 'पूर्वनिर्धारित';

  @override
  String get cardholder => 'कार्डधारक';

  @override
  String get expires => 'म्याद समाप्त';

  @override
  String get lowBalanceTrigger => 'कम ब्यालेन्स ट्रिगर';

  @override
  String get triggerLowTopUp => 'कम टपअप ट्रिगर गर्नुहोस्';

  @override
  String get reloadDepositAmount => 'पुनः लोड जम्मा रकम';

  @override
  String get amountToLoad => 'लोड गर्ने रकम';

  @override
  String get linkCreditDebitCard => 'क्रेडिट/डेबिट कार्ड लिङ्क गर्नुहोस्';

  @override
  String get cardNumberLabel => 'कार्ड नम्बर';

  @override
  String get expiryDateLabel => 'म्याद समाप्ति मिति';

  @override
  String get cvvCodeLabel => 'CVV कोड';

  @override
  String get securelyLinkCard => 'सुरक्षित रूपमा कार्ड लिङ्क गर्नुहोस्';

  @override
  String get pleaseEnterValidCardNumber =>
      'कृपया वैध १६-अंकको कार्ड नम्बर प्रविष्ट गर्नुहोस्।';

  @override
  String get pleaseEnterValidExpiryDate =>
      'कृपया वैध म्याद समाप्ति मिति (MM/YY) प्रविष्ट गर्नुहोस्।';

  @override
  String get invalidExpiryMonth => 'अमान्य म्याद समाप्ति महिना।';

  @override
  String get cvvMustBe3Digits => 'CVV ३ अंकको हुनुपर्छ।';

  @override
  String get cardLinkedSuccessfully =>
      'सुरक्षित बिलिङ कार्ड सफलतापूर्वक लिङ्क भयो!';

  @override
  String get defaultPaymentCardUpdated =>
      'पूर्वनिर्धारित भुक्तानी कार्ड अपडेट भयो!';

  @override
  String get removePaymentCard => 'भुक्तानी कार्ड हटाउनुहोस्';

  @override
  String get confirmRemoveCardDesc =>
      'के तपाईं यो कार्ड हटाउन चाहनुहुन्छ? कुनै पूर्वनिर्धारित भुक्तानी कार्ड नभएमा लिङ्क गरिएको स्वत:-कोष असफल हुन सक्छ।';

  @override
  String get cancel => 'रद्द गर्नुहोस्';

  @override
  String get remove => 'हटाउनुहोस्';

  @override
  String get billingCardSuccessfullyRemoved =>
      'बिलिङ कार्ड सफलतापूर्वक हटाइयो।';

  @override
  String get pleaseAddDefaultCardFirst =>
      'स्वत:-कोष सक्षम गर्न पहिले पूर्वनिर्धारित भुक्तानी कार्ड थप्नुहोस् र चयन गर्नुहोस्।';

  @override
  String get autoFundPrefsSavedSuccess =>
      'स्वत:-कोष प्राथमिकताहरू सफलतापूर्वक सुरक्षित भयो!';

  @override
  String get preparingDataExport => 'डेटा निर्यात तयार गर्दैछ...';

  @override
  String exportFailed(String error) {
    return 'निर्यात असफल भयो: $error';
  }

  @override
  String get deleteAccountWarning =>
      'एकपटक तपाईंको खाता मेटाएपछि फिर्ता हुने उपाय छैन। कृपया निश्चित हुनुहोस्।';

  @override
  String get deleteAccount => 'खाता मेटाउनुहोस्';

  @override
  String get deleteAccountIrreversible =>
      'यो कार्य अपरिवर्तनीय छ। तपाईंको सबै डेटा स्थायी रूपमा मेटिनेछ।';

  @override
  String get typeDeleteToConfirm =>
      'पुष्टि गर्न \\\"DELETE\\\" टाइप गर्नुहोस्:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'प्रणाली निदान लगहरू';

  @override
  String get online => 'अनलाइन';

  @override
  String errorLoadingPrefs(String error) {
    return 'प्राथमिकताहरू लोड गर्दा त्रुटि: $error';
  }

  @override
  String get privacyPolicyLoaded => 'गोपनीयता नीतिको विवरण लोड भयो।';

  @override
  String get protectionConsole => 'सुरक्षा कन्सोल';

  @override
  String get deleteProtectionTooltip => 'सुरक्षा मेटाउनुहोस्';

  @override
  String get refreshTooltip => 'रिफ्रेस गर्नुहोस्';

  @override
  String get failedToLoadDetails => 'विवरण लोड गर्न असफल भयो';

  @override
  String get retryConnection => 'जडान पुनः प्रयास गर्नुहोस्';

  @override
  String get healthLabel => 'स्वास्थ्य';

  @override
  String get mySimCardDefault => 'मेरो SIM कार्ड';

  @override
  String get upLabel => 'माथि';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'साझा गरेको: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'गम्भीर जोखिम';

  @override
  String get simDeactivationRisk => 'कारबाही नगरे SIM निष्क्रिय हुन सक्छ';

  @override
  String get missingAlertsDesc =>
      'कुनै सूचना बिज्ञप्ति कन्फिगर गरिएको छैन — १०० अंक गुम';

  @override
  String get missingAutoRefillDesc =>
      'कुनै स्वत:-रिफिल कन्फिगर गरिएको छैन — ५० अंक गुम';

  @override
  String get missingVerificationDesc =>
      'फोन नम्बर प्रमाणित गरिएको छैन — २५ अंक गुम';

  @override
  String get missingRecentRefillDesc =>
      'अन्तिम रिफिल ८० दिनभन्दा बढी अगाडि — २५ अंक गुम';

  @override
  String get quickActionsLabel => 'द्रुत कार्यहरू';

  @override
  String get manualRefillLabel => 'म्यानुअल रिफिल';

  @override
  String get chargeFromWalletNow => 'अहिले नै वालेटबाट चार्ज गर्नुहोस्';

  @override
  String get rechargeFromFriend => 'साथीबाट रिचार्ज गर्नुहोस्';

  @override
  String get requestViaTelegram => 'Telegram मार्फत अनुरोध गर्नुहोस्';

  @override
  String get shareViaWaTg => 'WhatsApp/Telegram मार्फत साझा गर्नुहोस्';

  @override
  String get testSimActivity => 'SIM गतिविधि परीक्षण गर्नुहोस्';

  @override
  String get verifyLineReachable =>
      'लाइन पहुँचयोग्य छ कि छैन प्रमाणित गर्नुहोस्';

  @override
  String get checkCompleted1x => '१x जाँच पूरा भयो';

  @override
  String get starterPlan1xCompleted =>
      'स्टार्टर योजना १x जाँच पूरा भयो। असीमित जाँचका लागि प्रिमियममा अपग्रेड गर्नुहोस्।';

  @override
  String leaveCountry(String countryName) {
    return '$countryName छोड्नुहोस्';
  }

  @override
  String get resumeProtectionLayers => 'सुरक्षा तहहरू पुनः सुरु गर्नुहोस्';

  @override
  String backToCountryMode(String countryName) {
    return '$countryName मोडमा फर्कनुहोस्';
  }

  @override
  String get pauseWhileVisitingHome => 'घर भ्रमण गर्दा रोक्नुहोस्';

  @override
  String get rechargeFromFriendTitle => 'साथीबाट रिचार्ज गर्नुहोस्';

  @override
  String get selectPlatformShare =>
      'आफ्नो साथीसँग रिचार्ज अनुरोध सन्देश साझा गर्न प्लेटफर्म छान्नुहोस्।';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'नमस्ते! मेरो KeepSIMs कार्ड ($phone) को म्याद चाँडै समाप्त हुँदैछ। के तपाईं कृपया यसलाई रिचार्ज गर्न सक्नुहुन्छ? धन्यवाद!';
  }

  @override
  String get requestViaWhatsApp => 'WhatsApp मार्फत अनुरोध गर्नुहोस्';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return '$platformName लिङ्क सुरु गर्न सकिएन: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Telegram लिङ्क सुरु गर्न सकिएन: $error';
  }

  @override
  String get protectionLayersLabel => 'सुरक्षा तहहरू';

  @override
  String get autoNotifyDisabled => 'स्वत:-सूचना: अक्षम';

  @override
  String get noActiveAlertSchedule =>
      'तपाईंको SIM कार्डमा कुनै सक्रिय सूचना तालिका छैन। तपाईंले स्वचालित स्मरणपत्र वा निष्क्रियकरण सूचनाहरू पाउनुहुनेछैन।';

  @override
  String get askOwnerConfigureAlerts =>
      'सूचनाहरू कन्फिगर गर्न घरायसी मालिकलाई अनुरोध गर्नुहोस्।';

  @override
  String get configureAutoNotify => 'स्वत:-सूचना कन्फिगर गर्नुहोस्';

  @override
  String get activeLabel => 'सक्रिय';

  @override
  String get pausedHomeMode => 'रोकिएको (गृह मोड)';

  @override
  String get pausedLabel => 'रोकिएको';

  @override
  String get everyHour => 'हरेक १ घण्टामा';

  @override
  String everyNDays(int days) {
    return 'हरेक $days दिनमा';
  }

  @override
  String get nextAlertCheck => 'अर्को सूचना जाँच';

  @override
  String get premiumKeepAliveRefill => 'प्रिमियम किप-अलाइभ रिफिल';

  @override
  String autoRefillIncludedText(String date) {
    return 'स्वत:-रिफिल समावेश - हरेक ८५ दिनमा ~३.५ USD (टेलिकम, VAT समावेश),\\\\nअर्को रिफिल $date मा';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'प्रिमियम किप-अलाइभ रिफिल हाल अक्षम छ।';

  @override
  String get customAutoRefill => 'कस्टम स्वत:-रिफिल';

  @override
  String get addAdditionalScheduledRecharge =>
      'आफ्नो SIM मा अतिरिक्त ब्यालेन्स राख्न थप निर्धारित रिचार्ज रकम थप्नुहोस्।';

  @override
  String get askOwnerConfigureRefill =>
      'स्वत:-रिफिल कन्फिगर गर्न घरायसी मालिकलाई अनुरोध गर्नुहोस्।';

  @override
  String get configureCustomAutoRefill => 'कस्टम स्वत:-रिफिल कन्फिगर गर्नुहोस्';

  @override
  String get rechargeAmount => 'रिचार्ज रकम';

  @override
  String get refillInterval => 'रिफिल अन्तराल';

  @override
  String get nextRefillDue => 'अर्को रिफिल बाँकी';

  @override
  String get failedRefillAttempts => 'असफल रिफिल प्रयासहरू';

  @override
  String retriesCount(int count) {
    return '$count / ४ पुनः प्रयासहरू';
  }

  @override
  String get editRefillAmount => 'रिफिल रकम सम्पादन गर्नुहोस्';

  @override
  String get refillExecutionsHistory => 'रिफिल कार्यान्वयन इतिहास';

  @override
  String get renewalExecutionsHistory => 'नवीकरण कार्यान्वयन इतिहास';

  @override
  String get noHistoricalTopup =>
      'यस लाइनका लागि अहिलेसम्म कुनै ऐतिहासिक टपअप कार्यान्वयन रेकर्ड भएको छैन।';

  @override
  String get noHistoricalRenewal =>
      'यस लाइनका लागि अहिलेसम्म कुनै ऐतिहासिक नवीकरण कार्यान्वयन रेकर्ड भएको छैन।';

  @override
  String get viewAllHistory => 'सम्पूर्ण इतिहास हेर्नुहोस्';

  @override
  String get securityActivityLogs => 'सुरक्षा गतिविधि लगहरू';

  @override
  String get clearLogs => 'लगहरू खाली गर्नुहोस्';

  @override
  String get noActivityLogsRecorded =>
      'यस लाइनका लागि अहिलेसम्म कुनै गतिविधि लग रेकर्ड भएको छैन।';

  @override
  String get activityLogDeleted => 'गतिविधि लग प्रविष्टि मेटाइयो।';

  @override
  String get activityLogsCleared => 'गतिविधि लगहरू सफलतापूर्वक खाली भयो।';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'स्वत:-नवीकरण सफलतापूर्वक $status भयो।';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'तालिका अपडेट गर्न असफल भयो: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'प्रिमियम किप-अलाइभ रिफिल सफलतापूर्वक सक्षम भयो।';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'स्वत:-रिफिल सक्षम गर्न असफल भयो: $error';
  }

  @override
  String get removeScheduleTitle => 'तालिका हटाउनुहोस्';

  @override
  String get confirmDeleteAutoRefill =>
      'के तपाईं यो स्वत:-रिफिल तालिका मेटाउन चाहनुहुन्छ? तपाईंको SIM स्वास्थ्य स्कोर उल्लेखनीय रूपमा घट्नेछ, निष्क्रियकरणको जोखिम रहनेछ।';

  @override
  String get confirmDeleteAutoRenewal =>
      'के तपाईं यो स्वत:-नवीकरण तालिका मेटाउन चाहनुहुन्छ? तपाईंको SIM स्वास्थ्य स्कोर उल्लेखनीय रूपमा घट्नेछ, निष्क्रियकरणको जोखिम रहनेछ।';

  @override
  String get autoRefillRemoved => 'स्वत:-रिफिल तालिका सफलतापूर्वक हटाइयो।';

  @override
  String get autoRenewalRemoved => 'स्वत:-नवीकरण तालिका सफलतापूर्वक हटाइयो।';

  @override
  String failedToDeleteSchedule(String error) {
    return 'तालिका मेटाउन असफल भयो: $error';
  }

  @override
  String get refillRetrySuccess => 'रिफिल पुनः प्रयास सफलतापूर्वक पूरा भयो!';

  @override
  String get refillRetryQueued =>
      'पुनः प्रयास लाइनमा राखियो — रिफिल प्रशोधन हुँदैछ।';

  @override
  String get renewalRetrySuccess => 'नवीकरण पुनः प्रयास सफलतापूर्वक पूरा भयो!';

  @override
  String retryFailed(String error) {
    return 'पुनः प्रयास असफल भयो: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'पुनः प्रयास कार्यान्वयन त्रुटि: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'गतिविधि लग मेटाउन असफल भयो: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'गतिविधि लगहरू खाली गर्न असफल भयो: $error';
  }

  @override
  String get removeProtectionTitle => 'सुरक्षा हटाउनुहोस्';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'के तपाईं $name लाई सुरक्षित राख्न बन्द गर्न चाहनुहुन्छ? यस SIM लाइनका निर्धारित टपअपहरू स्थायी रूपमा रद्द हुनेछन्।';
  }

  @override
  String get simLineProtectionRemoved => 'SIM लाइन सुरक्षा सफलतापूर्वक हटाइयो।';

  @override
  String failedToDeleteSimLine(String error) {
    return 'मेटाउन असफल भयो: $error';
  }

  @override
  String get editSimNameTitle => 'SIM नाम सम्पादन गर्नुहोस्';

  @override
  String get enterNicknameInstruction =>
      'यस SIM कार्ड लाइनका लागि उपनाम प्रविष्ट गर्नुहोस्:';

  @override
  String get nicknameExampleHint => 'जस्तै मेरो अरेन्ज इजिप्ट SIM';

  @override
  String get simNameUpdatedSuccess => 'SIM नाम सफलतापूर्वक अपडेट भयो।';

  @override
  String failedToUpdateSimName(String error) {
    return 'SIM नाम अपडेट गर्न असफल भयो: $error';
  }

  @override
  String get saveButton => 'सुरक्षित गर्नुहोस्';

  @override
  String get deleteButton => 'मेटाउनुहोस्';

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
  String get autoNotifySchedule => 'स्वत:-सूचना तालिका';

  @override
  String get renewalCheckInterval => 'नवीकरण जाँच अन्तराल';

  @override
  String get editNotificationConfig => 'सूचना कन्फिग सम्पादन गर्नुहोस्';

  @override
  String get openTicket => 'टिकट खोल्नुहोस्';

  @override
  String get offlineRefillLabel => 'अफलाइन रिफिल';

  @override
  String get categoryLabel => 'श्रेणी';

  @override
  String get techSupportCategory => 'प्राविधिक सहायता';

  @override
  String get billingWalletCategory => 'बिलिङ & वालेट';

  @override
  String get simLinesCategory => 'SIM लाइन व्यवस्थापन';

  @override
  String get feedbackOtherCategory => 'प्रतिक्रिया & अन्य';

  @override
  String get subjectLabel => 'विषय';

  @override
  String get subjectHint => 'समस्याको संक्षिप्त सारांश';

  @override
  String get descriptionLabel => 'विवरण';

  @override
  String get descriptionHint => 'आफ्नो समस्या विस्तारमा वर्णन गर्नुहोस्...';

  @override
  String get attachmentLabel => 'संलग्नक (ऐच्छिक)';

  @override
  String get uploadScreenshot => 'स्क्रिनसट अपलोड गर्नुहोस्';

  @override
  String get submitTicketButton => 'टिकट पेश गर्नुहोस्';

  @override
  String get pleaseFillFields => 'कृपया विषय र विवरण दुवै भर्नुहोस्';

  @override
  String get ticketSubmittedSuccess => 'टिकट सफलतापूर्वक पेश भयो!';

  @override
  String get lastRefillLabel => 'अन्तिम रिफिल';

  @override
  String get noRefillYet => 'अहिलेसम्म रिफिल छैन';

  @override
  String get nextAlertLabel => 'अर्को सूचना';

  @override
  String get protectionLabel => 'सुरक्षा';

  @override
  String get actionRequiredLabel => 'कारबाही आवश्यक';

  @override
  String get protectionOffLabel => 'सुरक्षा बन्द';

  @override
  String get notSet => 'सेट गरिएको छैन';

  @override
  String get homeMode => 'गृह मोड';

  @override
  String get keepProtectedAtHome => 'घरमा पनि सुरक्षा जारी राख्नुहोस्';

  @override
  String get protectionPausesAtHome => 'घरमा सुरक्षा रोकिन्छ';

  @override
  String get incidentChannelsTitle => 'घटना च्यानलहरू';

  @override
  String get topUpSuccessTitle => 'टपअप सफल';

  @override
  String get topUpSuccessDesc =>
      'स्वचालित SIM वैधता विस्तार सफलतापूर्वक पूरा भएमा मलाई सूचित गर्नुहोस्।';

  @override
  String get topUpFailedTitle => 'टपअप असफल (गम्भीर)';

  @override
  String get topUpFailedDesc =>
      'क्यारियर वा वालेट समस्याका कारण स्वचालित टपअप असफल भएमा गम्भीर सूचनाहरू।';

  @override
  String get walletLowTitle => 'वालेट ब्यालेन्स कम';

  @override
  String get walletLowDesc =>
      'प्राथमिक ब्यालेन्स सुरक्षा सीमाभन्दा तल झरेमा मलाई सचेत गर्नुहोस्।';

  @override
  String get walletDepletedTitle => 'वालेट सकियो';

  @override
  String get walletDepletedDesc =>
      'वालेट ब्यालेन्स पूर्णरूपमा सकिएर नवीकरण रोकिएमा निलम्बन सूचनाहरू।';

  @override
  String get lineCriticalTitle => 'वैधता म्याद समाप्ति सतर्कता';

  @override
  String get lineCriticalDesc =>
      '४८ घण्टाभित्र SIM वैधता विन्डो समाप्त हुँदै गरेमा मलाई सचेत गर्नुहोस्।';

  @override
  String get lineEnteringGraceTitle => 'ग्रेस अवधिमा प्रवेश';

  @override
  String get lineEnteringGraceDesc =>
      'क्यारियर निष्क्रियकरण ग्रेस अवधि पत्ता लागेमा मलाई सूचित गर्नुहोस्।';

  @override
  String get geoFenceTriggeredTitle => 'स्थान / रोमिङ सूचनाहरू';

  @override
  String get geoFenceTriggeredDesc =>
      'क्यारियरले रोमिङ क्लस्टर वा नेटवर्क नोड परिवर्तन गरेमा सूचनाहरू।';

  @override
  String get welcomeHomeReadyTitle => 'घरमा स्वागत सिङ्क';

  @override
  String get welcomeHomeReadyDesc =>
      'गृह-देश नेटवर्क नोडले स्वचालित सिङ्क ट्रिगर गरेमा सूचनाहरू।';

  @override
  String get referralRewardTitle => 'रेफरल & पुरस्कारहरू';

  @override
  String get referralRewardDesc =>
      'साथीको रेफरलले मेरो वालेटमा प्रचारात्मक ब्यालेन्स जम्मा गरेमा मलाई सूचित गर्नुहोस्।';

  @override
  String get systemUpdatesTitle => 'सामान्य प्रणाली अपडेटहरू';

  @override
  String get systemUpdatesDesc =>
      'महत्त्वपूर्ण इन्जिन अपडेटहरू, मर्मत र प्लेटफर्म घोषणाहरू।';

  @override
  String get walletCreditTitle => 'वालेटमा रकम जम्मा';

  @override
  String get walletCreditDesc =>
      'मेरो वालेटमा रकम जम्मा हुँदा मलाई सूचित गर्नुहोस्।';

  @override
  String get promoTitle => 'अफर र प्रवर्धन';

  @override
  String get promoDesc =>
      'छुट र नयाँ सुविधाहरूबारे कहिलेकाहीँ समाचार। तपाईंले नखोल्दासम्म बन्द रहन्छ।';

  @override
  String get deliverVia => 'यसमार्फत पठाउनुहोस्';

  @override
  String get channelPushShort => 'पुश';

  @override
  String get channelEmailShort => 'इमेल';

  @override
  String get channelOffGlobally => 'माथिको अलर्ट च्यानलमा बन्द छ';

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
  String get rechargeNow => 'अहिले रिचार्ज गर्नुहोस्';

  @override
  String get planFeePaidFromWallet =>
      'योजना शुल्क तपाईंको वालेट ब्यालेन्सबाट भुक्तानी गरियो।';

  @override
  String get planFeeNotChargedRetry =>
      'तपाईंको टप-अप आइपुग्यो तर योजना शुल्क लिन सकिएन, त्यसैले लाइन सिर्जना भएन। तपाईंको ब्यालेन्स सुरक्षित छ — कृपया फेरि प्रयास गर्नुहोस्।';

  @override
  String activityTopupRequested(String amount) {
    return '\$$amount को रिफिल अनुरोध पेश गरियो';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return '$provider मार्फत \$$amount को टप-अप सम्पन्न भयो';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return '\$$amount को टप-अप असफल भयो: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return '\$$amount को रिफिल वालेटमा फिर्ता गरियो';
  }

  @override
  String activityTopupCancelled(String amount) {
    return '\$$amount को रिफिल अनुरोध रद्द गरियो';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return '\$$amount को रिफिलको लागि पुनः प्रयास कतारमा राखियो';
  }

  @override
  String get activityLineCreated => 'SIM लाइन SIM Shield मा दर्ता भयो';

  @override
  String get activityHealthUpdate => 'SIM लाइन सक्रिय स्थिति प्रमाणीकरण भयो';

  @override
  String get activityReminderSent => 'नवीकरण स्मरण गराउने सूचना पठाइयो';

  @override
  String get supportTicketsTitle => 'सहायता र समर्थन';

  @override
  String get supportTicketsSubtitle =>
      'सहायता अनुरोध पेश गर्नुहोस्, गतिविधि लगहरू संलग्न गर्नुहोस्, र समर्थन टोलीसँग प्रत्यक्ष कुराकानी गर्नुहोस्।';

  @override
  String get supportTicketsEmpty => 'कुनै सहायता टिकट भेटिएन।';

  @override
  String get createSupportTicket => 'टिकट बनाउनुहोस्';

  @override
  String get ticketCategoryGeneral => 'साधारण सोधपुछ';

  @override
  String get ticketCategoryBilling => 'बिलिङ र वालेट';

  @override
  String get ticketCategoryTechnical => 'प्राविधिक समस्या';

  @override
  String get ticketCategoryRefillIssue => 'रिफिल समस्या';

  @override
  String get ticketCategoryAccount => 'खाता र सुरक्षा';

  @override
  String get ticketStatusOpen => 'खुल्ला';

  @override
  String get ticketStatusPending => 'जवाफको पर्खाइमा';

  @override
  String get ticketStatusResolved => 'समाधान भयो';

  @override
  String get ticketStatusClosed => 'बन्द';

  @override
  String get ticketSubjectLabel => 'विषय';

  @override
  String get ticketSubjectHint => 'समस्याको छोटो विवरण';

  @override
  String get ticketCategoryLabel => 'वर्ग';

  @override
  String get ticketMessageLabel => 'सन्देश';

  @override
  String get ticketMessageHint => 'विस्तृत जानकारी प्रदान गर्नुहोस्...';

  @override
  String get attachImage => 'तस्बिर संलग्न गर्नुहोस्';

  @override
  String get attachActivityLogs => 'लाइन लग संलग्न गर्नुहोस्';

  @override
  String get submitTicket => 'टिकट पेश गर्नुहोस्';

  @override
  String get typeMessageHint => 'सन्देश लेख्नुहोस्...';

  @override
  String get closeTicketButton => 'टिकट बन्द गर्नुहोस्';

  @override
  String get ticketClosedNotice => 'यो सहायता टिकट बन्द गरिएको छ।';

  @override
  String get attachedFiles => 'संलग्नकहरू';

  @override
  String get referralsTitle => 'रेफर र कमाउनुहोस्';

  @override
  String get referralsSubtitle =>
      'साथीहरूलाई आमन्त्रित गर्नुहोस्, उनीहरूको सिम सदस्यतामा अंकहरू कमाउनुहोस् र वालेट क्रेडिटमा साट्नुहोस्!';

  @override
  String get referralCode => 'तपाईंको रेफरल कोड';

  @override
  String get copyCode => 'कोड कपी गर्नुहोस्';

  @override
  String get codeCopied => 'रेफरल कोड क्लिपबोर्डमा कपी भयो!';

  @override
  String get shareCode => 'कोड सेयर गर्नुहोस्';

  @override
  String get pointsBalance => 'पोइन्ट ब्यालेन्स';

  @override
  String get pointsUnit => 'अंक';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return 'अर्को \$2.00 पुरस्कारको लागि अझै $pointsNeeded अंक चाहिन्छ';
  }

  @override
  String get redeemButton => '\$2.00 को लागि 10 अंक रिडिम गर्नुहोस्';

  @override
  String get redeemSuccess =>
      '\$2.00 वालेट क्रेडिटको लागि 10 अंक सफलतापूर्वक साटियो!';

  @override
  String get applyCodeTitle => 'के तपाईंसँग रेफरल कोड छ?';

  @override
  String get applyCodeHint => 'रेफरल कोड प्रविष्ट गर्नुहोस्';

  @override
  String get applyCodeButton => 'कोड लागू गर्नुहोस्';

  @override
  String get applyCodeSuccess => 'रेफरल कोड सफलतापूर्वक लागू भयो!';

  @override
  String get referredFriendsTitle => 'रेफर गरिएका साथीहरू';

  @override
  String get noReferredFriends =>
      'अझै कुनै साथीहरू रेफर गरिएको छैन। सुरु गर्न आफ्नो कोड सेयर गर्नुहोस्!';

  @override
  String get redemptionHistoryTitle => 'रिडेम्प्शन इतिहास';

  @override
  String get noRedemptions => 'अझै कुनै रिडेम्प्शन छैन।';

  @override
  String get pointHistoryTitle => 'पोइन्ट इतिहास';

  @override
  String get noPointsEarned => 'अझै कुनै अंक कमाइएको छैन।';

  @override
  String get howItWorksTitle => 'रेफर र कमाउनुहोस् कसरी काम गर्छ';

  @override
  String get howItWorksStep1 =>
      '1. साथीहरूसँग आफ्नो अनौठो रेफरल कोड सेयर गर्नुहोस्।';

  @override
  String get howItWorksStep2 =>
      '2. कुनै रेफर गरिएको साथीले सिम लाइन सदस्यता लिँदा 1 अंक कमाउनुहोस्।';

  @override
  String get howItWorksStep3 =>
      '3. कुनै पनि समयमा \$2.00 वालेट क्रेडिटको लागि 10 अंकहरू रिडिम गर्नुहोस्!';

  @override
  String get geoTitle => 'यात्रा र जियोलोकेशन';

  @override
  String get geoSubtitle =>
      'स्वचालित देश पहिचान र अन्तर्राष्ट्रिय सिम लाइन सुरक्षा';

  @override
  String get currentCountryLabel => 'हालको स्थान';

  @override
  String get travelModeToggle => 'यात्रा मोड';

  @override
  String get travelModeDescription =>
      'अन्तर्राष्ट्रिय लाइन सुरक्षा प्रबन्ध गर्न एप खोल्दा देश जाँच गर्नुहोस्';

  @override
  String get geoNotice =>
      'एप खोल्दा आईपी खोजी मार्फत देश जाँच गरिन्छ। कुनै स्थान अनुमति आवश्यक छैन।';

  @override
  String get freezeInternationalLines =>
      'अन्तर्राष्ट्रिय लाइनहरू फ्रिज गर्नुहोस्';

  @override
  String get resumeInternationalLines =>
      'अन्तर्राष्ट्रिय लाइनहरू पुनः सुरु गर्नुहोस्';

  @override
  String get linesFrozenSuccess =>
      'अन्तर्राष्ट्रिय सिम लाइनहरू फ्रिज गरियो र रिफिलहरू रोकिए!';

  @override
  String get linesResumedSuccess =>
      'अन्तर्राष्ट्रिय सिम लाइनहरू र रिफिलहरू पुनः सक्रिय गरियो!';

  @override
  String get alwaysProtectedBadge => 'सधैं सुरक्षित';

  @override
  String get detectedViaIp => 'आईपी मार्फत पहिचान गरिएको';

  @override
  String get esimManagerTitle => 'eSIM प्रबन्धक';

  @override
  String get esimPlansTitle => 'eSIM योजनाहरू';

  @override
  String get searchDestinationHint =>
      'गन्तव्य खोज्नुहोस् (जस्तै फ्रान्स, संयुक्त राज्य अमेरिका)';

  @override
  String get selectDestinationTitle => 'गन्तव्य चयन गर्नुहोस्';

  @override
  String get localTab => 'स्थानीय';

  @override
  String get regionalTab => 'क्षेत्रीय';

  @override
  String get globalTab => 'ग्लोबल';

  @override
  String get bestValueBadge => 'सर्वोत्कृष्ट मूल्य';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days दिन';
  }

  @override
  String get buyPlanButton => 'योजना किन्नुहोस्';

  @override
  String get deviceIncompatibleNotice =>
      'तपाईंको उपकरणले eSIM प्रविधिलाई समर्थन गर्दैन।';

  @override
  String get activationPolicyTitle => 'सक्रियता नीति';

  @override
  String get activationPolicyNotice =>
      'तपाईंको गन्तव्यमा समर्थित नेटवर्कमा eSIM जडान भएपछि मान्यता अवधि सुरु हुन्छ।';

  @override
  String get coveredCountriesTitle => 'समावेश गरिएका देशहरू';

  @override
  String get sortPriceLowToHigh => 'मूल्य: कम देखि बढी';

  @override
  String get sortPricePerGb => 'मूल्य / GB: कम देखि बढी';

  @override
  String get sortDataHighToLow => 'डेटा: बढी देखि कम';

  @override
  String get filterAll => 'सबै योजनाहरू';

  @override
  String get filterMin5Gb => '≥ ५ GB';

  @override
  String get filterMin15Days => '≥ १५ दिन';

  @override
  String get filterUnlimited => 'अनलिमिटेड';

  @override
  String get purchaseInNextRelease =>
      'eSIM खरिद सुविधा आगामी संस्करण (C9b) मा उपलब्ध हुनेछ।';

  @override
  String get confirmPurchaseTitle => 'eSIM खरिद पुष्टि गर्नुहोस्';

  @override
  String get myEsimsTitle => 'मेरो eSIM हरू';

  @override
  String get showQrCode => 'QR कोड देखाउनुहोस्';

  @override
  String get buyAgain => 'पुनः खरिद गर्नुहोस्';

  @override
  String get dataRemaining => 'बाँकी डेटा';

  @override
  String get archivedEsims => 'आर्काइभ गरिएका eSIM हरू';

  @override
  String rateLimitExceeded(String seconds) {
    return 'धेरै अनुरोधहरू। कृपया पुनः प्रयास गर्नु अघि $seconds सेकेन्ड पर्खनुहोस्।';
  }

  @override
  String get confirmDeleteButton => 'मेटाउन पुष्टि गर्नुहोस्';

  @override
  String get cancelAccountDeletion => 'खाता मेटाउने रद्द गर्नुहोस्';

  @override
  String get accountScheduledForDeletion => 'खाता मेटाउन तय गरिएको छ';

  @override
  String deletionScheduledNotice(String date) {
    return 'तपाईंको खाता फ्रिज गरिएको छ र $date मा स्थायी रूपमा मेटाउने तालिका बनाइएको छ।';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'तपाईंको वालेट ब्यालेन्स (\$$balance) सीमा (\$1.00) भन्दा बढी छ। कृपया यसलाई खर्च गर्नुहोस् वा समर्थनमा सम्पर्क गर्नुहोस्।';
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
  String get householdTitle => 'परिवार र घरपरिवार';

  @override
  String get householdTabMyFamily => 'मेरो परिवार';

  @override
  String get householdTabReceived => 'निमन्त्रणा';

  @override
  String get householdTabJoined => 'सामेल';

  @override
  String get householdInviteMember => 'सदस्य निम्त्याउनुहोस्';

  @override
  String get householdEmptyTitle => 'अहिलेसम्म कुनै सदस्य छैन';

  @override
  String get householdEmptyDesc =>
      'इमेलबाट कसैलाई निम्त्याएर आफ्नो प्रिपेड सिम लाइन र नवीकरण साझा गर्नुहोस्।';

  @override
  String get householdStatusPending => 'पर्खाइमा';

  @override
  String get householdStatusAccepted => 'सक्रिय';

  @override
  String get householdPendingHint => 'उहाँले स्वीकार गर्ने पर्खाइमा';

  @override
  String get householdRoleViewer => 'हेर्ने';

  @override
  String get householdRoleManager => 'प्रबन्धक';

  @override
  String get householdRoleViewerHint => 'तपाईंका लाइन हेर्न सक्छ';

  @override
  String get householdRoleManagerHint => 'तपाईंका लाइन हेर्न र टपअप गर्न सक्छ';

  @override
  String get householdManagerWarning =>
      'प्रबन्धकले तपाईंका लाइन टपअप गर्न सक्छ। तपाईंले सीमा तोकेमा मात्र तपाईंको वालेटबाट खर्च हुन्छ।';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'मेरो वालेटबाट खर्च · यो महिना $cap मध्ये $spent';
  }

  @override
  String get householdPaysOwnWallet => 'आफ्नै वालेटबाट तिर्छ';

  @override
  String get householdManagersOnly =>
      'प्रबन्धकका लागि मात्र — हेर्ने व्यक्तिले तपाईंको वालेट खर्च गर्न सक्दैन';

  @override
  String get householdChangeLimit => 'सीमा परिवर्तन';

  @override
  String get householdSetLimit => 'सीमा तोक्नुहोस्';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining बाँकी · $queued पङ्क्तिमा, अझै काटिएको छैन';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return 'यो महिना $remaining बाँकी';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return '$name को खर्च सीमा';
  }

  @override
  String get householdSpendingLimitDesc =>
      'हरेक महिना उहाँले तपाईंका लाइनमा तपाईंको वालेटबाट कति खर्च गर्न पाउने। बन्द गर्न ० राख्नुहोस् — त्यसपछि उहाँ आफ्नै वालेटबाट तिर्नुहुनेछ।';

  @override
  String get householdMonthlyLimit => 'मासिक सीमा (USD)';

  @override
  String get householdMaxPerRefill => 'प्रति टपअप अधिकतम (वैकल्पिक)';

  @override
  String get householdSave => 'सुरक्षित गर्नुहोस्';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name ले अब महिनामा तपाईंको वालेटबाट $cap सम्म खर्च गर्न सक्नुहुन्छ।';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name फेरि आफ्नै वालेटबाट तिर्नुहुनेछ।';
  }

  @override
  String get householdLimitFailed => 'सीमा अद्यावधिक गर्न सकिएन।';

  @override
  String get householdNoInvitesTitle => 'कुनै निमन्त्रणा छैन';

  @override
  String get householdNoInvitesDesc =>
      'कसैले तपाईंलाई आफ्नो परिवारमा निम्त्याएमा यहाँ देखिनेछ।';

  @override
  String get householdFamilyAccount => 'पारिवारिक खाता';

  @override
  String get householdInvitedYouViewer =>
      'आफ्ना सिम लाइन हेर्न तपाईंलाई निम्त्याउनुभयो';

  @override
  String get householdInvitedYouManager =>
      'आफ्ना सिम लाइन हेर्न र टपअप गर्न तपाईंलाई निम्त्याउनुभयो';

  @override
  String get householdAccept => 'स्वीकार गर्नुहोस्';

  @override
  String get householdDecline => 'अस्वीकार गर्नुहोस्';

  @override
  String get householdNotJoinedTitle =>
      'तपाईं कुनै परिवारमा सामेल हुनुभएको छैन';

  @override
  String get householdNotJoinedDesc =>
      'तपाईंले पाउने निमन्त्रणा निमन्त्रणा ट्याबमा देखिन्छ।';

  @override
  String get householdSharedHousehold => 'साझा परिवार';

  @override
  String get householdRoleManagerFull => 'प्रबन्धक · टपअप गर्न सक्छ';

  @override
  String get householdRoleViewerFull => 'हेर्ने · पढ्ने मात्र';

  @override
  String get householdLeave => 'छोड्नुहोस्';

  @override
  String householdOwnerFunds(String owner) {
    return '$owner ले तपाईंको टपअपको खर्च बेहोर्नुहुन्छ';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'तपाईंले यो महिनाको सम्पूर्ण $cap प्रयोग गरिसक्नुभयो। रिसेट नहुँदासम्म उहाँका लाइनमा टपअप अस्वीकार हुनेछ।';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return 'यो महिना $cap मध्ये $remaining बाँकी';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · प्रति टपअप अधिकतम $perTxn';
  }

  @override
  String get householdInviteTitle => 'परिवारका सदस्यलाई निम्त्याउनुहोस्';

  @override
  String get householdInviteDesc =>
      'उहाँले एपभित्रै निमन्त्रणा पाउनुहुनेछ। स्वीकार गरेपछि तपाईंका र उहाँका सिम लाइन सँगै देखिनेछन्।';

  @override
  String get householdEmailLabel => 'इमेल ठेगाना';

  @override
  String get householdAccessLevel => 'उहाँले के गर्न पाउनुहुन्छ?';

  @override
  String get householdSendInvite => 'निमन्त्रणा पठाउनुहोस्';

  @override
  String get householdInvalidEmail => 'कृपया मान्य इमेल ठेगाना राख्नुहोस्';

  @override
  String householdInviteSent(String email) {
    return '$email लाई निमन्त्रणा पठाइयो';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return '$email लाई निमन्त्रणा पठाइयो। दर्ता गर्नेबित्तिकै उहाँले देख्नुहुनेछ।';
  }

  @override
  String get householdInviteAccepted => 'तपाईं परिवारमा सामेल हुनुभयो';

  @override
  String get householdInviteDeclined => 'निमन्त्रणा अस्वीकार गरियो';

  @override
  String get householdRemoveTitle => 'परिवारका सदस्य हटाउनुहोस्';

  @override
  String householdRemoveConfirm(String name) {
    return '$name ले तुरुन्तै तपाईंका सिम लाइनको पहुँच र तोकिएको खर्च सीमा गुमाउनुहुनेछ।';
  }

  @override
  String householdRemoved(String name) {
    return '$name लाई तपाईंको परिवारबाट हटाइयो';
  }

  @override
  String get householdLeaveTitle => 'परिवार छोड्नुहोस्';

  @override
  String householdLeaveConfirm(String owner) {
    return '$owner ले साझा गर्नुभएका सिम लाइनको पहुँच तपाईंले गुमाउनुहुनेछ।';
  }

  @override
  String get householdLeft => 'तपाईंले परिवार छोड्नुभयो';

  @override
  String get householdActionFailed => 'यो भएन। कृपया फेरि प्रयास गर्नुहोस्।';

  @override
  String get householdOwnerLabel => 'तपाईं (मालिक)';

  @override
  String get householdSettingsSubtitle =>
      'परिवारसँग सिम लाइन साझा गर्नुहोस्, खर्च सीमा तोक्नुहोस्';

  @override
  String get householdStatusDeclined => 'अस्वीकृत';

  @override
  String get householdDeclinedHint =>
      'उहाँले अस्वीकार गर्नुभयो। फेरि निम्त्याउन हटाउनुहोस्।';

  @override
  String get carrierActivityFallbackOperator => 'यो क्यारियर';

  @override
  String get carrierUsageRequiredTitle =>
      'अटो-रिफिलले यो लाइन सुरक्षित राख्न सक्दैन';

  @override
  String carrierUsageRequiredBody(String operator) {
    return '$operator ले लाइनबाट कल गरेमा, एसएमएस पठाएमा वा डेटा प्रयोग गरेमा मात्र निष्क्रियता काउन्टडाउन पुनः सुरु गर्छ। ब्यालेन्स थप्नु यसमा गनिँदैन, त्यसैले कुनै पनि अटो टप-अपले यो नम्बर निष्क्रिय हुनबाट रोक्न सक्दैन। स्ट्यान्डर्ड प्लान छान्नुहोस् — हामी तपाईंलाई समयमै सूचित गर्नेछौं ताकि तपाईं आफैं लाइन प्रयोग गर्न सक्नुहुन्छ।';
  }

  @override
  String get carrierMinDenominationTitle => 'यो क्यारियरलाई ठूलो टप-अप चाहिन्छ';

  @override
  String carrierMinDenominationBody(
    String operator,
    String amount,
    String currency,
  ) {
    return '$operator ले $amount $currency वा बढी टप-अपमा मात्र लाइनको वैधता थप्छ। यसभन्दा कम रकम खर्च गर्न मिल्ने ब्यालेन्सको रूपमा मात्र आउँछ र नम्बर अझै निष्क्रिय हुन सक्छ, त्यसैले प्रिमियमले यो लाइन $amount $currency मा रिफिल गर्छ।';
  }

  @override
  String get premiumUnavailableForCarrier =>
      'यो क्यारियरका लागि प्रिमियम उपलब्ध छैन';

  @override
  String get carrierRulesLinkLabel => 'यो क्यारियरका नियमबारे थप';

  @override
  String get carrierRulesSheetTitle => 'नम्बर बन्द हुने नियम';

  @override
  String carrierRulesHowTitle(String operator) {
    return '$operator ले कसरी निर्णय गर्छ';
  }

  @override
  String carrierRechargeOkBody(String operator) {
    return 'लाइनमा टप-अप हुनासाथ $operator ले आफ्नो गन्ती फेरि सुरु गर्छ, रकम जति भए पनि। त्यसैले यहाँ स्वचालित रिफिलले नम्बर जोगाउन सक्छ।';
  }

  @override
  String get carrierRulesNumbersTitle => 'अंकहरू';

  @override
  String carrierRulesWindowRow(int days) {
    return 'गन्तीमा आउने टप-अप बिना $days दिनपछि नम्बर निष्क्रिय गरिन्छ';
  }

  @override
  String carrierRulesGraceRow(int days) {
    return 'त्यसपछि उही नम्बर फिर्ता लिन $days दिन';
  }

  @override
  String get carrierRulesNoGraceRow =>
      'फिर्ता लिने समय छैन — नम्बर तुरुन्तै छाडिन्छ';

  @override
  String carrierRulesMinTopupRow(String amount, String currency) {
    return 'वैधता थप्ने सबैभन्दा सानो टप-अप $amount $currency हो';
  }

  @override
  String carrierRulesCadenceRow(int days, int count) {
    return 'हामी हरेक $days दिनमा रिफिल गर्थ्यौं — वर्षमा $count पटक';
  }

  @override
  String get carrierRulesVerdictTitle => 'हामी के गर्थ्यौं';

  @override
  String get carrierVerdictSelfServiceTitle =>
      'यो लाइनका लागि प्रिमियम नकिन्नुहोस्';

  @override
  String get carrierVerdictSelfServiceBody =>
      'पैसा जोगाउनुहोस्। हामीले पठाउन सक्ने कुनै पनि कुराले यो क्यारियरको घडी फेरि सुरु गर्दैन; नम्बर जोगाउने एउटै उपाय भनेको त्यसलाई प्रयोग गर्नु हो।';

  @override
  String get carrierVerdictStandardTitle => 'यहाँ स्ट्यान्डर्ड नै पर्याप्त छ';

  @override
  String get carrierVerdictStandardBody =>
      'यो क्यारियरले तपाईंलाई लामो समय दिन्छ। मिति हामी हेर्छौं र तपाईंलाई भन्छौं; भनेपछि आफैँ टप-अप गर्नुहोस्, अनि बालेन्सको मात्र पैसा लाग्छ।';

  @override
  String get carrierVerdictPremiumWorthTitle => 'प्रिमियम लिनु उपयुक्त छ';

  @override
  String get carrierVerdictPremiumWorthBody =>
      'वर्षमा केही टप-अप, हरेक यस्तो मितिमा जुन यहाँबाट देखिँदैन। चाहनुहुन्छ भने आफैँ पनि गर्न सकिन्छ — स्वचालित गर्नुको अर्थ यसबारे कहिल्यै सोच्नै नपर्नु हो।';

  @override
  String get carrierVerdictPremiumMustTitle => 'यसलाई स्वचालित बनाउनुहोस्';

  @override
  String get carrierVerdictPremiumMustBody =>
      'यो क्यारियर यति छिटो चल्छ कि अर्को देशबाट हरेक पटक आफैँ सम्झिने काम कुनै दिन छुट्छ नै — र एक पटक छुट्नुको अर्थ नम्बर नै गुम्नु हो।';

  @override
  String get carrierReasonUsageOnly =>
      'कल, SMS वा डेटा प्रयोग मात्र गनिन्छ। एक्लै बालेन्स गनिँदैन।';

  @override
  String carrierReasonQualifying(String amount, String currency) {
    return '$amount $currency भन्दा कमको टप-अप बालेन्सका रूपमा मात्र आउँछ, वैधता थप्दैन।';
  }

  @override
  String carrierReasonShortWindow(int days) {
    return 'दुई गन्तीयोग्य टप-अपबीच जम्मा $days दिन।';
  }

  @override
  String carrierReasonLongWindow(int days) {
    return '$days दिन भनेको लगभग पूरै वर्ष हो — एउटै रिमाइन्डरले पुग्छ।';
  }

  @override
  String get carrierReasonNoGrace =>
      'कुनै छुट अवधि छैन। मिति नाघ्यो भने नम्बर गयो।';

  @override
  String carrierReasonGrace(int days) {
    return 'मितिपछि नम्बर फिर्ता लिन तपाईंसँग $days दिन हुनेछ।';
  }

  @override
  String carrierReasonAutomationCost(
    String self,
    String premium,
    String extra,
  ) {
    return 'बालेन्सको मात्रै वर्षमा करिब $self लाग्छ। प्रिमियम $premium हो, अर्थात् त्यसमध्ये $extra स्वचालनको मूल्य हो।';
  }

  @override
  String carrierSelfServiceTitle(String operator) {
    return 'वा सिधै $operator बाट किन्नुहोस्';
  }

  @override
  String get carrierSelfServiceBody =>
      'क्यारियरकै एपबाट टप-अप गर्नुहोस्, अनि बालेन्सको मात्र पैसा लाग्छ, अरू केही लाग्दैन।';

  @override
  String carrierSelfServiceCountryLine(String country) {
    return 'नम्बरको देश: $country';
  }

  @override
  String carrierSelfServiceAppHint(String app) {
    return 'यसको एप प्रायः \"$app\" नामले प्रकाशित हुन्छ।';
  }

  @override
  String carrierSelfServiceUnverified(String operator) {
    return 'हामीले यो एप आफैँ जाँचेका छैनौँ। स्टोरमा खोज्नुहोस् र केही इन्स्टल गर्नुअघि प्रकाशक साँच्चै $operator हो कि होइन पक्का गर्नुहोस्।';
  }

  @override
  String get carrierSelfServiceSearchStore => 'एप स्टोरमा खोज्नुहोस्';

  @override
  String get carrierSelfServiceOpenApp => 'क्यारियरको एप खोल्नुहोस्';

  @override
  String get carrierSelfServiceWeb => 'क्यारियरको वेबसाइटबाट टप-अप गर्नुहोस्';

  @override
  String carrierSelfServiceUssd(String code) {
    return 'डेटा छैन? त्यही फोनबाट $code डायल गर्नुहोस्।';
  }

  @override
  String get carrierRulesSourceLink => 'क्यारियरले प्रकाशित गरेका सर्तहरू';

  @override
  String get carrierRulesDisclaimer =>
      'क्यारियरहरूले यी नियम नबताई परिवर्तन गर्छन्। तपाईंको क्यारियरले परिवर्तन गरेको भए सहयोग टोलीलाई भन्नुहोस्, हामी फेरि जाँच्नेछौँ।';

  @override
  String get carrierActionTitle => 'तपाईंको कदम आवश्यक';

  @override
  String get carrierActionDesc =>
      'कुनै लाइनलाई म आफैँले मात्र गर्न सक्ने काम चाहिँदा मलाई भन्नुहोस् — सिम प्रयोग गर्नु वा क्यारियरकै एपबाट टप-अप गर्नु।';

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
