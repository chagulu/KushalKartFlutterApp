import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A centralized HTTP request handler that supports GET, POST, PATCH, DELETE.
/// Automatically handles JWT token expiration and redirects to `/send-otp` if needed.
Future<http.Response> safeRequest({
  required BuildContext context,
  required Uri url,
  required String method,
  Map<String, String>? headers,
  Object? body,
}) async {
  http.Response response;

  try {
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(url, headers: headers, body: body);
        break;
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'PATCH':
        response = await http.patch(url, headers: headers, body: body);
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // Check for token expiration with exact match
    if (response.statusCode == 401 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);

      if (data['errorCode'] == 'TOKEN_EXPIRED' &&
          data['error'] == true &&
          data['message'] == 'JWT token has expired' &&
          data['status'] == 401) {
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('jwt_token');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please verify OTP again.')),
        );

        Navigator.pushNamedAndRemoveUntil(context, '/send-otp', (_) => false);
      }
    }

    return response;
  } catch (e) {
    // Optional: Handle network errors or unexpected exceptions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Network error: ${e.toString()}')),
    );
    rethrow;
  }
}
