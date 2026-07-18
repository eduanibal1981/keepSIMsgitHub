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
}
