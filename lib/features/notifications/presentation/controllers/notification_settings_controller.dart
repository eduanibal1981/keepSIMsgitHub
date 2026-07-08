import 'dart:async';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';

part 'notification_settings_controller.g.dart';

@riverpod
class AlertSettingsController extends _$AlertSettingsController {
  @override
  FutureOr<List<AlertSetting>> build() async {
    final authState = ref.watch(authControllerProvider);
    if (authState.value == null) {
      return const [];
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getAlertSettings();
  }

  /// Toggles whether a specific alert category is enabled.
  Future<void> toggleCategory(String category, bool isEnabled) async {
    final repo = ref.read(notificationsRepositoryProvider);

    // Optimistic UI update
    state = state.whenData((list) {
      return list.map((item) {
        if (item.category == category) {
          return item.copyWith(isEnabled: isEnabled);
        }
        return item;
      }).toList();
    });

    try {
      final list = state.value ?? [];
      final match = list.firstWhere((item) => item.category == category);
      await repo.updateAlertSetting(match);
    } catch (_) {
      // Reload on failure
      ref.invalidateSelf();
    }
  }
}

@riverpod
class UserPreferencesController extends _$UserPreferencesController {
  @override
  FutureOr<UserPreferences> build() async {
    final authState = ref.watch(authControllerProvider);
    final profile = authState.value;
    if (profile == null) {
      return const UserPreferences(
        id: '',
        userId: '',
        theme: 'system',
        language: 'en',
        weeklyDigestEnabled: true,
        travelModeEnabled: false,
        biometricEnabled: false,
      );
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getUserPreferences();
  }

  /// Updates the user preferences (e.g. quiet hours, weekly digest).
  Future<void> updatePreferences(UserPreferences preferences) async {
    final repo = ref.read(notificationsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.updateUserPreferences(preferences);
      return preferences;
    });
  }

  /// Toggles the weekly digest preference.
  Future<void> toggleWeeklyDigest(bool isEnabled) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(current.copyWith(weeklyDigestEnabled: isEnabled));
  }

  /// Updates quiet hours range.
  Future<void> updateQuietHours(String? start, String? end) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(
      current.copyWith(quietHoursStart: start, quietHoursEnd: end),
    );
  }

  /// Toggles the travel mode preference.
  Future<void> toggleTravelMode(bool isEnabled) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(current.copyWith(travelModeEnabled: isEnabled));
  }

  /// Toggles the biometric authentication preference.
  Future<void> toggleBiometricAuth(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(current.copyWith(biometricEnabled: enabled));
  }

  /// Updates and hashes the transaction PIN.
  Future<void> updateTransactionPin(String pin) async {
    final current = state.value;
    if (current == null) return;
    final hashed = _hashPin(pin);
    await updatePreferences(current.copyWith(transactionPinHash: hashed));
  }

  /// Updates the application theme.
  Future<void> updateTheme(String theme) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(current.copyWith(theme: theme));
  }

  /// Updates the application language.
  Future<void> updateLanguage(String language) async {
    final current = state.value;
    if (current == null) return;
    await updatePreferences(current.copyWith(language: language));
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode("${pin}SIM_SHIELD_SALT_2026");
    var hash = 0;
    for (var byte in bytes) {
      hash = (hash * 31 + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

@riverpod
class NotificationChannelsController extends _$NotificationChannelsController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    final authState = ref.watch(authControllerProvider);
    if (authState.value == null) {
      return const [];
    }
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getNotificationChannels();
  }

  Future<void> toggleChannel(String channelType, bool isEnabled) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final currentList = state.value ?? [];

    final matchIndex = currentList.indexWhere(
      (c) => c['channel_type'] == channelType,
    );
    if (matchIndex == -1) return;

    final updatedChannel = Map<String, dynamic>.from(currentList[matchIndex]);
    updatedChannel['is_enabled'] = isEnabled;

    final newList = List<Map<String, dynamic>>.from(currentList);
    newList[matchIndex] = updatedChannel;
    state = AsyncData(newList);

    try {
      await repo.updateNotificationChannel(
        channelType: channelType,
        isEnabled: isEnabled,
        config: Map<String, dynamic>.from(updatedChannel['config'] ?? {}),
      );
    } catch (_) {
      ref.invalidateSelf();
    }
  }

  Future<void> updateChannelConfig(
    String channelType,
    Map<String, dynamic> config,
  ) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final currentList = state.value ?? [];

    final matchIndex = currentList.indexWhere(
      (c) => c['channel_type'] == channelType,
    );
    if (matchIndex == -1) return;

    final updatedChannel = Map<String, dynamic>.from(currentList[matchIndex]);
    updatedChannel['config'] = config;

    final newList = List<Map<String, dynamic>>.from(currentList);
    newList[matchIndex] = updatedChannel;
    state = AsyncData(newList);

    try {
      await repo.updateNotificationChannel(
        channelType: channelType,
        isEnabled: updatedChannel['is_enabled'] ?? false,
        config: config,
      );
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}
