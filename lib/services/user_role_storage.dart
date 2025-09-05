import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveUserRole(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_role', role);
}

Future<String?> getUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_role');
}

Future<void> clearUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user_role');
}
