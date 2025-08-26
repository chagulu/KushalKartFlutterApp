import 'package:flutter/material.dart';
import 'package:kushal_kart_flutter_app/MyBookingPage.dart';
import 'package:kushal_kart_flutter_app/MyTransactionPage.dart';
import 'package:kushal_kart_flutter_app/service_listing_page.dart';
import 'package:kushal_kart_flutter_app/SettingsPage.dart';

class KushalBottomNav extends StatelessWidget {
  final int currentIndex;
  final BuildContext context;

  const KushalBottomNav({
    Key? key,
    required this.currentIndex,
    required this.context,
  }) : super(key: key);

  void _onTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyTransactionPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ServiceListingPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: _onTap,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.event_available),
          label: 'Booking',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home_repair_service),
          label: 'Services',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
