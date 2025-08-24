import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';

class MyBookingPage extends StatefulWidget {
  const MyBookingPage({Key? key}) : super(key: key);

  @override
  State<MyBookingPage> createState() => _MyBookingPageState();
}

class _MyBookingPageState extends State<MyBookingPage> {
  List<dynamic> bookings = [];
  bool _isLoading = true;
  String _errorMessage = '';

  Future<void> fetchBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'No token found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/mine?status=PENDING&page=0&size=1000'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('🔐 Token: $token');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          bookings = data['content'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String formatDate(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking['address'] ?? 'No address provided',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text('Status: ${booking['status']}'),
                              Text('Payment: ${booking['paymentStatus']}'),
                              Text('Scheduled: ${formatDate(booking['scheduledTime'])}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
