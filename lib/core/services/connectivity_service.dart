import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

enum NetworkStatus { online, offline }

@Riverpod(keepAlive: true)
class ConnectivityService extends _$ConnectivityService {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  NetworkStatus build() {
    _init();
    return NetworkStatus.online; // Default to online
  }

  void _init() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      state = _getStatusFromResults(results);
    });

    Connectivity().checkConnectivity().then((results) {
      state = _getStatusFromResults(results);
    });
  }

  NetworkStatus _getStatusFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  bool get isOnline => state == NetworkStatus.online;
  bool get isOffline => state == NetworkStatus.offline;

  void dispose() {
    _subscription.cancel();
  }
}
