import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ClientDetailsPage extends StatelessWidget {
  final ClientModel client;

  const ClientDetailsPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final clientDisplayName = client.name.isNotEmpty ? client.name : 'Client Details';

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(clientDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
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
                            label: client.name.isNotEmpty ? client.name : 'Client',
                            style: AvatarStyle.gradient,
                            size: 72,
                            radius: 36,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.name.isNotEmpty ? client.name : 'Client Organization',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumGold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  client.company.isNotEmpty ? client.company : 'Commercial Partner',
                                  style: const TextStyle(fontSize: 16, color: kPremiumMuted),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (client.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (client.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    client.status,
                                    style: TextStyle(
                                      color: client.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: 16),
                      _infoRow(Icons.email_outlined, 'Email Address', client.email.isNotEmpty ? client.email : 'Not specified'),
                      _infoRow(Icons.phone_outlined, 'Phone Contact', client.phone.isNotEmpty ? client.phone : 'Not specified'),
                      _infoRow(Icons.work_outline, 'Project Scope', client.projectType),
                      _infoRow(Icons.currency_rupee, 'Contract Budget', '₹${client.budget.toStringAsFixed(2)}'),
                      _infoRow(Icons.person_outline, 'Account Manager Lead', client.assignedEmployeeName ?? 'Unassigned'),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          PremiumAvatar(
            icon: icon,
            style: AvatarStyle.glowIcon,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kPremiumText),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
