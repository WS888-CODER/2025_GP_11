// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4A5FBC),
        elevation: 0,
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 100,
              color: Color(0xFFFF7B7B),
            ),
            SizedBox(height: 30),
            Text(
              'Admin Control Panel',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A5FBC),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Manage users and applications',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
