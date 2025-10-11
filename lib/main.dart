import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:gp_2025_11/config/theme.dart';
import 'package:gp_2025_11/screens/start_screen.dart';
import 'package:gp_2025_11/screens/job_posting_page.dart';

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
      home: const JobPostingPage(), // Temporary: testing JobPostingPage
      // home: StartScreen(), // Restore this later
      debugShowCheckedModeBanner: false,
    );
  }
}
