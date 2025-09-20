import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/widgets/kushal_bottom_nav.dart';
// If adding a package, consider `skeletonizer` or implement a simple placeholder.

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
  DateTime? _scheduledDateTime;

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
        headers: {'Authorization': 'Bearer $token'},
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

  Future<void> _pickDateTime() async {
    // Bottom sheet date + time sequence. You can swap for a package-based bottom picker.
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
      helpText: 'Select service date',
    );
    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select service time',
    );
    if (selectedTime == null) return;

    final dt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() => _scheduledDateTime = dt);
  }

  Future<void> bookService() async {
    if (_scheduledDateTime == null) {
      await _pickDateTime();
      if (_scheduledDateTime == null) return;
    }

    setState(() => _isBooking = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No token found. Please login again.')),
          );
        }
        return;
      }

      final bookingPayload = {
        "workerId": widget.workerId,
        "scheduledTime": _scheduledDateTime!.toIso8601String(),
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

      if (!mounted) return;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchServiceDetails();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service details'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: fetchServiceDetails,
        child: _buildBody(theme),
      ),
      bottomNavigationBar: KushalBottomNav(currentIndex: 2, context: context),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _DetailsSkeleton(),
          SizedBox(height: 12),
          _DetailsSkeletonLine(),
          SizedBox(height: 8),
          _DetailsSkeletonLine(widthFactor: 0.7),
        ],
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Could not load details', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_errorMessage, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: fetchServiceDetails, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final s = serviceDetails ?? {};
    final name = s['categoryName'] ?? 'Service';
    final desc = s['description'] ?? 'N/A';
    final price = s['defaultRate'] != null ? '₹${s['defaultRate']}' : 'Ask price';
    final rating = (s['averageRating'] ?? '—').toString();
    final workers = (s['availableWorkersCount'] ?? 0).toString();
    final pincode = s['userPincode']?.toString() ?? 'Unknown';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Card.filled(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(Icons.home_repair_service, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(icon: Icons.currency_rupee, label: price),
                                    _MetaChip(icon: Icons.star_rounded, label: rating),
                                    _MetaChip(icon: Icons.groups_2, label: '$workers workers'),
                                    _MetaChip(icon: Icons.place, label: pincode),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card.outlined(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('About this service', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 12),
                          Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_scheduledDateTime != null)
                    Card.outlined(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const Icon(Icons.event_available),
                        title: Text('Scheduled time', style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(_scheduledDateTime.toString()),
                        trailing: TextButton(onPressed: _pickDateTime, child: const Text('Change')),
                      ),
                    ),
                  const SizedBox(height: 100), // space for sticky CTA
                ]),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBooking ? null : bookService,
                    icon: _isBooking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_available),
                    label: Text(_isBooking ? 'Booking...' : 'Book now'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_scheduledDateTime == null ? 'Pick time' : 'Reschedule'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(28))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, color: Colors.black12),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Container(height: 14, color: Colors.black12)),
                      const SizedBox(width: 8),
                      Container(width: 60, height: 14, color: Colors.black12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _DetailsSkeletonLine({this.widthFactor = 1});
  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Card.outlined(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(height: 56, color: Colors.transparent),
      ),
    );
  }
}
