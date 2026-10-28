import 'package:intl/intl.dart';

/// Supported notification event types in KeepSIMs.
enum NotificationEventType {
  lineAdded('line_added'),
  autoRechargeScheduled('auto_recharge_scheduled'),
  lineSetupIncomplete('line_setup_incomplete'),
  rechargeDateMissing('recharge_date_missing'),
  rechargeSucceeded('recharge_succeeded'),
  rechargeReminder('recharge_reminder'),
  rechargeDueToday('recharge_due_today'),
  rechargeFailed('recharge_failed'),
  walletLow('wallet_low'),
  rechargeBlockedFunds('recharge_blocked_funds'),
  lineCritical('line_critical'),
  esimReady('esim_ready'),
  esimActivated('esim_activated'),
  esimLowData('esim_low_data'),
  esimNearExpiry('esim_near_expiry'),
  esimExpired('esim_expired'),
  esimOrderCompleted('esim_order_completed'),
  esimOrderSupportRequired('esim_order_support_required');

  final String wireName;
  const NotificationEventType(this.wireName);

  static NotificationEventType? fromWireName(String? name) {
    if (name == null) return null;
    for (final val in values) {
      if (val.wireName == name) return val;
    }
    return null;
  }
}

/// Android importance channels for KeepSIMs notifications.
abstract final class NotificationChannels {
  static const String confirmations = 'ks_confirmations_v1';
  static const String updates = 'ks_updates_v1';
  static const String urgent = 'ks_urgent_v1';
}

/// Notification transport priority.
enum NotificationPriority { quiet, normal, urgent }

/// Rendered notification title and body.
class RenderedNotification {
  final String title;
  final String body;
  final String channelId;
  final NotificationPriority priority;
  final String largeIcon;
  final String smallIcon;

  const RenderedNotification({
    required this.title,
    required this.body,
    required this.channelId,
    required this.priority,
    required this.largeIcon,
    this.smallIcon = 'ic_stat_keepsims',
  });
}

/// Formats and renders deterministic notifications according to product specification.
class NotificationEventCatalog {
  static const String smallIcon = 'ic_stat_keepsims';
  static const String iconSuccess = 'ic_notif_success';
  static const String iconReminder = 'ic_notif_reminder';
  static const String iconWarning = 'ic_notif_warning';
  static const String iconError = 'ic_notif_error';

  /// Formats line identity safely: `{nickname} · {last4}` or fallback `Line ending {last4}`.
  static String formatLineIdentity({
    String? nickname,
    required String rawPhoneNumber,
    String language = 'en',
  }) {
    final digits = rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : (digits.isNotEmpty ? digits : 'SIM');

    final cleanNickname = _sanitizeNickname(nickname);
    if (cleanNickname.isNotEmpty) {
      return '$cleanNickname · $last4';
    }

    if (language.startsWith('ar')) {
      return 'المنتهي بـ $last4';
    }
    return 'Line ending $last4';
  }

