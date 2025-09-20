import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/MybookingPage.dart';
import 'package:kushal_kart_flutter_app/ServiceDetailsPage.dart';
import 'package:kushal_kart_flutter_app/MyTransactionPage.dart';
import 'package:kushal_kart_flutter_app/AddressUpdatePage.dart';
import 'package:kushal_kart_flutter_app/safe_request.dart';
import 'package:kushal_kart_flutter_app/widgets/kushal_bottom_nav.dart';

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
        Uri.parse('$baseUrl/api/services/by-location/enriched'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

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

  void handleMenuSelection(String value) async {
    switch (value) {
      case 'booking':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingPage()));
        break;
      case 'transaction':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTransactionPage()));
        break;
      case 'profile':
        // TODO: Navigate to profile
        break;
      case 'address':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressUpdatePage()));
        break;
      case 'logout':
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token == null || token.isEmpty) return;

        final response = await safeRequest(
          context: context,
          url: Uri.parse('$baseUrl/auth/logout'),
          method: 'POST',
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          await prefs.remove('jwt_token');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logout successful')),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logout failed: ${response.body}')),
            );
          }
        }
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
    final theme = Theme.of(context); // Material 3 theming
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Services'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'booking',
                child: Row(
                  children: const [
                    Icon(Icons.event_available),
                    SizedBox(width: 8),
                    Text('My Booking'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'transaction',
                child: Row(
                  children: const [
                    Icon(Icons.receipt_long),
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
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'address',
                child: Row(
                  children: const [
                    Icon(Icons.location_on),
                    SizedBox(width: 8),
                    Text('Update Address'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchServices,
        child: Container(
          color: theme.colorScheme.surfaceContainerLowest, // M3 surface
          child: _buildBody(theme),
        ),
      ),
      bottomNavigationBar: KushalBottomNav(currentIndex: 2, context: context),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => _ServiceCardSkeleton(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: fetchServices,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('No services nearby', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your location or check again later.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = services[index];
        final category = s['categoryName'] ?? 'Service';
        final price = s['defaultRate'] != null ? '₹${s['defaultRate']}' : 'Ask price';
        final rating = (s['averageRating'] ?? '—').toString();

        return Card.filled(
          elevation: 0,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              final serviceId = s['id'];
              const workerId = 1; // TODO: make dynamic
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceDetailsPage(serviceId: serviceId, workerId: workerId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.home_repair_service, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                title: Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(price, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ServiceCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Lightweight skeleton without external package; replace with ShaderMask shimmer for richer effect.
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(24))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.black12),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 120, color: Colors.black12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
