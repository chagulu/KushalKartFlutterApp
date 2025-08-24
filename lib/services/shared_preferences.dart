// lib/services/shared_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> storeJwtToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', token);
}

Future<String?> getJwtToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt_token');
}

Future<void> clearJwtToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwt_token');
}
