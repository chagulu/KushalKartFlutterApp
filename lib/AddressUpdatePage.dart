import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';

class AddressUpdatePage extends StatefulWidget {
  const AddressUpdatePage({Key? key}) : super(key: key);

  @override
  State<AddressUpdatePage> createState() => _AddressUpdatePageState();
}

class _AddressUpdatePageState extends State<AddressUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController line1Controller = TextEditingController();
  final TextEditingController line2Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  bool _isSubmitting = false;
  String _responseMessage = '';

  Future<void> updateAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _responseMessage = 'No token found. Please login again.';
          _isSubmitting = false;
        });
        return;
      }

      final payload = {
        "addressLine1": line1Controller.text,
        "addressLine2": line2Controller.text,
        "city": cityController.text,
        "state": stateController.text,
        "pincode": pincodeController.text,
        "locationLat": double.tryParse(latController.text) ?? 0.0,
        "locationLng": double.tryParse(lngController.text) ?? 0.0,
      };

      final response = await http.patch(
        Uri.parse('$baseUrl/api/user/3/address'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _responseMessage = data['message'] ?? 'Unknown response';
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_responseMessage)),
      );
    } catch (e) {
      setState(() {
        _responseMessage = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Address')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Enter your address details:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              TextFormField(
                controller: line1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: line2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2'),
              ),
              TextFormField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: stateController,
                decoration: const InputDecoration(labelText: 'State'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: pincodeController,
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : updateAddress,
                icon: const Icon(Icons.save),
                label: Text(_isSubmitting ? 'Updating...' : 'Update Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_responseMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_responseMessage, style: const TextStyle(color: Colors.green)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
