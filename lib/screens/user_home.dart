// lib/screens/user_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// صفحات البنات: الموديل + التفاصيل + قائمة الوظائف + UserProfile
import 'package:gp_2025_11/screens/all_jobs.dart'
    show JobsPage, Job, JobDetailsPage, UserProfile;

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  // 0 = Reports, 1 = Home, 2 = Wishlist
  int _tab = 1;
  final _homeScroll = ScrollController();

  // بروفايل بسيط للتنقل لصفحة البنات
  final _profile = UserProfile(
    cvUrl: null,
    major: 'computer science',
    hasMinimumInfo: true,
    savedJobIds: {},
  );

  final _majors = const [
    'All',
    'computer science',
    'information systems',
    'cybersecurity',
    'data science',
    'software engineering',
    'business',
    'marketing',
  ];

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✨ إخفاء أي MaterialBanner (مثل "Upload your CV") بدون لمس كود البنات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });

    final homeBody = ListView(
      controller: _homeScroll,
      padding: const EdgeInsets.all(16),
      children: [
        // Mock / CV
        Row(
          children: [
            Expanded(
              child: _BigTile(
                label: 'Mock',
                icon: Icons.quiz_outlined,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mock – قريبًا')),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigTile(
                label: 'CV',
                icon: Icons.description_outlined,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CV – قريبًا')),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // عنوان Jobs + All
        Row(
          children: [
            Text('Jobs', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        JobsPage(profile: _profile, allMajors: _majors),
                  ),
                );
              },
              child: const Text('All'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // معاينة وظايف
        const _JobsPreview(limit: 2),
        const SizedBox(height: 16),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hi, User'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications – قريبًا')),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings – قريبًا')),
            ),
          ),
        ],
      ),

      // تبويبات فعلية مع الحفاظ على الحالة
      body: IndexedStack(
        index: _tab,
        children: [
          Center(
            child: Text('Reports – قريبًا',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          homeBody,
          const WishlistPage(), // 👈 Placeholder فقط
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == _tab) {
            // لو ضغطتِ Home وهو ظاهر: رجوع لأعلى
            if (i == 1) {
              _homeScroll.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
            return;
          }
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), label: 'Wishlist'),
        ],
      ),
    );
  }
}

// كرت كبير (Mock / CV)
class _BigTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BigTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 90,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// معاينة سريعة للوظائف من Firestore وتفاصيل البنات
class _JobsPreview extends StatelessWidget {
  final int limit;
  const _JobsPreview({this.limit = 2});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Jobs')
          .orderBy('StartDate', descending: true)
          .limit(limit)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snap.error}'),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No jobs yet',
                style: Theme.of(context).textTheme.bodyMedium),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data();
            final title = (data['JobTitle'] ?? '').toString();
            final position = (data['Position'] ?? '').toString();
            final specialty = (data['Specialty'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [position, specialty].where((e) => e.isNotEmpty).join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final job = Job.fromDoc(d);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailsPage(job: job),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// تبويب Wishlist — Placeholder فقط
class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Wishlist – قريبًا',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
