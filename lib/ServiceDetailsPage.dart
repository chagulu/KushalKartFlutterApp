import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';

class ServiceDetailsPage extends StatefulWidget {
  final int serviceId;
  final int workerId;

  const ServiceDetailsPage({
    Key? key,
    required this.serviceId,
    required this.workerId,
  }) : super(key: key);

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  Map<String, dynamic>? serviceDetails;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isBooking = false;

  Future<void> fetchServiceDetails() async {
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
        Uri.parse('$baseUrl/api/services/by-pincode/enriched/${widget.serviceId}/worker/${widget.workerId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          serviceDetails = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load details: ${response.body}';
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

  Future<void> bookService() async {
    setState(() => _isBooking = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found. Please login again.')),
        );
        return;
      }

      final bookingPayload = {
        "workerId": widget.workerId,
        "scheduledTime": "2025-07-26T15:30:00", // You can make this dynamic later
        "serviceId": widget.serviceId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bookingPayload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Booking successful!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isBooking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchServiceDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.home_repair_service, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Service Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 20),
                            Text(
                              serviceDetails?['categoryName'] ?? 'Unnamed Category',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text('📝 Description: ${serviceDetails?['description'] ?? 'N/A'}'),
                            Text('💰 Rate: ₹${serviceDetails?['defaultRate'] ?? 'N/A'}'),
                            Text('⭐ Rating: ${serviceDetails?['averageRating'] ?? 'Not rated'}'),
                            Text('👥 Available Workers: ${serviceDetails?['availableWorkersCount'] ?? 0}'),
                            Text('📍 Pincode: ${serviceDetails?['userPincode'] ?? 'Unknown'}'),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isBooking ? null : bookService,
                                icon: const Icon(Icons.event_available),
                                label: _isBooking
                                    ? const Text('Booking...')
                                    : const Text('Book Now'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
