import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B5D34),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 96, color: Color(0xFFF5C542)),
            SizedBox(height: 12),
            Text('UNN Route Navigator', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Campus shuttles & bus stops, Nsukka', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
