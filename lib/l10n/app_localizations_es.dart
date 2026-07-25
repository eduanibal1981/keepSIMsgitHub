// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'KeepSIMs';

  @override
  String get preferencesAndSecurity => 'Preferencias y Seguridad';

  @override
  String get appAppearance => 'Apariencia de la App';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get lightMode => 'Modo Claro';

  @override
  String get localizationAndRegional => 'Localización y Regional';

  @override
  String get appLanguage => 'Idioma de la App';

  @override
  String currentlyUsing(String langName) {
    return 'Usando actualmente $langName regional';
  }

  @override
  String get selectAppLanguage => 'Seleccionar Idioma de la App';

  @override
  String get securityAndAccessLock => 'Seguridad y Bloqueo de Acceso';

  @override
  String get biometricSecurity => 'Seguridad Biométrica';

  @override
  String get biometricDesc => 'Iniciar sesión con Face ID o Touch ID';

  @override
  String get biometricReasonPayment => 'Autentícate para confirmar el pago';

  @override
  String get biometricReasonUnlock => 'Autentícate para desbloquear KeepSIMs';

  @override
  String get biometricLockout =>
      'Autenticación biométrica bloqueada por demasiados intentos fallidos. Utiliza el código de acceso de tu dispositivo.';

  @override
  String get biometricNotEnrolled =>
      'La autenticación biométrica no está configurada en este dispositivo.';

  @override
  String get biometricAppLockTitle => 'KeepSIMs está bloqueado';

  @override
  String get biometricUnlockButton => 'Desbloquear con biometría';

  @override
  String get biometricCancel => 'Cancelar';

  @override
  String get transactionPin => 'PIN de Transacción';

  @override
  String get transactionPinDesc => 'Proteger renovaciones y retiros';

  @override
  String get setup => 'CONFIGURAR';

  @override
  String get pinSuccess => '¡PIN de transacción actualizado correctamente!';

  @override
  String get pinMismatch => 'Los PINs no coinciden. ¡Inténtalo de nuevo!';

  @override
  String get pinActiveAndSecure =>
      'La configuración del PIN está activa y segura';

  @override
  String get automatedSummaryAndAlerts => 'Resumen Automatizado y Alertas';

  @override
  String get weeklyDigest => 'Resumen Semanal';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get nextNotify => 'PRÓXIMA NOTIFICACIÓN';

  @override
  String get days => 'días';

  @override
  String get showingNearestLine => 'Mostrando la línea más cercana';

  @override
  String get addSim => 'Agregar SIM';

  @override
  String get linesToProtect => 'Líneas a Proteger';

  @override
  String get active => 'Activo';

  @override
  String get upgrade => 'ACTUALIZAR';

  @override
  String get standard => 'ESTÁNDAR';

  @override
  String get autoNotify => 'Notificación Automática';

  @override
  String get configure => 'Configurar';

  @override
  String get autoRefill => 'Recarga Automática';

  @override
  String get quickActions => 'Acciones Rápidas';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSims => 'SIMs';

  @override
  String get navMore => 'Más';

  @override
  String get protectedSims => 'SIMs Protegidas';

  @override
  String get mySimCards => 'Mis Tarjetas SIM';

  @override
  String get familySharedSims => 'SIMs Compartidas Familiares';

  @override
  String get protectAnotherSimLine => 'Proteger Otra Línea SIM';

  @override
  String get keepInfiniteNumbersAlive =>
      'Mantén activos infinitos números internacionales';

  @override
  String get bulkActionsConsole => 'Consola de Acciones Masivas';

  @override
  String get resume => 'Reanudar';

  @override
  String get pause => 'Pausar';

  @override
  String get simulate => 'Simular';

  @override
  String get noProtectedLines => 'Sin Líneas Protegidas';

  @override
  String get noInternationalSimsAdded =>
      'Aún no tienes tarjetas SIM internacionales agregadas. Protege tu primera tarjeta ahora para mantenerla activa para siempre.';

  @override
  String get protectNewLine => 'Proteger Nueva Línea';

  @override
  String get noSharedSimsYet => 'Aún no hay SIMs compartidas';

  @override
  String get inviteFamilyMembers =>
      'Invita a miembros de tu familia a unirse a tu Hogar. Una vez que acepten, sus líneas SIM protegidas aparecerán aquí para monitoreo colaborativo.';

  @override
  String get manageHousehold => 'Gestionar Hogar';

  @override
  String get manageProfileDesc =>
      'Gestiona tu perfil, líneas SIM, alertas y preferencias compartidas';

  @override
  String get keepSIMsUser => 'Usuario de KeepSIMs';

  @override
  String get pro => 'PRO';

  @override
  String get homeCountry => 'País de Origen: ';

  @override
  String get console => 'Consola';

  @override
  String get offlineRefill => 'Recarga Sin Conexión (SMS/WA)';

  @override
  String get refillSimOfflineDesc =>
      'Recarga el saldo de la SIM sin conexión mediante SMS o WhatsApp';

  @override
  String get wallet => 'Billetera';

  @override
  String get manageBalancesDesc =>
      'Gestiona tus saldos y visualiza el historial de transacciones';

  @override
  String get alertPreferences => 'Preferencias de Alertas';

  @override
  String get togglePushEmailDesc =>
      'Activar/desactivar configuraciones de push y correo para renovaciones/saldos';

  @override
  String get referAndEarn => 'Referir y Ganar';

  @override
  String get shareKeepSIMsDesc =>
      'Comparte KeepSIMs, desbloquea recompensas de saldo dinámicas';

  @override
  String get paymentMethods => 'Métodos de Pago';

  @override
  String get addBankCardsDesc =>
      'Agrega tarjetas bancarias o vincula cuentas de retiro automático';

  @override
  String get travelAndGeolocation => 'Viajes y Geolocalización';

  @override
  String get manageHomeCountryDesc =>
      'Gestiona reglas de congelamiento del país de origen y modo viaje';

  @override
  String get dataAndPrivacy => 'Datos y Privacidad';

  @override
  String get manageTrackingConsentDesc =>
      'Gestiona tu consentimiento de seguimiento, exporta datos o elimina la cuenta';

  @override
  String get powerUser => 'Usuario Avanzado';

  @override
  String get accessSystemSimulatorsDesc =>
      'Accede a simuladores del sistema y herramientas de diagnóstico';

  @override
  String get testChecklist => 'Lista de Pruebas';

  @override
  String get manualUiTestingDesc =>
      'Lista de verificación de pruebas manuales de UI para aseguramiento de calidad';

  @override
  String get soon => 'PRÓXIMAMENTE';

  @override
  String featureComingSoon(String feature) {
    return '¡La función $feature estará disponible pronto!';
  }

  @override
  String get logOut => 'Cerrar Sesión';

  @override
  String get confirmLogOut =>
      '¿Estás seguro de que quieres cerrar sesión en KeepSIMs?';

  @override
  String get walletLedger => 'Libro Mayor de Billetera';

  @override
  String get keepSIMsPrepaid => 'KeepSIMs PREPAGO';

  @override
  String get offlineMode => 'MODO SIN CONEXIÓN';

  @override
  String get activeBalance => 'Saldo Activo';

  @override
  String get criticalBalanceLevel => 'Nivel de Saldo Crítico';

  @override
  String get balanceBelow10 =>
      'Tu saldo está por debajo de \$10.00. Las recargas programadas de SIM podrían fallar pronto.';

  @override
  String get depositFunds => 'Depositar Fondos';

  @override
  String get walletDepositsRequireInternet =>
      'Los depósitos a la billetera requieren conexión a internet activa.';

  @override
  String get exportLedger => 'Exportar Libro Mayor';

  @override
  String get ledgerHistoryExported =>
      'Historial del libro mayor exportado como CSV.';

  @override
  String get spendAnalysis => 'Análisis de Gastos';

  @override
  String get transactionHistory => 'Historial de Transacciones';

  @override
  String itemsCount(int count) {
    return '$count elementos';
  }

  @override
  String get noTransactionsRecorded =>
      'Aún no se han registrado transacciones.';

  @override
  String get prepaidMonthlyOutflow => 'Salida Mensual Prepago';

  @override
  String avgMonthlySpend(String amount) {
    return 'Prom: \$$amount/mes (12M)';
  }

  @override
  String depositViaCard(String last4) {
    return 'Depósito con tarjeta terminada en $last4';
  }

  @override
  String get lineRenewal => 'Renovación de Línea';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get loadCreditFunds => 'Cargar Fondos de Crédito';

  @override
  String get depositAmountUsd => 'Monto de Depósito (USD)';

  @override
  String get pleaseEnterAmount => 'Por favor ingresa un monto';

  @override
  String get enterPositiveNumber => 'Ingresa un número positivo';

  @override
  String get cardDetails => 'Detalles de la Tarjeta';

  @override
  String get savedCards => 'Tarjetas Guardadas';

  @override
  String get visaCardNumber => 'Número de Tarjeta Visa';

  @override
  String get pleaseEnterCardNumber => 'Por favor ingresa el número de tarjeta';

  @override
  String get mustBe16Digits => 'Debe tener 16 dígitos';

  @override
  String get expiryMmYy => 'Vencimiento (MM/AA)';

  @override
  String get expiryRequired => 'Vencimiento requerido';

  @override
  String get invalid => 'Inválido';

  @override
  String get cvv => 'CVV';

  @override
  String get cvvRequired => 'CVV requerido';

  @override
  String get verifyingCardSecurity => 'Verificando Seguridad de la Tarjeta...';

  @override
  String get authorizeDepositFunds => 'Autorizar Depósito de Fondos';

  @override
  String successfullyDeposited(String amount) {
    return '¡Se depositaron \$$amount USD exitosamente!';
  }

  @override
  String get failedToDepositFunds =>
      'Error al depositar fondos. Por favor verifica la conexión de la tarjeta.';

  @override
  String get noSavedPaymentMethods =>
      'No se encontraron métodos de pago guardados.';

  @override
  String get addPaymentMethod => 'Agregar Método de Pago';

  @override
  String get savedPaymentMethods => 'Métodos de Pago Guardados';

  @override
  String get addAnotherPaymentMethod => 'Agregar otro método de pago';

  @override
  String expiresMmYy(String month, String year) {
    return 'Vence $month/$year';
  }

  @override
  String get offlineRefillTitle => 'Recarga Sin Conexión (SMS/WA)';

  @override
  String get offlineRefillSubtitle =>
      'Trigger a top-up with no data and no credit';

  @override
  String get selectTargetSimLine => 'Seleccionar Línea SIM Objetivo';

  @override
  String get noRegisteredSimLines =>
      'No se encontraron líneas SIM registradas.';

  @override
  String get targetSimLine => 'Línea SIM Objetivo';

  @override
  String get simLine => 'Línea SIM';

  @override
  String get carrier => 'OPERADORA';

  @override
  String get change => 'Cambiar';

  @override
  String get offlineRefillProtection => 'Protección de Recarga Sin Conexión';

  @override
  String get premiumExclusive => 'EXCLUSIVO PREMIUM';

  @override
  String get neverGetStrandedDesc =>
      'Nunca más te quedes sin datos móviles. KeepSIMs Premium te permite recargar el saldo de tu SIM sin conexión mediante SMS estándar o mensajes de WhatsApp cuando no tienes conexión a internet.';

  @override
  String get offlineCapability100 => '100% de Capacidad Sin Conexión';

  @override
  String get deductsFromKeepSIMsDesc =>
      'Descuenta de tu billetera KeepSIMs para acreditar tu línea mediante conmutaciones de pasarela SMS local.';

  @override
  String get dynamicUssdPlanActivation => 'Activación Dinámica de Plan USSD';

  @override
  String get exactCopyPasteDialCodesDesc =>
      'Proporciona códigos de marcación exactos para copiar y pegar (ej., *900*1#) para activar paquetes de Datos+Llamadas sin conexión.';

  @override
  String get dualChannelSupport => 'Soporte de Canal Dual';

  @override
  String get textRefillDesc =>
      'Envía \"RECARGA\" mediante SMS estándar o WhatsApp según la cobertura celular disponible.';

  @override
  String get close => 'Cerrar';

  @override
  String get howToTriggerOfflineRefill =>
      'Cómo Activar la Recarga Sin Conexión';

  @override
  String get ifZeroMobileDataDesc1 =>
      'Si no tienes datos móviles, envía un SMS estándar o mensaje de WhatsApp que contenga solo ';

  @override
  String get refill => 'RECARGA';

  @override
  String get toOurSecureGatewayDesc2 =>
      ' a nuestra pasarela de sistema segura:';

  @override
  String get targetSimLineLabel => 'LÍNEA SIM OBJETIVO';

  @override
  String get configureCashRefillAmount =>
      'CONFIGURAR MONTO DE RECARGA EN EFECTIVO';

  @override
  String get refillAmount => 'Monto de Recarga';

  @override
  String walletBalanceUsd(String amount) {
    return 'Saldo de Billetera: \$$amount USD';
  }

  @override
  String get lowBalanceWarning => '⚠️ Saldo Bajo';

  @override
  String get localCarrierPlanSuggestions =>
      'SUGERENCIAS DE PLAN DE OPERADORA LOCAL';

  @override
  String get noStandardUssdDialCodes =>
      'No se encontraron códigos de marcación USSD estándar para esta operadora. Aún recibirás la recarga en efectivo exitosamente en tu línea.';

  @override
  String get dynamicDialCodesPreview =>
      'Vista Previa de Códigos de Marcación Dinámicos';

  @override
  String get botSuggestDialingCodes =>
      'Tras completarse la recarga sin conexión, el bot sugerirá marcar estos códigos exactos en tu teléfono para desbloquear Datos+Llamadas sin conexión de inmediato:';

  @override
  String costAmount(String amount) {
    return 'Costo: \$$amount';
  }

  @override
  String get whatsappSmsSenderOverride => 'ANULACIÓN DE REMITENTE WHATSAPP/SMS';

  @override
  String get verificationNumber => 'Número de Verificación';

  @override
  String get triggerRefillsDifferentNumber =>
      'Si activas recargas desde un número diferente al teléfono principal de tu perfil, ingrésalo a continuación con código de país (ej. 96891234567).';

  @override
  String get enterPhoneNumberDigits =>
      'Ingresa número de teléfono (solo dígitos)';

  @override
  String get offlineRefillSettingsSaved =>
      '¡Configuración de Recarga Sin Conexión guardada exitosamente!';

  @override
  String get saveSettings => 'Guardar Configuración';

  @override
  String errorLoadingSettings(String error) {
    return 'Error al cargar la configuración: $error';
  }

  @override
  String get retry => 'Reintentar';

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
  String get offlineRefillChannelsHeader => 'Formas de recargar sin conexión';

  @override
  String offlineRefillTopUpFromWallet(String amount) {
    return 'Recarga $amount desde tu billetera';
  }

  @override
  String get offlineRefillWalletFunded => 'Desde tu billetera';

  @override
  String offlineRefillServiceFee(String fee) {
    return '+$fee de comisión';
  }

  @override
  String get offlineRefillMissedCallTitle => 'Da una llamada perdida';

  @override
  String get offlineRefillMissedCallSubtitle => 'Sin saldo ni datos';

  @override
  String get offlineRefillCallAction => 'Llama para recargar';

  @override
  String get offlineRefillRetry => 'Reintentar';

  @override
  String offlineRefillWaitSeconds(int seconds) {
    return 'Espera ${seconds}s';
  }

  @override
  String get offlineRefillStatusSent => 'Enviado — esperando confirmación';

  @override
  String get offlineRefillStatusProcessing => 'Recargando tu línea…';

  @override
  String get offlineRefillStatusConfirmed => 'Recarga confirmada';

  @override
  String get offlineRefillStatusFailed => 'No se completó — prueba otra vía';

  @override
  String get offlineRefillStatusTimedOut =>
      'Sin respuesta aún — prueba otra vía';

  @override
  String get offlineRefillUssdTitle => 'Aprovecha más tu recarga';

  @override
  String get offlineRefillUssdSubtitle =>
      'Cuando llegue el saldo, marca el código de tu operador para el mejor valor';

  @override
  String get offlineRefillUssdDial => 'Marcar';

  @override
  String get editProtectedLine => 'Editar Línea Protegida';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get activateShieldProtection => 'Activar Protección Shield';

  @override
  String get phoneNumber => 'Número de Teléfono';

  @override
  String get nicknameOptional => 'Apodo (Opcional)';

  @override
  String get whatsappAlerts => 'Alertas de WhatsApp';

  @override
  String get emailAlertsDesc =>
      'Alertas críticas de desactivación enviadas vía Resend';

  @override
  String get refillWalletLow =>
      'Recargar billetera cuando los fondos estén bajos';

  @override
  String get legalPoliciesDesc =>
      'Al usar KeepSIMs, aceptas nuestros términos. KeepSIMs proporciona herramientas para ayudar a gestionar el ciclo de vida de tu SIM, pero no somos responsables de pérdidas directas o indirectas, daños o interrupciones del servicio causados por proveedores de telecomunicaciones de terceros.';

  @override
  String get globalTravelModeDesc =>
      'Permite que las reglas de geovallado automatizadas activen rutinas de cruce de fronteras';

  @override
  String get dataPreferences => 'Preferencias de Datos';

  @override
  String get doNotDisturb => 'No Molestar';

  @override
  String get linkedCards => 'Tarjetas Vinculadas';

  @override
  String get analyticsTracking => 'Analíticas y Seguimiento';

  @override
  String get dubai => 'Dubái';

  @override
  String get flyHome => 'Volar a Casa';

  @override
  String get managePreferencesAndSecurityDesc =>
      'Gestiona tema, idioma y bloqueos biométricos';

  @override
  String get autoFundingRulesDesc =>
      'Mantén la renovación de SIM en funcionamiento continuo habilitando recargas automáticas desde tu tarjeta de crédito predeterminada cuando el saldo baje demasiado';

  @override
  String get pushNotifications => 'Notificaciones Push';

  @override
  String get quietHoursSchedule => 'Horario de Silencio y Programación';

  @override
  String get exportMyDataDesc =>
      'Descarga una copia JSON de tu perfil y preferencias (Derecho de Acceso RGPD)';

  @override
  String get borderSimulatorTitle => 'Simulador de Cruce de Fronteras';

  @override
  String get yourData => 'Tus Datos';

  @override
  String get mostImportant => 'Más Importante';

  @override
  String get emailAlerts => 'Alertas por Correo';

  @override
  String get pushNotificationsDesc =>
      'Notificaciones nativas agresivas en este dispositivo';

  @override
  String get alertSettingsTitle => 'Configuración de Alertas';

  @override
  String get atHome => 'EN CASA';

  @override
  String get telegramBotDesc =>
      'Notificaciones interactivas de chat de Telegram vinculadas';

  @override
  String get alertChannels => 'Canales de Alerta';

  @override
  String get london => 'Londres';

  @override
  String get shieldProtection => 'Protección Shield';

  @override
  String get legalPolicies => 'Legal y Políticas';

  @override
  String get supportVisaMastercard =>
      'Compatible con Visa y MasterCard de débito o crédito de forma segura';

  @override
  String get exportMyData => 'Exportar Mis Datos';

  @override
  String get dangerZone => 'Zona de Peligro';

  @override
  String get analyticsTrackingDesc =>
      'Ayúdanos a mejorar la app compartiendo datos de uso anónimos. La funcionalidad esencial de la app no se verá afectada si está deshabilitado';

  @override
  String get autoFundingRules => 'Reglas de Financiamiento Automático';

  @override
  String get singapore => 'Singapur';

  @override
  String get weeklySummaryDigest => 'Resumen Semanal Compilado';

  @override
  String get fullyShielded => 'Totalmente Protegido';

  @override
  String get dndDesc =>
      'Silenciar notificaciones push durante las horas de sueño especificadas';

  @override
  String get paymentsAutoFundTitle => 'Pagos y Financiamiento Automático';

  @override
  String get travelGeolocationTitle => 'Viajes y Geolocalización';

  @override
  String get telegramBot => 'Bot de Telegram';

  @override
  String get weeklyDigestDesc =>
      'Informe de estado compilado de todas las tarjetas SIM cada domingo a las 9:00 AM';

  @override
  String get borderSimulatorDesc =>
      'Simula embarques para activar reglas de congelamiento inteligente o reanudación del país activo.';

  @override
  String get linkFirstCard => 'Vincula tu primera tarjeta de pago';

  @override
  String get globalTravelMode => 'Modo de Viaje Global';

  @override
  String get readPrivacyPolicy =>
      'Leer Política de Privacidad Completa y Términos';

  @override
  String get whatsappAlertsDesc =>
      'Alertas de fallo de recarga enviadas directamente a WhatsApp';

  @override
  String get abroadTraveling => 'EN EL EXTRANJERO / VIAJANDO';

  @override
  String get freezeAllLines => 'Congelar Todas las Líneas';

  @override
  String get resumeRenewals => 'Reanudar Renovaciones';

  @override
  String get freezeRecommendationDesc =>
      'Detectamos que actualmente estás en tu País de Origen. Puedes congelar las renovaciones de tus líneas internacionales para evitar el agotamiento no deseado del saldo de la billetera.';

  @override
  String get travelDetected => '¡Viaje Detectado! ✈️';

  @override
  String get resumeRecommendationDesc =>
      'Estás viajando al extranjero. Por favor reanuda las renovaciones de tus SIM internacionales pausadas para garantizar cobertura de red móvil ininterrumpida.';

  @override
  String get dismiss => 'Descartar';

  @override
  String get welcomeHome => '¡Bienvenido a Casa! 🏡';

  @override
  String get addCard => 'Agregar Tarjeta';

  @override
  String get noAlertChannelsConfigured =>
      'No se han configurado canales de entrega de alertas.';

  @override
  String channelSettingsUpdated(String channelName) {
    return 'Configuración de $channelName actualizada.';
  }

  @override
  String channelLocked(String channelName) {
    return '$channelName Bloqueado 🔒';
  }

  @override
  String lockedAlertSubtitle(String channelName) {
    return 'Las alertas de $channelName son funciones de los planes Starter y Premium. ¡Actualiza tu plan para desbloquear alertas de WhatsApp, Telegram y Correo!';
  }

  @override
  String get upsellProtect5Lines =>
      'Protege hasta 5 líneas SIM simultáneamente';

  @override
  String get upsellUnlockChannels =>
      'Desbloquea notificaciones de WhatsApp, Telegram y Correo';

  @override
  String get upsellEnableTravelModes =>
      'Habilita modos de validez automáticos para Viaje y Casa';

  @override
  String get emailAddressLabel => 'Correo de Notificaciones';

  @override
  String get emailAddressHint => 'ej. usuario@dominio.com';

  @override
  String get whatsappNumberLabel =>
      'Número de WhatsApp (Formato Internacional)';

  @override
  String get whatsappNumberHint => 'ej. +96891234567';

  @override
  String get whatsappFormatInstruction =>
      'Ingresa el formato internacional completo comenzando con + (ej. +96893990492)';

  @override
  String telegramStatusBound(String chatId) {
    return 'Estado: Vinculado (Chat ID: $chatId)';
  }

  @override
  String get telegramStatusUnbound => 'Estado: No Vinculado';

  @override
  String get telegramLinkInstructions =>
      'Para recibir alertas interactivas de Telegram de forma gratuita, vincula nuestro Bot de Telegram con tu cuenta.';

  @override
  String get linkTelegramBot => 'Vincular Bot de Telegram';

  @override
  String get emailFreePlanGuarded =>
      'Plan Gratuito de Resend Protegido: Limitado solo a disparadores de desactivación. Sin spam promocional.';

  @override
  String get whatsappMetaCloudCapped =>
      'Meta Cloud Directo con Límite: Máximo 1 mensaje por programación de recarga, enviado SOLO si la recarga automática no está activa o falla.';

  @override
  String get failedToLoadPaymentInfo => 'Error al cargar información de pago';

  @override
  String get defaultCardIndicator => 'PREDETERMINADA';

  @override
  String get cardholder => 'TITULAR';

  @override
  String get expires => 'VENCE';

  @override
  String get lowBalanceTrigger => 'Disparador de Saldo Bajo';

  @override
  String get triggerLowTopUp => 'Activar recarga por saldo bajo';

  @override
  String get reloadDepositAmount => 'Monto de Depósito de Recarga';

  @override
  String get amountToLoad => 'Monto a cargar';

  @override
  String get linkCreditDebitCard => 'Vincular Tarjeta de Crédito/Débito';

  @override
  String get cardNumberLabel => 'NÚMERO DE TARJETA';

  @override
  String get expiryDateLabel => 'FECHA DE VENCIMIENTO';

  @override
  String get cvvCodeLabel => 'CÓDIGO CVV';

  @override
  String get securelyLinkCard => 'Vincular Tarjeta de Forma Segura';

  @override
  String get pleaseEnterValidCardNumber =>
      'Por favor ingresa un número de tarjeta válido de 16 dígitos.';

  @override
  String get pleaseEnterValidExpiryDate =>
      'Por favor ingresa una fecha de vencimiento válida (MM/AA).';

  @override
  String get invalidExpiryMonth => 'Mes de vencimiento inválido.';

  @override
  String get cvvMustBe3Digits => 'El CVV debe tener 3 dígitos.';

  @override
  String get cardLinkedSuccessfully =>
      '¡Tarjeta de facturación segura vinculada exitosamente!';

  @override
  String get defaultPaymentCardUpdated =>
      '¡Tarjeta de pago predeterminada actualizada!';

  @override
  String get removePaymentCard => 'Eliminar Tarjeta de Pago';

  @override
  String get confirmRemoveCardDesc =>
      '¿Estás seguro de que quieres eliminar esta tarjeta? El financiamiento automático vinculado podría fallar si no queda ninguna tarjeta de pago predeterminada.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get remove => 'Eliminar';

  @override
  String get billingCardSuccessfullyRemoved =>
      'Tarjeta de facturación eliminada exitosamente.';

  @override
  String get pleaseAddDefaultCardFirst =>
      'Por favor agrega y selecciona primero una tarjeta de pago predeterminada para habilitar el financiamiento automático.';

  @override
  String get autoFundPrefsSavedSuccess =>
      '¡Preferencias de Financiamiento Automático guardadas exitosamente!';

  @override
  String get preparingDataExport => 'Preparando exportación de datos...';

  @override
  String exportFailed(String error) {
    return 'Error de exportación: $error';
  }

  @override
  String get deleteAccountWarning =>
      'Una vez que elimines tu cuenta, no hay vuelta atrás. Por favor asegúrate.';

  @override
  String get deleteAccount => 'Eliminar Cuenta';

  @override
  String get deleteAccountIrreversible =>
      'Esta acción es irreversible. Todos tus datos serán eliminados permanentemente.';

  @override
  String get typeDeleteToConfirm => 'Escribe \"ELIMINAR\" para confirmar:';

  @override
  String get deleteWord => 'ELIMINAR';

  @override
  String get systemDiagnosticsLogs => 'REGISTROS DE DIAGNÓSTICO DEL SISTEMA';

  @override
  String get online => 'EN LÍNEA';

  @override
  String errorLoadingPrefs(String error) {
    return 'Error al cargar preferencias: $error';
  }

  @override
  String get privacyPolicyLoaded =>
      'Detalles de la Política de Privacidad cargados.';

  @override
  String get protectionConsole => 'Consola de Protección';

  @override
  String get deleteProtectionTooltip => 'Eliminar Protección';

  @override
  String get refreshTooltip => 'Actualizar';

  @override
  String get failedToLoadDetails => 'Error al cargar detalles';

  @override
  String get retryConnection => 'Reintentar Conexión';

  @override
  String get healthLabel => 'salud';

  @override
  String get mySimCardDefault => 'Mi Tarjeta SIM';

  @override
  String get upLabel => 'ACTIVO';

  @override
  String sharedByFamily(String ownerName, String role) {
    return 'Compartido por: $ownerName ($role)';
  }

  @override
  String get criticalRisk => 'Riesgo crítico';

  @override
  String get simDeactivationRisk => 'La SIM puede desactivarse sin acción';

  @override
  String get missingAlertsDesc =>
      'Sin notificaciones de alerta configuradas — faltan 100 pts';

  @override
  String get missingAutoRefillDesc =>
      'Sin recarga automática configurada — faltan 50 pts';

  @override
  String get missingVerificationDesc =>
      'Número de teléfono no verificado — faltan 25 pts';

  @override
  String get missingRecentRefillDesc =>
      'La última recarga fue hace más de 80 días — faltan 25 pts';

  @override
  String get quickActionsLabel => 'Acciones Rápidas';

  @override
  String get manualRefillLabel => 'Recarga Manual';

  @override
  String get chargeFromWalletNow => 'Cargar desde billetera ahora';

  @override
  String get rechargeFromFriend => 'Recargar desde un Amigo';

  @override
  String get requestViaTelegram => 'Solicitar vía Telegram';

  @override
  String get shareViaWaTg => 'Compartir vía WhatsApp/Telegram';

  @override
  String get testSimActivity => 'Probar Actividad de SIM';

  @override
  String get verifyLineReachable => 'Verificar que la línea es accesible';

  @override
  String get checkCompleted1x => '1 Verificación Completada';

  @override
  String get starterPlan1xCompleted =>
      'Verificación 1x del plan Starter completada. Actualiza a Premium para verificaciones ilimitadas.';

  @override
  String leaveCountry(String countryName) {
    return 'Salir de $countryName';
  }

  @override
  String get resumeProtectionLayers => 'Reanudar capas de protección';

  @override
  String backToCountryMode(String countryName) {
    return 'Volver al modo $countryName';
  }

  @override
  String get pauseWhileVisitingHome => 'Pausar mientras se visita el hogar';

  @override
  String get rechargeFromFriendTitle => 'Recargar desde un Amigo';

  @override
  String get selectPlatformShare =>
      'Selecciona una plataforma para compartir un mensaje de solicitud de recarga con tu amigo.';

  @override
  String rechargeRequestTemplate(String phone) {
    return '¡Hola! Mi tarjeta KeepSIMs ($phone) está por vencer. ¿Podrías recargarla por mí? ¡Gracias!';
  }

  @override
  String get requestViaWhatsApp => 'Solicitar vía WhatsApp';

  @override
  String couldNotLaunchLink(String platformName, String error) {
    return 'No se pudo abrir el enlace de $platformName: $error';
  }

  @override
  String couldNotLaunchTelegram(String error) {
    return 'No se pudo abrir el enlace de Telegram: $error';
  }

  @override
  String get protectionLayersLabel => 'Capas de Protección';

  @override
  String get autoNotifyDisabled => 'Notificación Automática: Deshabilitada';

  @override
  String get noActiveAlertSchedule =>
      'Tu tarjeta SIM no tiene una programación de notificaciones de alerta activa. No recibirás recordatorios automáticos ni alertas de desactivación.';

  @override
  String get askOwnerConfigureAlerts =>
      'Por favor solicita al propietario del hogar que configure las alertas.';

  @override
  String get configureAutoNotify => 'Configurar Notificación Automática';

  @override
  String get activeLabel => 'ACTIVO';

  @override
  String get pausedHomeMode => 'PAUSADO (MODO HOGAR)';

  @override
  String get pausedLabel => 'PAUSADO';

  @override
  String get everyHour => 'Cada 1 hora';

  @override
  String everyNDays(int days) {
    return 'Cada $days días';
  }

  @override
  String get nextAlertCheck => 'Próxima Verificación de Alerta';

  @override
  String get premiumKeepAliveRefill => 'Recarga Premium Keep-Alive';

  @override
  String autoRefillIncludedText(String date) {
    return 'Recarga automática incluida - ~3.5 USD (telecom, IVA incluido) cada 85 días,\\nnext refill on $date';
  }

  @override
  String get premiumKeepAliveDisabled =>
      'La recarga premium keep-alive está actualmente deshabilitada.';

  @override
  String get customAutoRefill => 'Recarga Automática Personalizada';

  @override
  String get addAdditionalScheduledRecharge =>
      'Agrega un monto de recarga programada adicional para mantener un saldo extra en tu SIM.';

  @override
  String get askOwnerConfigureRefill =>
      'Por favor solicita al propietario del hogar que configure la Recarga Automática.';

  @override
  String get configureCustomAutoRefill =>
      'Configurar Recarga Automática Personalizada';

  @override
  String get rechargeAmount => 'Monto de Recarga';

  @override
  String get refillInterval => 'Intervalo de Recarga';

  @override
  String get nextRefillDue => 'Próxima Recarga Programada';

  @override
  String get failedRefillAttempts => 'Intentos de Recarga Fallidos';

  @override
  String retriesCount(int count) {
    return '$count / 4 intentos';
  }

  @override
  String get editRefillAmount => 'Editar Monto de Recarga';

  @override
  String get refillExecutionsHistory => 'Historial de Ejecuciones de Recarga';

  @override
  String get renewalExecutionsHistory =>
      'Historial de Ejecuciones de Renovación';

  @override
  String get noHistoricalTopup =>
      'Aún no se han registrado ejecuciones históricas de recarga para esta línea.';

  @override
  String get noHistoricalRenewal =>
      'Aún no se han registrado ejecuciones históricas de renovación para esta línea.';

  @override
  String get viewAllHistory => 'Ver Todo el Historial';

  @override
  String get securityActivityLogs => 'Registros de Actividad de Seguridad';

  @override
  String get clearLogs => 'Limpiar Registros';

  @override
  String get noActivityLogsRecorded =>
      'Aún no se han registrado actividades para esta línea.';

  @override
  String get activityLogDeleted =>
      'Entrada de registro de actividad eliminada.';

  @override
  String get activityLogsCleared =>
      'Registros de actividad limpiados exitosamente.';

  @override
  String autoRenewalStatusUpdated(String status) {
    return 'Renovación Automática $status exitosamente.';
  }

  @override
  String failedToUpdateSchedule(String error) {
    return 'Error al actualizar la programación: $error';
  }

  @override
  String get premiumRefillEnabled =>
      'Recarga premium keep-alive habilitada exitosamente.';

  @override
  String failedToEnableAutoRefill(String error) {
    return 'Error al habilitar la recarga automática: $error';
  }

  @override
  String get removeScheduleTitle => 'Eliminar Programación';

  @override
  String get confirmDeleteAutoRefill =>
      '¿Estás seguro de que quieres eliminar esta programación de recarga automática? Tu puntuación de salud de SIM descenderá significativamente, arriesgando la desactivación.';

  @override
  String get confirmDeleteAutoRenewal =>
      '¿Estás seguro de que quieres eliminar esta programación de renovación automática? Tu puntuación de salud de SIM descenderá significativamente, arriesgando la desactivación.';

  @override
  String get autoRefillRemoved =>
      'Programación de recarga automática eliminada exitosamente.';

  @override
  String get autoRenewalRemoved =>
      'Programación de renovación automática eliminada exitosamente.';

  @override
  String failedToDeleteSchedule(String error) {
    return 'Error al eliminar la programación: $error';
  }

  @override
  String get refillRetrySuccess =>
      '¡Reintento de recarga completado exitosamente!';

  @override
  String get refillRetryQueued =>
      'Reintento en cola — la recarga se está procesando.';

  @override
  String get renewalRetrySuccess =>
      '¡Reintento de renovación completado exitosamente!';

  @override
  String retryFailed(String error) {
    return 'Error en el reintento: $error';
  }

  @override
  String retryExecutionError(String error) {
    return 'Error de ejecución del reintento: $error';
  }

  @override
  String failedToDeleteActivityLog(String error) {
    return 'Error al eliminar el registro de actividad: $error';
  }

  @override
  String failedToClearActivityLogs(String error) {
    return 'Error al limpiar los registros de actividad: $error';
  }

  @override
  String get removeProtectionTitle => 'Eliminar Protección';

  @override
  String confirmRemoveProtectionDesc(String name) {
    return '¿Estás seguro de que quieres dejar de proteger $name? Las recargas programadas para esta línea SIM serán canceladas permanentemente.';
  }

  @override
  String get simLineProtectionRemoved =>
      'Protección de línea SIM eliminada exitosamente.';

  @override
  String failedToDeleteSimLine(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get editSimNameTitle => 'Editar Nombre de SIM';

  @override
  String get enterNicknameInstruction =>
      'Ingresa un apodo para esta línea de tarjeta SIM:';

  @override
  String get nicknameExampleHint => 'ej. Mi SIM Orange Egipto';

  @override
  String get simNameUpdatedSuccess => 'Nombre de SIM actualizado exitosamente.';

  @override
  String failedToUpdateSimName(String error) {
    return 'Error al actualizar el nombre de SIM: $error';
  }

  @override
  String get saveButton => 'Guardar';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get autoNotifySchedule => 'Programación de Notificación Automática';

  @override
  String get renewalCheckInterval => 'Intervalo de Verificación de Renovación';

  @override
  String get editNotificationConfig => 'Editar Configuración de Notificaciones';

  @override
  String get openTicket => 'Abrir Ticket';

  @override
  String get offlineRefillLabel => 'Recarga Sin Conexión';

  @override
  String get categoryLabel => 'Categoría';

  @override
  String get techSupportCategory => 'Soporte Técnico';

  @override
  String get billingWalletCategory => 'Facturación y Billetera';

  @override
  String get simLinesCategory => 'Gestión de Líneas SIM';

  @override
  String get feedbackOtherCategory => 'Comentarios y Otros';

  @override
  String get subjectLabel => 'Asunto';

  @override
  String get subjectHint => 'Breve resumen del problema';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get descriptionHint => 'Describe tu problema en detalle...';

  @override
  String get attachmentLabel => 'Adjunto (Opcional)';

  @override
  String get uploadScreenshot => 'Subir Captura de Pantalla';

  @override
  String get submitTicketButton => 'Enviar Ticket';

  @override
  String get pleaseFillFields =>
      'Por favor completa tanto el asunto como la descripción';

  @override
  String get ticketSubmittedSuccess => '¡Ticket enviado exitosamente!';

  @override
  String get lastRefillLabel => 'Última Recarga';

  @override
  String get noRefillYet => 'Sin recargas aún';

  @override
  String get nextAlertLabel => 'Próxima Alerta';

  @override
  String get protectionLabel => 'PROTECCIÓN';

  @override
  String get actionRequiredLabel => 'Acción Req.';

  @override
  String get protectionOffLabel => 'Protección Desactivada';

  @override
  String get notSet => 'No configurado';

  @override
  String get homeMode => 'Modo Hogar';

  @override
  String get keepProtectedAtHome => 'Mantener protegida en casa';

  @override
  String get protectionPausesAtHome => 'La protección se pausa en casa';

  @override
  String get incidentChannelsTitle => 'Canales de Incidentes';

  @override
  String get topUpSuccessTitle => 'Recarga Exitosa';

  @override
  String get topUpSuccessDesc =>
      'Notificarme cuando se complete exitosamente una extensión automática de validez de SIM.';

  @override
  String get topUpFailedTitle => 'Recarga Fallida (Crítica)';

  @override
  String get topUpFailedDesc =>
      'Alertas críticas cuando las recargas automáticas fallan por problemas de operadora o billetera.';

  @override
  String get walletLowTitle => 'Saldo de Billetera Bajo';

  @override
  String get walletLowDesc =>
      'Avisarme cuando el saldo principal caiga por debajo del umbral de seguridad.';

  @override
  String get walletDepletedTitle => 'Billetera Agotada';

  @override
  String get walletDepletedDesc =>
      'Alertas de suspensión cuando el saldo de la billetera está completamente agotado y las renovaciones se detienen.';

  @override
  String get lineCriticalTitle => 'Advertencia de Expiración de Validez';

  @override
  String get lineCriticalDesc =>
      'Avisarme cuando una ventana de validez de SIM esté terminando dentro de 48 horas.';

  @override
  String get lineEnteringGraceTitle => 'Entrando en Período de Gracia';

  @override
  String get lineEnteringGraceDesc =>
      'Notificarme cuando se detecten períodos de gracia de desactivación de la operadora.';

  @override
  String get geoFenceTriggeredTitle => 'Alertas de Ubicación / Roaming';

  @override
  String get geoFenceTriggeredDesc =>
      'Alertas cuando la operadora cambia clústeres de roaming o nodos de red.';

  @override
  String get welcomeHomeReadyTitle => 'Sincronización de Bienvenida en Casa';

  @override
  String get welcomeHomeReadyDesc =>
      'Alertas cuando el nodo de red del país de origen activa sincronizaciones automatizadas.';

  @override
  String get referralRewardTitle => 'Referidos y Recompensas';

  @override
  String get referralRewardDesc =>
      'Notificarme cuando los referidos de amigos depositen saldos promocionales en mi billetera.';

  @override
  String get systemUpdatesTitle => 'Actualizaciones Generales del Sistema';

  @override
  String get systemUpdatesDesc =>
      'Actualizaciones vitales del motor, mantenimiento y anuncios de la plataforma.';

  @override
  String get walletCreditTitle => 'Monedero acreditado';

  @override
  String get walletCreditDesc =>
      'Avísame cuando entre un depósito en mi monedero.';

  @override
  String get promoTitle => 'Ofertas y promociones';

  @override
  String get promoDesc =>
      'Novedades ocasionales sobre ofertas y nuevas funciones. Permanece desactivado hasta que lo actives.';

  @override
  String get deliverVia => 'Enviar por';

  @override
  String get channelPushShort => 'Push';

  @override
  String get channelEmailShort => 'Correo';

  @override
  String get channelOffGlobally => 'Desactivado en Canales de alerta arriba';

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
  String get rechargeNow => 'Recargar ahora';

  @override
  String get planFeePaidFromWallet =>
      'La tarifa del plan se pagó con el saldo de tu billetera.';

  @override
  String activityTopupRequested(String amount) {
    return 'Solicitud de recarga enviada por \$$amount';
  }

  @override
  String activityTopupSuccess(String amount, String provider) {
    return 'Recarga de \$$amount completada mediante $provider';
  }

  @override
  String activityTopupFailed(String amount, String reason) {
    return 'Error en recarga de \$$amount: $reason';
  }

  @override
  String activityTopupRefunded(String amount) {
    return 'Recarga de \$$amount reembolsada a la billetera';
  }

  @override
  String activityTopupCancelled(String amount) {
    return 'Solicitud de recarga de \$$amount cancelada';
  }

  @override
  String activityTopupRetryQueued(String amount) {
    return 'Reintento programado para recarga de \$$amount';
  }

  @override
  String get activityLineCreated => 'Línea SIM registrada en SIM Shield';

  @override
  String get activityHealthUpdate => 'Estado activo de la línea SIM verificado';

  @override
  String get activityReminderSent =>
      'Notificación de recordatorio de renovación enviada';

  @override
  String get supportTicketsTitle => 'Ayuda y soporte';

  @override
  String get supportTicketsSubtitle =>
      'Envía solicitudes de soporte, adjunta registros de actividad y chatea en vivo con nuestro equipo.';

  @override
  String get supportTicketsEmpty => 'No se encontraron tickets de soporte.';

  @override
  String get createSupportTicket => 'Crear ticket';

  @override
  String get ticketCategoryGeneral => 'Consulta general';

  @override
  String get ticketCategoryBilling => 'Facturación y billetera';

  @override
  String get ticketCategoryTechnical => 'Problema técnico';

  @override
  String get ticketCategoryRefillIssue => 'Problema de recarga';

  @override
  String get ticketCategoryAccount => 'Cuenta y seguridad';

  @override
  String get ticketStatusOpen => 'Abierto';

  @override
  String get ticketStatusPending => 'Respuesta pendiente';

  @override
  String get ticketStatusResolved => 'Resuelto';

  @override
  String get ticketStatusClosed => 'Cerrado';

  @override
  String get ticketSubjectLabel => 'Asunto';

  @override
  String get ticketSubjectHint => 'Breve descripción del problema';

  @override
  String get ticketCategoryLabel => 'Categoría';

  @override
  String get ticketMessageLabel => 'Mensaje';

  @override
  String get ticketMessageHint => 'Proporciona información detallada...';

  @override
  String get attachImage => 'Adjuntar imagen';

  @override
  String get attachActivityLogs => 'Adjuntar registros de línea';

  @override
  String get submitTicket => 'Enviar ticket';

  @override
  String get typeMessageHint => 'Escribe un mensaje...';

  @override
  String get closeTicketButton => 'Cerrar ticket';

  @override
  String get ticketClosedNotice => 'Este ticket de soporte ha sido cerrado.';

  @override
  String get attachedFiles => 'Archivos adjuntos';

  @override
  String get referralsTitle => 'Recomienda y Gana';

  @override
  String get referralsSubtitle =>
      '¡Invita amigos, gana puntos en sus suscripciones SIM y canjéalos por crédito de billetera!';

  @override
  String get referralCode => 'Tu Código de Referido';

  @override
  String get copyCode => 'Copiar Código';

  @override
  String get codeCopied => '¡Código de referido copiado al portapapeles!';

  @override
  String get shareCode => 'Compartir Código';

  @override
  String get pointsBalance => 'Balance de Puntos';

  @override
  String get pointsUnit => 'puntos';

  @override
  String progressToNextRedemption(Object pointsNeeded) {
    return '$pointsNeeded puntos más para la próxima recompensa de \$2.00';
  }

  @override
  String get redeemButton => 'Canjear 10 Puntos por \$2.00';

  @override
  String get redeemSuccess =>
      '¡Se canjearon con éxito 10 puntos por \$2.00 de crédito de billetera!';

  @override
  String get applyCodeTitle => '¿Tienes un Código de Referido?';

  @override
  String get applyCodeHint => 'Ingresa el código de referido';

  @override
  String get applyCodeButton => 'Aplicar Código';

  @override
  String get applyCodeSuccess => '¡Código de referido aplicado con éxito!';

  @override
  String get referredFriendsTitle => 'Amigos Referidos';

  @override
  String get noReferredFriends =>
      '¡Aún no hay amigos referidos. Comparte tu código para empezar!';

  @override
  String get redemptionHistoryTitle => 'Historial de Canjes';

  @override
  String get noRedemptions => 'Sin canjes aún.';

  @override
  String get pointHistoryTitle => 'Historial de Puntos';

  @override
  String get noPointsEarned => 'Sin puntos ganados aún.';

  @override
  String get howItWorksTitle => 'Cómo Funciona Recomienda y Gana';

  @override
  String get howItWorksStep1 =>
      '1. Comparte tu código de referido único con amigos.';

  @override
  String get howItWorksStep2 =>
      '2. Gana 1 punto cada vez que un amigo referido suscriba una línea SIM.';

  @override
  String get howItWorksStep3 =>
      '3. ¡Canjea 10 puntos por \$2.00 de crédito en la billetera en cualquier momento!';

  @override
  String get geoTitle => 'Viajes y Geolocalización';

  @override
  String get geoSubtitle =>
      'Detección automática de país y protección de líneas SIM internacionales';

  @override
  String get currentCountryLabel => 'Ubicación actual';

  @override
  String get travelModeToggle => 'Modo viaje';

  @override
  String get travelModeDescription =>
      'Verifica el país al abrir la aplicación para gestionar la protección de líneas internacionales';

  @override
  String get geoNotice =>
      'El país se verifica mediante búsqueda IP al abrir la aplicación. Sin permisos de ubicación.';

  @override
  String get freezeInternationalLines => 'Congelar líneas internacionales';

  @override
  String get resumeInternationalLines => 'Reanudar líneas internacionales';

  @override
  String get linesFrozenSuccess =>
      '¡Líneas SIM internacionales congeladas y recargas programadas pausadas!';

  @override
  String get linesResumedSuccess =>
      '¡Líneas SIM internacionales y recargas reactivadas!';

  @override
  String get alwaysProtectedBadge => 'Siempre protegida';

  @override
  String get detectedViaIp => 'Detectado por IP';

  @override
  String get esimManagerTitle => 'Gestor de eSIM';

  @override
  String get esimPlansTitle => 'Planes de eSIM';

  @override
  String get searchDestinationHint =>
      'Buscar destino (ej. Francia, Estados Unidos)';

  @override
  String get selectDestinationTitle => 'Seleccionar destino';

  @override
  String get localTab => 'Local';

  @override
  String get regionalTab => 'Regional';

  @override
  String get globalTab => 'Global';

  @override
  String get bestValueBadge => 'MEJOR VALOR';

  @override
  String get perGb => '/ GB';

  @override
  String validityDays(Object days) {
    return '$days Días';
  }

  @override
  String get buyPlanButton => 'Comprar Plan';

  @override
  String get deviceIncompatibleNotice =>
      'Tu dispositivo no es compatible con la tecnología eSIM.';

  @override
  String get activationPolicyTitle => 'Política de activación';

  @override
  String get activationPolicyNotice =>
      'La validez comienza cuando la eSIM se conecta a una red compatible en tu destino.';

  @override
  String get coveredCountriesTitle => 'Países cubiertos';

  @override
  String get sortPriceLowToHigh => 'Precio: menor a mayor';

  @override
  String get sortPricePerGb => 'Precio / GB: menor a mayor';

  @override
  String get sortDataHighToLow => 'Datos: mayor a menor';

  @override
  String get filterAll => 'Todos los planes';

  @override
  String get filterMin5Gb => '≥ 5 GB';

  @override
  String get filterMin15Days => '≥ 15 Días';

  @override
  String get filterUnlimited => 'Ilimitado';

  @override
  String get purchaseInNextRelease =>
      'La opción de compra estará disponible en la próxima versión (C9b).';

  @override
  String get confirmPurchaseTitle => 'Confirmar compra de eSIM';

  @override
  String get myEsimsTitle => 'Mis eSIMs';

  @override
  String get showQrCode => 'Mostrar código QR';

  @override
  String get buyAgain => 'Comprar de nuevo';

  @override
  String get dataRemaining => 'Datos restantes';

  @override
  String get archivedEsims => 'eSIMs archivadas';

  @override
  String rateLimitExceeded(String seconds) {
    return 'Demasiadas solicitudes. Por favor espere $seconds segundos antes de intentarlo de nuevo.';
  }

  @override
  String get confirmDeleteButton => 'Confirmar eliminación';

  @override
  String get cancelAccountDeletion => 'Cancelar eliminación de cuenta';

  @override
  String get accountScheduledForDeletion =>
      'Cuenta programada para eliminación';

  @override
  String deletionScheduledNotice(String date) {
    return 'Su cuenta está congelada y programada para su eliminación permanente el $date.';
  }

  @override
  String walletBalanceBlockedNotice(String balance) {
    return 'Tu saldo (\$$balance) supera el límite (\$1.00). Por favor gastalo o contacta soporte.';
  }

  @override
  String get payPalCheckoutTitle => 'Pago con PayPal';

  @override
  String get payPalWalletTopUp => 'Recarga de monedero KeepSIMs';

  @override
  String get payPalPaySecurely => 'Pagar de forma segura con PayPal';

  @override
  String get payPalRedirectInfo =>
      'Serás redirigido a PayPal para autorizar tu pago.';

  @override
  String get payPalCreatingOrder => 'Creando pedido seguro de PayPal...';

  @override
  String get payPalAwaitingConfirmation =>
      'Esperando confirmación de PayPal...';

  @override
  String get payPalCompleteInBrowser =>
      'Por favor completa el pago en la ventana del navegador.';

  @override
  String get payPalPaymentConfirmed => '¡Pago confirmado!';

  @override
  String get payPalPaymentFailed => 'El pago falló o fue cancelado.';

  @override
  String get payPalForceCaptureButton => 'He completado el pago en PayPal';
}
