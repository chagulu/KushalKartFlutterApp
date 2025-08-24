import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';

class ServiceListingPage extends StatefulWidget {
  const ServiceListingPage({Key? key}) : super(key: key);

  @override
  State<ServiceListingPage> createState() => _ServiceListingPageState();
}

class _ServiceListingPageState extends State<ServiceListingPage> {
  List<dynamic> services = [];
  bool _isLoading = true;
  String _errorMessage = '';

  Future<void> fetchServices() async {
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
        Uri.parse('$baseUrl/api/services/by-location'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('🔐 Token: $token');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          services = jsonDecode(response.body);
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

  void handleMenuSelection(String value) {
    switch (value) {
      case 'booking':
        print('🧾 My Booking tapped');
        break;
      case 'transaction':
        print('💳 My Transaction tapped');
        break;
      case 'profile':
        print('👤 Profile tapped');
        break;
      case 'logout':
        print('🚪 Logout tapped');
        // Optionally clear token and navigate to login
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Services'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'booking',
                child: Row(
                  children: const [
                    Icon(Icons.event_available, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('My Booking'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'transaction',
                child: Row(
                  children: const [
                    Icon(Icons.receipt_long, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('My Transaction'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: const [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            service['categoryName'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Pincode: ${service['userPincode']}'),
                          trailing: Text(
                            'Workers: ${service['availableWorkersCount']}',
                            style: const TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
