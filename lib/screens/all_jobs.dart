import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/* ========================== FIRESTORE CONSTANTS ========================== */

const kJobsCollection = 'Jobs';

class JobFields {
  static const jobId = 'JobID';
  static const title = 'JobTitle';
  static const position = 'Position';
  static const keywords = 'JobKeywords';
  static const startDate = 'StartDate';
  static const endDate = 'EndDate';
  static const description = 'JobDescription';
  static const status = 'JobStatus';
  static const requirements = 'Requirments';
  static const specialty = 'Specialty';
  static const userId = 'UserID';
  static const company = 'Company';
  static const applyUrl = 'ApplyURL';
}

/* ========================== MODEL ========================== */

class Job {
  final String id;
  final String jobId;
  final String title;
  final String position; // Position
  final List<String> keywords;
  final DateTime postedAt;
  final DateTime? endDate;
  final String description;
  final String status;
  final List<String> requirements;
  final String specialty;
  final String userId;
  final String? applyUrl; // ApplyURL

  const Job({
    required this.id,
    required this.jobId,
    required this.title,
    required this.position,
    required this.keywords,
    required this.postedAt,
    this.endDate,
    required this.description,
    required this.status,
    required this.requirements,
    required this.specialty,
    required this.userId,
    this.applyUrl,
  });

  factory Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    DateTime? asDate(dynamic v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

    List<String> asStringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    final req = d[JobFields.requirements] ?? d[JobFields.requirements];

    return Job(
      id: doc.id,
      jobId: (d[JobFields.jobId] ?? '').toString(),
      title: (d[JobFields.title] ?? '').toString(),
      position: (d[JobFields.position] ?? '').toString(),
      keywords: asStringList(d[JobFields.keywords]),
      postedAt: asDate(d[JobFields.startDate]) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endDate: asDate(d[JobFields.endDate]),
      description: (d[JobFields.description] ?? '').toString(),
      status: (d[JobFields.status] ?? '').toString(),
      requirements: asStringList(req),
      specialty: (d[JobFields.specialty] ?? '').toString(),
      userId: (d[JobFields.userId] ?? '').toString(),
      applyUrl: (d[JobFields.applyUrl] as String?)?.toString(),
    );
  }
}

/* ========================== DATA STREAM ========================== */

Stream<List<Job>> _jobsStream() {
  return FirebaseFirestore.instance
      .collection(kJobsCollection)
      .orderBy(JobFields.startDate, descending: true)
      .snapshots()
      .map((qs) => qs.docs.map((d) => Job.fromDoc(d)).toList());
}

/* ========================== UI ========================== */

enum SortOrder { newestFirst, oldestFirst }

class JobsPage extends StatefulWidget {
  final UserProfile profile;
  final List<String> allMajors;

  const JobsPage({
    super.key,
    this.profile = const UserProfile(), // قيمة افتراضية
    this.allMajors = const ['All'], // قيمة افتراضية
  });

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  String _search = '';
  String _selectedMajor = 'All';
  SortOrder _sort = SortOrder.newestFirst;
  bool _forYou = false;

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  bool _matchesMajor(Job j, String major) {
    final m = major.toLowerCase().trim();
    return j.specialty.toLowerCase() == m ||
        j.keywords.any((k) => k.toLowerCase() == m);
  }

  List<Job> _applyFilters(List<Job> jobs) {
    Iterable<Job> res = jobs;

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      res = res.where(
        (j) =>
            j.title.toLowerCase().contains(q) ||
            j.position.toLowerCase().contains(q) ||
            j.specialty.toLowerCase().contains(q) ||
            j.keywords.any((k) => k.toLowerCase().contains(q)),
      );
    }

    if (_selectedMajor != 'All') {
      res = res.where((j) => _matchesMajor(j, _selectedMajor));
    }

    if (_forYou) {
      if (widget.profile.cvUrl == null) {
        res = const <Job>[];
      } else {
        final userMajor = widget.profile.major;
        if (userMajor != null && userMajor.isNotEmpty) {
          res = res.where((j) => _matchesMajor(j, userMajor));
        }
      }
    }

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
              },
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      );
      return;
    }
    // Next step will handle creating an Application
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsPage(job: job)),
    );
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
                hintText: 'Search company, title, position or keyword…',
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
          // Filters row
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

          // Live list
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: _jobsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final jobs = _applyFilters(snap.data ?? const <Job>[]);
                if (jobs.isEmpty) {
                  return Center(
                    child: Text(
                      _forYou && widget.profile.cvUrl == null
                          ? 'Upload your CV to see personalized jobs.'
                          : 'No jobs match your filters.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final j = jobs[i];
                    final saved = widget.profile.savedJobIds.contains(j.id);
                    final isClosed = (j.endDate != null &&
                            j.endDate!.isBefore(DateTime.now())) ||
                        j.status.toLowerCase() == 'closed';

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _onApply(j),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row: avatar + title + company/position
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          j.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Posted: ${_fmtDate(j.postedAt)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: saved
                                        ? 'Remove from saved'
                                        : 'Save for later',
                                    icon: Icon(
                                      saved
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    onPressed: () => _toggleSave(j),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Keywords chips (max 3)
                              if (j.keywords.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: -8,
                                  children: j.keywords.take(3).map((k) {
                                    return Chip(
                                      label: Text(k),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 10),

                              // Bottom row: specialty + status + apply
                              Row(
                                children: [
                                  if (j.specialty.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(.08),
                                      ),
                                      child: Text(
                                        j.specialty,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (isClosed)
                                    const Text(
                                      'Closed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: () => _onApply(j),
                                      child: const Text('Apply'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

/* ========================== PROFILE (for passing) ========================== */

class UserProfile {
  final String? cvUrl;
  final String? major;
  final bool hasMinimumInfo;
  final Set<String> savedJobIds;

  const UserProfile({
    this.cvUrl,
    this.major,
    this.hasMinimumInfo = false,
    this.savedJobIds = const {},
  });
}

/* ========================== DETAILS PAGE ========================== */

class JobDetailsPage extends StatelessWidget {
  final Job job;
  const JobDetailsPage({super.key, required this.job});

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isClosed =
        (job.endDate != null && job.endDate!.isBefore(DateTime.now())) ||
            job.status.toLowerCase() == 'closed';

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: isClosed ? null : () {},
          child: const Text('Apply'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Company info
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(job.position),
                        const SizedBox(height: 4),
                        Text(
                          'Posted: ${_fmtDate(job.postedAt)}'
                          '${job.endDate != null ? ' • Ends: ${_fmtDate(job.endDate!)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Job title + specialty
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (job.specialty.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Chip(label: Text(job.specialty)),
                  ],
                  if (job.keywords.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: job.keywords
                          .map((e) => Chip(label: Text(e)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Description',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.description.isEmpty
                        ? 'No description provided.'
                        : job.description,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Requirements
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Requirements',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (job.requirements.isEmpty)
                    const Text('No requirements listed.')
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: job.requirements
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(child: Text(r)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
