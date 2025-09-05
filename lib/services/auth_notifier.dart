import 'package:flutter/foundation.dart';

class AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners(); // simples trigger
}

final authNotifier = AuthNotifier(); // usado no router
