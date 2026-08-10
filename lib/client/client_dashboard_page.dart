import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clientName = SupabaseService().currentUser?.userMetadata?['full_name'] ?? 'Client Partner';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            HeroBanner(
              title: 'Welcome, $clientName',
              subtitle: 'Access your account manager, active projects, and live support chat',
              badge: 'Client Portal',
            ),
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const PremiumAvatar(
                    icon: Icons.business_center_rounded,
                    style: AvatarStyle.glowIcon,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Client Portal Services',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your ongoing enterprise projects, invoices, and direct support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kPremiumMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
