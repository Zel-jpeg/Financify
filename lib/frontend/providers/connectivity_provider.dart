import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<ConnectivityResult> _subscription;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _subscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    _init();
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    _updateStatus(result);
  }

  void _updateStatus(ConnectivityResult result) {
    final offline = result == ConnectivityResult.none;
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

