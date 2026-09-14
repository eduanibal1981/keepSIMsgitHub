import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/offline_recharge/model/recovery_state_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kDefaultProbeTimeout = Duration(seconds: 4);
const _kProbeCacheKeyPrefix = 'keepsims_recovery_state_';

final recoveryReachabilityServiceProvider =
    NotifierProvider<RecoveryReachabilityNotifier, RecoveryStateModel>(
  RecoveryReachabilityNotifier.new,
);

class RecoveryReachabilityNotifier extends Notifier<RecoveryStateModel> {
  final LocalCacheService? _customLocalCache;
  final http.Client? _customClient;
  final Connectivity? _customConnectivity;
  final bool _autoListenConnectivity;

  late final http.Client _client;
  LocalCacheService? _localCache;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  RecoveryReachabilityNotifier({
    LocalCacheService? localCache,
    http.Client? client,
    Connectivity? connectivity,
    bool autoListenConnectivity = true,
  })  : _customLocalCache = localCache,
        _customClient = client,
        _customConnectivity = connectivity,
        _autoListenConnectivity = autoListenConnectivity;

  @override
  RecoveryStateModel build() {
    _localCache = _customLocalCache ?? ref.watch(localCacheServiceProvider);
    _client = _customClient ?? http.Client();

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
      _client.close();
    });

    _init();
    return _loadInitialCache();
  }

  void _init() {
    if (_autoListenConnectivity) {
      try {
        final connectivity = _customConnectivity ?? Connectivity();
        _connectivitySubscription =
            connectivity.onConnectivityChanged.listen((results) {
          _handleConnectivityChange(results);
        });
      } catch (e) {
        debugPrint('Connectivity listener registration failed: $e');
      }
    }
  }

  String _getCacheKey() {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
      return '$_kProbeCacheKeyPrefix$userId';
    } catch (_) {
      return '${_kProbeCacheKeyPrefix}guest';
    }
  }

  RecoveryStateModel _loadInitialCache() {
    try {
      final cachedJson = _localCache?.readString(_getCacheKey());
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = RecoveryStateModel.decode(cachedJson);
        if (decoded != null) {
          return decoded.copyWith(
            reachability: KeepSimsReachability.unknown,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to read recovery cache: $e');
    }
    return const RecoveryStateModel();
  }

  Future<void> _persistState(RecoveryStateModel model) async {
    try {
      await _localCache?.writeString(_getCacheKey(), model.encode());
    } catch (e) {
      debugPrint('Failed to persist recovery cache: $e');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final interfaceType = _mapInterfaceType(results);
    state = state.copyWith(interfaceType: interfaceType);

    if (interfaceType == NetworkInterfaceType.none) {
      state = state.copyWith(reachability: KeepSimsReachability.unreachable);
    } else {
      probeReachability();
    }
  }

  NetworkInterfaceType _mapInterfaceType(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkInterfaceType.none;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkInterfaceType.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkInterfaceType.cellular;
    }
    return NetworkInterfaceType.other;
  }

  /// Probes the approved KeepSIMs recovery endpoint to verify reachability.
  /// Distinguishes HTTP application errors from socket/transport/DNS failures.
  Future<KeepSimsReachability> probeReachability({Uri? customUri}) async {
    state = state.copyWith(reachability: KeepSimsReachability.checking);

    final targetUri = customUri ?? _resolveDefaultProbeUri();
    final headers = {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };

    final supabaseKey = _getSupabaseAnonKey();
    if (supabaseKey != null && supabaseKey.isNotEmpty) {
      headers['apikey'] = supabaseKey;
    }

    try {
      final response = await _client
          .get(targetUri, headers: headers)
          .timeout(_kDefaultProbeTimeout);

      final now = DateTime.now();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _consecutiveFailures = 0;
        state = state.copyWith(
          reachability: KeepSimsReachability.reachable,
          lastCheckedAt: now,
          errorMessage: null,
        );
        _persistState(state);
        return KeepSimsReachability.reachable;
      } else {
        // Transport succeeded, but HTTP returned 4xx or 5xx
        state = state.copyWith(
          reachability: KeepSimsReachability.serviceError,
          lastCheckedAt: now,
          errorMessage: 'Service returned HTTP ${response.statusCode}',
        );
        _persistState(state);
        return KeepSimsReachability.serviceError;
      }
    } on SocketException catch (e) {
      return _handleTransportFailure('Network unreachable: ${e.message}');
    } on TimeoutException {
      return _handleTransportFailure('Connection probe timed out (4s)');
    } on http.ClientException catch (e) {
      return _handleTransportFailure('Client network error: ${e.message}');
    } catch (e) {
      return _handleTransportFailure('Transport failure: $e');
    }
  }

  KeepSimsReachability _handleTransportFailure(String reason) {
    _consecutiveFailures++;
    final now = DateTime.now();
    state = state.copyWith(
      reachability: KeepSimsReachability.unreachable,
      lastCheckedAt: now,
      errorMessage: reason,
    );
    _persistState(state);
    return KeepSimsReachability.unreachable;
  }

  Uri _resolveDefaultProbeUri() {
    const baseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://zwxswagokhgbuzrrbnhr.supabase.co',
    );
    return Uri.parse('$baseUrl/functions/v1/recovery-service/probe');
  }

  String? _getSupabaseAnonKey() {
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0',
    );
  }

  /// Updates state with remotely synced recovery metadata.
  void updateFromRemote({
    String? profileReference,
    String? esimReference,
    String? iccid,
    String? activationCode,
    String? smdpAddress,
    String? matchingId,
    RecoveryProvisioningState? provisioningState,
    RecoveryEntitlement? entitlement,
    int? remainingMb,
    int? totalMb,
    DateTime? expiresAt,
    bool isMock = true,
  }) {
    state = state.copyWith(
      profileReference: profileReference ?? state.profileReference,
      esimReference: esimReference ?? state.esimReference,
      iccid: iccid ?? state.iccid,
      activationCode: activationCode ?? state.activationCode,
      smdpAddress: smdpAddress ?? state.smdpAddress,
      matchingId: matchingId ?? state.matchingId,
      provisioningState: provisioningState ?? state.provisioningState,
      entitlement: entitlement ?? state.entitlement,
      remainingMb: remainingMb ?? state.remainingMb,
      totalMb: totalMb ?? state.totalMb,
      expiresAt: expiresAt ?? state.expiresAt,
      isMock: isMock,
    );
    _persistState(state);
  }

  /// Marks local installation reported by user after viewing QR / adding profile.
  void reportInstallationCompleted() {
    state = state.copyWith(
      provisioningState: RecoveryProvisioningState.installationReported,
    );
    _persistState(state);
  }

  /// Clears user-specific cached snapshot on logout.
  Future<void> clearUserCache() async {
    try {
      await _localCache?.remove(_getCacheKey());
      state = const RecoveryStateModel();
    } catch (_) {}
  }
}
