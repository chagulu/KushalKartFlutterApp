import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kushal_kart_flutter_app/config.dart';
import '../services/shared_preferences.dart'; // ✅ Relative import
import 'service_listing_page.dart'; // ✅ Import destination screen

class VerifyOtpPage extends StatefulWidget {
  final String mobile;

  const VerifyOtpPage({Key? key, required this.mobile}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String _responseMessage = '';

  Future<void> verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      setState(() => _responseMessage = 'Enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mobile': widget.mobile,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final userId = data['user']['id'];

        await storeJwtToken(token); // ✅ Store token locally

        setState(() => _responseMessage = 'Login successful!');
        print('JWT Token: $token');
        print('User ID: $userId');

        // ✅ Navigate to Service Listing Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ServiceListingPage()),
        );
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
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mobile: ${widget.mobile}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : verifyOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Verify OTP'),
            ),
            const SizedBox(height: 20),
            Text(
              _responseMessage,
              style: TextStyle(
                color: _responseMessage.contains('successful') ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
