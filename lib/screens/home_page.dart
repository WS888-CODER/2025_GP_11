import 'package:flutter/material.dart';
import 'package:gp_2025_11/screens/job_posting_page.dart';
import 'all_jobs.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = UserProfile(
      cvUrl: null,
      major: 'Computer Science',
      hasMinimumInfo: true,
      savedJobIds: {'2'},
    );
    return Scaffold(
      appBar: AppBar(title: const Text('أهلاً يا W 👋')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'مشروعك جاهز للتطوير 💻📱',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JobPostingPage(),
                  ),
                );
              },
              child: const Text('Create Job Posting'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobsPage(
                      profile: profile,
                      allMajors: const [
                        'All',
                        'Computer Science',
                        'Information Systems',
                        'Cybersecurity',
                        'Data Science',
                        'Software Engineering',
                        'Business',
                        'Marketing',
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Browse jobs'),
            ),
          ],
        ),
      ),
    );
  }
}
