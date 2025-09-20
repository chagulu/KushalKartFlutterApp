import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kushal_kart_flutter_app/config.dart';
import 'package:kushal_kart_flutter_app/widgets/kushal_bottom_nav.dart';

class MyTransactionPage extends StatefulWidget {
  const MyTransactionPage({Key? key}) : super(key: key);

  @override
  State<MyTransactionPage> createState() => _MyTransactionPageState();
}

class _MyTransactionPageState extends State<MyTransactionPage> {
  List<dynamic> transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  late final NumberFormat _inrFormat;

  @override
  void initState() {
    super.initState();
    _inrFormat = NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹');
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
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
        Uri.parse('$baseUrl/api/transactions/mine'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          transactions = jsonDecode(response.body) as List<dynamic>;
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

  Future<void> _refresh() async {
    await fetchTransactions();
  }

  String _formatAmount(num? value) {
    if (value == null) return '₹0';
    return _inrFormat.format(value);
  }

  String _formatDate(dynamic createdAt) {
    // createdAt can be ISO8601 string or epoch; handle string ISO here
    try {
      final dt = DateTime.parse(createdAt.toString());
      return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(dt);
    } catch (_) {
      return createdAt?.toString() ?? '—';
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return theme.colorScheme.primaryContainer;
      case 'PENDING':
        return theme.colorScheme.secondaryContainer;
      case 'FAILED':
      case 'CANCELLED':
        return theme.colorScheme.errorContainer;
      case 'REFUNDED':
        return theme.colorScheme.tertiaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _typeColor(String type, ThemeData theme) {
    switch (type.toUpperCase()) {
      case 'CREDIT':
        return theme.colorScheme.primaryContainer;
      case 'DEBIT':
        return theme.colorScheme.secondaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My transactions'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(theme),
      ),
      bottomNavigationBar: KushalBottomNav(currentIndex: 1, context: context),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _TxSkeleton(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Could not load transactions', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_errorMessage, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: fetchTransactions, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('No transactions yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Payments and refunds will appear here.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index] as Map<String, dynamic>;
        final amount = _formatAmount(tx['amount'] as num?);
        final type = (tx['transactionType'] ?? '—').toString();
        final status = (tx['transactionStatus'] ?? '—').toString();
        final bookingId = tx['bookingId']?.toString() ?? '—';
        final remarks = (tx['remarks'] ?? '').toString();
        final createdAt = _formatDate(tx['createdAt']);

        // Optional: extract link from remarks
        String? link;
        if (remarks.contains('Link: ')) {
          final parts = remarks.split('Link: ');
          if (parts.length > 1) {
            final candidate = parts.last.trim();
            if (candidate.startsWith('http')) link = candidate;
          }
        }

        return Card.outlined(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    type.toUpperCase() == 'CREDIT' ? Icons.south_west : Icons.north_east,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount + type/status badges
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$amount',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(label: type.toUpperCase(), color: _typeColor(type, theme)),
                          _Badge(label: status.toUpperCase(), color: _statusColor(status, theme)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Meta lines
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Booking: $bookingId', style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(createdAt, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (remarks.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          remarks,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: link != null ? 'Open link' : 'Receipt',
                  onPressed: link != null
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔗 Link: $link')));
                          // Or launchUrl(Uri.parse(link));
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening receipt...')));
                        },
                  icon: Badge(
                    // Show a small dot if pending
                    isLabelVisible: status.toUpperCase() == 'PENDING',
                    child: const Icon(Icons.receipt_long),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _TxSkeleton extends StatelessWidget {
  const _TxSkeleton();
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
