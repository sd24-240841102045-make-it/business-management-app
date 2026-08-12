import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ClientDetailsPage extends StatelessWidget {
  final ClientModel client;

  const ClientDetailsPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('${client.name} Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PremiumAvatar(
                        label: client.name,
                        style: AvatarStyle.gradient,
                        size: 72,
                        radius: 36,
                      ),
                      const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text(client.company, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Chip(
                                label: Text(client.status),
                                backgroundColor: client.status == 'Active' ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                                labelStyle: TextStyle(color: client.status == 'Active' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 40),
                    _infoRow(Icons.email, 'Email Address', client.email),
                    _infoRow(Icons.phone, 'Phone Contact', client.phone),
                    _infoRow(Icons.work, 'Project Scope', client.projectType),
                    _infoRow(Icons.currency_rupee, 'Contract Budget', '₹${client.budget.toStringAsFixed(2)}'),
                    _infoRow(Icons.person, 'Account Manager Lead', client.assignedEmployeeName ?? 'Unassigned'),
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
          Icon(icon, color: Colors.indigo, size: 22),
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
