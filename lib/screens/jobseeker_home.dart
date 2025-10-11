// lib/screens/jobseeker_home.dart
import 'package:flutter/material.dart';

class JobSeekerHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4A5FBC),
        elevation: 0,
        title: Text(
          'Welcome, Job Seeker!',
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
              Icons.work_outline,
              size: 100,
              color: Color(0xFF4A5FBC),
            ),
            SizedBox(height: 30),
            Text(
              'Job Seeker Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A5FBC),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'This is your home page',
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
