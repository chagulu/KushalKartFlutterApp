import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isLoading = false;
  String _responseMessage = '';

  Future<void> sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty || mobile.length != 10) {
      setState(() => _responseMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://41d7a7933870.ngrok-free.app/api/user/send-otp'), // ✅ Updated URL
        headers: {
          'Content-Type': 'application/json',
          'Content-Transfer-Encoding': 'application/json',
        },
        body: jsonEncode({'mobile': mobile}),
      );

      if (response.statusCode == 200) {
        setState(() => _responseMessage = 'OTP sent successfully!');
      } else {
        setState(() => _responseMessage = 'Failed: ${response.body}');
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : sendOtp,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send OTP'),
            ),
            const SizedBox(height: 16),
            Text(_responseMessage, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
