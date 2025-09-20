import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/widgets/dialogs/address_update_dialog.dart';
import 'package:kushal_kart_flutter_app/service_listing_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String mobile;
  const VerifyOtpPage({Key? key, required this.mobile}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String _responseMessage = '';
  int _secondsLeft = 30;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Autofocus first field when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nodes.isNotEmpty) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String _otpValue() => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otpValue();
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
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
        body: jsonEncode({'mobile': widget.mobile, 'otp': otp}),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
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

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ServiceListingPage()),
          (route) => false,
        );
      } else {
        if (response.body.isNotEmpty) {
          try {
            final error = jsonDecode(response.body);
            setState(() => _responseMessage = 'Failed: ${error['message'] ?? error['error'] ?? 'Unknown error'}');
          } catch (_) {
            setState(() => _responseMessage = 'Failed: Malformed error response');
          }
        } else {
          setState(() => _responseMessage = 'Failed: ${response.statusCode == 403 ? "Unauthorized or invalid OTP" : "Unknown error"}');
        }
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _responseMessage = '';
    });
    try {
      final url = Uri.parse('$baseUrl/api/user/send-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': widget.mobile}),
      );

      if (response.statusCode == 200) {
        setState(() => _responseMessage = 'OTP resent successfully!');
        _startTimer();
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        setState(() => _responseMessage = 'Failed: ${error?['message'] ?? response.body}');
      }
    } catch (e) {
      setState(() => _responseMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int idx, String value) {
    // Keep only 1 digit
    if (value.length > 1) {
      _controllers[idx].text = value.substring(value.length - 1);
      _controllers[idx].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[idx].text.length),
      );
    }
    if (value.isNotEmpty && idx < _nodes.length - 1) {
      _nodes[idx + 1].requestFocus();
    }
    if (value.isEmpty && idx > 0) {
      // if backspace, go to previous
      _nodes[idx - 1].requestFocus();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    final six = RegExp(r'\d{6}').firstMatch(text)?.group(0);
    if (six != null) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = six[i];
      }
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB2EBF2), Color(0xFF80DEEA), Color(0xFF4DD0E1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(child: Image.asset('assets/logo.png', height: 100)),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Verify OTP',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter the 6-digit code sent to ${widget.mobile}',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // OTP fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          return SizedBox(
                            width: 44,
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _nodes[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '•',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                ),
                              ),
                              onChanged: (v) => _onDigitChanged(i, v),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Paste and Resend row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste),
                            label: const Text('Paste code'),
                          ),
                          TextButton(
                            onPressed: (_secondsLeft == 0 && !_isResending) ? _resendOtp : null,
                            child: _isResending
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_secondsLeft > 0 ? 'Resend in $_secondsLeft s' : 'Resend OTP'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Verify button
                      ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.blueAccent,
                        ),
                        icon: _isVerifying
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.verified),
                        label: Text(_isVerifying ? 'Verifying...' : 'Verify OTP'),
                      ),
                      const SizedBox(height: 16),

                      // Response message
                      Text(
                        _responseMessage,
                        style: TextStyle(
                          color: _responseMessage.toLowerCase().contains('success') ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
