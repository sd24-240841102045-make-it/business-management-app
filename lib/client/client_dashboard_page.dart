import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_center, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${SupabaseService().currentUser?.userMetadata?['full_name'] ?? 'Client'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Client Portal (Under Construction)', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
