// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'Tercihler ve Güvenlik';

  @override
  String get appAppearance => 'Uygulama Görünümü';

  @override
  String get systemTheme => 'Sistem';

  @override
  String get darkMode => 'Karanlık Mod';

  @override
  String get lightMode => 'Aydınlık Mod';

  @override
  String get localizationAndRegional => 'Yerelleştirme ve Bölgesel Ayarlar';

  @override
  String get appLanguage => 'Uygulama Dili';

  @override
  String currentlyUsing(String langName) {
    return 'Şu anda bölgesel $langName kullanılıyor';
  }

  @override
  String get selectAppLanguage => 'Uygulama Dilini Seçin';

  @override
  String get securityAndAccessLock => 'Güvenlik ve Erişim Kilidi';

  @override
  String get biometricSecurity => 'Biyometrik Güvenlik';

  @override
  String get biometricDesc => 'Face ID veya Touch ID kullanarak giriş yapın';

  @override
  String get biometricReasonPayment =>
      'Ödemeyi onaylamak için kimlik doğrulayın';

  @override
  String get biometricReasonUnlock =>
      'KeepSIMs kilidini açmak için kimlik doğrulayın';

  @override
  String get biometricLockout =>
      'Çok fazla başarısız deneme nedeniyle biyometrik doğrulama kilitlendi. Lütfen cihaz şifrenizi kullanın.';

  @override
  String get biometricNotEnrolled =>
      'Bu cihazda biyometrik doğrulama ayarlanmamış.';

  @override
  String get biometricAppLockTitle => 'KeepSIMs Kilitli';

  @override
  String get biometricUnlockButton => 'Biyometri ile Kilidi Aç';

  @override
  String get biometricCancel => 'İptal';

  @override
  String get transactionPin => 'İşlem PIN\'i';

  @override
  String get transactionPinDesc =>
      'Yenilemeleri ve para çekme işlemlerini güvene alın';

  @override
  String get setup => 'KURULUM';

  @override
  String get pinSuccess => 'İşlem PIN\'i başarıyla güncellendi!';

  @override
  String get pinMismatch => 'PIN\'ler eşleşmiyor. Tekrar deneyin!';

  @override
  String get pinActiveAndSecure => 'PIN kurulumu etkin ve güvenli';

  @override
  String get automatedSummaryAndAlerts => 'Otomatik Özet ve Uyarılar';

  @override
  String get weeklyDigest => 'Haftalık Özet';

  @override
  String get welcomeBack => 'Tekrar Hoş Geldiniz';

  @override
  String get nextNotify => 'SIRADAKİ BİLDİRİM';

  @override
  String get days => 'gün';

  @override
  String get showingNearestLine => 'En yakın hat gösteriliyor';

  @override
  String get addSim => 'SIM Ekle';

  @override
  String get linesToProtect => 'Korunacak Hatlar';

  @override
  String get active => 'Aktif';

  @override
  String get upgrade => 'YÜKSELT';

  @override
  String get standard => 'STANDART';

  @override
  String get autoNotify => 'Otomatik Bildirim';

  @override
  String get configure => 'Yapılandır';

  @override
  String get autoRefill => 'Otomatik Yükleme';

  @override
  String get quickActions => 'Hızlı İşlemler';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navSims => 'SIM\'ler';

  @override
  String get navMore => 'Daha Fazla';

  @override
  String get protectedSims => 'Korunan SIM\'ler';

  @override
  String get mySimCards => 'SIM Kartlarım';

  @override
  String get familySharedSims => 'Aile ile Paylaşılan SIM\'ler';

  @override
  String get protectAnotherSimLine => 'Başka Bir SIM Hattını Koru';

  @override
  String get keepInfiniteNumbersAlive =>
      'Sınırsız uluslararası numarayı aktif tutun';

  @override
  String get bulkActionsConsole => 'Toplu İşlemler Konsolu';

  @override
  String get resume => 'Devam Ettir';

  @override
  String get pause => 'Duraklat';

  @override
  String get simulate => 'Simüle Et';

  @override
  String get noProtectedLines => 'Korunan Hat Yok';

  @override
  String get noInternationalSimsAdded =>
      'Henüz bir uluslararası SIM kart eklemediniz. Sürekli aktif tutmak için şimdi ilk kartınızı koruyun.';

  @override
  String get protectNewLine => 'Yeni Hat Koru';

  @override
  String get noSharedSimsYet => 'Henüz Paylaşılan SIM Yok';

  @override
  String get inviteFamilyMembers =>
      'Hanenize katılmaları için aile üyelerini davet edin. Kabul ettiklerinde, korunan SIM hatları ortak izleme için burada görünecek.';

  @override
  String get manageHousehold => 'Haneyi Yönet';

  @override
  String get manageProfileDesc =>
      'Profilinizi, SIM hatlarınızı, uyarılarınızı ve paylaşılan tercihlerinizi yönetin';

  @override
  String get keepSIMsUser => 'KeepSIMs Kullanıcısı';

  @override
  String get pro => 'PRO';

  @override
  String get homeCountry => 'Ana Ülke: ';

  @override
  String get console => 'Konsol';

  @override
  String get offlineRefill => 'Çevrimdışı Yükleme (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'SMS veya WhatsApp ile çevrimdışı SIM bakiyesi yükleyin';

  @override
  String get wallet => 'Cüzdan';

  @override
  String get manageBalancesDesc =>
      'Bakiyelerinizi yönetin ve işlem geçmişini görüntüleyin';

  @override
  String get alertPreferences => 'Uyarı Tercihleri';

  @override
  String get togglePushEmailDesc =>
      'Yenileme/bakiye için push ve e-posta ayarlarını değiştirin';

  @override
  String get referAndEarn => 'Davet Et ve Kazan';

  @override
  String get shareKeepSIMsDesc =>
      'KeepSIMs\'i paylaşın, dinamik bakiye ödülleri kazanın';

  @override
  String get paymentMethods => 'Ödeme Yöntemleri';

  @override
  String get addBankCardsDesc =>
      'Banka kartları ekleyin veya otomatik çekim hesapları bağlayın';

  @override
  String get travelAndGeolocation => 'Seyahat ve Konum';

  @override
  String get manageHomeCountryDesc =>
      'Ana ülke dondurma kurallarını ve seyahat modunu yönetin';

  @override
  String get dataAndPrivacy => 'Veri ve Gizlilik';

  @override
  String get manageTrackingConsentDesc =>
      'Takip izninizi yönetin, verilerinizi dışa aktarın veya hesabınızı silin';

  @override
  String get powerUser => 'İleri Düzey Kullanıcı';

  @override
  String get accessSystemSimulatorsDesc =>
      'Sistem simülatörlerine ve hata ayıklama araçlarına erişin';

  @override
  String get testChecklist => 'Test Kontrol Listesi';

  @override
  String get manualUiTestingDesc =>
      'Kalite güvencesi için manuel UI test kontrol listesi';

  @override
  String get soon => 'YAKINDA';

  @override
  String featureComingSoon(String feature) {
    return '$feature özelliği yakında geliyor!';
  }

  @override
  String get logOut => 'Çıkış Yap';

  @override
  String get confirmLogOut =>
      'KeepSIMs\'den çıkış yapmak istediğinizden emin misiniz?';

  @override
  String get walletLedger => 'Cüzdan Defteri';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs ÖN ÖDEMELİ';

  @override
  String get offlineMode => 'ÇEVRİMDIŞI MOD';

  @override
  String get activeBalance => 'Aktif Bakiye';

  @override
  String get criticalBalanceLevel => 'Kritik Bakiye Seviyesi';

  @override
  String get balanceBelow10 =>
      'Bakiyeniz 10,00 \$\'ın altında. Planlanmış SIM yüklemeleri yakında başarısız olabilir.';

  @override
  String get depositFunds => 'Para Yatır';

  @override
  String get walletDepositsRequireInternet =>
      'Cüzdana para yatırmak için aktif internet bağlantısı gerekir.';

  @override
  String get exportLedger => 'Defteri Dışa Aktar';

  @override
  String get ledgerHistoryExported =>
      'Defter geçmişi CSV olarak dışa aktarıldı.';

  @override
  String get spendAnalysis => 'Harcama Analizi';

  @override
  String get transactionHistory => 'İşlem Geçmişi';

  @override
  String itemsCount(int count) {
    return '$count öğe';
  }

  @override
  String get noTransactionsRecorded => 'Henüz kayıtlı işlem yok.';

  @override
  String get prepaidMonthlyOutflow => 'Ön Ödemeli Aylık Gider';

  @override
  String avgMonthlySpend(String amount) {
    return 'Ortalama: \$$amount/ay (12A)';
  }

  @override
  String depositViaCard(String last4) {
    return 'Sonu $last4 ile biten kart ile yatır';
  }

  @override
  String get lineRenewal => 'Hat Yenileme';

  @override
  String get justNow => 'Az önce';

  @override
  String get loadCreditFunds => 'Kredi Bakiyesi Yükle';

  @override
  String get depositAmountUsd => 'Yatırılacak Tutar (USD)';

  @override
  String get pleaseEnterAmount => 'Lütfen bir tutar girin';

  @override
  String get enterPositiveNumber => 'Pozitif bir sayı girin';

  @override
  String get cardDetails => 'Kart Bilgileri';

  @override
  String get savedCards => 'Kayıtlı Kartlar';

  @override
  String get visaCardNumber => 'Visa Kart Numarası';

  @override
  String get pleaseEnterCardNumber => 'Lütfen kart numarasını girin';

  @override
  String get mustBe16Digits => '16 hane olmalı';

  @override
  String get expiryMmYy => 'Son Kullanma (AA/YY)';

  @override
  String get expiryRequired => 'Son kullanma tarihi gerekli';

  @override
  String get invalid => 'Geçersiz';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV gerekli';

  @override
  String get verifyingCardSecurity => 'Kart güvenliği doğrulanıyor...';

  @override
  String get authorizeDepositFunds => 'Para Yatırmayı Onayla';

  @override
  String successfullyDeposited(String amount) {
    return '\$$amount USD başarıyla yatırıldı!';
  }

  @override
  String get failedToDepositFunds =>
      'Para yatırma başarısız oldu. Lütfen kart bağlantınızı kontrol edin.';

  @override
  String get noSavedPaymentMethods => 'Kayıtlı ödeme yöntemi bulunamadı.';

  @override
  String get addPaymentMethod => 'Ödeme Yöntemi Ekle';

  @override
  String get savedPaymentMethods => 'Kayıtlı Ödeme Yöntemleri';

  @override
  String get addAnotherPaymentMethod => 'Başka bir ödeme yöntemi ekle';

  @override
  String expiresMmYy(String month, String year) {
    return '$month/$year tarihinde sona erer';
  }

  @override
  String get offlineRefillTitle => 'Çevrimdışı Yükleme (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'Hedef SIM Hattını Seçin';

  @override
  String get noRegisteredSimLines => 'Kayıtlı SIM hattı bulunamadı.';

  @override
  String get targetSimLine => 'Hedef SIM Hattı';

  @override
  String get simLine => 'SIM Hattı';

  @override
  String get carrier => 'OPERATÖR';

  @override
  String get change => 'Değiştir';

  @override
  String get offlineRefillProtection => 'Çevrimdışı Yükleme Koruması';

  @override
  String get premiumExclusive => 'PREMIUM ÖZEL';

  @override
  String get neverGetStrandedDesc =>
      'Mobil veri olmadan bir daha asla mahsur kalmayın. KeepSIMs Premium, sıfır internet bağlantısı olsa bile standart yerel SMS veya WhatsApp mesajları aracılığıyla SIM kartınızın bakiyesini çevrimdışı yüklemenize olanak tanır.';

  @override
  String get offlineCapability100 => '%100 Çevrimdışı Yetenek';

  @override
  String get deductsFromKeepSIMsDesc =>
      'Yerel SMS ağ geçidi yedeklemeleri aracılığıyla hattınıza yükleme yapmak için KeepSIMs cüzdanınızdan tutar düşülür.';

  @override
  String get dynamicUssdPlanActivation => 'Dinamik USSD Plan Aktivasyonu';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'Çevrimdışı Veri+Arama paketlerini etkinleştirmek için tam kopyala-yapıştır arama kodları (örn. *900*1#) sağlar.';

  @override
  String get dualChannelSupport => 'Çift Kanallı Destek';

  @override
  String get textRefillDesc =>
      'Mevcut hücresel kapsama alanına bağlı olarak standart SMS veya WhatsApp kullanarak \"REFILL\" yazın.';

  @override
  String get close => 'Kapat';

  @override
  String get howToTriggerOfflineRefill => 'Çevrimdışı Yükleme Nasıl Tetiklenir';

  @override
  String get ifZeroMobileDataDesc1 =>
      'Sıfır mobil verinizin olması durumunda, güvenli sistem ağ geçidimize sadece ';

  @override
  String get refill => 'REFILL';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' kelimesini içeren standart bir SMS veya WhatsApp mesajı gönderin:';

  @override
  String get targetSimLineLabel => 'HEDEF SIM HATTI';

  @override
  String get configureCashRefillAmount => 'NAKİT YÜKLEME TUTARINI YAPILANDIR';

  @override
  String get refillAmount => 'Yükleme Tutarı';

  @override
  String walletBalanceUsd(String amount) {
    return 'Cüzdan Bakiyesi: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ Düşük Bakiye';

  @override
  String get localCarrierPlanSuggestions => 'YEREL OPERATÖR PLAN ÖNERİLERİ';

  @override
  String get noStandardUssdDialCodes =>
      'Bu operatör için standart USSD arama kodu bulunamadı. Yine de nakit yükleme hattınıza başarıyla ulaşacak.';

  @override
  String get dynamicDialCodesPreview => 'Dinamik Arama Kodları Önizleme';

  @override
  String get botSuggestDialingCodes =>
      'Çevrimdışı yükleme tamamlandıktan sonra, bot Veri+Arama\'yı anında çevrimdışı olarak açmak için telefonunuzda bu tam kodları aramayı önerecektir:';

  @override
  String costAmount(String amount) {
    return 'Maliyet: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride =>
      'WHATSAPP/SMS GÖNDEREN GEÇERSİZ KILMA';

  @override
  String get verificationNumber => 'Doğrulama Numarası';

  @override
  String get triggerRefillsDifferentNumber =>
      'Yüklemeleri ana profil telefonunuzdan farklı bir numaradan tetikliyorsanız, aşağıya ülke koduyla birlikte girin (örn. 96891234567).';

  @override
  String get enterPhoneNumberDigits =>
      'Telefon numarasını girin (sadece rakamlar)';

  @override
  String get offlineRefillSettingsSaved =>
      'Çevrimdışı Yükleme ayarları başarıyla kaydedildi!';

  @override
  String get saveSettings => 'Ayarları Kaydet';

  @override
  String errorLoadingSettings(String error) {
    return 'Ayarlar yüklenirken hata oluştu: $error';
  }

  @override
  String get retry => 'Tekrar Dene';

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
  String get offlineRefillChannelsHeader => 'Çevrimdışı yükleme yolları';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'Cüzdanından $amount yükle';
  }

  @override
  String get offlineRefillWalletFunded => 'Cüzdanından';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee ücret';
  }

  @override
  String get offlineRefillMissedCallTitle => 'Cevapsız çağrı bırak';

  @override
  String get offlineRefillMissedCallSubtitle => 'Bakiye veya veri gerekmez';

  @override
  String get offlineRefillCallAction => 'Yüklemek için ara';

  @override
  String get offlineRefillRetry => 'Tekrar dene';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return '${seconds}sn bekle';
  }

  @override
  String get offlineRefillStatusSent => 'Gönderildi — onay bekleniyor';

  @override
  String get offlineRefillStatusProcessing => 'Hattın yükleniyor…';

  @override
  String get offlineRefillStatusConfirmed => 'Yükleme onaylandı';

  @override
  String get offlineRefillStatusFailed => 'Gerçekleşmedi — başka bir yol dene';

  @override
  String get offlineRefillStatusTimedOut =>
      'Henüz yanıt yok — başka bir yol dene';

  @override
  String get offlineRefillUssdTitle => 'Yüklemenden en iyi şekilde yararlan';

  @override
  String get offlineRefillUssdSubtitle =>
      'Bakiye geldikten sonra, en iyi değer için operatörünün kodunu çevir';

  @override
  String get offlineRefillUssdDial => 'Çevir';

  @override
  String get editProtectedLine => 'Korunan Hattı Düzenle';

  @override
  String get saveChanges => 'Değişiklikleri Kaydet';

  @override
  String get activateShieldProtection => 'Shield Korumasını Etkinleştir';

  @override
  String get phoneNumber => 'Telefon Numarası';

  @override
  String get nicknameOptional => 'Takma Ad (İsteğe Bağlı)';

  @override
  String get whatsappAlerts => 'WhatsApp Uyarıları';

  @override
  String get emailAlertsDesc =>
      'Resend aracılığıyla gönderilen kritik devre dışı bırakma uyarıları';

  @override
  String get refillWalletLow => 'Fonlar azaldığında cüzdanı yükle';

  @override
  String get legalPoliciesDesc =>
      'KeepSIMs\'i kullanarak şartlarımızı kabul edersiniz. KeepSIMs, SIM yaşam döngünüzü yönetmenize yardımcı olacak araçlar sağlar, ancak üçüncü taraf telekom sağlayıcılarından kaynaklanan doğrudan veya dolaylı kayıp, zarar veya hizmet kesintilerinden sorumlu değiliz.';

  @override
  String get globalTravelModeDesc =>
      'Sınır geçişi rutinlerini etkinleştirmek için otomatik coğrafi sınırlama kurallarına izin verir';

  @override
  String get dataPreferences => 'Veri Tercihleri';

  @override
  String get doNotDisturb => 'Rahatsız Etme';

  @override
  String get linkedCards => 'Bağlı Kartlar';

  @override
  String get analyticsTracking => 'Analitik ve Takip';

  @override
  String get dubai => 'Dubai';

  @override
  String get flyHome => 'Eve Uç';

  @override
  String get managePreferencesAndSecurityDesc =>
      'Temayı, dili ve biyometrik kilitlenmeleri yönetin';

  @override
  String get autoFundingRulesDesc =>
      'Bakiye çok düştüğünde varsayılan kredi kartınızdan otomatik yüklemeyi etkinleştirerek SIM yenilemelerini sürekli aktif tutun';

  @override
  String get pushNotifications => 'Push Bildirimleri';

  @override
  String get quietHoursSchedule => 'Sessiz Saatler ve Program';

  @override
  String get exportMyDataDesc =>
      'Profilinizin ve tercihlerinizin JSON kopyasını indirin (GDPR Erişim Hakkı)';

  @override
  String get borderSimulatorTitle => 'Sınır Geçişi Simülatörü';

  @override
  String get yourData => 'Verileriniz';

  @override
  String get mostImportant => 'En Önemli';

  @override
  String get emailAlerts => 'E-posta Uyarıları';

  @override
  String get pushNotificationsDesc => 'Bu cihazda yoğun yerel bildirimler';

  @override
  String get alertSettingsTitle => 'Uyarı Ayarları';

  @override
  String get atHome => 'EVDE';

  @override
  String get telegramBotDesc => 'Bağlı interaktif Telegram sohbet bildirimleri';

  @override
  String get alertChannels => 'Uyarı Kanalları';

  @override
  String get london => 'Londra';

  @override
  String get shieldProtection => 'Shield Koruması';

  @override
  String get legalPolicies => 'Yasal ve Politikalar';

  @override
  String get supportVisaMastercard =>
      'Güvenli Visa ve MasterCard banka/kredi kartını destekler';

  @override
  String get exportMyData => 'Verilerimi Dışa Aktar';

  @override
  String get dangerZone => 'Tehlikeli Bölge';

  @override
  String get analyticsTrackingDesc =>
      'Anonim kullanım verilerini paylaşarak uygulamayı geliştirmemize yardımcı olun. Kapatmak temel uygulama işlevselliğini etkilemez';

  @override
  String get autoFundingRules => 'Otomatik Fonlama Kuralları';

  @override
  String get singapore => 'Singapur';

  @override
  String get weeklySummaryDigest => 'Haftalık Özet Bülteni';

  @override
  String get fullyShielded => 'Tam Korumalı';

  @override
  String get dndDesc =>
      'Belirlenen uyku saatlerinde push bildirimlerini sessize al';

  @override
  String get paymentsAutoFundTitle => 'Ödemeler ve Otomatik Fonlama';

  @override
  String get travelGeolocationTitle => 'Seyahat ve Konum';

  @override
  String get telegramBot => 'Telegram Botu';

  @override
  String get weeklyDigestDesc =>
      'Her Pazar sabah 9:00\'da tüm SIM kartların derlenmiş durum raporu';

  @override
  String get borderSimulatorDesc =>
      'Akıllı dondurma veya aktif ülke devam ettirme kurallarını tetiklemek için sınır geçişlerini simüle edin.';

  @override
  String get linkFirstCard => 'İlk ödeme kartınızı bağlayın';

  @override
  String get globalTravelMode => 'Küresel Seyahat Modu';

  @override
  String get readPrivacyPolicy =>
      'Tam Gizlilik Politikasını ve Şartları Okuyun';

  @override
  String get whatsappAlertsDesc =>
      'Yükleme başarısızlık uyarıları doğrudan WhatsApp\'a gönderilir';

  @override
  String get abroadTraveling => 'YURT DIŞI / SEYAHATTE';

  @override
  String get freezeAllLines => 'Tüm Hatları Dondur';

  @override
  String get resumeRenewals => 'Yenilemeleri Devam Ettir';

  @override
  String get freezeRecommendationDesc =>
      'Şu anda ana ülkenizde olduğunuzu tespit ettik. İstenmeyen cüzdan bakiyesi tükenmesini önlemek için uluslararası hatlarınızdaki yenilemeleri dondurabilirsiniz.';

  @override
  String get travelDetected => 'Seyahat Tespit Edildi! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'Yurt dışında seyahat ediyorsunuz. Kesintisiz mobil ağ kapsama alanı sağlamak için lütfen duraklatılmış uluslararası SIM yenilemelerinizi devam ettirin.';

  @override
  String get dismiss => 'Kapat';

  @override
  String get welcomeHome => 'Evinize Hoş Geldiniz! 🏡';

  @override
  String get addCard => 'Kart Ekle';

  @override
  String get noAlertChannelsConfigured =>
      'Hiç uyarı iletim kanalı yapılandırılmadı.';

  @override
  String channelSettingsUpdated(String channelName) {
    return '$channelName ayarları güncellendi.';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName Kilitli 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return '$channelName uyarıları Starter ve Premium plan özellikleridir. WhatsApp, Telegram ve E-posta uyarılarının kilidini açmak için planınızı yükseltin!';
  }

  @override
  String get upsellProtect5Lines => 'Aynı anda 5 SIM hattına kadar koruyun';

  @override
  String get upsellUnlockChannels =>
      'WhatsApp, Telegram ve E-posta bildirimlerinin kilidini açın';

  @override
  String get upsellEnableTravelModes =>
      'Seyahat ve Ev otomatik geçerlilik modlarını etkinleştirin';

  @override
  String get emailAddressLabel => 'Bildirim E-posta Adresi';

  @override
  String get emailAddressHint => 'örn. kullanici@alanadi.com';

  @override
  String get whatsappNumberLabel => 'WhatsApp Numarası (Uluslararası Format)';

  @override
  String get whatsappNumberHint => 'örn. +96891234567';

  @override
  String get whatsappFormatInstruction =>
      '+ ile başlayan tam uluslararası formatı girin (örn. +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'Durum: Bağlı (Sohbet ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'Durum: Bağlı Değil';

  @override
  String get telegramLinkInstructions =>
      'Ücretsiz, interaktif Telegram uyarıları almak için Telegram Botumuzu hesabınızla bağlayın.';

  @override
  String get linkTelegramBot => 'Telegram Botunu Bağla';

  @override
  String get emailFreePlanGuarded =>
      'Resend Ücretsiz Plan Korumalı: Yalnızca devre dışı bırakma tetikleyicileriyle sınırlıdır. Tanıtım spam\'i yoktur.';

  @override
  String get whatsappMetaCloudCapped =>
      'Doğrudan Meta Cloud Sınırlı: Her yükleme programı için en fazla 1 mesaj, yalnızca otomatik yükleme etkin değilse veya başarısız olursa gönderilir.';

  @override
  String get failedToLoadPaymentInfo => 'Ödeme bilgisi yüklenemedi';

  @override
  String get defaultCardIndicator => 'VARSAYILAN';

  @override
  String get cardholder => 'KART SAHİBİ';

  @override
  String get expires => 'SON KULLANMA';

  @override
  String get lowBalanceTrigger => 'Düşük Bakiye Tetikleyicisi';

  @override
  String get triggerLowTopUp => 'Düşük bakiyede yüklemeyi tetikle';

  @override
  String get reloadDepositAmount => 'Yeniden Yükleme Tutarı';

  @override
  String get amountToLoad => 'Yüklenecek tutar';

  @override
  String get linkCreditDebitCard => 'Kredi/Banka Kartı Bağla';

  @override
  String get cardNumberLabel => 'KART NUMARASI';

  @override
  String get expiryDateLabel => 'SON KULLANMA TARİHİ';

  @override
  String get cvvCodeLabel => 'CVV KODU';

  @override
  String get securelyLinkCard => 'Kartı Güvenle Bağla';

  @override
  String get pleaseEnterValidCardNumber =>
      'Lütfen geçerli 16 haneli bir kart numarası girin.';

  @override
  String get pleaseEnterValidExpiryDate =>
      'Lütfen geçerli bir son kullanma tarihi girin (AA/YY).';

  @override
  String get invalidExpiryMonth => 'Geçersiz son kullanma ayı.';

  @override
  String get cvvMustBe3Digits => 'CVV 3 hane olmalı.';

  @override
  String get cardLinkedSuccessfully =>
      'Güvenli fatura kartı başarıyla bağlandı!';

  @override
  String get defaultPaymentCardUpdated => 'Varsayılan ödeme kartı güncellendi!';

  @override
  String get removePaymentCard => 'Ödeme Kartını Kaldır';

  @override
  String get confirmRemoveCardDesc =>
      'Bu kartı kaldırmak istediğinizden emin misiniz? Varsayılan ödeme kartı kalmazsa bağlı otomatik fonlama başarısız olabilir.';

  @override
  String get cancel => 'İptal';

  @override
  String get remove => 'Kaldır';

  @override
  String get billingCardSuccessfullyRemoved =>
      'Fatura kartı başarıyla kaldırıldı.';

  @override
  String get pleaseAddDefaultCardFirst =>
      'Otomatik fonlamayı etkinleştirmek için lütfen önce bir varsayılan ödeme kartı ekleyip seçin.';

  @override
  String get autoFundPrefsSavedSuccess =>
      'Otomatik Fonlama tercihleri başarıyla kaydedildi!';

  @override
  String get preparingDataExport => 'Veri dışa aktarımı hazırlanıyor...';

  @override
  String exportFailed(String error) {
    return 'Dışa aktarma başarısız oldu: $error';
  }

  @override
  String get deleteAccountWarning =>
      'Hesabınızı sildikten sonra geri dönüş yoktur. Lütfen emin olun.';

  @override
  String get deleteAccount => 'Hesabı Sil';

  @override
  String get deleteAccountIrreversible =>
      'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecektir.';

  @override
  String get typeDeleteToConfirm => 'Onaylamak için \"DELETE\" yazın:';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get systemDiagnosticsLogs => 'SİSTEM TANILAMA GÜNLÜKLERİ';

  @override
  String get online => 'ÇEVRİMİÇİ';

  @override
  String errorLoadingPrefs(String error) {
    return 'Tercihler yüklenirken hata oluştu: $error';
  }

  @override
  String get privacyPolicyLoaded => 'Gizlilik Politikası ayrıntıları yüklendi.';

  @override
  String get protectionConsole => 'Koruma Konsolu';

  @override
  String get deleteProtectionTooltip => 'Korumayı Sil';

  @override
  String get refreshTooltip => 'Yenile';

  @override
  String get failedToLoadDetails => 'Ayrıntılar yüklenemedi';

  @override
  String get retryConnection => 'Bağlantıyı Tekrar Dene';

  @override
  String get healthLabel => 'sağlık';

  @override
  String get mySimCardDefault => 'SIM Kartım';

  @override
  String get upLabel => 'YUKARI';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'Paylaşan: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'Kritik risk';

  @override
  String get simDeactivationRisk => 'İşlem yapılmazsa SIM devre dışı kalabilir';

  @override
  String get missingAlertsDesc =>
      'Hiç uyarı bildirimi yapılandırılmadı — 100 puan eksik';

  @override
  String get missingAutoRefillDesc =>
      'Otomatik yükleme yapılandırılmadı — 50 puan eksik';

  @override
  String get missingVerificationDesc =>
      'Telefon numarası doğrulanmadı — 25 puan eksik';

  @override
  String get missingRecentRefillDesc =>
      'Son yükleme 80 günden daha önce yapıldı — 25 puan eksik';

  @override
  String get quickActionsLabel => 'Hızlı İşlemler';

  @override
  String get manualRefillLabel => 'Manuel Yükleme';

  @override
  String get chargeFromWalletNow => 'Şimdi cüzdandan yükle';

  @override
  String get rechargeFromFriend => 'Arkadaştan Yükleme İste';

  @override
  String get requestViaTelegram => 'Telegram ile İste';

  @override
  String get shareViaWaTg => 'WhatsApp/Telegram ile Paylaş';

  @override
  String get testSimActivity => 'SIM Etkinliğini Test Et';

  @override
  String get verifyLineReachable => 'Hattın erişilebilir olduğunu doğrula';

  @override
  String get checkCompleted1x => '1x Kontrol Tamamlandı';

  @override
  String get starterPlan1xCompleted =>
      'Starter planı 1x kontrolü tamamlandı. Sınırsız kontrol için Premium\'a yükseltin.';

  @override
  String leaveCountry(String countryName) {
    return '$countryName\'dan Ayrıl';
  }

  @override
  String get resumeProtectionLayers => 'Koruma katmanlarını devam ettir';

  @override
  String backToCountryMode(String countryName) {
    return '$countryName moduna geri dön';
  }

  @override
  String get pauseWhileVisitingHome => 'Eve dönerken duraklat';

  @override
  String get rechargeFromFriendTitle => 'Bir Arkadaştan Yükleme İste';

  @override
  String get selectPlatformShare =>
      'Arkadaşınızla bir yükleme isteği mesajı paylaşmak için bir platform seçin.';

  @override
  String rechargeRequestTemplate(String phone) {
    return 'Merhaba! KeepSIMs kartım ($phone) yakında sona eriyor. Benim için yükleme yapabilir misin? Teşekkürler!';
  }

  @override
  String get requestViaWhatsApp => 'WhatsApp ile İste';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return '$platformName bağlantısı açılamadı: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'Telegram bağlantısı açılamadı: $error';
  }

  @override
  String get protectionLayersLabel => 'Koruma Katmanları';

  @override
  String get autoNotifyDisabled => 'Otomatik Bildirim: Devre Dışı';

  @override
  String get noActiveAlertSchedule =>
      'SIM kartınızın aktif bir uyarı bildirim programı yok. Otomatik hatırlatmalar veya devre dışı bırakma uyarıları almayacaksınız.';

  @override
  String get askOwnerConfigureAlerts =>
      'Lütfen uyarıları yapılandırması için hane sahibinden isteyin.';

  @override
  String get configureAutoNotify => 'Otomatik Bildirimi Yapılandır';

  @override
  String get activeLabel => 'AKTİF';

  @override
  String get pausedHomeMode => 'DURAKLATILDI (EV MODU)';

  @override
  String get pausedLabel => 'DURAKLATILDI';

  @override
  String get everyHour => 'Her 1 saatte';

  @override
  String everyNDays(int days) {
    return 'Her $days günde';
  }

  @override
  String get nextAlertCheck => 'Sıradaki Uyarı Kontrolü';

  @override
  String get premiumKeepAliveRefill => 'Premium Aktif Tutma Yüklemesi';

  @override
  String autoRefillIncludedText(String date) {
    return 'Otomatik yükleme dahil - ~3,5 USD (telekom, KDV dahil) her 85 günde,\\nsıradaki yükleme $date tarihinde';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'Premium aktif tutma yüklemesi şu anda devre dışı.';

  @override
  String get customAutoRefill => 'Özel Otomatik Yükleme';

  @override
  String get addAdditionalScheduledRecharge =>
      'SIM\'inizde ekstra bakiye tutmak için ek bir planlı yükleme tutarı ekleyin.';

  @override
  String get askOwnerConfigureRefill =>
      'Lütfen Otomatik Yüklemeyi yapılandırması için hane sahibinden isteyin.';

  @override
  String get configureCustomAutoRefill => 'Özel Otomatik Yüklemeyi Yapılandır';

  @override
  String get rechargeAmount => 'Yükleme Tutarı';

  @override
  String get refillInterval => 'Yükleme Aralığı';

  @override
  String get nextRefillDue => 'Sıradaki Yükleme Tarihi';

  @override
  String get failedRefillAttempts => 'Başarısız Yükleme Denemeleri';

  @override
  String retriesCount(int count) {
    return '$count / 4 deneme';
  }

  @override
  String get editRefillAmount => 'Yükleme Tutarını Düzenle';

  @override
  String get refillExecutionsHistory => 'Yükleme İşlemleri Geçmişi';

  @override
  String get renewalExecutionsHistory => 'Yenileme İşlemleri Geçmişi';

  @override
  String get noHistoricalTopup =>
      'Bu hat için henüz geçmiş yükleme işlemi kaydedilmedi.';

  @override
  String get noHistoricalRenewal =>
      'Bu hat için henüz geçmiş yenileme işlemi kaydedilmedi.';

  @override
  String get viewAllHistory => 'Tüm Geçmişi Görüntüle';

  @override
  String get securityActivityLogs => 'Güvenlik Etkinlik Günlükleri';

  @override
  String get clearLogs => 'Günlükleri Temizle';

  @override
  String get noActivityLogsRecorded =>
      'Bu hat için henüz etkinlik günlüğü kaydedilmedi.';

  @override
  String get activityLogDeleted => 'Etkinlik günlüğü kaydı silindi.';

  @override
  String get activityLogsCleared => 'Etkinlik günlükleri başarıyla temizlendi.';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'Otomatik Yenileme başarıyla $status oldu.';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'Program güncellenemedi: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'Premium aktif tutma yüklemesi başarıyla etkinleştirildi.';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'Otomatik yükleme etkinleştirilemedi: $error';
  }

  @override
  String get removeScheduleTitle => 'Programı Kaldır';

  @override
  String get confirmDeleteAutoRefill =>
      'Bu otomatik yükleme programını silmek istediğinizden emin misiniz? SIM sağlık puanınız önemli ölçüde düşecek ve devre dışı kalma riskini artıracaktır.';

  @override
  String get confirmDeleteAutoRenewal =>
      'Bu otomatik yenileme programını silmek istediğinizden emin misiniz? SIM sağlık puanınız önemli ölçüde düşecek ve devre dışı kalma riskini artıracaktır.';

  @override
  String get autoRefillRemoved =>
      'Otomatik yükleme programı başarıyla kaldırıldı.';

  @override
  String get autoRenewalRemoved =>
      'Otomatik yenileme programı başarıyla kaldırıldı.';

  @override
  String failedToDeleteSchedule(String error) {
    return 'Program silinemedi: $error';
  }

  @override
  String get refillRetrySuccess =>
      'Yükleme tekrar denemesi başarıyla tamamlandı!';

  @override
  String get refillRetryQueued =>
      'Tekrar deneme sıraya alındı — yükleme işleniyor.';

  @override
  String get renewalRetrySuccess =>
      'Yenileme tekrar denemesi başarıyla tamamlandı!';

  @override
  String retryFailed(String error) {
    return 'Tekrar deneme başarısız oldu: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'Tekrar deneme yürütme hatası: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'Etkinlik günlüğü silinemedi: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'Etkinlik günlükleri temizlenemedi: $error';
  }

  @override
  String get removeProtectionTitle => 'Korumayı Kaldır';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return '$name\'i korumayı durdurmak istediğinizden emin misiniz? Bu SIM hattı için planlanmış yüklemeler kalıcı olarak iptal edilecek.';
  }

  @override
  String get simLineProtectionRemoved =>
      'SIM hattı koruması başarıyla kaldırıldı.';

  @override
  String failedToDeleteSimLine(String error) {
    return 'Silinemedi: $error';
  }

  @override
  String get editSimNameTitle => 'SIM Adını Düzenle';

  @override
  String get enterNicknameInstruction =>
      'Bu SIM kart hattı için bir takma ad girin:';

  @override
  String get nicknameExampleHint => 'örn. Orange Egypt SIM\'im';

  @override
  String get simNameUpdatedSuccess => 'SIM adı başarıyla güncellendi.';

  @override
  String failedToUpdateSimName(String error) {
    return 'SIM adı güncellenemedi: $error';
  }

  @override
  String get saveButton => 'Kaydet';

  @override
  String get deleteButton => 'Sil';

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
  String get autoNotifySchedule => 'Otomatik Bildirim Programı';

  @override
  String get renewalCheckInterval => 'Yenileme Kontrol Aralığı';

  @override
  String get editNotificationConfig => 'Bildirim Yapılandırmasını Düzenle';

  @override
  String get openTicket => 'Talep Aç';

  @override
  String get offlineRefillLabel => 'Çevrimdışı Yükleme';

  @override
  String get categoryLabel => 'Kategori';

  @override
  String get techSupportCategory => 'Teknik Destek';

  @override
  String get billingWalletCategory => 'Faturalama ve Cüzdan';

  @override
  String get simLinesCategory => 'SIM Hat Yönetimi';

  @override
  String get feedbackOtherCategory => 'Geri Bildirim ve Diğer';

  @override
  String get subjectLabel => 'Konu';

  @override
  String get subjectHint => 'Sorunun kısa özeti';

  @override
  String get descriptionLabel => 'Açıklama';

  @override
  String get descriptionHint => 'Sorununuzu detaylı olarak açıklayın...';

  @override
  String get attachmentLabel => 'Ek (İsteğe Bağlı)';

  @override
  String get uploadScreenshot => 'Ekran Görüntüsü Yükle';

  @override
  String get submitTicketButton => 'Talebi Gönder';

  @override
  String get pleaseFillFields => 'Lütfen konuyu ve açıklamayı doldurun';

  @override
  String get ticketSubmittedSuccess => 'Talep başarıyla gönderildi!';

  @override
  String get lastRefillLabel => 'Son Yükleme';

  @override
  String get noRefillYet => 'Henüz yükleme yok';

  @override
  String get nextAlertLabel => 'Sıradaki Uyarı';

  @override
  String get protectionLabel => 'KORUMA';

  @override
  String get actionRequiredLabel => 'İşlem Gerekli';

  @override
  String get protectionOffLabel => 'Koruma Kapalı';

  @override
  String get notSet => 'Ayarlanmadı';

  @override
  String get homeMode => 'Ev Modu';

  @override
  String get keepProtectedAtHome => 'Evdeyken korumayı sürdür';

  @override
  String get protectionPausesAtHome => 'Evdeyken koruma duraklatılır';

  @override
  String get incidentChannelsTitle => 'Olay Kanalları';

  @override
  String get topUpSuccessTitle => 'Yükleme Başarılı';

  @override
  String get topUpSuccessDesc =>
      'Otomatik SIM geçerlilik uzatması başarıyla tamamlandığında beni bilgilendir.';

  @override
  String get topUpFailedTitle => 'Yükleme Başarısız (Kritik)';

  @override
  String get topUpFailedDesc =>
      'Operatör veya cüzdan sorunları nedeniyle otomatik yüklemeler başarısız olduğunda kritik uyarılar.';

  @override
  String get walletLowTitle => 'Düşük Cüzdan Bakiyesi';

  @override
  String get walletLowDesc =>
      'Birincil bakiye güvenlik eşiğinin altına düştüğünde beni uyar.';

  @override
  String get walletDepletedTitle => 'Cüzdan Tükendi';

  @override
  String get walletDepletedDesc =>
      'Cüzdan bakiyesi tamamen tükendiğinde ve yenilemeler durduğunda askıya alınmış uyarılar.';

  @override
  String get lineCriticalTitle => 'Geçerlilik Süresi Dolma Uyarısı';

  @override
  String get lineCriticalDesc =>
      'Bir SIM geçerlilik penceresi 48 saat içinde sona erecekken beni uyar.';

  @override
  String get lineEnteringGraceTitle => 'Ek Süreye Giriliyor';

  @override
  String get lineEnteringGraceDesc =>
      'Operatör devre dışı bırakma ek süreleri tespit edildiğinde beni bilgilendir.';

  @override
  String get geoFenceTriggeredTitle => 'Konum / Dolaşım Uyarıları';

  @override
  String get geoFenceTriggeredDesc =>
      'Operatör dolaşım kümelerini veya ağ düğümlerini değiştirdiğinde uyarılar.';

  @override
  String get welcomeHomeReadyTitle => 'Eve Hoş Geldin Senkronu';

  @override
  String get welcomeHomeReadyDesc =>
      'Ana ülke ağ düğümü otomatik senkronizasyonları tetiklediğinde uyarılar.';

  @override
  String get referralRewardTitle => 'Davet ve Ödüller';

  @override
  String get referralRewardDesc =>
      'Arkadaş davetleri cüzdanıma promosyon bakiyesi yatırdığında beni bilgilendir.';

  @override
  String get systemUpdatesTitle => 'Genel Sistem Güncellemeleri';

  @override
  String get systemUpdatesDesc =>
      'Önemli motor güncellemeleri, bakım ve platform duyuruları.';

  @override
  String get walletCreditTitle => 'Cüzdana Para Yüklendi';

  @override
  String get walletCreditDesc =>
      'Cüzdanıma para yatırıldığında beni bilgilendir.';

  @override
  String get promoTitle => 'Teklifler ve Promosyonlar';

  @override
  String get promoDesc =>
      'Fırsatlar ve yeni özellikler hakkında ara sıra haberler. Siz açana kadar kapalı kalır.';

  @override
  String get deliverVia => 'Şununla gönder';

  @override
  String get channelPushShort => 'Anlık';

  @override
  String get channelEmailShort => 'E-posta';

  @override
  String get channelOffGlobally => 'Yukarıdaki Uyarı Kanalları\'nda kapalı';

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
  String get rechargeNow => 'Şimdi Yükle';

  @override
  String get planFeePaidFromWallet => 'Plan ücreti cüzdan bakiyenizden ödendi.';

  @override
  String get planFeeNotChargedRetry =>
      'Yüklemeniz ulaştı ancak plan ücreti tahsil edilemedi, bu yüzden hat oluşturulmadı. Bakiyeniz güvende — lütfen tekrar deneyin.';

  @override
  String activityTopupRequested(String amount) {
    return '\$$amount tutarında yükleme talebi gönderildi';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return '\$$amount yüklemesi $provider üzerinden tamamlandı';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return '\$$amount yüklemesi başarısız oldu: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return '\$$amount yüklemesi cüzdana iade edildi';
  }

  @override
  String activityTopupCancelled(String amount) {
    return '\$$amount yükleme talebi iptal edildi';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return '\$$amount yüklemesi için tekrar deneme sıraya alındı';
  }

  @override
  String get activityLineCreated => 'SIM Hattı SIM Shield\'e kaydedildi';

  @override
  String get activityHealthUpdate => 'SIM Hattı aktif durumu doğrulandı';

  @override
  String get activityReminderSent => 'Yenileme hatırlatma bildirimi gönderildi';

  @override
  String get supportTicketsTitle => 'Yardım ve Destek';

  @override
  String get supportTicketsSubtitle =>
      'Destek talepleri gönderin, etkinlik günlüklerini ekleyin ve destek ekibimizle canlı sohbet edin.';

  @override
  String get supportTicketsEmpty => 'Destek talebi bulunamadı.';

  @override
  String get createSupportTicket => 'Talep Oluştur';

  @override
  String get ticketCategoryGeneral => 'Genel Soru';

  @override
  String get ticketCategoryBilling => 'Faturalandırma ve Cüzdan';

  @override
  String get ticketCategoryTechnical => 'Teknik Sorun';

  @override
  String get ticketCategoryRefillIssue => 'Yükleme Sorunu';

  @override
  String get ticketCategoryAccount => 'Hesap ve Güvenlik';

  @override
  String get ticketStatusOpen => 'Açık';

  @override
  String get ticketStatusPending => 'Yanıt Bekliyor';

  @override
  String get ticketStatusResolved => 'Çözüldü';

  @override
  String get ticketStatusClosed => 'Kapandı';

  @override
  String get ticketSubjectLabel => 'Konu';

  @override
  String get ticketSubjectHint => 'Sorunun kısa açıklaması';

  @override
  String get ticketCategoryLabel => 'Kategori';

  @override
  String get ticketMessageLabel => 'Mesaj';

  @override
  String get ticketMessageHint => 'Detaylı bilgi verin...';

  @override
  String get attachImage => 'Görsel Ekle';

  @override
  String get attachActivityLogs => 'Hat Günlüklerini Ekle';

  @override
  String get submitTicket => 'Talebi Gönder';

  @override
  String get typeMessageHint => 'Bir mesaj yazın...';

  @override
  String get closeTicketButton => 'Talebi Kapat';

  @override
  String get ticketClosedNotice => 'Bu destek talebi kapatıldı.';

  @override
  String get attachedFiles => 'Ekler';

  @override
  String get referralsTitle => 'Davet Et & Kazan';

  @override
  String get referralsSubtitle =>
      'Arkadaşlarınızı davet edin, SIM aboneliklerinden puan kazanın ve cüzdan kredisine dönüştürün!';

  @override
  String get referralCode => 'Davet Kodunuz';

  @override
  String get copyCode => 'Kodu Kopyala';

  @override
  String get codeCopied => 'Davet kodu panoya kopyalandı!';

  @override
  String get shareCode => 'Kodu Paylaş';

  @override
  String get pointsBalance => 'Puan Bakiyesi';

  @override
  String get pointsUnit => 'puan';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return 'Sonraki \$2.00 ödül için $pointsNeeded puan daha gerekli';
  }

  @override
  String get redeemButton => '10 Puanı \$2.00 olarak Bozdur';

  @override
  String get redeemSuccess =>
      '10 puan başarıyla \$2.00 cüzdan kredisine dönüştürüldü!';

  @override
  String get applyCodeTitle => 'Davet Kodunuz Var mı?';

  @override
  String get applyCodeHint => 'Davet kodunu girin';

  @override
  String get applyCodeButton => 'Kodu Uygula';

  @override
  String get applyCodeSuccess => 'Davet kodu başarıyla uygulandı!';

  @override
  String get referredFriendsTitle => 'Davet Edilen Arkadaşlar';

  @override
  String get noReferredFriends =>
      'Henüz arkadaş davet edilmedi. Başlamak için kodunuzu paylaşın!';

  @override
  String get redemptionHistoryTitle => 'Bozdurma Geçmişi';

  @override
  String get noRedemptions => 'Henüz bozdurma yok.';

  @override
  String get pointHistoryTitle => 'Puan Geçmişi';

  @override
  String get noPointsEarned => 'Henüz puan kazanılmadı.';

  @override
  String get howItWorksTitle => 'Davet Et & Kazan Nasıl Çalışır';

  @override
  String get howItWorksStep1 =>
      '1. Benzersiz davet kodunuzu arkadaşlarınızla paylaşın.';

  @override
  String get howItWorksStep2 =>
      '2. Davet edilen bir arkadaşınız SIM hattı abonesi olduğunda 1 puan kazanın.';

  @override
  String get howItWorksStep3 =>
      '3. İstediğiniz zaman \$2.00 cüzdan kredisi için 10 puan kullanın!';

  @override
  String get geoTitle => 'Seyahat ve Konum';

  @override
  String get geoSubtitle =>
      'Otomatik ülke tespiti ve uluslararası SIM hattı koruması';

  @override
  String get currentCountryLabel => 'Mevcut Konum';

  @override
  String get travelModeToggle => 'Seyahat Modu';

  @override
  String get travelModeDescription =>
      'Uluslararası hat korumasını yönetmek için uygulamayı açarken ülkeyi kontrol et';

  @override
  String get geoNotice =>
      'Ülke, uygulama açıldığında IP sorgulaması ile kontrol edilir. Konum izni gerekmez.';

  @override
  String get freezeInternationalLines => 'Uluslararası Hatları Dondur';

  @override
  String get resumeInternationalLines => 'Uluslararası Hatları Devam Ettir';

  @override
  String get linesFrozenSuccess =>
      'Uluslararası SIM hatları donduruldu ve zamanlanmış yenilemeler duraklatıldı!';

  @override
  String get linesResumedSuccess =>
      'Uluslararası SIM hatları ve yenilemeler yeniden etkinleştirildi!';

  @override
  String get alwaysProtectedBadge => 'Her Zaman Korumalı';

  @override
  String get detectedViaIp => 'IP İle Tespit Edildi';

  @override
  String get esimManagerTitle => 'eSIM Yöneticisi';

  @override
  String get esimPlansTitle => 'eSIM Paketleri';

  @override
  String get searchDestinationHint =>
      'Hedef ara (ör. Fransa, Amerika Birleşik Devletleri)';

  @override
  String get selectDestinationTitle => 'Hedef Seçin';

  @override
  String get localTab => 'Yerel';

  @override
  String get regionalTab => 'Bölgesel';

  @override
  String get globalTab => 'Küresel';

  @override
  String get bestValueBadge => 'EN İYİ FİYAT';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days Gün';
  }

  @override
  String get buyPlanButton => 'Paket Satın Al';

  @override
  String get deviceIncompatibleNotice =>
      'Cihazınız eSIM teknolojisini desteklememektedir.';

  @override
  String get activationPolicyTitle => 'Aktivasyon Politikası';

  @override
  String get activationPolicyNotice =>
      'Geçerlilik süresi eSIM hedefinizdeki desteklenen bir ağa bağlandığında başlar.';

  @override
  String get coveredCountriesTitle => 'Kapsanan Ülkeler';

  @override
  String get sortPriceLowToHigh => 'Fiyat: Düşükten Yükseğe';

  @override
  String get sortPricePerGb => 'Fiyat / GB: Düşükten Yükseğe';

  @override
  String get sortDataHighToLow => 'Veri: Yüksekten Düşüğe';

  @override
  String get filterAll => 'Tüm Paketler';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ 15 Gün';

  @override
  String get filterUnlimited => 'Sınırsız';

  @override
  String get purchaseInNextRelease =>
      'Satın alma özelliği bir sonraki sürümde (C9b) sunulacaktır.';

  @override
  String get confirmPurchaseTitle => 'eSIM Satın Alımını Onayla';

  @override
  String get myEsimsTitle => 'eSIM\'lerim';

  @override
  String get showQrCode => 'QR Kodunu Göster';

  @override
  String get buyAgain => 'Tekrar Satın Al';

  @override
  String get dataRemaining => 'Kalan Veri';

  @override
  String get archivedEsims => 'Arşivlenmiş eSIM\'ler';

  @override
  String rateLimitExceeded(String seconds) {
    return 'Çok fazla istek. Lütfen tekrar denemeden önce $seconds saniye bekleyin.';
  }

  @override
  String get confirmDeleteButton => 'Silmeyi Onayla';

  @override
  String get cancelAccountDeletion => 'Hesap Silmeyi İptal Et';

  @override
  String get accountScheduledForDeletion => 'Hesap Silinmek Üzere Planlandı';

  @override
  String deletionScheduledNotice(String date) {
    return 'Hesabınız donduruldu ve $date tarihinde kalıcı olarak silinmek üzere planlandı.';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'Cüzdan bakiyeniz (\$$balance) limiti (\$1.00) aşıyor. Lütfen harcayın veya destekle iletişime geçin.';
  }

  @override
  String get payPalCheckoutTitle => 'PayPal Ödeme';

  @override
  String get payPalWalletTopUp => 'KeepSIMs Cüzdan Yüklemesi';

  @override
  String get payPalPaySecurely => 'PayPal ile Güvenli Öde';

  @override
  String get payPalRedirectInfo =>
      'Ödemenizi onaylamak için PayPal\'a yönlendirileceksiniz.';

  @override
  String get payPalCreatingOrder => 'Güvenli PayPal siparişi oluşturuluyor...';

  @override
  String get payPalAwaitingConfirmation => 'PayPal Onayı Bekleniyor...';

  @override
  String get payPalCompleteInBrowser =>
      'Lütfen açılan tarayıcı penceresinde ödemeyi tamamlayın.';

  @override
  String get payPalPaymentConfirmed => 'Ödeme Onaylandı!';

  @override
  String get payPalPaymentFailed => 'Ödeme başarısız oldu veya iptal edildi.';

  @override
  String get payPalForceCaptureButton => 'PayPal\'da Ödemeyi Tamamladım';

  @override
  String get payPalBrowserOpened => 'PayPal tarayıcınızda açık';

  @override
  String get payPalBrowserOpenedBody =>
      'Ödemeyi orada tamamlayın — bu ekran kendiliğinden güncellenir.';

  @override
  String get payPalTakingLonger =>
      'Bu her zamankinden uzun sürüyor. Ödemeyi zaten yaptıysanız aşağıdan kontrol edin.';

  @override
  String get payPalReopenButton => 'PayPal\'ı yeniden aç';

  @override
  String get payPalVerifying => 'Ödemeniz doğrulanıyor…';

  @override
  String get payPalVerifyingBody =>
      'PayPal ile onaylarken bir dakika bekleyin.';

  @override
  String get payPalPaymentCancelled =>
      'Ödeme iptal edildi. Sizden ücret alınmadı.';

  @override
  String get payPalDoneButton => 'Tamam';

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
  String get householdTitle => 'Hane ve Aile';

  @override
  String get householdTabMyFamily => 'Ailem';

  @override
  String get householdTabReceived => 'Davetler';

  @override
  String get householdTabJoined => 'Katıldıklarım';

  @override
  String get householdInviteMember => 'Üye davet et';

  @override
  String get householdEmptyTitle => 'Henüz aile üyesi yok';

  @override
  String get householdEmptyDesc =>
      'Ön ödemeli SIM hatlarınızı ve yenilemelerini paylaşmak için e-postayla birini davet edin.';

  @override
  String get householdStatusPending => 'BEKLEMEDE';

  @override
  String get householdStatusAccepted => 'AKTİF';

  @override
  String get householdPendingHint => 'Kabul etmesi bekleniyor';

  @override
  String get householdRoleViewer => 'İzleyici';

  @override
  String get householdRoleManager => 'Yönetici';

  @override
  String get householdRoleViewerHint => 'Hatlarınızı görebilir';

  @override
  String get householdRoleManagerHint =>
      'Hatlarınızı görebilir ve yükleme yapabilir';

  @override
  String get householdManagerWarning =>
      'Yönetici hatlarınıza yükleme yapabilir. Cüzdanınızdan ancak bir limit tanımlarsanız harcar.';

  @override
  String householdSpendsMyWallet(String spent, String cap) {
    return 'Cüzdanımdan harcıyor · bu ay $cap tutarın $spent kadarı';
  }

  @override
  String get householdPaysOwnWallet => 'Kendi cüzdanından öder';

  @override
  String get householdManagersOnly =>
      'Yalnızca yöneticiler — izleyici cüzdanınızdan harcayamaz';

  @override
  String get householdChangeLimit => 'Limiti değiştir';

  @override
  String get householdSetLimit => 'Limit belirle';

  @override
  String householdRemainingQueued(String remaining, String queued) {
    return '$remaining kaldı · $queued sırada, henüz tahsil edilmedi';
  }

  @override
  String householdRemainingThisMonth(String remaining) {
    return 'Bu ay $remaining kaldı';
  }

  @override
  String householdSpendingLimitFor(String name) {
    return '$name için harcama limiti';
  }

  @override
  String get householdSpendingLimitDesc =>
      'Her takvim ayında hatlarınız için SİZİN cüzdanınızdan ne kadar harcayabileceği. Kapatmak için 0 girin — yeniden kendi cüzdanından öder.';

  @override
  String get householdMonthlyLimit => 'Aylık limit (USD)';

  @override
  String get householdMaxPerRefill => 'Yükleme başına üst sınır (isteğe bağlı)';

  @override
  String get householdSave => 'Kaydet';

  @override
  String householdLimitSaved(String name, String cap) {
    return '$name artık ayda cüzdanınızdan $cap tutarına kadar harcayabilir.';
  }

  @override
  String householdLimitCleared(String name) {
    return '$name yeniden kendi cüzdanından ödüyor.';
  }

  @override
  String get householdLimitFailed => 'Limit güncellenemedi.';

  @override
  String get householdNoInvitesTitle => 'Davet yok';

  @override
  String get householdNoInvitesDesc =>
      'Biri sizi hanesine davet ettiğinde burada görünür.';

  @override
  String get householdFamilyAccount => 'Aile hesabı';

  @override
  String get householdInvitedYouViewer =>
      'Sizi SIM hatlarını görmeye davet etti';

  @override
  String get householdInvitedYouManager =>
      'Sizi SIM hatlarını görmeye ve yüklemeye davet etti';

  @override
  String get householdAccept => 'Kabul et';

  @override
  String get householdDecline => 'Reddet';

  @override
  String get householdNotJoinedTitle => 'Henüz bir haneye katılmadınız';

  @override
  String get householdNotJoinedDesc =>
      'Aldığınız davetler Davetler sekmesinde görünür.';

  @override
  String get householdSharedHousehold => 'Paylaşılan hane';

  @override
  String get householdRoleManagerFull => 'YÖNETİCİ · YÜKLEME YAPABİLİR';

  @override
  String get householdRoleViewerFull => 'İZLEYİCİ · SALT OKUNUR';

  @override
  String get householdLeave => 'Ayrıl';

  @override
  String householdOwnerFunds(String owner) {
    return 'Yüklemelerinizi $owner karşılıyor';
  }

  @override
  String householdAllowanceExhausted(String cap) {
    return 'Bu ayın tamamını ($cap) kullandınız. Sıfırlanana kadar hatlarına yapılan yüklemeler reddedilecek.';
  }

  @override
  String householdAllowanceRemaining(String remaining, String cap) {
    return 'Bu ay $cap tutarın $remaining kadarı kaldı';
  }

  @override
  String householdAllowancePerTxn(String perTxn) {
    return ' · yükleme başına en fazla $perTxn';
  }

  @override
  String get householdInviteTitle => 'Bir aile üyesi davet et';

  @override
  String get householdInviteDesc =>
      'Daveti uygulama içinde alırlar. Kabul ettiklerinde sizin ve onların SIM hatları birlikte görünür.';

  @override
  String get householdEmailLabel => 'E-posta adresi';

  @override
  String get householdAccessLevel => 'Ne yapabilir?';

  @override
  String get householdSendInvite => 'Davet gönder';

  @override
  String get householdInvalidEmail => 'Lütfen geçerli bir e-posta adresi girin';

  @override
  String householdInviteSent(String email) {
    return 'Davet $email adresine gönderildi';
  }

  @override
  String householdInviteSentNoAccount(String email) {
    return 'Davet $email adresine gönderildi. Kayıt olur olmaz görecekler.';
  }

  @override
  String get householdInviteAccepted => 'Haneye katıldınız';

  @override
  String get householdInviteDeclined => 'Davet reddedildi';

  @override
  String get householdRemoveTitle => 'Aile üyesini kaldır';

  @override
  String householdRemoveConfirm(String name) {
    return '$name SIM hatlarınıza erişimini ve tanımladığınız harcama limitini anında kaybeder.';
  }

  @override
  String householdRemoved(String name) {
    return '$name hanenizden çıkarıldı';
  }

  @override
  String get householdLeaveTitle => 'Haneden ayrıl';

  @override
  String householdLeaveConfirm(String owner) {
    return '$owner tarafından paylaşılan SIM hatlarına erişiminizi kaybedersiniz.';
  }

  @override
  String get householdLeft => 'Haneden ayrıldınız';

  @override
  String get householdActionFailed =>
      'İşlem başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String get householdOwnerLabel => 'Siz (sahip)';

  @override
  String get householdSettingsSubtitle =>
      'SIM hatlarınızı ailenizle paylaşın, harcama limitleri belirleyin';

  @override
  String get householdStatusDeclined => 'REDDEDİLDİ';

  @override
  String get householdDeclinedHint =>
      'Reddetti. Yeniden davet etmek için kaldırın.';

  @override
  String get carrierActivityFallbackOperator => 'Bu operatör';

  @override
  String get carrierUsageRequiredTitle => 'Otomatik yükleme bu hattı koruyamaz';

  @override
  String carrierUsageRequiredBody(String operator) {
    return '$operator hareketsizlik geri sayımını yalnızca hat arama yaptığında, SMS gönderdiğinde veya veri kullandığında yeniden başlatır. Bakiye yüklemek bu kapsama girmez, bu yüzden hiçbir otomatik yükleme bu numaranın devre dışı kalmasını engelleyemez. Standart planı seçin — hattı kendiniz kullanabilmeniz için sizi zamanında uyaracağız.';
  }

  @override
  String get carrierMinDenominationTitle =>
      'Bu operatör daha büyük bir yükleme gerektiriyor';

  @override
  String carrierMinDenominationBody(
    String operator,
    String amount,
    String currency,
  ) {
    return '$operator yalnızca $amount $currency veya üzeri yüklemelerde hat geçerliliği ekler. Daha küçük tutarlar yalnızca harcanabilir bakiye olarak gelir ve numara yine de devre dışı bırakılabilir, bu yüzden Premium bu hattı $amount $currency ile yükler.';
  }

  @override
  String get premiumUnavailableForCarrier =>
      'Premium bu operatör için kullanılamıyor';

  @override
  String get carrierRulesLinkLabel =>
      'Bu operatörün kuralları hakkında daha fazlası';

  @override
  String get carrierRulesSheetTitle => 'Devre dışı bırakma kuralları';

  @override
  String carrierRulesHowTitle(String operator) {
    return '$operator nasıl karar veriyor';
  }

  @override
  String carrierRechargeOkBody(String operator) {
    return '$operator, hatta her yükleme yapıldığında geri sayımı yeniden başlatır; tutar fark etmez. Otomatik yüklemenin numarayı burada koruyabilmesinin nedeni budur.';
  }

  @override
  String get carrierRulesNumbersTitle => 'Rakamlar';

  @override
  String carrierRulesWindowRow(int days) {
    return 'Sayılan bir yükleme olmadan $days gün sonra devre dışı bırakılır';
  }

  @override
  String carrierRulesGraceRow(int days) {
    return 'Sonrasında aynı numarayı geri almak için $days gün';
  }

  @override
  String get carrierRulesNoGraceRow =>
      'Geri alma süresi yok — numara hemen serbest bırakılır';

  @override
  String carrierRulesMinTopupRow(String amount, String currency) {
    return 'Geçerlilik ekleyen en küçük yükleme $amount $currency';
  }

  @override
  String carrierRulesCadenceRow(int days, int count) {
    return 'Her $days günde bir yükleriz — yılda $count kez';
  }

  @override
  String get carrierRulesVerdictTitle => 'Biz ne yapardık';

  @override
  String get carrierVerdictSelfServiceTitle => 'Bu hat için Premium almayın';

  @override
  String get carrierVerdictSelfServiceBody =>
      'Paranızı tutun. Gönderebileceğimiz hiçbir şey bu operatörün sayacını sıfırlamıyor; numarayı koruyan tek şey onu kullanmanız.';

  @override
  String get carrierVerdictStandardTitle => 'Burada Standard yeterli';

  @override
  String get carrierVerdictStandardBody =>
      'Bu operatör size uzun bir süre tanıyor. Tarihi biz takip edip haber verelim; biz haber verince kendiniz yükleyin, yalnızca kontör parasını ödeyin.';

  @override
  String get carrierVerdictPremiumWorthTitle => 'Premium buna değer';

  @override
  String get carrierVerdictPremiumWorthBody =>
      'Yılda birkaç yükleme, her biri buradan göremediğiniz bir tarihte. İsterseniz elle de yapılabilir — otomatikleştirmek ise hiç düşünmemek demek.';

  @override
  String get carrierVerdictPremiumMustTitle => 'Bunu otomatikleştirin';

  @override
  String get carrierVerdictPremiumMustBody =>
      'Bu operatör, başka bir ülkeden elle hatırlamanın er ya da geç aksayacağı kadar hızlı ilerliyor — ve tek bir aksama numaranın kendisi demek.';

  @override
  String get carrierReasonUsageOnly =>
      'Yalnızca bir arama, bir SMS ya da bir veri oturumu sayılır. Tek başına kontör saymaz.';

  @override
  String carrierReasonQualifying(String amount, String currency) {
    return '$amount $currency altındaki bir yükleme kontör olarak gelir ve hiç geçerlilik kazandırmaz.';
  }

  @override
  String carrierReasonShortWindow(int days) {
    return 'Sayılan iki yükleme arasında yalnızca $days gün var.';
  }

  @override
  String carrierReasonLongWindow(int days) {
    return '$days gün neredeyse tam bir yıl — tek bir hatırlatma yeter.';
  }

  @override
  String get carrierReasonNoGrace =>
      'Ek süre yok. Tarihi kaçırırsanız numara gider.';

  @override
  String carrierReasonGrace(int days) {
    return 'Tarihten sonra numarayı geri almak için $days gününüz olur.';
  }

  @override
  String carrierReasonAutomationCost(
    String self,
    String premium,
    String extra,
  ) {
    return 'Yalnızca kontör yılda yaklaşık $self tutuyor. Premium $premium, yani bunun $extra kadarı otomasyonun bedeli.';
  }

  @override
  String carrierSelfServiceTitle(String operator) {
    return 'Ya da doğrudan $operator üzerinden alın';
  }

  @override
  String get carrierSelfServiceBody =>
      'Operatörün kendi uygulamasından yükleyin; yalnızca kontör parasını ödersiniz, başka hiçbir şey ödemezsiniz.';

  @override
  String carrierSelfServiceCountryLine(String country) {
    return 'Hattın ülkesi: $country';
  }

  @override
  String carrierSelfServiceAppHint(String app) {
    return 'Uygulaması genellikle \"$app\" adıyla yayımlanır.';
  }

  @override
  String carrierSelfServiceUnverified(String operator) {
    return 'Bu uygulama kaydını biz doğrulamadık. Mağazada arayın ve bir şey yüklemeden önce yayıncının gerçekten $operator olduğundan emin olun.';
  }

  @override
  String get carrierSelfServiceSearchStore => 'Uygulama mağazasında ara';

  @override
  String get carrierSelfServiceOpenApp => 'Operatörün uygulamasını aç';

  @override
  String get carrierSelfServiceWeb => 'Operatörün sitesinden yükle';

  @override
  String carrierSelfServiceUssd(String code) {
    return 'İnternet yok mu? Telefonun kendisinden $code tuşlayın.';
  }

  @override
  String get carrierRulesSourceLink => 'Operatörün yayımladığı koşullar';

  @override
  String get carrierRulesDisclaimer =>
      'Operatörler bu kuralları duyurmadan değiştirir. Sizinki değiştirdiyse desteğe bildirin, yeniden kontrol edelim.';

  @override
  String get carrierActionTitle => 'Sizden bir işlem gerekiyor';

  @override
  String get carrierActionDesc =>
      'Bir hat yalnızca benim yapabileceğim bir şeye ihtiyaç duyduğunda haber ver — SIM\'i kullanmak ya da operatörün kendi uygulamasından yüklemek gibi.';

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
  String get mySims => 'SIM\'lerim';

  @override
  String get sharedWithMe => 'Benimle paylaşılan';

  @override
  String get searchNameOrNumber => 'İsim veya numara ara';

  @override
  String get allFilter => 'Tümü';

  @override
  String get alertSoon => 'Yakında uyarı';

  @override
  String get showFilters => 'Filtreleri göster';

  @override
  String get hideFilters => 'Filtreleri gizle';

  @override
  String get refreshSims => 'SIM\'leri yenile';

  @override
  String get noMatchingSims => 'Eşleşen SIM bulunamadı';

  @override
  String get tryDifferentSimSearch =>
      'Farklı bir isim, numara veya filtre deneyin.';

  @override
  String get clearSearchAndFilters => 'Aramayı ve filtreleri temizle';

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
