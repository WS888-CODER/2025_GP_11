import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gp_2025_11/screens/all_jobs.dart';
import 'firebase_options.dart';
import 'package:gp_2025_11/config/theme.dart';
import 'package:gp_2025_11/screens/start_screen.dart';
import 'package:gp_2025_11/screens/login_screen.dart';
import 'package:gp_2025_11/screens/jobseeker_home.dart';
import 'package:gp_2025_11/screens/company_home.dart';
import 'package:gp_2025_11/screens/admin_dashboard.dart';
import 'package:gp_2025_11/screens/job_posting_page.dart';
import 'package:gp_2025_11/screens/signup_screen.dart';
import 'package:gp_2025_11/screens/otp_verification_screen.dart'; // ← ضيفي هذا السطر

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const Jadeer());
}

class Jadeer extends StatelessWidget {
  const Jadeer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadeer',
      theme: AppTheme.lightTheme,
      home: JobPostingPage(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/start': (context) => StartScreen(),
        '/login': (context) => LoginScreen(),
        '/jobseeker-home': (context) => JobSeekerHome(),
        '/signup': (context) => SignupScreen(),
        '/company-home': (context) => CompanyHome(),
        '/otp-verification': (context) => OTPVerificationScreen(),
        '/admin-dashboard': (context) => AdminDashboard(),
        '/job-posting': (context) => const JobPostingPage(),
      },
    );
  }
}
