import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


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
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
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
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _addRequirement() {
    if (_requirementController.text.isNotEmpty) {
      setState(() {
        _requirements.add(_requirementController.text);
        _requirementController.clear();
      });
    }
  }

  void _removeRequirement(int index) {
    setState(() {
      _requirements.removeAt(index);
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_requirements.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one requirement')),
        );
        return;
      }

      // Form is valid, process the data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posting created successfully')),
      );

      // Here you can process the form data
      print('Job Title: ${_jobTitleController.text}');
      print('Description: ${_jobDescriptionController.text}');
      print('Requirements: $_requirements');
      print('Position: ${_positionController.text}');
      print('Start Date: $_startDate');
      print('End Date: $_endDate');
      print('Speciality: ${_specialityController.text}');
    }
  }
Future<void> _generateJobPost() async {
  if (_jobTitleController.text.isEmpty || _positionController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter job title and position first')),
    );
    return;
  }

  final skills = _requirements.join(', ');
  final url = Uri.parse('http://10.0.2.2:5000/generateJobPost'); // For Android emulator
  // Use http://localhost:5000 if you're running Flutter Web

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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final generatedText = data['job_post'];

      setState(() {
        _jobDescriptionController.text = generatedText;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI job description generated!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Job Posting'),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
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
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Requirements Section
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                      const Text(
                        'No requirements added yet',
                        style: TextStyle(color: Colors.grey),
                      )
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
                  _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : 'Select date',
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
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'Select date',
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
              child: const Text(
                'Create Job Posting',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
