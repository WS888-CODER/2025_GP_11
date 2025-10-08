import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مشروع التخرج',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(title: Text('أهلاً يا W 👋')),
        body: Center(
          child: Text(
            'مشروعك جاهز للتطوير 💻📱',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
