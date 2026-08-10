import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

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
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _startDate = pickedDate;
          _startTime = pickedTime;
        });
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
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _endTime,
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _endDate = pickedDate;
          _endTime = pickedTime;
        });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client account.'), backgroundColor: Colors.redAccent),
      );
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
      
      if (_selectedTeamMemberIds.isNotEmpty) {
        await SupabaseService().assignProjectMembers(newProjectId, _selectedTeamMemberIds);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error inserting project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add project: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Add New Project', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 80.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: GlassCard(
                  padding: const EdgeInsets.all(28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Project Specifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 20),
                          
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Project Name *',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.folder_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Project name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.description_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedClientId,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Client Account *',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.business_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: _store.clients.fold<Map<String, DropdownMenuItem<String>>>({}, (map, c) {
                            map[c.id] = DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: kPremiumText)));
                            return map;
                          }).values.toList(),
                          onChanged: (val) => setState(() => _selectedClientId = val),
                          validator: (value) => value == null ? 'Client is required' : null,
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedManagerId,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Project Manager',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.person_outline, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Unassigned Manager', style: TextStyle(color: kPremiumMuted))),
                            ..._store.employees.where((e) => e.userId.isNotEmpty).fold<Map<String, DropdownMenuItem<String>>>({}, (map, e) {
                              map[e.userId] = DropdownMenuItem(value: e.userId, child: Text(e.name, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)));
                              return map;
                            }).values,
                          ],
                          onChanged: (val) => setState(() => _selectedManagerId = val),
                        ),
                        const SizedBox(height: 16),

                        const Text('Assigned Team Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kPremiumSurface.withOpacity(0.5),
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _store.employees.where((e) => e.userId.isNotEmpty).isEmpty
                              ? const Text('No assignable team members found.', style: TextStyle(color: kPremiumMuted))
                              : Wrap(
                                  spacing: 8.0,
                                  runSpacing: 6.0,
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
                                          label: Text(e.name, style: TextStyle(color: isSelected ? kPremiumBg : kPremiumText, fontWeight: FontWeight.bold)),
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
                                          selectedColor: kPremiumGold,
                                          backgroundColor: Colors.white.withOpacity(0.06),
                                          checkmarkColor: kPremiumBg,
                                          side: BorderSide(color: isSelected ? kPremiumGold : Colors.white10),
                                        );
                                      }).toList(),
                                ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedStatus,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.flag_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'In Progress', child: Text('In Progress', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'On Hold', child: Text('On Hold', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) => setState(() => _selectedStatus = val!),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedHealth,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Project Health',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.health_and_safety_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'On Track', child: Text('On Track', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'At Risk', child: Text('At Risk', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Delayed', child: Text('Delayed', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) => setState(() => _selectedHealth = val!),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _budgetCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Total Budget (\$)',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.attach_money, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text('Timeline & Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: _pickStartDateTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Date & Time', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTimeDisplay(_startDate, _startTime), 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: _pickEndDateTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('End Date & Deadline', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTimeDisplay(_endDate, _endTime), 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        GoldButton(
                          label: 'Save Project',
                          icon: Icons.check_circle_outline,
                          expand: true,
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _saveProject,
                        ),
                      ],
                    ),
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
