import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // keep if you have it
import 'package:gp_2025_11/config/theme.dart';
import 'package:gp_2025_11/screens/home_page.dart';

void main() async {
  // 1️⃣ Make sure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Initialize Firebase BEFORE running the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3️⃣ Now run your app
  runApp(const Jadeer());
}

class Jadeer extends StatelessWidget {
  const Jadeer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مشروع التخرج',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
