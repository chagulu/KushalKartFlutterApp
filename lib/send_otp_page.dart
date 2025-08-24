import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kushal_kart_flutter_app/config.dart';
import 'verify_otp_page.dart';

class SendOtpPage extends StatefulWidget {
  const SendOtpPage({Key? key}) : super(key: key);

  @override
  State<SendOtpPage> createState() => _SendOtpPageState();
}

class _SendOtpPageState extends State<SendOtpPage> {
  final TextEditingController _mobileController = TextEditingController();
  bool _isLoading = false;
  String _responseMessage = '';

  Future<void> sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      setState(() => _responseMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _responseMessage = '';
    });

    try {
      final url = Uri.parse('$baseUrl/api/user/send-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobile}),
      );

      print('📨 Request Body: ${jsonEncode({'mobile': mobile})}');
      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() => _responseMessage = 'OTP sent successfully!');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpPage(mobile: mobile),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        setState(() => _responseMessage = 'Failed: ${error['message'] ?? response.body}');
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Enter your mobile number to receive OTP',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : sendOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send OTP'),
              ),
              const SizedBox(height: 20),
              Text(
                _responseMessage,
                style: TextStyle(
                  color: _responseMessage.contains('success') ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
