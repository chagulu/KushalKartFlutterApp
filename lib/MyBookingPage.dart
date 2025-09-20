import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/widgets/kushal_bottom_nav.dart';

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
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          bookings = (data['content'] as List?) ?? [];
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
    return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: fetchBookings,
        child: _buildBody(theme),
      ),
      bottomNavigationBar: KushalBottomNav(currentIndex: 0, context: context),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, __) => const _BookingSkeleton(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Could not load bookings', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_errorMessage, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: fetchBookings, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    if (bookings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('No bookings yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('New bookings will appear here.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = bookings[index];
        final address = b['address'] ?? 'No address provided';
        final status = (b['status'] ?? 'UNKNOWN').toString();
        final payment = (b['paymentStatus'] ?? 'UNKNOWN').toString();
        final scheduled = b['scheduledTime'] != null ? formatDate(b['scheduledTime']) : '—';

        final statusColor = _statusColor(status, theme);
        final paymentColor = _paymentColor(payment, theme);

        final tile = Card.outlined(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.event_note, color: theme.colorScheme.onPrimaryContainer),
            ),
            title: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(label: status, color: statusColor),
                      _Badge(label: payment, color: paymentColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 6),
                      Text(scheduled, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to booking detail if exists
            },
          ),
        );

        // Optional swipe actions for eligible statuses only.
        final canCancel = status.toUpperCase() == 'PENDING';
        if (!canCancel) return tile;

        return Dismissible(
          key: ValueKey(b['id'] ?? index),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.cancel, color: theme.colorScheme.onErrorContainer),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cancel booking?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel')),
                ],
              ),
            );
          },
          onDismissed: (_) {
            // TODO: call cancel API, then remove locally
            setState(() => bookings.removeAt(index));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
          },
          child: tile,
        );
      },
    );
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return theme.colorScheme.secondaryContainer;
      case 'CONFIRMED':
        return theme.colorScheme.tertiaryContainer;
      case 'COMPLETED':
        return theme.colorScheme.primaryContainer;
      case 'CANCELLED':
        return theme.colorScheme.errorContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _paymentColor(String payment, ThemeData theme) {
    switch (payment.toUpperCase()) {
      case 'PAID':
        return theme.colorScheme.primaryContainer;
      case 'REFUNDED':
        return theme.colorScheme.tertiaryContainer;
      case 'FAILED':
        return theme.colorScheme.errorContainer;
      case 'PENDING':
        return theme.colorScheme.secondaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHigh;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(22))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, color: Colors.black12),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 160, color: Colors.black12),
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
