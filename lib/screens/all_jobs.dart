import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/* ========================== FIRESTORE CONSTANTS ========================== */

const kJobsCollection = 'Jobs';
const kUsersCollection = 'Users';

class JobFields {
  static const jobId = 'JobID';
  static const title = 'JobTitle';
  static const position = 'Position';
  static const keywords = 'JobKeywords';
  static const startDate = 'StartDate';
  static const endDate = 'EndDate';
  static const description = 'JobDescription';
  static const status = 'JobStatus';
  static const requirements = 'Requirements';
  static const specialty = 'Specialty';
  static const userId = 'UserID';
  static const company = 'Company';
  static const applyUrl = 'ApplyURL';
}

class UserFields {
  static const name = 'Name';
  static const userType = 'UserType';
}

/* ========================== MODEL ========================== */

class Job {
  final String id;
  final String jobId;
  final String title;
  final String position;
  final List<String> keywords;
  final DateTime postedAt;
  final DateTime? endDate;
  final String description;
  final String status;
  final List<String> requirements;
  final String specialty;
  final String userId;
  final String? applyUrl;

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

    return Job(
      id: doc.id,
      jobId: (d[JobFields.jobId] ?? '').toString(),
      title: (d[JobFields.title] ?? '').toString(),
      position: (d[JobFields.position] ?? '').toString(),
      keywords: asStringList(d[JobFields.keywords]),
      postedAt: asDate(d[JobFields.startDate]) ?? DateTime.now(),
      endDate: asDate(d[JobFields.endDate]),
      description: (d[JobFields.description] ?? '').toString(),
      status: (d[JobFields.status] ?? '').toString(),
      requirements: asStringList(d[JobFields.requirements]),
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

  const JobsPage({
    super.key,
    this.profile = const UserProfile(),
  });

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  String _search = '';
  String _selectedMajor = 'All';
  SortOrder _sort = SortOrder.newestFirst;
  bool _forYou = false;

  late Set<String> _saved;
  List<String> _majors = ['All'];

  final Map<String, String> _companyNames = {};
  bool _loadingCompanies = false;

  @override
  void initState() {
    super.initState();
    _saved = {...widget.profile.savedJobIds};
  }

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  bool _matchesMajor(Job j, String major) {
    final m = major.toLowerCase().trim();
    final spec = j.specialty.toLowerCase().trim();
    final inSpec = spec.contains(m);
    final inTags = j.keywords.any((k) => k.toLowerCase().trim().contains(m));
    return inSpec || inTags;
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
    setState(() {
      if (_saved.contains(job.id)) {
        _saved.remove(job.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Removed from saved')));
      } else {
        _saved.add(job.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved for later')));
      }
    });
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
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Upload CV'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _forYou = false);
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Later'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  void _updateMajorsFrom(List<Job> jobs) {
    final set = <String>{'All'};
    for (final j in jobs) {
      final s = j.specialty.trim();
      if (s.isNotEmpty) set.add(s);
    }
    final next = set.toList();

    if (!listEquals(next, _majors)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _majors = next;
        if (!_majors.contains(_selectedMajor)) {
          _selectedMajor = 'All';
        }
        setState(() {});
      });
    }
  }

  Future<void> _ensureCompanyNames(Set<String> uids) async {
    final missing = uids.where((id) => !_companyNames.containsKey(id)).toList();
    if (missing.isEmpty || _loadingCompanies) return;

    setState(() => _loadingCompanies = true);

    List<List<String>> chunks = [];
    for (var i = 0; i < missing.length; i += 10) {
      chunks.add(missing.sublist(
          i, i + 10 > missing.length ? missing.length : i + 10));
    }

    for (final chunk in chunks) {
      final qs = await FirebaseFirestore.instance
          .collection(kUsersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in qs.docs) {
        final data = doc.data();
        final name = (data[UserFields.name] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _companyNames[doc.id] = name;
        }
      }

      for (final id in chunk) {
        _companyNames.putIfAbsent(id, () => 'Company');
      }
    }

    if (mounted) setState(() => _loadingCompanies = false);
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedMajor,
                  items: _majors
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
                  onSelected: (v) {
                    setState(() => _forYou = v);
                    _maybeShowCvBanner();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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

                final data = snap.data ?? const <Job>[];
                _updateMajorsFrom(data);
                _ensureCompanyNames(data.map((j) => j.userId).toSet());

                final jobs = _applyFilters(data);
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
                    final saved = _saved.contains(j.id);
                    final companyName = _companyNames[j.userId] ?? 'Company';

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailsPage(
                                job: j,
                                companyName: companyName,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                        Text(
                                          companyName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
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
                                  FilledButton(
                                    onPressed: (j.applyUrl != null &&
                                            j.applyUrl!.trim().isNotEmpty)
                                        ? () async {
                                            final uri =
                                                Uri.parse(j.applyUrl!.trim());
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          }
                                        : null,
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

/* ========================== PROFILE ========================== */

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
  final String? companyName;
  const JobDetailsPage({super.key, required this.job, this.companyName});

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final canApply = job.applyUrl != null && job.applyUrl!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: canApply
              ? () async {
                  final uri = Uri.parse(job.applyUrl!.trim());
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          child: const Text('Apply'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                        if ((companyName ?? '').isNotEmpty)
                          Text(
                            companyName!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if ((companyName ?? '').isNotEmpty)
                          const SizedBox(height: 4),
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
