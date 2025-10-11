// lib/screens/jobseeker_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// صفحات البنات: الموديل + التفاصيل + قائمة الوظائف + UserProfile
import 'package:gp_2025_11/screens/all_jobs.dart'
    show JobsPage, Job, JobDetailsPage, UserProfile;

class JobSeekerHome extends StatefulWidget {
  const JobSeekerHome({super.key});

  @override
  State<JobSeekerHome> createState() => _JobSeekerHomeState();
}

class _JobSeekerHomeState extends State<JobSeekerHome> {
  // 0 = Reports, 1 = Home, 2 = Wishlist
  int _tab = 1;
  final _homeScroll = ScrollController();

  // بروفايل بسيط للتنقل إلى JobsPage (عرض فقط)
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

  static const _brand = Color(0xFF4A5FBC);

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إخفاء أي MaterialBanner (مثل "Upload your CV") بدون لمس كود البنات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });

    final homeBody = ListView(
      controller: _homeScroll,
      padding: const EdgeInsets.all(16),
      children: [
        // العنوان الكبير (بنفس روح الليدر)
        Row(
          children: const [
            Icon(Icons.work_outline, size: 36, color: _brand),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Job Seeker Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _brand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // أزرار Mock / CV
        Row(
          children: [
            Expanded(
              child: _BigTile(
                label: 'Mock',
                icon: Icons.quiz_outlined,
                color: _brand,
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
                color: _brand,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CV – قريبًا')),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // عنوان Jobs + زر All
        Row(
          children: [
            const Text(
              'Jobs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                       JobsPage(profile: _profile),

                  ),
                );
              },
              child: const Text('All'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // معاينة أحدث وظيفتين
        const _JobsPreview(limit: 2),

        const SizedBox(height: 16),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        title: const Text(
          'Welcome, Job Seeker!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications – قريبًا')),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
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
            child: Text(
              'Reports – قريبًا',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          homeBody,
          const _WishlistPlaceholder(),
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

// كرت كبير (Mock / CV) بنفس روح الليدر
class _BigTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _BigTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
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

// معاينة سريعة للوظائف (من Firestore) وتفتح تفاصيل البنات
class _JobsPreview extends StatelessWidget {
  final int limit;
  const _JobsPreview({this.limit = 2});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Jobs') // تأكدي من J كبيرة مطابقة للقواعد
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
            child: Text(
              'No jobs yet',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                color: Colors.white,
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
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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

// Wishlist Placeholder (بناءً على طلبك)
class _WishlistPlaceholder extends StatelessWidget {
  const _WishlistPlaceholder();

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
