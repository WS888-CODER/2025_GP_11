import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id; // Firestore doc id
  final String jobId; // from JobID
  final String title; // from JobTitle
  final String location; // from Position
  final List<String> majors; // from JobKeywords
  final DateTime postedAt; // from StartDate
  final DateTime? endDate; // from EndDate
  final String description; // from JobDescription
  final String status; // from JobStatus
  final List<String> requirements; // from Requirements
  final String specialty; // from Specialty
  final String userId; // from UserID
  final String? applyUrl; // not in DB now -> null or add ApplyURL

  const Job({
    required this.id,
    required this.jobId,
    required this.title,
    required this.location,
    required this.majors,
    required this.postedAt,
    this.endDate,
    required this.description,
    required this.status,
    required this.requirements,
    required this.specialty,
    required this.userId,
    this.applyUrl,
  });

  factory Job.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    DateTime? asDate(dynamic v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

    List<String> asStringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    return Job(
      id: doc.id,
      jobId: (d['JobID'] ?? '').toString(),
      title: (d['JobTitle'] ?? '').toString(),
      location: (d['Position'] ?? '').toString(),
      majors: asStringList(d['JobKeywords']),
      postedAt:
          asDate(d['StartDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endDate: asDate(d['EndDate']),
      description: (d['JobDescription'] ?? '').toString(),
      status: (d['JobStatus'] ?? '').toString(),
      requirements: asStringList(d['Requirements']),
      specialty: (d['Specialty'] ?? '').toString(),
      userId: (d['UserID'] ?? '').toString(),
      applyUrl: d['ApplyURL']?.toString(), // optional
    );
  }
}

class UserProfile {
  final String? cvUrl;
  final String? major;
  final bool hasMinimumInfo;
  final Set<String> savedJobIds;

  UserProfile({
    this.cvUrl,
    this.major,
    this.hasMinimumInfo = false,
    Set<String>? savedJobIds,
  }) : savedJobIds = savedJobIds ?? {};
}

Future<List<Job>> _fetchJobs() async {
  final qs = await FirebaseFirestore.instance
      .collection('Jobs')
      .orderBy('StartDate', descending: true)
      .get();

  return qs.docs.map((d) => Job.fromFirestore(d)).toList();
}

enum SortOrder { newestFirst, oldestFirst }

class JobsPage extends StatefulWidget {
  final UserProfile profile;
  final List<String> allMajors; // first item should be "All"

  const JobsPage({super.key, required this.profile, required this.allMajors});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  // UI state
  String _search = '';
  String _selectedMajor = 'All';
  SortOrder _sort = SortOrder.newestFirst;
  bool _forYou = false;

  late final Future<List<Job>> _jobsFuture = _fetchJobs();

  // helpers
  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  List<Job> _applyFilters(List<Job> jobs) {
    Iterable<Job> res = jobs;

    // search
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      res = res.where(
        (j) =>
            j.title.toLowerCase().contains(q) ||
            j.location.toLowerCase().contains(q) ||
            j.majors.any((m) => m.toLowerCase().contains(q)),
      );
    }

    // major
    if (_selectedMajor != 'All') {
      res = res.where((j) => j.majors.contains(_selectedMajor));
    }

    // For You
    if (_forYou) {
      if (widget.profile.cvUrl == null) {
        res = const <Job>[];
      } else {
        final userMajor = widget.profile.major;
        if (userMajor != null && userMajor.isNotEmpty) {
          res = res.where((j) => j.majors.contains(userMajor));
        }
      }
    }

    // sort
    final list = res.toList();
    list.sort(
      (a, b) => _sort == SortOrder.newestFirst
          ? b.postedAt.compareTo(a.postedAt)
          : a.postedAt.compareTo(b.postedAt),
    );
    return list;
  }

  void _toggleSave(Job job) {
    final saved = widget.profile.savedJobIds;
    setState(() {
      if (saved.contains(job.id)) {
        saved.remove(job.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from saved')));
      } else {
        saved.add(job.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved for later')));
      }
    });
    // TODO: persist saved jobs in Firestore under user document if needed
  }

  void _onApply(Job job) {
    if (!widget.profile.hasMinimumInfo) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Complete your profile'),
          content: const Text(
            'Please complete your account details before applying.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile page opened (placeholder)'),
                  ),
                );
              },
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      );
      return;
    }

    if (job.applyUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening application link: ${job.applyUrl}')),
      );
      // TODO: launchUrl(job.applyUrl!)
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailsPage(job: job)),
      );
    }
  }

  void _maybeShowCvBanner() {
    if (_forYou && widget.profile.cvUrl == null) {
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'Upload your CV to enable "For You" recommendations.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _forYou = false);
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                // TODO: navigate to CV upload page
              },
              child: const Text('Upload CV'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybeShowCvBanner();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search job title or company...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedMajor,
                  items: widget.allMajors
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedMajor = val ?? 'All'),
                ),
                DropdownButton<SortOrder>(
                  value: _sort,
                  items: const [
                    DropdownMenuItem(
                      value: SortOrder.newestFirst,
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: SortOrder.oldestFirst,
                      child: Text('Oldest first'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _sort = val!),
                ),
                FilterChip(
                  selected: _forYou,
                  label: const Text('For You'),
                  onSelected: (v) => setState(() => _forYou = v),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Data loader + list
          Expanded(
            child: FutureBuilder<List<Job>>(
              future: _jobsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final jobs = snap.data ?? const <Job>[];
                final filtered = _applyFilters(jobs);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _forYou && widget.profile.cvUrl == null
                          ? 'Upload your CV to see personalized jobs.'
                          : 'No matching jobs.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final job = filtered[i];
                    final saved = widget.profile.savedJobIds.contains(job.id);
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text(
                          job.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${job.location}\nPosted: ${_fmtDate(job.postedAt)}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: saved
                                  ? 'Remove from saved'
                                  : 'Save for later',
                              icon: Icon(
                                saved ? Icons.favorite : Icons.favorite_border,
                              ),
                              onPressed: () => _toggleSave(job),
                            ),
                            FilledButton(
                              onPressed: () => _onApply(job),
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                        onTap: () => _onApply(job),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ========================== JOB DETAILS PAGE ========================== */

class JobDetailsPage extends StatelessWidget {
  final Job job;
  const JobDetailsPage({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Location: ${job.location}\n\n'
          'This is a placeholder for job details. Add full description, '
          'requirements, and benefits here later.',
        ),
      ),
    );
  }
}
