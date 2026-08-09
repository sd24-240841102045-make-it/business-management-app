import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key});

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final AppDataStore _store = AppDataStore();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  String? _selectedClientId;
  String? _selectedManagerId;
  String _selectedStatus = 'In Progress';
  String _selectedHealth = 'On Track';

  final List<String> _selectedTeamMemberIds = [];

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);

  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_store.clients.isNotEmpty) {
      _selectedClientId = _store.clients.first.id;
    }
    _selectedManagerId = null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      if (mounted) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: _startTime,
        );
        if (pickedTime != null) {
          setState(() {
            _startDate = pickedDate;
            _startTime = pickedTime;
          });
        }
      }
    }
  }

  Future<void> _pickEndDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      if (mounted) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: _endTime,
        );
        if (pickedTime != null) {
          setState(() {
            _endDate = pickedDate;
            _endTime = pickedTime;
          });
        }
      }
    }
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:00';
  }

  String _formatDateTimeDisplay(DateTime date, TimeOfDay time) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hourStr = time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
    final minStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$y-$m-$d  $hourStr:$minStr $period';
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final orgId = SupabaseService().currentOrganizationId;
      final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0.0;
      
      final startIso = _formatDateTime(_startDate, _startTime);
      final endIso = _formatDateTime(_endDate, _endTime);

      final response = await SupabaseService().client.from('projects').insert({
        'organization_id': orgId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'client_id': _selectedClientId,
        'manager_id': _selectedManagerId,
        'status': _selectedStatus,
        'health': _selectedHealth,
        'budget': budget,
        'start_date': startIso,
        'deadline': endIso,
      }).select('id').single();

      final newProjectId = response['id'].toString();
      
      // Assign team members
      if (_selectedTeamMemberIds.isNotEmpty) {
        await SupabaseService().assignProjectMembers(newProjectId, _selectedTeamMemberIds);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project added successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error inserting project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add project: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Project', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Project Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 24),
                      
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Project Name *',
                          prefixIcon: const Icon(Icons.folder),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Project name is required' : null,
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedClientId,
                        decoration: InputDecoration(
                          labelText: 'Client Account *',
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _store.clients.fold<Map<String, DropdownMenuItem<String>>>({}, (map, c) {
                          map[c.id] = DropdownMenuItem(value: c.id, child: Text(c.name));
                          return map;
                        }).values.toList(),
                        onChanged: (val) => setState(() => _selectedClientId = val),
                        validator: (value) => value == null ? 'Client is required' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedManagerId,
                        decoration: InputDecoration(
                          labelText: 'Project Manager',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None / Unassigned')),
                          ..._store.employees.where((e) => e.userId.isNotEmpty).fold<Map<String, DropdownMenuItem<String>>>({}, (map, e) {
                            map[e.userId] = DropdownMenuItem(value: e.userId, child: Text(e.name));
                            return map;
                          }).values,
                        ],
                        onChanged: (val) => setState(() => _selectedManagerId = val),
                      ),
                      const SizedBox(height: 20),

                      const Text('Team Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _store.employees.where((e) => e.userId.isNotEmpty).isEmpty
                            ? const Text('No assignable team members found.', style: TextStyle(color: Colors.grey))
                            : Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: _store.employees
                                    .where((e) => e.userId.isNotEmpty)
                                    .fold<Map<String, Employee>>({}, (map, e) {
                                      map[e.userId] = e;
                                      return map;
                                    })
                                    .values
                                    .map((e) {
                                      final isSelected = _selectedTeamMemberIds.contains(e.userId);
                                      return FilterChip(
                                        label: Text(e.name),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedTeamMemberIds.add(e.userId);
                                            } else {
                                              _selectedTeamMemberIds.remove(e.userId);
                                            }
                                          });
                                        },
                                        selectedColor: Colors.teal.withOpacity(0.2),
                                        checkmarkColor: Colors.teal,
                                      );
                                    }).toList(),
                              ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          prefixIcon: const Icon(Icons.flag),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'On Hold', child: Text('On Hold')),
                          DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (val) => setState(() => _selectedStatus = val!),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedHealth,
                        decoration: InputDecoration(
                          labelText: 'Project Health',
                          prefixIcon: const Icon(Icons.health_and_safety),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'On Track', child: Text('On Track')),
                          DropdownMenuItem(value: 'At Risk', child: Text('At Risk')),
                          DropdownMenuItem(value: 'Delayed', child: Text('Delayed')),
                        ],
                        onChanged: (val) => setState(() => _selectedHealth = val!),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _budgetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Budget (\$)',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text('Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 16),

                      InkWell(
                        onTap: _pickStartDateTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_outline, color: Colors.teal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Start Date & Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      _formatDateTimeDisplay(_startDate, _startTime), 
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickEndDateTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('End Date & Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      _formatDateTimeDisplay(_endDate, _endTime), 
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Save Project'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