  static String _sanitizeNickname(String? raw) {
    if (raw == null) return '';
    final cleaned = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty) return '';
    // Limit to 24 characters safely without breaking runes
    final runes = cleaned.runes.toList();
    if (runes.length > 24) {
      return String.fromCharCodes(runes.take(24)).trim();
    }
    return cleaned;
  }

  /// Formats a DateTime for notification body copy in a locale-friendly way.
  static String formatDate(DateTime? date, {String language = 'en'}) {
    if (date == null) return '';
    try {
      final locale = language.startsWith('ar') ? 'ar' : 'en';
      return DateFormat('d MMM yyyy', locale).format(date.toLocal());
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(date.toLocal());
    }
  }

  /// Resolves the corresponding existing category for database compatibility.
  static String resolveCategory(NotificationEventType eventType) {
    switch (eventType) {
      case NotificationEventType.lineAdded:
      case NotificationEventType.autoRechargeScheduled:
      case NotificationEventType.lineSetupIncomplete:
      case NotificationEventType.rechargeDateMissing:
        return 'system';
      case NotificationEventType.rechargeSucceeded:
        return 'top_up_success';
      case NotificationEventType.rechargeReminder:
      case NotificationEventType.rechargeDueToday:
        return 'top_up_reminder';
      case NotificationEventType.rechargeFailed:
        return 'top_up_failed';
      case NotificationEventType.walletLow:
        return 'wallet_low';
      case NotificationEventType.rechargeBlockedFunds:
        return 'wallet_depleted';
      case NotificationEventType.lineCritical:
        return 'line_critical';
      case NotificationEventType.esimLowData:
        return 'esim_low_data';
      case NotificationEventType.esimReady:
      case NotificationEventType.esimActivated:
      case NotificationEventType.esimNearExpiry:
      case NotificationEventType.esimExpired:
      case NotificationEventType.esimOrderCompleted:
      case NotificationEventType.esimOrderSupportRequired:
        return 'esim_updates';
    }
  }

  /// Renders localized title, body, channel, and artwork for an event.
  static RenderedNotification render({
    required NotificationEventType eventType,
    required Map<String, dynamic> data,
    String language = 'en',
  }) {
    final isAr = language.startsWith('ar');

    final line =
        (data['line'] as String?) ??
        formatLineIdentity(
          nickname: data['nickname'] as String?,
          rawPhoneNumber: (data['phone_number'] as String?) ?? '',
          language: language,
        );

    final dateStr =
        (data['date_str'] as String?) ??
        (data['date'] is DateTime
            ? formatDate(data['date'] as DateTime, language: language)
            : (DateTime.tryParse(data['date']?.toString() ?? '') != null
                  ? formatDate(
                      DateTime.parse(data['date'].toString()),
                      language: language,
                    )
                  : (data['date']?.toString() ?? '')));

    final amount = data['amount']?.toString() ?? '';
    final currency = data['currency']?.toString() ?? '';
    final days = data['days'] is int
        ? data['days'] as int
        : int.tryParse(data['days']?.toString() ?? '') ?? 0;

    switch (eventType) {
      case NotificationEventType.esimReady:
      case NotificationEventType.esimActivated:
      case NotificationEventType.esimLowData:
      case NotificationEventType.esimNearExpiry:
      case NotificationEventType.esimExpired:
      case NotificationEventType.esimOrderCompleted:
      case NotificationEventType.esimOrderSupportRequired:
        final title = switch (eventType) {
          NotificationEventType.esimReady =>
            isAr ? 'شريحتك جاهزة للتثبيت' : 'Your eSIM is ready to install',
          NotificationEventType.esimActivated =>
            isAr ? 'شريحتك مفعّلة' : 'Your eSIM is active',
          NotificationEventType.esimLowData =>
            isAr ? 'بيانات شريحتك منخفضة' : 'Your eSIM data is running low',
          NotificationEventType.esimNearExpiry =>
            isAr
                ? 'صلاحية شريحتك تنتهي قريباً'
                : 'Your eSIM validity is ending soon',
          NotificationEventType.esimExpired =>
            isAr ? 'انتهت صلاحية شريحتك' : 'Your eSIM has expired',
          NotificationEventType.esimOrderCompleted =>
            isAr ? 'طلب شريحتك جاهز' : 'Your eSIM order is ready',
          _ =>
            isAr
                ? 'طلب شريحتك يحتاج إلى الدعم'
                : 'Your eSIM order needs support',
        };
        return RenderedNotification(
          title: title,
          body: isAr
              ? 'افتح شريحتك بأمان في KeepSIMs لمراجعة أحدث التفاصيل.'
              : 'Open your eSIM securely in KeepSIMs to review the latest details.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon:
              eventType == NotificationEventType.esimLowData ||
                  eventType == NotificationEventType.esimNearExpiry
              ? iconWarning
              : iconReminder,
        );
      case NotificationEventType.lineAdded:
        return RenderedNotification(
          title: isAr ? '✅ تمت إضافة الرقم' : '✅ Number added',
          body: isAr
              ? 'الرقم $line. تذكير الشحن القادم: $dateStr.'
              : '$line. Next recharge reminder: $dateStr.',
          channelId: NotificationChannels.confirmations,
          priority: NotificationPriority.quiet,
          largeIcon: iconSuccess,
        );

      case NotificationEventType.autoRechargeScheduled:
        return RenderedNotification(
          title: isAr
              ? '✅ تمت جدولة الشحن التلقائي'
              : '✅ Auto-recharge scheduled',
          body: isAr
              ? 'الرقم $line. موعد الشحن التلقائي القادم: $dateStr.'
              : '$line. Next automatic recharge: $dateStr.',
          channelId: NotificationChannels.confirmations,
          priority: NotificationPriority.quiet,
          largeIcon: iconSuccess,
        );

      case NotificationEventType.lineSetupIncomplete:
        return RenderedNotification(
          title: isAr
              ? '⚠️ أكمل إعداد رقمك'
              : '⚠️ Finish setting up your number',
          body: isAr
              ? 'تمت إضافة الرقم $line. افتح KeepSIMs لإكمال إعداد التذكيرات.'
              : '$line was added. Open KeepSIMs to finish setting up reminders.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon: iconWarning,
        );

      case NotificationEventType.rechargeDateMissing:
        return RenderedNotification(
          title: isAr
              ? '⚠️ أضف تاريخ آخر شحن'
              : '⚠️ Add your last recharge date',
          body: isAr
              ? 'أضف تاريخ آخر شحن للرقم $line ليتمكن KeepSIMs من حساب موعد التذكير التالي.'
              : 'Add the most recent recharge date for $line so KeepSIMs can calculate when to remind you next.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon: iconWarning,
        );

      case NotificationEventType.rechargeSucceeded:
        final amountText = currency.isNotEmpty ? '$amount $currency' : amount;
        return RenderedNotification(
          title: isAr ? '✅ تم الشحن بنجاح' : '✅ Recharge successful',
          body: isAr
              ? 'تم شحن الرقم $line بمبلغ $amountText.'
              : '$line was recharged with $amountText.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon: iconSuccess,
        );

      case NotificationEventType.rechargeReminder:
        final title = days > 0
            ? (isAr
                  ? '🔔 موعد الشحن بعد $days أيام'
                  : '🔔 Recharge due in $days days')
            : (isAr ? '🔔 تذكير بالشحن' : '🔔 Recharge reminder');
        return RenderedNotification(
          title: title,
          body: isAr
              ? 'الرقم $line. موعد الشحن: $dateStr.'
              : '$line. Recharge by $dateStr.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon: iconReminder,
        );

      case NotificationEventType.rechargeDueToday:
        return RenderedNotification(
          title: isAr ? '⚠️ موعد الشحن اليوم' : '⚠️ Recharge due today',
          body: isAr
              ? 'الرقم $line. افتح KeepSIMs لمراجعة الشحن.'
              : '$line. Open KeepSIMs to review your recharge.',
          channelId: NotificationChannels.urgent,
          priority: NotificationPriority.urgent,
          largeIcon: iconWarning,
        );

      case NotificationEventType.rechargeFailed:
        return RenderedNotification(
          title: isAr ? '❌ تعذّر الشحن' : '❌ Recharge failed',
          body: isAr
              ? 'الرقم $line. افتح KeepSIMs لمراجعة المشكلة.'
              : '$line. Open KeepSIMs to review the issue.',
          channelId: NotificationChannels.urgent,
          priority: NotificationPriority.urgent,
          largeIcon: iconError,
        );

      case NotificationEventType.walletLow:
        return RenderedNotification(
          title: isAr ? '⚠️ رصيد المحفظة منخفض' : '⚠️ Wallet balance is low',
          body: isAr
              ? 'أضف رصيداً قبل $dateStr للرقم $line.'
              : 'Add funds before $dateStr for $line.',
          channelId: NotificationChannels.updates,
          priority: NotificationPriority.normal,
          largeIcon: iconWarning,
        );

      case NotificationEventType.rechargeBlockedFunds:
        return RenderedNotification(
          title: isAr ? '⚠️ الشحن يتطلب رصيداً' : '⚠️ Recharge needs funds',
          body: isAr
              ? 'الرقم $line. أضف رصيداً لمتابعة الشحن.'
              : '$line. Add funds to continue your recharge.',
          channelId: NotificationChannels.urgent,
          priority: NotificationPriority.urgent,
          largeIcon: iconWarning,
        );

      case NotificationEventType.lineCritical:
        return RenderedNotification(
          title: isAr
              ? '⚠️ رقمك بحاجة إلى إجراء'
              : '⚠️ Your number needs attention',
          body: isAr
              ? 'الرقم $line. افتح KeepSIMs لمراجعة رقمك.'
              : '$line. Open KeepSIMs to review your line.',
          channelId: NotificationChannels.urgent,
          priority: NotificationPriority.urgent,
          largeIcon: iconWarning,
        );
    }
  }
}
