import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class NetworkAlertWidget extends StatefulWidget {
  final Widget child;

  const NetworkAlertWidget({super.key, required this.child});

  @override
  _NetworkAlertWidgetState createState() => _NetworkAlertWidgetState();
}

class _NetworkAlertWidgetState extends State<NetworkAlertWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenForConnectivityChanges();
  }

  Future<void> _checkInitialConnectivity() async {
    _isConnected = _connectivityService.isConnected;
    _showBanner = !_isConnected;
    setState(() {});
  }

  void _listenForConnectivityChanges() {
    _connectivityService.connectionStatus.listen((ConnectivityResult result) {
      final bool wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      
      if (wasConnected && !_isConnected) {
        // User just went offline
        setState(() {
          _showBanner = true;
        });
      } else if (!wasConnected && _isConnected) {
        // User just came back online
        setState(() {
          _showBanner = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Symbols.wifi_off, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Você está offline. Conecte-se à internet para usar o aplicativo.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await _connectivityService.initialize();
                          if (_connectivityService.isConnected) {
                            setState(() {
                              _showBanner = false;
                            });
                          }
                        },
                        child: const Text(
                          'TENTAR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}