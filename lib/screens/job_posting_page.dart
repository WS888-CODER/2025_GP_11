import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class JobPostingPage extends StatefulWidget {
  const JobPostingPage({super.key});

  @override
  State<JobPostingPage> createState() => _JobPostingPageState();
}

class _JobPostingPageState extends State<JobPostingPage> {
  final _formKey = GlobalKey<FormState>();

  final _jobTitleController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _positionController = TextEditingController();
  final _specialityController = TextEditingController();
  final _requirementController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _requirements = [];

  // ---- وضع تعديل أم إنشاء؟
  bool _isEdit = false;
  String? _jobId; // لو تعديل راح نستعمله

  @override
  void initState() {
    super.initState();
    // نقرأ الarguments بعد بناء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _isEdit = true;
        _jobId = args['jobId'] as String?;

        _jobTitleController.text = (args['title'] ?? '') as String;
        _positionController.text = (args['position'] ?? '') as String;
        _specialityController.text = (args['specialty'] ?? args['speciality'] ?? '') as String;
        _jobDescriptionController.text = (args['description'] ?? '') as String;

        // requirements يمكن تجي List<String> أو List<dynamic>
        final req = args['requirements'];
        if (req is List) {
          _requirements
            ..clear()
            ..addAll(req.map((e) => e.toString()));
        }

        // التواريخ (timeStamp/date/string)
        DateTime? _asDate(v) {
          if (v == null) return null;
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          if (v is String && v.isNotEmpty) {
            return DateTime.tryParse(v);
          }
          return null;
        }

        _startDate = _asDate(args['startDate']);
        _endDate = _asDate(args['endDate']);

        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _jobDescriptionController.dispose();
    _positionController.dispose();
    _specialityController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _addRequirement() {
    if (_requirementController.text.trim().isNotEmpty) {
      setState(() {
        _requirements.add(_requirementController.text.trim());
        _requirementController.clear();
      });
    }
  }

  void _removeRequirement(int index) {
    setState(() => _requirements.removeAt(index));
  }

  Future<void> _generateJobPost() async {
    if (_jobTitleController.text.isEmpty || _positionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter job title and position first')),
      );
      return;
    }

    final skills = _requirements.join(', ');
    // NOTE: استعملي localhost للويب، 10.0.2.2 لمحاكي أندرويد
    final url = Uri.parse('http://localhost:5000/generateJobPost');

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating job description...')),
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _jobTitleController.text,
          'company': 'Jadeer',
          'skills': skills.isNotEmpty ? skills : _specialityController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['job_post'] ?? '';

        final cleanedText = generatedText
            .toString()
            .replaceAll(RegExp(r'\*\*'), '')
            .replaceAll(RegExp(r'\*'), '')
            .replaceAll(RegExp(r'#+'), '')
            .replaceAll(RegExp(r'- '), '• ')
            .trim();

        setState(() => _jobDescriptionController.text = cleanedText);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI job description generated!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_requirements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one requirement')),
      );
      return;
    }

    final data = <String, dynamic>{
      'title': _jobTitleController.text.trim(),
      'description': _jobDescriptionController.text.trim(),
      'position': _positionController.text.trim(),
      'specialty': _specialityController.text.trim(),
      'requirements': _requirements,
      'startDate': _startDate,
      'endDate': _endDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final jobs = FirebaseFirestore.instance.collection('Jobs');

      if (_isEdit && _jobId != null && _jobId!.isNotEmpty) {
        // UPDATE
        await jobs.doc(_jobId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully')),
        );
      } else {
        // CREATE
        await jobs.add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'Open',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job created successfully')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Job' : 'Create Job Posting'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Job Title
            TextFormField(
              controller: _jobTitleController,
              decoration: InputDecoration(
                labelText: 'Job Title *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'This field is required' : null,
            ),
            const SizedBox(height: 8),

            // AI Generate Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _generateJobPost,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text(
                  'Generate with AI',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF49469F),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Position
            TextFormField(
              controller: _positionController,
              decoration: InputDecoration(
                labelText: 'Position *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            // Speciality
            TextFormField(
              controller: _specialityController,
              decoration: InputDecoration(
                labelText: 'Speciality *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            // Job Description
            TextFormField(
              controller: _jobDescriptionController,
              decoration: InputDecoration(
                labelText: 'Job Description *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              validator: (v) => (v == null || v.isEmpty) ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            // Requirements
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requirements *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _requirementController,
                            decoration: InputDecoration(
                              hintText: 'Enter requirement',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onSubmitted: (_) => _addRequirement(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addRequirement,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_requirements.isEmpty)
                      const Text('No requirements added yet', style: TextStyle(color: Colors.grey))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _requirements.length,
                        itemBuilder: (context, index) {
                          return Card(
                            child: ListTile(
                              title: Text(_requirements[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeRequirement(index),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Start Date
            InkWell(
              onTap: _selectStartDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Start Date *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _startDate != null ? _fmtDate(_startDate!) : 'Select date',
                  style: TextStyle(
                    color: _startDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End Date
            InkWell(
              onTap: _selectEndDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'End Date *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _endDate != null ? _fmtDate(_endDate!) : 'Select date',
                  style: TextStyle(
                    color: _endDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isEdit ? 'Save changes' : 'Create Job Posting',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
