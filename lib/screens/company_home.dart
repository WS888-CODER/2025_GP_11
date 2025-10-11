// lib/screens/company_home.dart
import 'package:flutter/material.dart';

class CompanyHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4A5FBC),
        elevation: 0,
        title: Text(
          'Welcome, Company!',
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
              Icons.business_outlined,
              size: 100,
              color: Color(0xFFFF7B7B),
            ),
            SizedBox(height: 30),
            Text(
              'Company Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A5FBC),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Manage your job postings here',
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
