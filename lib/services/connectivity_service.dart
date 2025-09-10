import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Controller for the connectivity status stream
  final _connectionStatusController = StreamController<ConnectivityResult>.broadcast();
  Stream<ConnectivityResult> get connectionStatus => _connectionStatusController.stream;
  
  // Current connectivity status
  ConnectivityResult _currentStatus = ConnectivityResult.none;
  ConnectivityResult get currentStatus => _currentStatus;
  bool get isConnected => _currentStatus != ConnectivityResult.none;

  // Subscription to connectivity changes
  StreamSubscription<ConnectivityResult>? _subscription;

  // Initialize the service
  Future<void> initialize() async {
    final Connectivity connectivity = Connectivity();
    
    // Get initial connection status
    _currentStatus = await connectivity.checkConnectivity();
    _connectionStatusController.add(_currentStatus);
    
    // Listen for connectivity changes
    _subscription = connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _currentStatus = result;
      _connectionStatusController.add(result);
    });
  }

  // Dispose the service
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}