import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 96, color: Color(0xFF0B5D34)),
            SizedBox(height: 12),
            Text('Campus Route Navigator', style: TextStyle(color: Color(0xFF0B5D34), fontSize: 26, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Campus shuttles & bus stops, Nsukka', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
