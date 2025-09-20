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
  final _controller = ScrollController();
  final List<dynamic> _bookings = [];

  // Pagination
  int _page = 0; // starts at 0; the API also supports page=1,2,... we increment accordingly
  final int _size = 10; // page size = 10
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isLastPage = false;
  String _errorMessage = '';

  // Optional: to prevent duplicate pay taps
  int? _payingBookingId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _fetchPage(reset: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLastPage || _isLoadingMore || _isInitialLoading) return;
    if (!_controller.hasClients) return;
    final position = _controller.position;
    const threshold = 200.0;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage({bool reset = false}) async {
    try {
      if (reset) {
        setState(() {
          _page = 0;
          _isLastPage = false;
          _errorMessage = '';
          _isInitialLoading = true;
          _bookings.clear();
        });
      } else {
        setState(() => _isLoadingMore = true);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'No token found. Please login again.';
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      // If the backend accepts page=1..N, use (_page + 1) below; otherwise keep 0-based.
      final currentPageForApi = _page; // change to (_page + 1) if API is 1-based
      final uri = Uri.parse(
        '$baseUrl/api/bookings/mine?status=PENDING&page=$currentPageForApi&size=$_size',
      );
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> content = (body['content'] as List?) ?? [];
        final bool lastFlag = body['last'] == true;

        setState(() {
          _bookings.addAll(content);
          _isLastPage = lastFlag || content.length < _size;
          if (!_isLastPage) _page += 1;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed: ${res.body}';
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _fetchPage(reset: true);
  }

  String _formatDate(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(dateTime);
  }

  // Simulate pay flow trigger (replace with real navigation or API)
  Future<void> _onPayNow(dynamic booking) async {
    final id = booking['id'] as int?;
    if (id == null) return;
    setState(() => _payingBookingId = id);
    try {
      // TODO: Navigate to payment screen or call payment intent API
      // For example: Navigator.pushNamed(context, '/checkout', arguments: booking);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Redirecting to payment...')),
      );
    } finally {
      if (mounted) setState(() => _payingBookingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(theme),
      ),
      bottomNavigationBar: KushalBottomNav(currentIndex: 0, context: context),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isInitialLoading) {
      return ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _BookingSkeleton(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
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
                FilledButton.icon(onPressed: () => _fetchPage(reset: true), icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    if (_bookings.isEmpty) {
      return ListView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
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
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _bookings.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final b = _bookings[index];
        final address = b['address'] ?? 'No address provided';
        final bookingStatus = (b['status'] ?? 'UNKNOWN').toString(); // booking status
        final paymentStatus = (b['paymentStatus'] ?? 'UNKNOWN').toString(); // payment status
        final scheduled = b['scheduledTime'] != null ? _formatDate(b['scheduledTime']) : '—';

        final isPaymentPending = paymentStatus.toUpperCase() == 'PENDING';
        final isBookingPending = bookingStatus.toUpperCase() == 'PENDING';

        return Card.outlined(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Padding(
    padding: const EdgeInsets.all(12), // uniform padding fixes tight fits
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, // prevent bottom overflow
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.event_note, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        // Content column expands and wraps
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              // Badges wrap to new line as needed
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: 'Booking: $bookingStatus', color: _bookingColor(bookingStatus, theme)),
                  _Badge(label: 'Payment: $paymentStatus', color: _paymentColor(paymentStatus, theme)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 16),
                  const SizedBox(width: 6),
                  Flexible( // prevent row overflow on narrow screens
                    child: Text(
                      scheduled,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Trailing kept compact; use SizedBox constraints
        if (isPaymentPending)
          ConstrainedBox(
            constraints: const BoxConstraints.tightFor(width: 110, height: 36),
            child: FilledButton.tonalIcon(
              onPressed: _payingBookingId == b['id'] ? null : () => _onPayNow(b),
              icon: _payingBookingId == b['id']
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payment, size: 18),
              label: const Text('Pay now', overflow: TextOverflow.ellipsis),
            ),
          )
        else
          const Icon(Icons.chevron_right),
      ],
    ),
  ),
);
      },
    );
  }

  Color _bookingColor(String status, ThemeData theme) {
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
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
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
