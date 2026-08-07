import 'package:flutter/material.dart';
import '../services/app_data_store.dart';

class EmployeeDetailsPage extends StatelessWidget {
  final Employee employee;

  const EmployeeDetailsPage({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${employee.name} Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            employee.name.substring(0, 1),
                            style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(employee.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text('${employee.role} • ${employee.department}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Chip(
                                label: Text(employee.status),
                                backgroundColor: employee.status == 'Active' ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                                labelStyle: TextStyle(color: employee.status == 'Active' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 40),
                    _infoRow(Icons.email, 'Corporate Email', employee.email),
                    _infoRow(Icons.phone, 'Mobile Contact', employee.phone),
                    _infoRow(Icons.business_center, 'Department Unit', employee.department),
                    _infoRow(Icons.calendar_month, 'Joining Date', employee.joiningDate),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
