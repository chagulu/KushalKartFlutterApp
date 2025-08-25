import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/widgets/dialogs/address_update_dialog.dart';
import 'package:kushal_kart_flutter_app/service_listing_page.dart'; // ✅ Import your listing page

class VerifyOtpPage extends StatefulWidget {
  final String mobile;

  const VerifyOtpPage({Key? key, required this.mobile}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final TextEditingController otpController = TextEditingController();
  bool _isVerifying = false;
  String _responseMessage = '';

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _responseMessage = 'Enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _responseMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile': widget.mobile,
          'otp': otp,
        }),
      );

      print('📨 Request Body: ${jsonEncode({'mobile': widget.mobile, 'otp': otp})}');
      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          final token = data['token'];
          final userId = data['user']['id'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);

          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => AddressUpdateDialog(userId: userId),
          );

          // ✅ Redirect after dialog closes
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ServiceListingPage()),
          );
        } catch (e) {
          setState(() => _responseMessage = 'Invalid response format: ${e.toString()}');
        }
      } else {
        if (response.body.isNotEmpty) {
          try {
            final error = jsonDecode(response.body);
            setState(() => _responseMessage = 'Failed: ${error['message'] ?? error['error'] ?? 'Unknown error'}');
          } catch (e) {
            setState(() => _responseMessage = 'Failed: Malformed error response');
          }
        } else {
          setState(() => _responseMessage = 'Failed: ${response.statusCode == 403 ? "Unauthorized or invalid OTP" : "Unknown error"}');
        }
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Enter OTP sent to ${widget.mobile}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isVerifying ? null : verifyOtp,
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: 20),
            Text(
              _responseMessage,
              style: TextStyle(
                color: _responseMessage.contains('success')
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
