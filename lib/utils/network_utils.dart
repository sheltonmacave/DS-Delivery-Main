import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NetworkUtils {
  static Future<bool> checkConnectivity(BuildContext context) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isConnected = connectivityResult != ConnectivityResult.none;
    
    if (!isConnected) {
      Fluttertoast.showToast(
        msg: "Sem conexão com a internet. Conecte-se e tente novamente.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    
    return isConnected;
  }
}