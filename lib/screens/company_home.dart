// lib/screens/company_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// صفحة إنشاء وظيفة التي عندكم
import 'package:gp_2025_11/screens/job_posting_page.dart';

// (اختياري) لو تبين فتح التفاصيل لاحقًا:
// import 'package:gp_2025_11/screens/all_jobs.dart' show Job, JobDetailsPage;

class CompanyHome extends StatefulWidget {
  /// مرّري معرف الشركة (مثلاً uid) لتصفية وظائف الشركة فقط.
  /// إذا تُرك فارغًا سيعرض جميع الوظائف (مفيد للتجربة).
  final String? companyId;
  /// اسم الشركة لعرضه في AppBar
  final String companyName;

  const CompanyHome({
    super.key,
    this.companyId,
    this.companyName = 'Company name',
  });

  @override
  State<CompanyHome> createState() => _CompanyHomeState();
}

class _CompanyHomeState extends State<CompanyHome> {
  static const Color _brand = Color(0xFF4A5FBC);
  int _tab = 1; // 0: Reports, 1: Home

  @override
  void initState() {
    super.initState();
    // إخفاء أي MaterialBanner (لو موجود من صفحات ثانية)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  /// جلب الوظائف من Firestore مع تصفية اختيارية على UserID
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _jobsStream() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('Jobs');

    if (widget.companyId != null && widget.companyId!.isNotEmpty) {
      q = q.where('UserID', isEqualTo: widget.companyId);
    }

    // نترك orderBy لتجنّب الحاجة لإنشاء index — نرتّب محليًا.
    return q.snapshots().map((snap) {
      final docs = snap.docs.toList();
      // ترتيب محلي حسب StartDate (الأحدث أولًا) إن وُجد
      docs.sort((a, b) {
        final sa = a.data()['StartDate'];
        final sb = b.data()['StartDate'];
        final da = sa is Timestamp ? sa.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final db = sb is Timestamp ? sb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      return docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeBody = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // العنوان العريض + أيقونة settings
        Row(
          children: [
            Expanded(
              child: Text(
                widget.companyName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _brand,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, color: _brand),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings – قريبًا')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // زر Create الدائري (حسب السكيتش)
        Center(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JobPostingPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _brand, width: 1.6),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            child: const Text(
              'Create',
              style: TextStyle(
                color: _brand,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // سطر فاصل مثل السكيتش
        const Divider(height: 32),

        // عنوان Job Posts
        const _SectionTitle(),

        // قائمة الوظائف
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _jobsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}'),
              );
            }

            final jobs = snap.data ?? const [];
            if (jobs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('No job posts yet'),
                ),
              );
            }

            return Column(
              children: jobs.map((doc) {
                final data = doc.data();
                final title = (data['JobTitle'] ?? 'Untitled').toString();
                final position = (data['Position'] ?? '').toString();
                final specialty = (data['Specialty'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // نصوص الوظيفة (يسار)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [position, specialty]
                                  .where((e) => e.isNotEmpty)
                                  .join(' • '),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // زر Edit (يمين)
                      OutlinedButton(
                        onPressed: () {
                          // مكان للتعديل لاحقًا (تحرير بيانات الوظيفة)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit – قريبًا')),
                          );

                          // مثال لو حبين تفتحون صفحة التفاصيل:
                          // final job = Job.fromDoc(doc);
                          // Navigator.push(context, MaterialPageRoute(
                          //   builder: (_) => JobDetailsPage(job: job),
                          // ));
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _brand),
                          foregroundColor: _brand,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        // خط فاصل سفلي مثل السكيتش
        const SizedBox(height: 12),
        const Divider(height: 32),
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Welcome, Company!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications – قريبًا')),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          // Reports
          Center(
            child: Text(
              'Reports – قريبًا',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Home
          homeBody,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            'Job Posts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
