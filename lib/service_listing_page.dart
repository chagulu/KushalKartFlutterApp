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

  @override
  void initState() {
    super.initState();
    fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Services')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return ListTile(
                      title: Text(service['categoryName']),
                      subtitle: Text('Pincode: ${service['userPincode']}'),
                      trailing: Text('Workers: ${service['availableWorkersCount']}'),
                    );
                  },
                ),
    );
  }
}
