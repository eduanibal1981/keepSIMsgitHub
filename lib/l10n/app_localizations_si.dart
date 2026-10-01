// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get dashboardKeepSimActive => 'SIM සක්‍රියව තබාගන්න';

  @override
  String get dashboardProtectSimLines => 'ඔබේ SIM සම්බන්ධතා ආරක්ෂා කරන්න';

  @override
  String get dashboardManageReminders =>
      'මතක් කිරීම් සහ නැවත පිරවීම් කළමනාකරණය කරන්න';

  @override
  String get dashboardManageSims => 'SIM කළමනාකරණය';

  @override
  String dashboardSimLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SIM සම්බන්ධතා $countක්',
      one: 'SIM සම්බන්ධතා 1ක්',
    );
    return '$_temp0';
  }

  @override
  String get dashboardNewFeature => 'නව';

  @override
  String get dashboardWorldwideEsims => 'ලොව පුරා eSIM';

  @override
  String get dashboardExploreSmartCall => 'Smart Call බලන්න';

  @override
  String get dashboardExploreGlobalOffers => 'ගෝලීය දීමනා බලන්න';

  @override
  String get dashboardAddSims => 'SIM එක් කරන්න';

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'මනාපයන් සහ ආරක්ෂාව';

  @override
  String get appAppearance => 'යෙදුම් පෙනුම';

  @override
  String get systemTheme => 'පද්ධතිය';

  @override
  String get darkMode => 'අඳුරු මාදිලිය';

  @override
  String get lightMode => 'ආලෝක මාදිලිය';

  @override
  String get localizationAndRegional => 'දේශීයකරණය සහ කලාපීය';

  @override
  String get appLanguage => 'යෙදුම් භාෂාව';

  @override
  String currentlyUsing(String langName) {
    return 'දැනට $langName කලාපීය භාවිතා කරමින්';
  }

  @override
  String get selectAppLanguage => 'යෙදුම් භාෂාව තෝරන්න';

  @override
  String get securityAndAccessLock => 'ආරක්ෂාව සහ ප්‍රවේශ අගුල';

  @override
  String get biometricSecurity => 'ජෛවමිතික ආරක්ෂාව';

  @override
  String get biometricDesc => 'Face ID හෝ Touch ID භාවිතා කර පිවිසෙන්න';

  @override
  String get biometricReasonPayment => 'ගෙවීම තහවුරු කිරීමට සත්‍යාපනය කරන්න';

  @override
  String get biometricReasonUnlock => 'KeepSIMs අගුළු ඇරීමට සත්‍යාපනය කරන්න';

  @override
  String get biometricLockout =>
      'වැරදි උත්සාහයන් වැඩි නිසා ජෛවමිතික සත්‍යාපනය අගුළු වැටී ඇත. කරුණාකර ඔබගේ උපාංග මුරපදය භාවිතා කරන්න.';

  @override
  String get biometricNotEnrolled => 'මෙම උපාංගයේ ජෛවමිතික සත්‍යාපනය සකසා නැත.';

  @override
  String get biometricAppLockTitle => 'KeepSIMs අගුළු දමා ඇත';

  @override
  String get biometricUnlockButton => 'ජෛවමිතියෙන් අගුළු අරින්න';

  @override
  String get biometricCancel => 'අවලංගු කරන්න';

  @override
  String get transactionPin => 'ගනුදෙනු PIN';

  @override
  String get transactionPinDesc => 'අලුත් කිරීම් සහ ඉල්ලුම් ආරක්ෂා කරන්න';

  @override
  String get setup => 'සකසන්න';

  @override
  String get pinSuccess => 'ගනුදෙනු PIN සාර්ථකව යාවත්කාලීන කෙරිණි!';

  @override
  String get pinMismatch => 'PIN ගැලපෙන්නේ නැත. නැවත උත්සාහ කරන්න!';

  @override
  String get pinActiveAndSecure => 'PIN සැකසුම ක්‍රියාකාරී සහ ආරක්ෂිතයි';

  @override
  String get automatedSummaryAndAlerts => 'ස්වයංක්‍රීය සාරාංශය සහ ඇඟවීම්';

  @override
  String get weeklyDigest => 'සතිපතා සාරාංශය';

  @override
  String get welcomeBack => 'නැවත සාදරයෙන් පිළිගනිමු';

  @override
  String get nextNotify => 'ඊළඟ දැනුම්දීම';

  @override
  String get days => 'දින';

  @override
  String get showingNearestLine => 'ළඟම රේඛාව පෙන්වමින්';

  @override
  String get addSim => 'SIM එකතු කරන්න';

  @override
  String get linesToProtect => 'ආරක්ෂා කළ යුතු රේඛා';

  @override
  String get active => 'ක්‍රියාකාරී';

  @override
  String get upgrade => 'උසස් කරන්න';

  @override
  String get standard => 'සම්මත';

  @override
  String get autoNotify => 'ස්වයං-දැනුම්දීම';

  @override
  String get configure => 'වින්‍යාස කරන්න';

  @override
  String get autoRefill => 'ස්වයං-පිරවීම';

  @override
  String get quickActions => 'ඉක්මන් ක්‍රියාවන්';

  @override
  String get navHome => 'මුල් පිටුව';

  @override
  String get navSims => 'SIMs';

  @override
  String get navMore => 'තවත්';

  @override
  String get protectedSims => 'ආරක්ෂිත SIMs';

  @override
  String get mySimCards => 'මගේ SIM කාඩ්';

  @override
  String get familySharedSims => 'පවුලේ හවුල් SIMs';

  @override
  String get protectAnotherSimLine => 'තවත් SIM රේඛාවක් ආරක්ෂා කරන්න';

  @override
  String get keepInfiniteNumbersAlive => 'අසීමිත ජාත්‍යන්තර අංක ජීවත් තබන්න';

  @override
  String get bulkActionsConsole => 'වරලොකු ක්‍රියා කොන්සෝලය';

  @override
  String get resume => 'නැවත ආරම්භ කරන්න';

  @override
  String get pause => 'විරාම කරන්න';

  @override
  String get simulate => 'අනුකරණය කරන්න';

  @override
  String get noProtectedLines => 'ආරක්ෂිත රේඛා නැත';

  @override
  String get noInternationalSimsAdded =>
      'ඔබ තවම ජාත්‍යන්තර SIM කාඩ් එකතු කර නැත. ඔබේ පළමු කාඩ්පත දැන් ආරක්ෂා කර සදහටම ක්‍රියාශීලීව තබා ගන්න.';

  @override
  String get protectNewLine => 'නව රේඛාව ආරක්ෂා කරන්න';

  @override
  String get noSharedSimsYet => 'තවම හවුල් SIMs නැත';

  @override
  String get inviteFamilyMembers =>
      'ඔබේ ගෘහ කණ්ඩායමට සම්බන්ධ වීමට පවුලේ සාමාජිකයන් ආරාධනා කරන්න. ඔවුන් පිළිගත් පසු, ඔවුන්ගේ ආරක්ෂිත SIM රේඛා සහජ නිරීක්ෂණය සඳහා මෙහි දිස් වේ.';

  @override
  String get manageHousehold => 'ගෘහය කළමනාකරණය කරන්න';

  @override
  String get manageProfileDesc =>
      'ඔබේ පැතිකඩ, SIM රේඛා, ඇඟවීම් සහ හවුල් මනාපයන් කළමනාකරණය කරන්න';

  @override
  String get keepSIMsUser => 'KeepSIMs පරිශීලකයා';

  @override
  String get pro => 'PRO';

  @override
  String get homeCountry => 'මව් රට: ';

  @override
  String get console => 'කොන්සෝලය';

  @override
  String get offlineRefill => 'නොබැඳි පිරවීම (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'SMS හෝ WhatsApp හරහා නොබැඳිව SIM ශේෂය පිරවන්න';

  @override
  String get wallet => 'මුදල් පසුම්බිය';

  @override
  String get manageBalancesDesc => 'ඔබේ ශේෂ කළමනාකරණය කර ගනුදෙනු ඉතිහාසය බලන්න';

  @override
  String get alertPreferences => 'ඇඟවීම් මනාපයන්';

  @override
  String get togglePushEmailDesc =>
      'අලුත් කිරීම්/ශේෂ සඳහා push සහ ඊමේල් සැකසුම් ක්‍රියාත්මක/අක්‍රිය කරන්න';

  @override
  String get referAndEarn => 'යොමු කරන්න සහ උපයන්න';

  @override
  String get shareKeepSIMsDesc =>
      'KeepSIMs බෙදාහදා ගෙන, ගතික ශේෂ ත්‍යාග අගුළු හරින්න';

  @override
  String get paymentMethods => 'ගෙවීම් ක්‍රම';

  @override
  String get addBankCardsDesc =>
      'බැංකු කාඩ් එකතු කරන්න හෝ ස්වයං-ආහරණ ගිණුම් සම්බන්ධ කරන්න';

  @override
  String get travelAndGeolocation => 'සංචාරය සහ භූ-ස්ථාන';

  @override
  String get manageHomeCountryDesc =>
      'මව් රට කැටිගත් නීති සහ සංචාර මාදිලිය කළමනාකරණය කරන්න';

  @override
  String get dataAndPrivacy => 'දත්ත සහ පෞද්ගලිකත්වය';

  @override
  String get manageTrackingConsentDesc =>
      'ඔබේ ලුහුබැඳීමේ කැමැත්ත කළමනාකරණය කරන්න, දත්ත අපනයනය කරන්න, හෝ ගිණුම මකන්න';

  @override
  String get powerUser => 'බලසම්පන්න පරිශීලකයා';

  @override
  String get accessSystemSimulatorsDesc =>
      'පද්ධති අනුකාරකයන් සහ නිදොස්කරණ මෙවලම් ලබා ගන්න';

  @override
  String get testChecklist => 'පරීක්ෂණ ලැයිස්තුව';

  @override
  String get manualUiTestingDesc =>
      'ගුණාත්මකභාවය සහතික කිරීම සඳහා අතින් UI පරීක්ෂා කිරීමේ ලැයිස්තුව';

  @override
  String get soon => 'ඉක්මනින්';

  @override
  String featureComingSoon(String feature) {
    return '$feature විශේෂාංගය ඉක්මනින් ලැබේ!';
  }

  @override
  String get logOut => 'ඉවත් වන්න';

  @override
  String get confirmLogOut =>
      'ඔබට KeepSIMs වෙතින් ඉවත් වීමට අවශ්‍ය බව නිශ්චිතද?';

  @override
  String get walletLedger => 'මුදල් පසුම්බි ගිණුම් පොත';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs ප්‍රිපේඩ්';

  @override
  String get offlineMode => 'නොබැඳි මාදිලිය';

  @override
  String get activeBalance => 'ක්‍රියාකාරී ශේෂය';

  @override
  String get criticalBalanceLevel => 'තීරණාත්මක ශේෂ මට්ටම';

  @override
  String get balanceBelow10 =>
      'ඔබේ ශේෂය \$10.00 ට අඩුයි. නියමිත SIM ඉහළ නැංවීම් ඉක්මනින් අසාර්ථක විය හැක.';

  @override
  String get depositFunds => 'මුදල් තැන්පත් කරන්න';

  @override
  String get walletDepositsRequireInternet =>
      'මුදල් පසුම්බි තැන්පතු සඳහා ක්‍රියාශීලී අන්තර්ජාල සම්බන්ධතාවයක් අවශ්‍යයි.';

  @override
  String get exportLedger => 'ගිණුම් පොත අපනයනය කරන්න';

  @override
  String get ledgerHistoryExported =>
      'ගිණුම් පොත ඉතිහාසය CSV ලෙස අපනයනය කෙරිණි.';

  @override
  String get spendAnalysis => 'වියදම් විශ්ලේෂණය';

  @override
  String get transactionHistory => 'ගනුදෙනු ඉතිහාසය';

  @override
  String itemsCount(int count) {
    return 'අයිතම $count';
  }

  @override
  String get noTransactionsRecorded => 'තවම ගනුදෙනු වාර්තා නොකෙරිණි.';

  @override
  String get prepaidMonthlyOutflow => 'ප්‍රිපේඩ් මාසික ගලා යාම';

  @override
  String avgMonthlySpend(String amount) {
    return 'සාමා: \$$amount/මාස (12M)';
  }

  @override
  String depositViaCard(String last4) {
    return '$last4 ලකුණු ඇති කාඩ්පත හරහා තැන්පතු';
  }

  @override
  String get lineRenewal => 'රේඛා අලුත් කිරීම';

  @override
  String get justNow => 'දැන් පමණක්';

  @override
  String get loadCreditFunds => 'ණය මුදල් පූරණය කරන්න';

  @override
  String get depositAmountUsd => 'තැන්පතු මුදල (USD)';

  @override
  String get pleaseEnterAmount => 'කරුණාකර මුදලක් ඇතුළු කරන්න';

  @override
  String get enterPositiveNumber => 'ධනාත්මක සංඛ්‍යාවක් ඇතුළු කරන්න';

  @override
  String get cardDetails => 'කාඩ් විස්තර';

  @override
  String get savedCards => 'සුරකින ලද කාඩ්';

  @override
  String get visaCardNumber => 'Visa කාඩ් අංකය';

  @override
  String get pleaseEnterCardNumber => 'කරුණාකර කාඩ් අංකය ඇතුළු කරන්න';

  @override
  String get mustBe16Digits => 'අංක 16ක් විය යුතුයි';

  @override
  String get expiryMmYy => 'කල් ඉකුත් වීම (MM/YY)';

  @override
  String get expiryRequired => 'කල් ඉකුත් වීම අවශ්‍යයි';

  @override
  String get invalid => 'අවලංගු';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV අවශ්‍යයි';

  @override
  String get verifyingCardSecurity => 'කාඩ් ආරක්ෂාව සත්‍යාපනය කරමින්...';

  @override
  String get authorizeDepositFunds => 'තැන්පතු අනුමත කරන්න';

  @override
  String successfullyDeposited(String amount) {
    return '\$$amount USD සාර්ථකව තැන්පත් කෙරිණි!';
  }

  @override
  String get failedToDepositFunds =>
      'මුදල් තැන්පත් කිරීම අසාර්ථකයි. කාඩ් සම්බන්ධතාවය පරීක්ෂා කරන්න.';

  @override
  String get noSavedPaymentMethods => 'සුරකින ලද ගෙවීම් ක්‍රම හමු නොවිණි.';

  @override
  String get addPaymentMethod => 'ගෙවීම් ක්‍රමයක් එකතු කරන්න';

  @override
  String get savedPaymentMethods => 'සුරකින ලද ගෙවීම් ක්‍රම';

  @override
  String get addAnotherPaymentMethod => 'තවත් ගෙවීම් ක්‍රමයක් එකතු කරන්න';

  @override
  String expiresMmYy(String month, String year) {
    return '$month/$year දින කල් ඉකුත් වේ';
  }

  @override
  String get offlineRefillTitle => 'නොබැඳි පිරවීම (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'ඉලක්ක SIM රේඛාව තෝරන්න';

  @override
  String get noRegisteredSimLines => 'ලියාපදිංචි SIM රේඛා හමු නොවිණි.';

  @override
  String get targetSimLine => 'ඉලක්ක SIM රේඛාව';

  @override
  String get simLine => 'SIM රේඛාව';

  @override
  String get carrier => 'සේවා සපයන්නා';

  @override
  String get change => 'වෙනස් කරන්න';

  @override
  String get offlineRefillProtection => 'නොබැඳි පිරවීම් ආරක්ෂාව';

  @override
  String get premiumExclusive => 'ප්‍රිමියම් සුවිශේෂ';

  @override
  String get neverGetStrandedDesc =>
      'ජංගම දත්ත නොමැතිව කිසිදා ගොදුරු නොවන්න. KeepSIMs Premium ඔබට ශූන්‍ය අන්තර්ජාල සම්බන්ධතාවයකින් සිටින විට සම්මත දේශීය SMS හෝ WhatsApp පණිවිඩ හරහා නොබැඳිව ඔබේ SIM ශේෂය පිරවීමට ඉඩ සලසයි.';

  @override
  String get offlineCapability100 => '100% නොබැඳි හැකියාව';

  @override
  String get deductsFromKeepSIMsDesc =>
      'දේශීය SMS ද්වාර ව්‍යසන ආදේශ හරහා ඔබේ රේඛාවට ණය ලබා දීමට KeepSIMs මුදල් පසුම්බියෙන් අඩු කරයි.';

  @override
  String get dynamicUssdPlanActivation => 'ගතික USSD සැලැස්ම සක්‍රිය කිරීම';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'නොබැඳිව Data+Call පැකේජ සක්‍රිය කිරීමට හරියටම පිටපත් කළ හැකි ඩයල් කේත (උදා: *900*1#) සපයයි.';

  @override
  String get dualChannelSupport => 'ද්වි-නාලිකා සහාය';

  @override
  String get textRefillDesc =>
      'ලබා ගත හැකි සෛලීය ආවරණය අනුව සම්මත SMS හෝ WhatsApp භාවිතයෙන් \"REFILL\" ලෙස අකුරු කරන්න.';

  @override
  String get close => 'වසන්න';

  @override
  String get howToTriggerOfflineRefill =>
      'නොබැඳි පිරවීම ක්‍රියාත්මක කරන්නේ කෙසේද';

  @override
  String get ifZeroMobileDataDesc1 =>
      'ඔබ සතු ජංගම දත්ත ශූන්‍ය නම්, සම්මත SMS හෝ WhatsApp පණිවිඩයක් ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' පමණක් ඇතුළත් කර අපගේ ආරක්ෂිත ද්වාරයට යවන්න:';

  @override
  String get targetSimLineLabel => 'ඉලක්ක SIM රේඛාව';

  @override
  String get configureCashRefillAmount =>
      'මුදල් පිරවීමේ ප්‍රමාණය වින්‍යාස කරන්න';

  @override
  String get refillAmount => 'පිරවීමේ ප්‍රමාණය';

  @override
  String walletBalanceUsd(String amount) {
    return 'මුදල් පසුම්බි ශේෂය: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ අඩු ශේෂය';

  @override
  String get localCarrierPlanSuggestions => 'දේශීය සේවා සපයන්නා සැලැස්ම යෝජනා';

  @override
  String get noStandardUssdDialCodes =>
      'මෙම සේවා සපයන්නා සඳහා සම්මත USSD ඩයල් කේත හමු නොවිණි. ඔබේ රේඛාවට මුදල් පිරවීම තවමත් සාර්ථකව ලැබේ.';

  @override
  String get dynamicDialCodesPreview => 'ගතික ඩයල් කේත පෙරදසුන';

  @override
  String get botSuggestDialingCodes =>
      'නොබැඳි පිරවීම සම්පූර්ණ වූ පසු, නොබැඳිව Data+Calls වහාම අගුළු හැරීමට ඔබේ දුරකථනයේ මෙම නිශ්චිත කේත ඩයල් කිරීමට බොට් යෝජනා කරනු ඇත:';

  @override
  String costAmount(String amount) {
    return 'මිල: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'WHATSAPP/SMS යවන්නා ඉක්මවා යාම';

  @override
  String get verificationNumber => 'සත්‍යාපන අංකය';

  @override
  String get triggerRefillsDifferentNumber =>
      'ඔබ ඔබේ ප්‍රධාන පැතිකඩ දුරකථනයෙන් වෙනත් අංකයකින් පිරවීම් ක්‍රියාත්මක කරන්නේ නම්, රට කේතය සමඟ පහත ඇතුළු කරන්න (උදා: 96891234567).';

  @override
  String get enterPhoneNumberDigits => 'දුරකථන අංකය ඇතුළු කරන්න (ඉලක්කම් පමණි)';

  @override
  String get offlineRefillSettingsSaved =>
      'නොබැඳි පිරවීම් සැකසුම් සාර්ථකව සුරකිණි!';

  @override
  String get saveSettings => 'සැකසුම් සුරකින්න';

  @override
  String errorLoadingSettings(String error) {
    return 'සැකසුම් පූරණය කිරීමේ දෝෂය: $error';
  }

  @override
  String get retry => 'නැවත උත්සාහ කරන්න';

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
  String get offlineRefillChannelsHeader => 'නොබැඳිව නැවත පිරවීමේ ක්‍රම';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'ඔබගේ පසුම්බියෙන් $amount ක් පුරවන්න';
  }

  @override
  String get offlineRefillWalletFunded => 'ඔබගේ පසුම්බියෙන්';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee ගාස්තුව';
  }

  @override
  String get offlineRefillMissedCallTitle => 'මගහැරුණු ඇමතුමක් දෙන්න';

  @override
  String get offlineRefillMissedCallSubtitle => 'ශේෂයක් හෝ දත්ත අවශ්‍ය නැත';

  @override
  String get offlineRefillCallAction => 'නැවත පිරවීමට අමතන්න';

  @override
  String get offlineRefillRetry => 'නැවත උත්සාහ කරන්න';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return '$secondsතත් රැඳී සිටින්න';
  }

  @override
  String get offlineRefillStatusSent =>
      'යවන ලදී — තහවුරු කිරීම බලාපොරොත්තුවෙන්';

  @override
  String get offlineRefillStatusProcessing => 'ඔබගේ රේඛාව පුරවමින්…';

  @override
  String get offlineRefillStatusConfirmed => 'පිරවීම තහවුරු විය';

  @override
  String get offlineRefillStatusFailed =>
      'සාර්ථක නොවීය — වෙනත් ක්‍රමයක් උත්සාහ කරන්න';

  @override
  String get offlineRefillStatusTimedOut =>
      'තවම පිළිතුරක් නැත — වෙනත් ක්‍රමයක් උත්සාහ කරන්න';

  @override
  String get offlineRefillUssdTitle => 'ඔබගේ පිරවීමෙන් වැඩි ප්‍රයෝජනයක් ගන්න';

  @override
  String get offlineRefillUssdSubtitle =>
      'ශේෂය පැමිණි පසු, හොඳම වටිනාකම සඳහා ඔබගේ ක්‍රියාකරුගේ කේතය අමතන්න';

  @override
  String get offlineRefillUssdDial => 'අමතන්න';

  @override
  String get editProtectedLine => 'ආරක්ෂිත රේඛාව සංස්කරණය කරන්න';

  @override
  String get saveChanges => 'වෙනස්කම් සුරකින්න';

  @override
  String get activateShieldProtection => 'Shield ආරක්ෂාව සක්‍රිය කරන්න';

  @override
  String get phoneNumber => 'දුරකථන අංකය';

  @override
  String get nicknameOptional => 'අන්වර්ථ නාමය (විකල්ප)';

  @override
  String get whatsappAlerts => 'WhatsApp ඇඟවීම්';

  @override
  String get emailAlertsDesc =>
      'Resend හරහා යවන ලද තීරණාත්මක අක්‍රිය කිරීමේ ඇඟවීම්';

  @override
  String get refillWalletLow => 'මුදල් අඩු වූ විට මුදල් පසුම්බිය පිරවන්න';

  @override
  String get legalPoliciesDesc =>
      'KeepSIMs භාවිතා කිරීමෙන්, ඔබ අපගේ කොන්දේසිවලට එකඟ වේ. KeepSIMs ඔබේ SIM ජීවන චක්‍රය කළමනාකරණය කිරීමට උදවු කිරීමේ මෙවලම් සපයයි, නමුත් තෙවන පාර්ශ්ව විදුලි සංදේශ සේවා සපයන්නන් විසින් ඇති කරන ලද සෘජු හෝ වක්‍ර අලාභ, හානි, හෝ සේවා බාධාවන් සඳහා අපි වගකීම් නොදරමු.';

  @override
  String get globalTravelModeDesc =>
      'ස්වයංක්‍රීය භූ-වැට් නීතිවලට දේශ සීමා හරවා යාමේ චර්යා ක්‍රියාත්මක කිරීමට ඉඩ සලසයි';

  @override
  String get dataPreferences => 'දත්ත මනාපයන්';

  @override
  String get doNotDisturb => 'බාධා නොකරන්න';

  @override
  String get linkedCards => 'සම්බන්ධිත කාඩ්';

  @override
  String get analyticsTracking => 'විශ්ලේෂණ සහ ලුහුබැඳීම';

  @override
  String get dubai => 'දුබායි';

  @override
  String get flyHome => 'නිවසට යාම';

  @override
  String get managePreferencesAndSecurityDesc =>
      'තේමාව, භාෂාව සහ ජෛවමිතික අගුළු කළමනාකරණය කරන්න';

  @override
  String get autoFundingRulesDesc =>
      'ශේෂය ඉතා අඩු වූ විට ඔබේ පෙරනිමි ණය කාඩ්පතෙන් ස්වයංක්‍රීය ඉහළ නැංවීම් සක්‍රිය කිරීමෙන් SIM අලුත් කිරීම අඛණ්ඩව ක්‍රියාත්මක කරන්න';

  @override
  String get pushNotifications => 'Push දැනුම්දීම්';

  @override
  String get quietHoursSchedule => 'නිස්සාර කාලය සහ කාලසටහන';

  @override
  String get exportMyDataDesc =>
      'ඔබේ පැතිකඩ සහ මනාපයන්හි JSON පිටපතක් බාගන්න (GDPR ප්‍රවේශ අයිතිය)';

  @override
  String get borderSimulatorTitle => 'දේශ සීමා හරවා යාමේ අනුකාරකය';

  @override
  String get yourData => 'ඔබේ දත්ත';

  @override
  String get mostImportant => 'වැදගත්ම';

  @override
  String get emailAlerts => 'ඊමේල් ඇඟවීම්';

  @override
  String get pushNotificationsDesc =>
      'මෙම උපාංගයේ ආක්‍රමණශීලී මූලික දැනුම්දීම්';

  @override
  String get alertSettingsTitle => 'ඇඟවීම් සැකසුම්';

  @override
  String get atHome => 'නිවසේ';

  @override
  String get telegramBotDesc =>
      'බැඳී ඇති අන්තර්ක්‍රියාකාරී Telegram චැට් දැනුම්දීම්';

  @override
  String get alertChannels => 'ඇඟවීම් නාලිකා';

  @override
  String get london => 'ලන්ඩන්';

  @override
  String get shieldProtection => 'Shield ආරක්ෂාව';

  @override
  String get legalPolicies => 'නෛතික සහ ප්‍රතිපත්ති';

  @override
  String get supportVisaMastercard =>
      'ආරක්ෂිත Visa සහ MasterCard හර හෝ ණය සහාය දක්වයි';

  @override
  String get exportMyData => 'මගේ දත්ත අපනයනය කරන්න';

  @override
  String get dangerZone => 'අනතුරු කලාපය';

  @override
  String get analyticsTrackingDesc =>
      'නිර්නාමික භාවිත දත්ත බෙදාහදා ගැනීමෙන් යෙදුම වැඩිදියුණු කිරීමට අපට උදව් කරන්න. අක්‍රිය කළහොත් අත්‍යවශ්‍ය යෙදුම් කාර්යයන්ට බලපෑමක් නොවේ';

  @override
  String get autoFundingRules => 'ස්වයං-අරමුදල් නීති';

  @override
  String get singapore => 'සිංගප්පූරුව';

  @override
  String get weeklySummaryDigest => 'සතිපතා සාරාංශ ඒකාංකය';

  @override
  String get fullyShielded => 'සම්පූර්ණයෙන් ආරක්ෂිතයි';

  @override
  String get dndDesc =>
      'සාමාන්‍ය දැනුම්දීම් නිහඬ වේලාව අවසන් වන තුරු රඳවා තබයි. හදිසි රේඛා අනතුරු ඇඟවීම් කලින් පැමිණිය හැක; දුරකථනයේ බාධා නොකරන්න සැකසුම ක්‍රියාත්මක වේ.';

  @override
  String get paymentsAutoFundTitle => 'ගෙවීම් සහ ස්වයං-අරමුදල්';

  @override
  String get travelGeolocationTitle => 'සංචාරය සහ භූ-ස්ථාන';

  @override
  String get telegramBot => 'Telegram බොට්';

  @override
  String get weeklyDigestDesc =>
      'සෑම ඉරිදාම දේශීය වේලාවෙන් උදේ 9:00 ට සතිපතා SIM තත්ත්ව සාරාංශය';

  @override
  String get borderSimulatorDesc =>
      'ස්මාර්ට් කැටිගැස්සීම හෝ ක්‍රියාකාරී රට නැවත ආරම්භ කිරීමේ නීති ක්‍රියාත්මක කිරීමට නැව්ගත කිරීම් අනුකරණය කරන්න.';

  @override
  String get linkFirstCard => 'ඔබේ පළමු ගෙවීම් කාඩ්පත සම්බන්ධ කරන්න';

  @override
  String get globalTravelMode => 'ගෝලීය සංචාර මාදිලිය';

  @override
  String get readPrivacyPolicy =>
      'සම්පූර්ණ රහස්‍යතා ප්‍රතිපත්තිය සහ කොන්දේසි කියවන්න';

  @override
  String get whatsappAlertsDesc =>
      'WhatsApp වෙත සෘජුවම push කෙරෙන පිරවීම් අසාර්ථකත්ව ඇඟවීම්';

  @override
  String get abroadTraveling => 'විදේශ / සංචාරය';

  @override
  String get freezeAllLines => 'සියලු රේඛා කැටිගස්සන්න';

  @override
  String get resumeRenewals => 'අලුත් කිරීම් නැවත ආරම්භ කරන්න';

  @override
  String get freezeRecommendationDesc =>
      'ඔබ දැනට ඔබේ මව් රටේ සිටින බව අපි හඳුනා ගත්තෙමු. අනවශ්‍ය මුදල් පසුම්බි ශේෂ ක්ෂය වීම වැළැක්වීමට ඔබේ ජාත්‍යන්තර රේඛාවල අලුත් කිරීම් කැටිගස්සන්න.';

  @override
  String get travelDetected => 'සංචාරය හඳුනා ගන්නා ලදී! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'ඔබ විදේශ සංචාරයේ සිටිනවා. නිරන්තර ජංගම ජාල ආවරණය සහතික කිරීමට ඔබේ විරාම කරන ලද ජාත්‍යන්තර SIM අලුත් කිරීම් නැවත ආරම්භ කරන්න.';

  @override
  String get dismiss => 'ඉවත් කරන්න';

  @override
  String get welcomeHome => 'නිවසට සාදරයෙන් පිළිගනිමු! 🏡';

  @override
  String get addCard => 'කාඩ්පත එකතු කරන්න';

  @override
  String get noAlertChannelsConfigured => 'ඇඟවීම් ලබාදීමේ නාලිකා සකසා නැත.';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName සැකසුම් යාවත්කාලීන කෙරිණි.';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName අගුළු දමා ඇත 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName ඇඟවීම් Starter සහ Premium සැලැස්ම් විශේෂාංග වේ. WhatsApp, Telegram සහ ඊමේල් ඇඟවීම් අගුළු හැරීමට ඔබේ සැලැස්ම උසස් කරන්න!';
  }

  @override
  String get upsellProtect5Lines => 'එකවර SIM රේඛා 5ක් දක්වා ආරක්ෂා කරන්න';

  @override
  String get upsellUnlockChannels =>
      'WhatsApp, Telegram සහ ඊමේල් දැනුම්දීම් අගුළු හරින්න';

  @override
  String get upsellEnableTravelModes =>
      'සංචාර සහ නිවෙස් ස්වයංක්‍රීය වලංගු මාදිලි සක්‍රිය කරන්න';

  @override
  String get emailAddressLabel => 'දැනුම්දීම් ඊමේල් ලිපිනය';

  @override
  String get emailAddressHint => 'උදා: user@domain.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp අංකය (ජාත්‍යන්තර ආකෘතිය)';

  @override
  String get whatsappNumberHint => 'උදා: +96891234567';

  @override
  String get whatsappFormatInstruction =>
      '+ සමඟ ආරම්භ වන සම්පූර්ණ ජාත්‍යන්තර ආකෘතිය ඇතුළු කරන්න (උදා: +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'තත්ත්වය: සම්බන්ධිතයි (Chat ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'තත්ත්වය: අසම්බන්ධිතයි';

  @override
  String get telegramLinkInstructions =>
      'නිදහස්, අන්තර්ක්‍රියාකාරී Telegram ඇඟවීම් ලැබීමට, අපගේ Telegram Bot ඔබේ ගිණුමට සම්බන්ධ කරන්න.';

  @override
  String get linkTelegramBot => 'Telegram Bot සම්බන්ධ කරන්න';

  @override
  String get emailFreePlanGuarded =>
      'Resend නිදහස් සැලැස්ම ආරක්ෂිතයි: අක්‍රිය කිරීමේ ප්‍රේරක පමණක් ලෙස සීමා කෙරේ. ප්‍රවර්ධන ස්පෑම් නොමැත.';

  @override
  String get whatsappMetaCloudCapped =>
      'Meta Cloud Direct සීමා කෙරේ: ඉහළ නැංවීම් කාලසටහනකට උපරිම පණිවිඩ 1ක්, ස්වයං-පිරවීම ක්‍රියාශීලී නොවේ නම් හෝ අසාර්ථක නම් පමණක් යවනු ලැබේ.';

  @override
  String get failedToLoadPaymentInfo => 'ගෙවීම් තොරතුරු පූරණය කිරීම අසාර්ථකයි';

  @override
  String get defaultCardIndicator => 'පෙරනිමි';

  @override
  String get cardholder => 'කාඩ් හිමිකරු';

  @override
  String get expires => 'කල් ඉකුත් වේ';

  @override
  String get lowBalanceTrigger => 'අඩු ශේෂ ප්‍රේරකය';

  @override
  String get triggerLowTopUp => 'අඩු ඉහළ නැංවීම ක්‍රියාත්මක කරන්න';

  @override
  String get reloadDepositAmount => 'නැවත පූරණ තැන්පතු ප්‍රමාණය';

  @override
  String get amountToLoad => 'පූරණය කළ යුතු ප්‍රමාණය';

  @override
  String get linkCreditDebitCard => 'ණය/හර කාඩ්පත සම්බන්ධ කරන්න';

  @override
  String get cardNumberLabel => 'කාඩ් අංකය';

  @override
  String get expiryDateLabel => 'කල් ඉකුත් වීමේ දිනය';

  @override
  String get cvvCodeLabel => 'CVV කේතය';

  @override
  String get securelyLinkCard => 'ආරක්ෂිතව කාඩ්පත සම්බන්ධ කරන්න';

  @override
  String get pleaseEnterValidCardNumber =>
      'කරුණාකර වලංගු ඉලක්කම් 16ක් ඇති කාඩ් අංකයක් ඇතුළු කරන්න.';

  @override
  String get pleaseEnterValidExpiryDate =>
      'කරුණාකර වලංගු කල් ඉකුත් වීමේ දිනයක් (MM/YY) ඇතුළු කරන්න.';

  @override
  String get invalidExpiryMonth => 'අවලංගු කල් ඉකුත් වීමේ මාසය.';

  @override
  String get cvvMustBe3Digits => 'CVV ඉලක්කම් 3ක් විය යුතුයි.';

  @override
  String get cardLinkedSuccessfully =>
      'ආරක්ෂිත බිල් කාඩ්පත සාර්ථකව සම්බන්ධ කෙරිණි!';

  @override
  String get defaultPaymentCardUpdated =>
      'පෙරනිමි ගෙවීම් කාඩ්පත යාවත්කාලීන කෙරිණි!';

  @override
  String get removePaymentCard => 'ගෙවීම් කාඩ්පත ඉවත් කරන්න';

  @override
  String get confirmRemoveCardDesc =>
      'ඔබට මෙම කාඩ්පත ඉවත් කිරීමට අවශ්‍ය බව නිශ්චිතද? පෙරනිමි ගෙවීම් කාඩ්පතක් ඉතිරි නොවේ නම් සම්බන්ධිත ස්වයං-අරමුදල් අසාර්ථක විය හැක.';

  @override
  String get cancel => 'අවලංගු කරන්න';

  @override
  String get remove => 'ඉවත් කරන්න';

  @override
  String get billingCardSuccessfullyRemoved =>
      'බිල් කාඩ්පත සාර්ථකව ඉවත් කෙරිණි.';

  @override
  String get pleaseAddDefaultCardFirst =>
      'ස්වයං-අරමුදල් සක්‍රිය කිරීමට කරුණාකර මුලින් පෙරනිමි ගෙවීම් කාඩ්පතක් එකතු කර තෝරන්න.';

  @override
  String get autoFundPrefsSavedSuccess =>
      'ස්වයං-අරමුදල් මනාපයන් සාර්ථකව සුරකිණි!';

  @override
  String get preparingDataExport => 'දත්ත අපනයනය සූදානම් කරමින්...';

  @override
  String exportFailed(String error) {
    return 'අපනයනය අසාර්ථකයි: $error';
  }

  @override
  String get deleteAccountWarning =>
      'ඔබ ඔබේ ගිණුම මකා දැමූ පසු, ආපසු හැරවිය නොහැක. කරුණාකර නිශ්චිත වන්න.';

  @override
  String get deleteAccount => 'ගිණුම මකන්න';

  @override
  String get deleteAccountIrreversible =>
      'මෙම ක්‍රියාව ආපසු හැරවිය නොහැකි වේ. ඔබේ සියලු දත්ත ස්ථිරවම ඉවත් කෙරේ.';

  @override
  String get typeDeleteToConfirm => 'තහවුරු කිරීමට \"DELETE\" ටයිප් කරන්න:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'පද්ධති රෝග නිර්ණය ලොග්';

  @override
  String get online => 'සබැඳිව';

  @override
  String errorLoadingPrefs(String error) {
    return 'මනාපයන් පූරණය කිරීමේ දෝෂය: $error';
  }

  @override
  String get privacyPolicyLoaded => 'රහස්‍යතා ප්‍රතිපත්ති විස්තර පූරණය කෙරිණි.';

  @override
  String get protectionConsole => 'ආරක්ෂණ කොන්සෝලය';

  @override
  String get deleteProtectionTooltip => 'ආරක්ෂාව මකන්න';

  @override
  String get refreshTooltip => 'නැවුම් කරන්න';

  @override
  String get failedToLoadDetails => 'විස්තර පූරණය කිරීම අසාර්ථකයි';

  @override
  String get retryConnection => 'සම්බන්ධතාවය නැවත උත්සාහ කරන්න';

  @override
  String get healthLabel => 'සෞඛ්‍යය';

  @override
  String get mySimCardDefault => 'මගේ SIM කාඩ්';

  @override
  String get upLabel => 'සක්‍රිය';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'හවුල් කළේ: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'තීරණාත්මක අවදානම';

  @override
  String get simDeactivationRisk => 'ක්‍රියාවක් නොමැතිව SIM අක්‍රිය විය හැක';

  @override
  String get missingAlertsDesc =>
      'ඇඟවීම් දැනුම්දීම් සකසා නැත — ලකුණු 100ක් අඩුයි';

  @override
  String get missingAutoRefillDesc =>
      'ස්වයං-පිරවීම සකසා නැත — ලකුණු 50ක් අඩුයි';

  @override
  String get missingVerificationDesc =>
      'දුරකථන අංකය සත්‍යාපනය කර නැත — ලකුණු 25ක් අඩුයි';

  @override
  String get missingRecentRefillDesc =>
      'අවසන් පිරවීම දින 80කට වඩා පෙර විය — ලකුණු 25ක් අඩුයි';

  @override
  String get quickActionsLabel => 'ඉක්මන් ක්‍රියාවන්';

  @override
  String get manualRefillLabel => 'අතින් පිරවීම';

  @override
  String get chargeFromWalletNow => 'දැන් මුදල් පසුම්බියෙන් අය කරන්න';

  @override
  String get rechargeFromFriend => 'මිතුරෙකුගෙන් නැවත ආරෝපණය කරන්න';

  @override
  String get requestViaTelegram => 'Telegram හරහා ඉල්ලන්න';

  @override
  String get shareViaWaTg => 'WhatsApp/Telegram හරහා බෙදාහරින්න';

  @override
  String get testSimActivity => 'SIM ක්‍රියාකාරකම් පරීක්ෂා කරන්න';

  @override
  String get verifyLineReachable => 'රේඛාව ළඟා කළ හැකිදැයි සත්‍යාපනය කරන්න';

  @override
  String get checkCompleted1x => '1x පරීක්ෂාව සම්පූර්ණයි';

  @override
  String get starterPlan1xCompleted =>
      'Starter සැලැස්ම 1x පරීක්ෂාව සම්පූර්ණයි. අසීමිත පරීක්ෂා සඳහා Premium වෙත උසස් කරන්න.';

  @override
  String leaveCountry(String countryName) {
    return '$countryName හැර යන්න';
  }

  @override
  String get resumeProtectionLayers => 'ආරක්ෂණ ස්ථර නැවත ආරම්භ කරන්න';

  @override
  String backToCountryMode(String countryName) {
    return '$countryName මාදිලියට ආපසු';
  }

  @override
  String get pauseWhileVisitingHome => 'නිවස බලා ගිය විට විරාම කරන්න';

  @override
  String get rechargeFromFriendTitle => 'මිතුරෙකුගෙන් නැවත ආරෝපණය කරන්න';

  @override
  String get selectPlatformShare =>
      'ඔබේ මිතුරා සමඟ නැවත ආරෝපණ ඉල්ලීම් පණිවිඩයක් බෙදාගැනීමට වේදිකාවක් තෝරන්න.';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'හෙලෝ! මගේ KeepSIMs කාඩ් ($phone) ඉක්මනින් කල් ඉකුත් වේ. ඔබට එය මා වෙනුවෙන් නැවත ආරෝපණය කළ හැකිද? ස්තූතියි!';
  }

  @override
  String get requestViaWhatsApp => 'WhatsApp හරහා ඉල්ලන්න';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return '$platformName සබැඳිය විවෘත කළ නොහැකි විය: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Telegram සබැඳිය විවෘත කළ නොහැකි විය: $error';
  }

  @override
  String get protectionLayersLabel => 'ආරක්ෂණ ස්ථර';

  @override
  String get autoNotifyDisabled => 'ස්වයං-දැනුම්දීම: අක්‍රියයි';

  @override
  String get noActiveAlertSchedule =>
      'ඔබේ SIM කාඩ්පතේ ක්‍රියාකාරී ඇඟවීම් දැනුම්දීම් කාලසටහනක් නොමැත. ඔබට ස්වයංක්‍රීය මතක් කිරීම් හෝ අක්‍රිය කිරීමේ ඇඟවීම් ලැබෙන්නේ නැත.';

  @override
  String get askOwnerConfigureAlerts =>
      'කරුණාකර ගෘහ හිමිකාරයාගෙන් ඇඟවීම් සකස් කිරීමට ඉල්ලන්න.';

  @override
  String get configureAutoNotify => 'ස්වයං-දැනුම්දීම වින්‍යාස කරන්න';

  @override
  String get activeLabel => 'ක්‍රියාකාරී';

  @override
  String get pausedHomeMode => 'විරාම (නිවෙස් මාදිලිය)';

  @override
  String get pausedLabel => 'විරාම';

  @override
  String get everyHour => 'සෑම පැයකට';

  @override
  String everyNDays(int days) {
    return 'සෑම දින $daysකට';
  }

  @override
  String get nextAlertCheck => 'ඊළඟ ඇඟවීම් පරීක්ෂාව';

  @override
  String get premiumKeepAliveRefill => 'Premium Keep-Alive පිරවීම';

  @override
  String autoRefillIncludedText(String date) {
    return 'ස්වයං-පිරවීම ඇතුළත් - දින 85කට ~3.5 USD (විදුලි සංදේශ, VAT ඇතුළත්),\\nඊළඟ පිරවීම $date දින';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'Premium keep-alive පිරවීම දැනට අක්‍රියයි.';

  @override
  String get customAutoRefill => 'අභිරුචි ස්වයං-පිරවීම';

  @override
  String get addAdditionalScheduledRecharge =>
      'ඔබේ SIM හිදී අමතර ශේෂයක් තබා ගැනීමට අතිරේක නියමිත නැවත ආරෝපණ ප්‍රමාණයක් එකතු කරන්න.';

  @override
  String get askOwnerConfigureRefill =>
      'කරුණාකර ගෘහ හිමිකාරයාගෙන් ස්වයං-පිරවීම සකස් කිරීමට ඉල්ලන්න.';

  @override
  String get configureCustomAutoRefill => 'අභිරුචි ස්වයං-පිරවීම වින්‍යාස කරන්න';

  @override
  String get rechargeAmount => 'නැවත ආරෝපණ ප්‍රමාණය';

  @override
  String get refillInterval => 'පිරවීම් කාල පරාසය';

  @override
  String get nextRefillDue => 'ඊළඟ නිශ්චිත පිරවීම';

  @override
  String get failedRefillAttempts => 'අසාර්ථක පිරවීම් උත්සාහ';

  @override
  String retriesCount(int count) {
    return '$count / 4 නැවත උත්සාහ';
  }

  @override
  String get editRefillAmount => 'පිරවීමේ ප්‍රමාණය සංස්කරණය කරන්න';

  @override
  String get refillExecutionsHistory => 'පිරවීම් ක්‍රියාත්මක කිරීම් ඉතිහාසය';

  @override
  String get renewalExecutionsHistory =>
      'අලුත් කිරීම් ක්‍රියාත්මක කිරීම් ඉතිහාසය';

  @override
  String get noHistoricalTopup =>
      'මෙම රේඛාව සඳහා තවම ඓතිහාසික ඉහළ නැංවීම් ක්‍රියාත්මක කිරීම් වාර්තා නොකෙරිණි.';

  @override
  String get noHistoricalRenewal =>
      'මෙම රේඛාව සඳහා තවම ඓතිහාසික අලුත් කිරීම් ක්‍රියාත්මක කිරීම් වාර්තා නොකෙරිණි.';

  @override
  String get viewAllHistory => 'සම්පූර්ණ ඉතිහාසය බලන්න';

  @override
  String get securityActivityLogs => 'ආරක්ෂණ ක්‍රියාකාරකම් ලොග්';

  @override
  String get clearLogs => 'ලොග් හිස් කරන්න';

  @override
  String get noActivityLogsRecorded =>
      'මෙම රේඛාව සඳහා තවම ක්‍රියාකාරකම් ලොග් වාර්තා නොකෙරිණි.';

  @override
  String get activityLogDeleted =>
      'ක්‍රියාකාරකම් ලොග් ඇතුළත්කිරීම මකා දමන ලදී.';

  @override
  String get activityLogsCleared => 'ක්‍රියාකාරකම් ලොග් සාර්ථකව හිස් කෙරිණි.';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'ස්වයං-අලුත් කිරීම සාර්ථකව $status.';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'කාලසටහන යාවත්කාලීන කිරීම අසාර්ථකයි: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'Premium keep-alive පිරවීම සාර්ථකව සක්‍රිය කෙරිණි.';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'ස්වයං-පිරවීම සක්‍රිය කිරීම අසාර්ථකයි: $error';
  }

  @override
  String get removeScheduleTitle => 'කාලසටහන ඉවත් කරන්න';

  @override
  String get confirmDeleteAutoRefill =>
      'ඔබට මෙම ස්වයං-පිරවීම් කාලසටහන මකා දැමීමට අවශ්‍ය බව නිශ්චිතද? ඔබේ SIM සෞඛ්‍ය ලකුණු සැලකිය යුතු ලෙස අඩු වී, අක්‍රිය වීමේ අවදානමට ලක්වේ.';

  @override
  String get confirmDeleteAutoRenewal =>
      'ඔබට මෙම ස්වයං-අලුත් කිරීම් කාලසටහන මකා දැමීමට අවශ්‍ය බව නිශ්චිතද? ඔබේ SIM සෞඛ්‍ය ලකුණු සැලකිය යුතු ලෙස අඩු වී, අක්‍රිය වීමේ අවදානමට ලක්වේ.';

  @override
  String get autoRefillRemoved => 'ස්වයං-පිරවීම් කාලසටහන සාර්ථකව ඉවත් කෙරිණි.';

  @override
  String get autoRenewalRemoved =>
      'ස්වයං-අලුත් කිරීම් කාලසටහන සාර්ථකව ඉවත් කෙරිණි.';

  @override
  String failedToDeleteSchedule(String error) {
    return 'කාලසටහන මකා දැමීම අසාර්ථකයි: $error';
  }

  @override
  String get refillRetrySuccess =>
      'පිරවීම් නැවත උත්සාහය සාර්ථකව සම්පූර්ණ කෙරිණි!';

  @override
  String get refillRetryQueued =>
      'නැවත උත්සාහය පේළිගත කෙරිණි — පිරවීම සැකසෙමින් පවතී.';

  @override
  String get renewalRetrySuccess =>
      'අලුත් කිරීම් නැවත උත්සාහය සාර්ථකව සම්පූර්ණ කෙරිණි!';

  @override
  String retryFailed(String error) {
    return 'නැවත උත්සාහය අසාර්ථකයි: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'නැවත උත්සාහ ක්‍රියාත්මක කිරීමේ දෝෂය: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'ක්‍රියාකාරකම් ලොගය මකා දැමීම අසාර්ථකයි: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'ක්‍රියාකාරකම් ලොග් හිස් කිරීම අසාර්ථකයි: $error';
  }

  @override
  String get removeProtectionTitle => 'ආරක්ෂාව ඉවත් කරන්න';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return 'ඔබට $name ආරක්ෂිතව තබා ගැනීම නවත්වීමට අවශ්‍ය බව නිශ්චිතද? මෙම SIM රේඛාව සඳහා නියමිත ඉහළ නැංවීම් ස්ථිරවම අවලංගු කෙරේ.';
  }

  @override
  String get simLineProtectionRemoved =>
      'SIM රේඛා ආරක්ෂාව සාර්ථකව ඉවත් කෙරිණි.';

  @override
  String failedToDeleteSimLine(String error) {
    return 'මකා දැමීම අසාර්ථකයි: $error';
  }

  @override
  String get editSimNameTitle => 'SIM නාමය සංස්කරණය කරන්න';

  @override
  String get enterNicknameInstruction =>
      'මෙම SIM කාඩ් රේඛාව සඳහා අන්වර්ථ නාමයක් ඇතුළු කරන්න:';

  @override
  String get nicknameExampleHint => 'උදා: මගේ Orange Egypt SIM';

  @override
  String get simNameUpdatedSuccess => 'SIM නාමය සාර්ථකව යාවත්කාලීන කෙරිණි.';

  @override
  String failedToUpdateSimName(String error) {
    return 'SIM නාමය යාවත්කාලීන කිරීම අසාර්ථකයි: $error';
  }

  @override
  String get saveButton => 'සුරකින්න';

  @override
  String get deleteButton => 'මකන්න';

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
  String get autoNotifySchedule => 'ස්වයං-දැනුම්දීම් කාලසටහන';

  @override
  String get renewalCheckInterval => 'අලුත් කිරීම් පරීක්ෂා කාල පරාසය';

  @override
  String get editNotificationConfig => 'දැනුම්දීම් වින්‍යාසය සංස්කරණය කරන්න';

  @override
  String get openTicket => 'ටිකට්පතක් විවෘත කරන්න';

  @override
  String get offlineRefillLabel => 'නොබැඳි පිරවීම';

  @override
  String get categoryLabel => 'කාණ්ඩය';

  @override
  String get techSupportCategory => 'තාක්ෂණික සහාය';

  @override
  String get billingWalletCategory => 'බිල් සහ මුදල් පසුම්බිය';

  @override
  String get simLinesCategory => 'SIM රේඛා කළමනාකරණය';

  @override
  String get feedbackOtherCategory => 'ප්‍රතිපෝෂණ සහ වෙනත්';

  @override
  String get subjectLabel => 'විෂය';

  @override
  String get subjectHint => 'ගැටලුවේ කෙටි සාරාංශය';

  @override
  String get descriptionLabel => 'විස්තරය';

  @override
  String get descriptionHint => 'ඔබේ ගැටලුව විස්තරාත්මකව විස්තර කරන්න...';

  @override
  String get attachmentLabel => 'අමුණා (විකල්ප)';

  @override
  String get uploadScreenshot => 'තිරපිටපත අップロード කරන්න';

  @override
  String get submitTicketButton => 'ටිකට්පත ඉදිරිපත් කරන්න';

  @override
  String get pleaseFillFields => 'කරුණාකර විෂය සහ විස්තරය දෙකම පුරවන්න';

  @override
  String get ticketSubmittedSuccess => 'ටිකට්පත සාර්ථකව ඉදිරිපත් කෙරිණි!';

  @override
  String get lastRefillLabel => 'අවසන් පිරවීම';

  @override
  String get noRefillYet => 'තවම පිරවීමක් නැත';

  @override
  String get nextAlertLabel => 'ඊළඟ ඇඟවීම';

  @override
  String get protectionLabel => 'ආරක්ෂාව';

  @override
  String get actionRequiredLabel => 'ක්‍රියාව අවශ්‍යයි';

  @override
  String get protectionOffLabel => 'ආරක්ෂාව අක්‍රියයි';

  @override
  String get notSet => 'සකස් කර නැත';

  @override
  String get homeMode => 'නිවෙස් මාදිලිය';

  @override
  String get keepProtectedAtHome => 'නිවසේදීත් ආරක්ෂාව පවත්වා ගන්න';

  @override
  String get protectionPausesAtHome => 'නිවසේදී ආරක්ෂාව විරාම වේ';

  @override
  String get incidentChannelsTitle => 'සිද්ධි නාලිකා';

  @override
  String get topUpSuccessTitle => 'ඉහළ නැංවීම සාර්ථකයි';

  @override
  String get topUpSuccessDesc =>
      'ස්වයංක්‍රීය SIM වලංගු දීර්ඝ කිරීමක් සාර්ථකව සම්පූර්ණ වූ විට දැනුම් දෙන්න.';

  @override
  String get topUpFailedTitle => 'ඉහළ නැංවීම අසාර්ථකයි (තීරණාත්මක)';

  @override
  String get topUpFailedDesc =>
      'සේවා සපයන්නා හෝ මුදල් පසුම්බි ගැටලු නිසා ස්වයංක්‍රීය ඉහළ නැංවීම් අසාර්ථක වූ විට තීරණාත්මක ඇඟවීම්.';

  @override
  String get walletLowTitle => 'මුදල් පසුම්බි ශේෂය අඩුයි';

  @override
  String get walletLowDesc =>
      'ප්‍රාථමික ශේෂය ආරක්ෂිත සීමාවට වඩා අඩු වූ විට අනතුරු ඇඟවීම.';

  @override
  String get walletDepletedTitle => 'මුදල් පසුම්බිය ක්ෂය වී ඇත';

  @override
  String get walletDepletedDesc =>
      'මුදල් පසුම්බි ශේෂය සම්පූර්ණයෙන් ක්ෂය වී අලුත් කිරීම් නතර වූ විට අත්හිටුවන ලද ඇඟවීම්.';

  @override
  String get lineCriticalTitle => 'වලංගු කල් ඉකුත් වීමේ අනතුරු ඇඟවීම';

  @override
  String get lineCriticalDesc =>
      'SIM වලංගු කාල සීමාව පැය 48 ක් ඇතුළත අවසන් වන විට අනතුරු ඇඟවීම.';

  @override
  String get lineEnteringGraceTitle => 'කිරුළු කාලයට ඇතුළු වීම';

  @override
  String get lineEnteringGraceDesc =>
      'සේවා සපයන්නා අක්‍රිය කිරීමේ කිරුළු කාල හඳුනාගත් විට දැනුම් දෙන්න.';

  @override
  String get geoFenceTriggeredTitle => 'ස්ථාන / රෝමිං ඇඟවීම්';

  @override
  String get geoFenceTriggeredDesc =>
      'සේවා සපයන්නා රෝමිං ගොනු හෝ ජාල නෝඩ් මාරු කළ විට ඇඟවීම්.';

  @override
  String get welcomeHomeReadyTitle => 'නිවස සිංක් සාදරයෙන් පිළිගනිමු';

  @override
  String get welcomeHomeReadyDesc =>
      'මව් රට ජාල නෝඩ් ස්වයංක්‍රීය සිංක් ක්‍රියාත්මක කළ විට ඇඟවීම්.';

  @override
  String get referralRewardTitle => 'යොමු සහ ත්‍යාග';

  @override
  String get referralRewardDesc =>
      'මිතුරු යොමු මගේ මුදල් පසුම්බියට ප්‍රවර්ධන ශේෂ තැන්පත් කළ විට දැනුම් දෙන්න.';

  @override
  String get systemUpdatesTitle => 'සාමාන්‍ය පද්ධති යාවත්කාලීන';

  @override
  String get systemUpdatesDesc =>
      'අත්‍යවශ්‍ය එන්ජින් යාවත්කාලීන, නඩත්තු සහ වේදිකා නිවේදන.';

  @override
  String get walletCreditTitle => 'පසුම්බියට බැර විය';

  @override
  String get walletCreditDesc =>
      'මගේ පසුම්බියට තැන්පතුවක් ලැබුණු විට මට දන්වන්න.';

  @override
  String get promoTitle => 'දීමනා සහ ප්‍රවර්ධන';

  @override
  String get promoDesc =>
      'ගනුදෙනු සහ නව විශේෂාංග ගැන ඉඳහිට පුවත්. ඔබ ක්‍රියාත්මක කරන තෙක් අක්‍රියව පවතී.';

  @override
  String get deliverVia => 'යවන්නේ';

  @override
  String get channelPushShort => 'පුෂ්';

  @override
  String get channelEmailShort => 'ඊමේල්';

  @override
  String get channelOffGlobally => 'ඉහත ඇඟවීම් නාලිකා තුළ අක්‍රියයි';

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
  String get rechargeNow => 'දැන් රීචාජ් කරන්න';

  @override
  String get planFeePaidFromWallet =>
      'සැලසුම් ගාස්තුව ඔබගේ පසුම්බි ශේෂයෙන් ගෙවන ලදී.';

  @override
  String get planFeeNotChargedRetry =>
      'ඔබගේ ඉහළ දැමීම ලැබුණද සැලසුම් ගාස්තුව අය කළ නොහැකි වූ බැවින් රේඛාව නිර්මාණය නොවීය. ඔබගේ ශේෂය ආරක්ෂිතයි — කරුණාකර නැවත උත්සාහ කරන්න.';

  @override
  String activityTopupRequested(String amount) {
    return '\$$amount සඳහා නැවත පිරවීමේ ඉල්ලීම යොමු කරන ලදී';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return '$provider හරහා \$$amount හි ටොප්-අප් සාර්ථක විය';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return '\$$amount හි ටොප්-අප් අසාර්ථක විය: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return '\$$amount හි නැවත පිරවීම පසුම්බියට ආපසු ගෙවන ලදී';
  }

  @override
  String activityTopupCancelled(String amount) {
    return '\$$amount හි නැවත පිරවීමේ ඉල්ලීම අවලංගු කරන ලදී';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return '\$$amount හි නැවත පිරවීම සඳහා නැවත උත්සාහ කිරීම පෝලිම් කරන ලදී';
  }

  @override
  String get activityLineCreated => 'SIM රේඛාව SIM Shield හි ලියාපදිංචි විය';

  @override
  String get activityHealthUpdate => 'SIM රේඛාවේ සක්‍රිය තත්ත්වය තහවුරු විය';

  @override
  String get activityReminderSent => 'නවීකරණ මතක් කිරීමේ දැනුම්දීම යවන ලදී';

  @override
  String get supportTicketsTitle => 'උදව් සහ සහාය';

  @override
  String get supportTicketsSubtitle =>
      'සහාය ඉල්ලීම් යොමු කරන්න, ක්‍රියාකාරකම් සටහන් අමුණන්න, සහ සහායක කණ්ඩායම සමඟ සජීවීව කතාබස් කරන්න.';

  @override
  String get supportTicketsEmpty => 'සහාය ටිකට්පත් කිසිවක් හමු නොවීය.';

  @override
  String get createSupportTicket => 'ටිකට්පතක් සාදන්න';

  @override
  String get ticketCategoryGeneral => 'සාමාන්‍ය විමසීම';

  @override
  String get ticketCategoryBilling => 'ගෙවීම් සහ පසුම්බිය';

  @override
  String get ticketCategoryTechnical => 'තාක්ෂණික ගැටලුව';

  @override
  String get ticketCategoryRefillIssue => 'නැවත පිරවීමේ ගැටලුව';

  @override
  String get ticketCategoryAccount => 'ගිණුම සහ ආරක්ෂාව';

  @override
  String get ticketStatusOpen => 'විවෘතයි';

  @override
  String get ticketStatusPending => 'පිළිතුරක් බලාපොරොත්තුවෙන්';

  @override
  String get ticketStatusResolved => 'විසඳන ලදී';

  @override
  String get ticketStatusClosed => 'වසා ඇත';

  @override
  String get ticketSubjectLabel => 'මාතෘකාව';

  @override
  String get ticketSubjectHint => 'ගැටලුවේ කෙටි විස්තරයක්';

  @override
  String get ticketCategoryLabel => 'වර්ගය';

  @override
  String get ticketMessageLabel => 'පණිවිඩය';

  @override
  String get ticketMessageHint => 'විස්තරාත්මක තොරතුරු සපයන්න...';

  @override
  String get attachImage => 'රූපයක් අමුණන්න';

  @override
  String get attachActivityLogs => 'රේඛීය සටහන් අමුණන්න';

  @override
  String get submitTicket => 'ටිකට්පත යොමු කරන්න';

  @override
  String get typeMessageHint => 'පණිවිඩයක් ලියන්න...';

  @override
  String get closeTicketButton => 'ටිකට්පත වසන්න';

  @override
  String get ticketClosedNotice => 'මෙම සහාය ටිකට්පත වසා ඇත.';

  @override
  String get attachedFiles => 'ඇමුණුම්';

  @override
  String get referralsTitle => 'යොමු කර උපයන්න';

  @override
  String get referralsSubtitle =>
      'මිතුරන්ට ආරාධනා කරන්න, ඔවුන්ගේ SIM සබ්ස්ක්‍රිප්ෂන් මගින් ලකුණු උපයන්න සහ පසුම්බි ණය ලබා ගන්න!';

  @override
  String get referralCode => 'ඔබගේ යොමු කිරීමේ කේතය';

  @override
  String get copyCode => 'කේතය පිටපත් කරන්න';

  @override
  String get codeCopied => 'යොමු කිරීමේ කේතය ක්ලිප්බෝඩ් එකට පිටපත් කරන ලදී!';

  @override
  String get shareCode => 'කේතය බෙදාගන්න';

  @override
  String get pointsBalance => 'ලකුණු ශේෂය';

  @override
  String get pointsUnit => 'ලකුණු';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return 'ඊළඟ \$2.00 ත්‍යාගය සඳහා තව ලකුණු $pointsNeeded ක් අවශ්‍යයි';
  }

  @override
  String get redeemButton => '\$2.00 සඳහා ලකුණු 10 ක් මාරු කරන්න';

  @override
  String get redeemSuccess =>
      '\$2.00 පසුම්බි ණය සඳහා ලකුණු 10 ක් සාර්ථකව මාරු කරන ලදී!';

  @override
  String get applyCodeTitle => 'ඔබ සතුව යොමු කිරීමේ කේතයක් තිබේද?';

  @override
  String get applyCodeHint => 'යොමු කිරීමේ කේතය ඇතුළත් කරන්න';

  @override
  String get applyCodeButton => 'කේතය යොදන්න';

  @override
  String get applyCodeSuccess => 'යොමු කිරීමේ කේතය සාර්ථකව යොදන ලදී!';

  @override
  String get referredFriendsTitle => 'යොමු කළ මිතුරන්';

  @override
  String get noReferredFriends =>
      'තවම මිතුරන් යොමු කර නොමැත. ආරම්භ කිරීමට ඔබගේ කේතය බෙදා ගන්න!';

  @override
  String get redemptionHistoryTitle => 'මාරු කිරීම් ඉතිහාසය';

  @override
  String get noRedemptions => 'තවම මාරු කිරීම් නොමැත.';

  @override
  String get pointHistoryTitle => 'ලකුණු ඉතිහාසය';

  @override
  String get noPointsEarned => 'තවම ලකුණු උපයා නොමැත.';

  @override
  String get howItWorksTitle => 'යොමු කර උපයන්න ක්‍රියා කරන ආකාරය';

  @override
  String get howItWorksStep1 =>
      '1. මිතුරන් සමඟ ඔබගේ සුවිශේෂී යොමු කේතය බෙදා ගන්න.';

  @override
  String get howItWorksStep2 =>
      '2. යොමු කළ මිතුරෙකු SIM මාර්ගයක් සම්බන්ධ කරගත් විට ලකුණු 1 ක් උපයන්න.';

  @override
  String get howItWorksStep3 =>
      '3. ඕනෑම වේලාවක \$2.00 පසුම්බි ණය සඳහා ලකුණු 10 ක් ලබා ගන්න!';

  @override
  String get geoTitle => 'ගමන් සහ භූ-ස්ථානය';

  @override
  String get geoSubtitle =>
      'ස්වයංක්‍රීය රට හඳුනාගැනීම සහ ජාත්‍යන්තර SIM රේඛා ආරක්ෂාව';

  @override
  String get currentCountryLabel => 'වත්මන් ස්ථානය';

  @override
  String get travelModeToggle => 'ගමන් ප්‍රකාරය';

  @override
  String get travelModeDescription =>
      'ජාත්‍යන්තර රේඛා ආරක්ෂාව කළමනාකරණය කිරීමට යෙදුම විවෘත කරන විට රට පරීක්ෂා කරන්න';

  @override
  String get geoNotice =>
      'ඔබ යෙදුම විවෘත කරන විට IP මගින් රට පරීක්ෂා කෙරේ. ස්ථාන අවසර අවශ්‍ය නොවේ.';

  @override
  String get freezeInternationalLines => 'ජාත්‍යන්තර රේඛා අත්හිටුවන්න';

  @override
  String get resumeInternationalLines => 'ජාත්‍යන්තර රේඛා නැවත ආරම්භ කරන්න';

  @override
  String get linesFrozenSuccess =>
      'ජාත්‍යන්තර SIM රේඛා අත්හිටුවන ලද අතර නැවත පිරවීම් තාවකාලිකව නවත්වන ලදී!';

  @override
  String get linesResumedSuccess =>
      'ජාත්‍යන්තර SIM රේඛා සහ නැවත පිරවීම් නැවත සක්‍රිය කරන ලදී!';

  @override
  String get alwaysProtectedBadge => 'සෑම විටම ආරක්ෂිතයි';

  @override
  String get detectedViaIp => 'IP මගින් හඳුනා ගන්නා ලදී';

  @override
  String get esimManagerTitle => 'eSIM කළමනාකරු';

  @override
  String get esimPlansTitle => 'eSIM පැකේජ';

  @override
  String get searchDestinationHint =>
      'ගමනාන්තය සොයන්න (උදා. ප්‍රංශය, එක්සත් ජනපදය)';

  @override
  String get selectDestinationTitle => 'ගමනාන්තය තෝරන්න';

  @override
  String get localTab => 'දේශීය';

  @override
  String get regionalTab => 'කලාපීය';

  @override
  String get globalTab => 'ගෝලීය';

  @override
  String get bestValueBadge => 'හොඳම වටිනාකම';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return 'දින $days';
  }

  @override
  String get buyPlanButton => 'පැකේජය මිලදී ගන්න';

  @override
  String get deviceIncompatibleNotice =>
      'ඔබගේ උපාංගය eSIM තාක්ෂණයට සහාය නොදක්වයි.';

  @override
  String get activationPolicyTitle => 'ක්‍රියාත්මක කිරීමේ ප්‍රතිපත්තිය';

  @override
  String get activationPolicyNotice =>
      'ඔබගේ ගමනාන්තයේ සහාය දක්වන ජාලයකට eSIM සම්බන්ධ වූ විට වලංගු කාලය ආරම්භ වේ.';

  @override
  String get coveredCountriesTitle => 'ඇතුළත් රටවල්';

  @override
  String get sortPriceLowToHigh => 'මිල: අඩු සිට වැඩි';

  @override
  String get sortPricePerGb => 'මිල / GB: අඩු සිට වැඩි';

  @override
  String get sortDataHighToLow => 'දත්ත: වැඩි සිට අඩු';

  @override
  String get filterAll => 'සියලුම පැකේජ';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ දින 15';

  @override
  String get filterUnlimited => 'අසීමිත';

  @override
  String get purchaseInNextRelease =>
      'Purchase flow will land in the next release (C9b).';

  @override
  String get confirmPurchaseTitle => 'eSIM මිලදී ගැනීම තහවුරු කරන්න';

  @override
  String get myEsimsTitle => 'මගේ eSIM';

  @override
  String get showQrCode => 'QR කේතය පෙන්වන්න';

  @override
  String get buyAgain => 'නැවත මිලදී ගන්න';

  @override
  String get dataRemaining => 'ඉතිරි දත්ත';

  @override
  String get archivedEsims => 'සංරක්ෂිත eSIM';

  @override
  String rateLimitExceeded(String seconds) {
    return 'අධික ඉල්ලීම් ගණනක්. නැවත උත්සාහ කිරීමට පෙර තත්පර $seconds ක් රැඳී සිටින්න.';
  }

  @override
  String get confirmDeleteButton => 'මැකීම තහවුරු කරන්න';

  @override
  String get cancelAccountDeletion => 'ගිණුම මැකීම අවලංගු කරන්න';

  @override
  String get accountScheduledForDeletion => 'ගිණුම මැකීමට නියමිතයි';

  @override
  String deletionScheduledNotice(String date) {
    return 'ඔබගේ ගිණුම අත්හිටුවා ඇති අතර $date දින ස්ථිරවම මැකීමට නියමිතයි.';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'ඔබගේ මුදල් පසුම්බි ශේෂය (\$$balance) සීමාව (\$1.00) ඉක්මවයි. කරුණාකර එය වියදම් කරන්න හෝ සහාය අමතන්න.';
  }

  @override
  String get payPalCheckoutTitle => 'PayPal ගෙවීම';

  @override
  String get payPalWalletTopUp => 'KeepSIMs පසුම්බිය නැවත පිරවීම';

  @override
  String get payPalPaySecurely => 'PayPal හරහා ආරක්ෂිතව ගෙවන්න';

  @override
  String get payPalRedirectInfo =>
      'ඔබගේ ගෙවීම අනුමත කිරීමට ඔබව PayPal වෙත යොමු කරනු ඇත.';

  @override
  String get payPalCreatingOrder => 'ආරක්ෂිත PayPal ඇණවුමක් සාදමින්...';

  @override
  String get payPalAwaitingConfirmation => 'PayPal තහවුරු කිරීම අපේක්ෂාවෙන්...';

  @override
  String get payPalCompleteInBrowser =>
      'කරුණාකර විවෘත කළ බ්‍රවුසර් කවුළුවෙහි ගෙවීම සම්පූර්ණ කරන්න.';

  @override
  String get payPalPaymentConfirmed => 'ගෙවීම තහවුරු විය!';

  @override
  String get payPalPaymentFailed => 'ගෙවීම අසාර්ථක විය හෝ අවලංගු විය.';

  @override
  String get payPalForceCaptureButton => 'මම PayPal හි ගෙවීම සම්පූර්ණ කළෙමි';

  @override
  String get payPalBrowserOpened => 'PayPal ඔබේ බ්‍රවුසරයේ විවෘතව ඇත';

  @override
  String get payPalBrowserOpenedBody =>
      'ගෙවීම එහිදී සම්පූර්ණ කරන්න — මෙම තිරය ස්වයංක්‍රීයව යාවත්කාලීන වේ.';

  @override
  String get payPalTakingLonger =>
      'සාමාන්‍යයෙන් වඩා වැඩි කාලයක් ගත වේ. ඔබ දැනටමත් ගෙවා ඇත්නම්, පහත පරීක්ෂා කරන්න.';

  @override
  String get payPalReopenButton => 'PayPal නැවත විවෘත කරන්න';

  @override
  String get payPalVerifying => 'ඔබේ ගෙවීම සත්‍යාපනය කරමින්…';

  @override
  String get payPalVerifyingBody =>
      'PayPal සමඟ තහවුරු කරන තෙක් මොහොතක් රැඳී සිටින්න.';

  @override
  String get payPalPaymentCancelled =>
      'ගෙවීම අවලංගු කරන ලදී. ඔබෙන් කිසිදු මුදලක් අය කර නොමැත.';

  @override
  String get payPalDoneButton => 'නිමයි';

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
  String get householdTitle => 'නිවස සහ පවුල';

  @override
  String get householdTabMyFamily => 'මගේ පවුල';

  @override
  String get householdTabReceived => 'ආරාධනා';

  @override
  String get householdTabJoined => 'සම්බන්ධ වූ';

  @override
  String get householdInviteMember => 'සාමාජිකයෙකු ආරාධනා කරන්න';

  @override
  String get householdEmptyTitle => 'තවම පවුලේ සාමාජිකයන් නැත';

  @override
  String get householdEmptyDesc =>
      'ඔබේ පෙරගෙවුම් SIM ලයින් සහ අලුත් කිරීම් බෙදාගැනීමට ඊමේල් මගින් කෙනෙකුට ආරාධනා කරන්න.';

  @override
  String get householdStatusPending => 'පොරොත්තුවෙන්';

  @override
  String get householdStatusAccepted => 'සක්‍රියයි';

  @override
  String get householdPendingHint => 'ඔවුන් පිළිගන්නා තෙක් රැඳී සිටී';

  @override
  String get householdRoleViewer => 'නරඹන්නා';

  @override
  String get householdRoleManager => 'කළමනාකරු';

  @override
  String get householdRoleViewerHint => 'ඔබේ ලයින් බැලිය හැක';

  @override
  String get householdRoleManagerHint => 'ඔබේ ලයින් බලා ටොප්අප් කළ හැක';

  @override
  String get householdManagerWarning =>
      'කළමනාකරුවෙකුට ඔබේ ලයින් ටොප්අප් කළ හැක. ඔබ සීමාවක් දැමුවහොත් පමණක් ඔවුන් ඔබේ පසුම්බිය භාවිත කරයි.';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'මගේ පසුම්බියෙන් වියදම් · මෙම මාසයේ $cap න් $spent';
  }

  @override
  String get householdPaysOwnWallet => 'තමන්ගේ පසුම්බියෙන් ගෙවයි';

  @override
  String get householdManagersOnly =>
      'කළමනාකරුවන්ට පමණි — නරඹන්නෙකුට ඔබේ පසුම්බිය භාවිත කළ නොහැක';

  @override
  String get householdChangeLimit => 'සීමාව වෙනස් කරන්න';

  @override
  String get householdSetLimit => 'සීමාවක් දමන්න';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining ඉතිරියි · $queued පෝලිමේ, තවම අය කර නැත';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return 'මෙම මාසයේ $remaining ඉතිරියි';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return '$name සඳහා වියදම් සීමාව';
  }

  @override
  String get householdSpendingLimitDesc =>
      'සෑම දින දර්ශන මාසයකම ඔබේ ලයින් සඳහා ඔවුන්ට ඔබේ පසුම්බියෙන් වියදම් කළ හැකි ප්‍රමාණය. ක්‍රියා විරහිත කිරීමට 0 දමන්න — එවිට ඔවුන් තමන්ගේ පසුම්බියෙන් ගෙවනු ඇත.';

  @override
  String get householdMonthlyLimit => 'මාසික සීමාව (USD)';

  @override
  String get householdMaxPerRefill => 'එක් ටොප්අප් එකකට උපරිම (විකල්ප)';

  @override
  String get householdSave => 'සුරකින්න';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name හට දැන් මසකට ඔබේ පසුම්බියෙන් $cap දක්වා වියදම් කළ හැක.';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name නැවතත් තමන්ගේ පසුම්බියෙන් ගෙවයි.';
  }

  @override
  String get householdLimitFailed => 'සීමාව යාවත්කාලීන කළ නොහැකි විය.';

  @override
  String get householdNoInvitesTitle => 'ආරාධනා නැත';

  @override
  String get householdNoInvitesDesc =>
      'යමෙකු ඔබට ඔවුන්ගේ පවුලට ආරාධනා කළ විට එය මෙහි පෙන්වයි.';

  @override
  String get householdFamilyAccount => 'පවුලේ ගිණුම';

  @override
  String get householdInvitedYouViewer =>
      'ඔවුන්ගේ SIM ලයින් බැලීමට ඔබට ආරාධනා කර ඇත';

  @override
  String get householdInvitedYouManager =>
      'ඔවුන්ගේ SIM ලයින් බලා ටොප්අප් කිරීමට ඔබට ආරාධනා කර ඇත';

  @override
  String get householdAccept => 'පිළිගන්න';

  @override
  String get householdDecline => 'ප්‍රතික්ෂේප කරන්න';

  @override
  String get householdNotJoinedTitle => 'ඔබ කිසිදු පවුලකට සම්බන්ධ වී නැත';

  @override
  String get householdNotJoinedDesc => 'ඔබට ලැබෙන ආරාධනා ආරාධනා ටැබයේ පෙන්වයි.';

  @override
  String get householdSharedHousehold => 'බෙදාගත් පවුල';

  @override
  String get householdRoleManagerFull => 'කළමනාකරු · ටොප්අප් කළ හැක';

  @override
  String get householdRoleViewerFull => 'නරඹන්නා · කියවීම පමණි';

  @override
  String get householdLeave => 'ඉවත් වන්න';

  @override
  String householdOwnerFunds(String owner) {
    return '$owner ඔබේ ටොප්අප් සඳහා මුදල් සපයයි';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'ඔබ මෙම මාසයේ මුළු $cap ම භාවිත කර ඇත. නැවත සකසන තෙක් ඔවුන්ගේ ලයින් සඳහා ටොප්අප් ප්‍රතික්ෂේප වේ.';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return 'මෙම මාසයේ $cap න් $remaining ඉතිරියි';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · එක් ටොප්අප් එකකට උපරිම $perTxn';
  }

  @override
  String get householdInviteTitle => 'පවුලේ සාමාජිකයෙකුට ආරාධනා කරන්න';

  @override
  String get householdInviteDesc =>
      'ඔවුන්ට යෙදුම තුළම ආරාධනාව ලැබේ. පිළිගත් පසු ඔබේ සහ ඔවුන්ගේ SIM ලයින් එකට පෙන්වයි.';

  @override
  String get householdEmailLabel => 'ඊමේල් ලිපිනය';

  @override
  String get householdAccessLevel => 'ඔවුන්ට කුමක් කළ හැකිද?';

  @override
  String get householdSendInvite => 'ආරාධනාව යවන්න';

  @override
  String get householdInvalidEmail =>
      'කරුණාකර වලංගු ඊමේල් ලිපිනයක් ඇතුළත් කරන්න';

  @override
  String householdInviteSent(String email) {
    return '$email වෙත ආරාධනාව යවන ලදී';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return '$email වෙත ආරාධනාව යවන ලදී. ලියාපදිංචි වූ විගස ඔවුන් එය දකිනු ඇත.';
  }

  @override
  String get householdInviteAccepted => 'ඔබ පවුලට සම්බන්ධ විය';

  @override
  String get householdInviteDeclined => 'ආරාධනාව ප්‍රතික්ෂේප කරන ලදී';

  @override
  String get householdRemoveTitle => 'පවුලේ සාමාජිකයා ඉවත් කරන්න';

  @override
  String householdRemoveConfirm(String name) {
    return '$name හට වහාම ඔබේ SIM ලයින් වෙත ප්‍රවේශය සහ ඔබ දැමූ ඕනෑම වියදම් සීමාවක් අහිමි වේ.';
  }

  @override
  String householdRemoved(String name) {
    return '$name ඔබේ පවුලෙන් ඉවත් කරන ලදී';
  }

  @override
  String get householdLeaveTitle => 'පවුලෙන් ඉවත් වන්න';

  @override
  String householdLeaveConfirm(String owner) {
    return '$owner බෙදාගත් SIM ලයින් වෙත ඔබේ ප්‍රවේශය අහිමි වේ.';
  }

  @override
  String get householdLeft => 'ඔබ පවුලෙන් ඉවත් විය';

  @override
  String get householdActionFailed => 'එය සාර්ථක නොවීය. නැවත උත්සාහ කරන්න.';

  @override
  String get householdOwnerLabel => 'ඔබ (හිමිකරු)';

  @override
  String get householdSettingsSubtitle =>
      'ඔබේ SIM ලයින් පවුලේ අය සමඟ බෙදාගෙන වියදම් සීමා දමන්න';

  @override
  String get householdStatusDeclined => 'ප්‍රතික්ෂේපිතයි';

  @override
  String get householdDeclinedHint =>
      'ඔවුන් ප්‍රතික්ෂේප කළා. නැවත ආරාධනා කිරීමට ඉවත් කරන්න.';

  @override
  String get carrierActivityFallbackOperator => 'මෙම වාහකයා';

  @override
  String get carrierUsageRequiredTitle =>
      'ස්වයංක්‍රීය රීෆිල් මගින් මෙම රේඛාව ආරක්ෂා කළ නොහැක';

  @override
  String carrierUsageRequiredBody(String operator) {
    return '$operator නිෂ්ක්‍රියතා ගණන් කිරීම ආරම්භ කරන්නේ ඇමතුමක්, කෙටි පණිවිඩයක් හෝ දත්ත භාවිතයක් සිදු කළ විට පමණි. ශේෂය එකතු කිරීම එයට ගණන් නොගැනේ, එබැවින් කිසිදු ස්වයංක්‍රීය රීෆිල් එකකට මෙම අංකය අක්‍රිය වීම නවත්වාගත නොහැක. ස්ටෑන්ඩඩ් සැලැස්ම තෝරන්න — ඔබටම රේඛාව භාවිත කිරීමට ඉඩ ලැබෙන ලෙස වේලාවට අපි ඔබට දැනුම් දෙන්නෙමු.';
  }

  @override
  String get carrierMinDenominationTitle =>
      'මෙම වාහකයාට වඩා විශාල රීෆිල් එකක් අවශ්‍යයි';

  @override
  String carrierMinDenominationBody(
    String operator,
    String amount,
    String currency,
  ) {
    return '$operator රේඛා වලංගුතාවය එකතු කරන්නේ $amount $currency හෝ ඊට වැඩි රීෆිල් සඳහා පමණි. ඊට අඩු ඕනෑම මුදලක් වියදම් කළ හැකි ශේෂයක් ලෙස පමණක් පැමිණේ, තවමත් අංකය අක්‍රිය විය හැක, එබැවින් ප්‍රිමියම් මෙම රේඛාව $amount $currency වලින් රීෆිල් කරයි.';
  }

  @override
  String get premiumUnavailableForCarrier =>
      'මෙම වාහකයා සඳහා ප්‍රිමියම් ලබා ගත නොහැක';

  @override
  String get carrierRulesLinkLabel => 'මෙම වාහකයාගේ නීති ගැන තව';

  @override
  String get carrierRulesSheetTitle => 'අංකය අක්‍රිය වන නීති';

  @override
  String carrierRulesHowTitle(String operator) {
    return '$operator තීරණය කරන ආකාරය';
  }

  @override
  String carrierRechargeOkBody(String operator) {
    return '$operator රේඛාවට රීලෝඩ් කරන සෑම විටම එහි ගණන් කිරීම නැවත ආරම්භ කරයි, මුදල කුමක් වුවත්. ස්වයංක්‍රීය රීෆිල් එකකින් මෙහි අංකය රැක ගත හැක්කේ එබැවිනි.';
  }

  @override
  String get carrierRulesNumbersTitle => 'සංඛ්‍යා';

  @override
  String carrierRulesWindowRow(int days) {
    return 'වලංගු රීලෝඩයක් නොමැතිව දින $daysකින් පසු අක්‍රිය කරයි';
  }

  @override
  String carrierRulesGraceRow(int days) {
    return 'ඉන් පසු එම අංකයම නැවත ලබා ගැනීමට දින $daysක්';
  }

  @override
  String get carrierRulesNoGraceRow =>
      'නැවත ලබා ගැනීමේ කාලයක් නැත — අංකය වහාම නිදහස් කරයි';

  @override
  String carrierRulesMinTopupRow(String amount, String currency) {
    return 'වලංගුතාව එකතු කරන කුඩාම රීලෝඩය $amount $currency වේ';
  }

  @override
  String carrierRulesCadenceRow(int days, int count) {
    return 'අපි දින $daysකට වරක් රීෆිල් කරමු — වසරකට $count වතාවක්';
  }

  @override
  String get carrierRulesVerdictTitle => 'අපි කරන්නේ කුමක්ද';

  @override
  String get carrierVerdictSelfServiceTitle =>
      'මෙම රේඛාවට ප්‍රිමියම් මිලදී නොගන්න';

  @override
  String get carrierVerdictSelfServiceBody =>
      'ඔබේ මුදල් තබා ගන්න. අපට යැවිය හැකි කිසිවක් මෙම වාහකයාගේ ඔරලෝසුව නැවත ආරම්භ නොකරයි; අංකය රැකෙන එකම ක්‍රමය එය භාවිත කිරීමයි.';

  @override
  String get carrierVerdictStandardTitle => 'මෙහිදී ස්ටෑන්ඩර්ඩ් ප්‍රමාණවත්';

  @override
  String get carrierVerdictStandardBody =>
      'මෙම වාහකයා ඔබට දිගු කාලයක් දෙයි. දිනය අපි බලාගෙන ඔබට දන්වන්නම්; එවිට ඔබම රීලෝඩ් කරන්න, එවිට ගෙවන්නේ රීලෝඩ් මුදල පමණි.';

  @override
  String get carrierVerdictPremiumWorthTitle => 'ප්‍රිමියම් වටිනවා';

  @override
  String get carrierVerdictPremiumWorthBody =>
      'වසරකට රීෆිල් කිහිපයක්, එකිනෙක මෙතැනින් නොපෙනෙන දිනවල. කැමති නම් අතින්ම කළ හැකියි — ස්වයංක්‍රීය කිරීම කියන්නේ ඒ ගැන කිසිදා සිතන්නට නොවීමයි.';

  @override
  String get carrierVerdictPremiumMustTitle => 'මෙය ස්වයංක්‍රීය කරන්න';

  @override
  String get carrierVerdictPremiumMustBody =>
      'මෙම වාහකයා තරමක් වේගවත් නිසා වෙනත් රටක සිට සෑම වතාවකම මතක තබා ගැනීම කවදා හෝ අතපසු වේ — එක් අතපසුවීමක් යනු අංකයමයි.';

  @override
  String get carrierReasonUsageOnly =>
      'ගණන් ගන්නේ ඇමතුමක්, කෙටි පණිවුඩයක් හෝ දත්ත භාවිතයක් පමණි. ශේෂය පමණක් නොවේ.';

  @override
  String carrierReasonQualifying(String amount, String currency) {
    return '$amount $currencyට වඩා අඩු රීලෝඩයක් ශේෂයක් ලෙස පමණක් එකතු වන අතර වලංගුතාවක් නොදෙයි.';
  }

  @override
  String carrierReasonShortWindow(int days) {
    return 'වලංගු රීලෝඩ් දෙකක් අතර ඇත්තේ දින $daysක් පමණි.';
  }

  @override
  String carrierReasonLongWindow(int days) {
    return 'දින $days යනු වසරකට ආසන්නයි — එක් මතක් කිරීමක් ප්‍රමාණවත්.';
  }

  @override
  String get carrierReasonNoGrace =>
      'සහන කාලයක් නැත. දිනය මඟ හැරුණොත් අංකය නැති වේ.';

  @override
  String carrierReasonGrace(int days) {
    return 'දිනයෙන් පසු අංකය නැවත ලබා ගැනීමට ඔබට දින $daysක් ඇත.';
  }

  @override
  String carrierReasonAutomationCost(
    String self,
    String premium,
    String extra,
  ) {
    return 'රීලෝඩ් මුදල පමණක් වසරකට $self පමණ වේ. ප්‍රිමියම් $premium වන අතර, එයින් $extra ස්වයංක්‍රීයකරණයට යයි.';
  }

  @override
  String carrierSelfServiceTitle(String operator) {
    return 'නැත්නම් $operatorගෙන් සෘජුවම ගන්න';
  }

  @override
  String get carrierSelfServiceBody =>
      'වාහකයාගේම යෙදුමෙන් රීලෝඩ් කරන්න, එවිට ඔබ ගෙවන්නේ රීලෝඩ් මුදල පමණි, වෙන කිසිවක් නොවේ.';

  @override
  String carrierSelfServiceCountryLine(String country) {
    return 'අංකයේ රට: $country';
  }

  @override
  String carrierSelfServiceAppHint(String app) {
    return 'එහි යෙදුම සාමාන්‍යයෙන් \"$app\" ලෙස ප්‍රකාශයට පත් වේ.';
  }

  @override
  String carrierSelfServiceUnverified(String operator) {
    return 'අපි මෙම යෙදුම පරීක්ෂා කර නැත. ගබඩාවේ සොයා, කිසිවක් ස්ථාපනය කිරීමට පෙර ප්‍රකාශකයා ඇත්තටම $operator බව තහවුරු කරගන්න.';
  }

  @override
  String get carrierSelfServiceSearchStore => 'යෙදුම් ගබඩාවේ සොයන්න';

  @override
  String get carrierSelfServiceOpenApp => 'වාහකයාගේ යෙදුම විවෘත කරන්න';

  @override
  String get carrierSelfServiceWeb => 'වාහකයාගේ වෙබ් අඩවියෙන් රීලෝඩ් කරන්න';

  @override
  String carrierSelfServiceUssd(String code) {
    return 'දත්ත නැද්ද? එම දුරකථනයෙන්ම $code අමතන්න.';
  }

  @override
  String get carrierRulesSourceLink => 'වාහකයා ප්‍රකාශ කළ නියම';

  @override
  String get carrierRulesDisclaimer =>
      'වාහකයන් මෙම නීති නොදන්වා වෙනස් කරයි. ඔබේ වාහකයා වෙනස් කර ඇත්නම් සහායට දන්වන්න, අපි නැවත පරීක්ෂා කරමු.';

  @override
  String get carrierActionTitle => 'ඔබේ ක්‍රියාව අවශ්‍යයි';

  @override
  String get carrierActionDesc =>
      'රේඛාවකට මට පමණක් කළ හැකි දෙයක් අවශ්‍ය වූ විට මට දන්වන්න — සිම් එක භාවිත කිරීම හෝ වාහකයාගේම යෙදුමෙන් රීලෝඩ් කිරීම.';

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
  String get mySims => 'මගේ SIMපත්';

  @override
  String get sharedWithMe => 'මා සමඟ බෙදාගත්';

  @override
  String get searchNameOrNumber => 'නම හෝ අංකය සොයන්න';

  @override
  String get allFilter => 'සියල්ල';

  @override
  String get alertSoon => 'ඉක්මනින් අනතුරු ඇඟවීම';

  @override
  String get showFilters => 'පෙරහන් පෙන්වන්න';

  @override
  String get hideFilters => 'පෙරහන් සඟවන්න';

  @override
  String get refreshSims => 'SIMපත් නැවුම් කරන්න';

  @override
  String get noMatchingSims => 'ගැලපෙන SIMපත් නැත';

  @override
  String get tryDifferentSimSearch =>
      'වෙනත් නමක්, අංකයක් හෝ පෙරහනක් උත්සාහ කරන්න.';

  @override
  String get clearSearchAndFilters => 'සෙවුම සහ පෙරහන් ඉවත් කරන්න';

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
  String get virtualNumbers => 'Virtual Numbers';

  @override
  String get voicemail => 'Voicemail';

  @override
  String get inspector => 'Inspector';
}
