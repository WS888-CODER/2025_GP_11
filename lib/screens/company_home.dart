// lib/screens/company_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyHome extends StatefulWidget {
  final String? companyId;              // uid تبع الشركة (يوصل من اللوق إن)
  final String companyName;             // اسم افتراضي لو ما لاقينا شي من الداتابيس

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  // ---------------- Company name (dynamic from Firestore) ----------------
  Stream<String> _companyNameStream() {
    // لو ما فيه companyId نرجّع الاسم الافتراضي
    if (widget.companyId == null || widget.companyId!.isEmpty) {
      return Stream.value(widget.companyName);
    }

    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.companyId)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final name = (data?['CompanyName'] ?? data?['companyName'] ?? '')
          .toString()
          .trim();
      return name.isEmpty ? widget.companyName : name;
    });
  }

  // ---------------- Jobs list stream ----------------
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _jobsStream() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('Jobs');

    if (widget.companyId != null && widget.companyId!.isNotEmpty) {
      q = q.where('UserID', isEqualTo: widget.companyId);
    }

    return q.snapshots().map((snap) {
      final docs = snap.docs.toList();
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
        // -------------- تم حذف سطر "Company name" بالكامل --------------

        // زر Create يمين
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 8),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/job-posting'); // create mode
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _brand),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(
                    color: _brand,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(height: 32),

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
                child: Center(child: Text('No job posts yet')),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                              style:
                                  const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          final desc =
                              data['JobDescription'] ?? data['Description'] ?? '';
                          final req =
                              data['Requirements'] ?? data['Requirments'] ?? [];
                          final start = data['StartDate'];
                          final end = data['EndDate'];

                          Navigator.pushNamed(
                            context,
                            '/job-posting',
                            arguments: <String, dynamic>{
                              'jobId': doc.id,
                              'title': title,
                              'position': position,
                              'specialty': specialty,
                              'description': desc,
                              'requirements':
                                  req is List ? req : <String>[],
                              'startDate': start,
                              'endDate': end,
                            },
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _brand),
                          foregroundColor: _brand,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
        // --------- العنوان صار ديناميكي من Firestore ---------
        title: StreamBuilder<String>(
          stream: _companyNameStream(),
          builder: (context, snap) {
            final name =
                (snap.data ?? widget.companyName).toString().trim();
            return Text(
              'Welcome, $name!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined), label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
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
          Text('Job Posts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Spacer(),
        ],
      ),
    );
  }
}
