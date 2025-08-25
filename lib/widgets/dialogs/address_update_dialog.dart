import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';

class AddressUpdateDialog extends StatefulWidget {
  final int userId;

  const AddressUpdateDialog({Key? key, required this.userId}) : super(key: key);

  @override
  State<AddressUpdateDialog> createState() => _AddressUpdateDialogState();
}

class _AddressUpdateDialogState extends State<AddressUpdateDialog> {
  final TextEditingController line1Controller = TextEditingController();
  final TextEditingController line2Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    fetchGoogleLocation();
  }

  Future<void> fetchGoogleLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    print('📍 Permission status: $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      print('📍 Permission after request: $permission');

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        print('❌ Location permission not granted');
        setState(() => _isLoadingLocation = false);
        _showPermissionDeniedDialog();
        return;
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;

      final apiKey = 'AIzaSyBEC5zhJxznUsig1Xf2hSyiltoQ2Ja8SbM';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        final result = data['results'][0];
        final components = result['address_components'];

        final streetNumber = _extractComponent(components, 'street_number');
        final route = _extractComponent(components, 'route');
        final locality = _extractComponent(components, 'locality');
        final state = _extractComponent(components, 'administrative_area_level_1');
        final postalCode = _extractComponent(components, 'postal_code');

        setState(() {
          latController.text = lat.toString();
          lngController.text = lng.toString();
          line1Controller.text = '$streetNumber $route'.trim();
          cityController.text = locality;
          stateController.text = state;
          pincodeController.text = postalCode;
          _isLoadingLocation = false;
        });

        print('📍 Prefilled Address: $streetNumber $route, $locality, $state, $postalCode');
      } else {
        setState(() => _isLoadingLocation = false);
        print('❌ Google Geocoding failed: ${data['status']}');
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      print('❌ Location error: $e');
    }
  }

  String _extractComponent(List components, String type) {
    for (var c in components) {
      if (c['types'] != null && c['types'].contains(type)) {
        return c['long_name'] ?? '';
      }
    }
    return '';
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'To autofill your address, please allow location access in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> submitAddress() async {
    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

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
      Uri.parse('$baseUrl/api/user/${widget.userId}/address'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    Navigator.pop(context); // Close dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.statusCode == 200
            ? '✅ Address updated'
            : '❌ Failed to update address'),
      ),
    );

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Your Address'),
      content: _isLoadingLocation
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: line1Controller, decoration: const InputDecoration(labelText: 'Address Line 1')),
                  TextField(controller: line2Controller, decoration: const InputDecoration(labelText: 'Address Line 2')),
                  TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City')),
                  TextField(controller: stateController, decoration: const InputDecoration(labelText: 'State')),
                  TextField(controller: pincodeController, decoration: const InputDecoration(labelText: 'Pincode')),
                  TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude')),
                  TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitude')),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : submitAddress,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
