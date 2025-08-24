import 'package:flutter/material.dart';
import 'send_otp_page.dart';

void main() {
  runApp(const KushalKartApp());
}

class KushalKartApp extends StatelessWidget {
  const KushalKartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KushalKart',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SendOtpPage(),
    );
  }
}
