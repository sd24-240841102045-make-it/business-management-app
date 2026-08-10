import 'package:flutter/material.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
            backgroundColor: kPremiumBg,
            foregroundColor: kPremiumGold,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroBanner(
                      title: 'Executive Analytics',
                      subtitle: 'Generate operation summaries, revenue audits, and progress reports',
                      badge: 'Analytics Suite',
                    ),
                    const SizedBox(height: 20),
                    _reportCard(context, 'Monthly Revenue Summary', 'Detailed revenue, billing breakdown, and project profits', Icons.analytics),
                    _reportCard(context, 'Employee Attendance & Leave Report', 'Audit logs for punch times, sick leaves, and approvals', Icons.fact_check),
                    _reportCard(context, 'Client Account Audit', 'Contract statuses, budget usage, and account lead assignments', Icons.business),
                    _reportCard(context, 'Task & Project Milestone Progress', 'Kanban completion speed and overdue deliverables', Icons.assessment),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reportCard(BuildContext context, String title, String subtitle, IconData icon) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PremiumAvatar(
                      icon: icon,
                      style: AvatarStyle.glowIcon,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                const SizedBox(height: 14),
                GoldButton(
                  label: 'Export PDF Report',
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Generating PDF for $title...')),
                    );
                  },
                ),
              ],
            );
          }

          return Row(
            children: [
              PremiumAvatar(
                icon: icon,
                style: AvatarStyle.glowIcon,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GoldButton(
                label: 'Export PDF',
                icon: Icons.download_rounded,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Generating PDF for $title...')),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
