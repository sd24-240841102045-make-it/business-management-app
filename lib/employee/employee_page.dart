import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/employee/employee_details_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  final AppDataStore _store = AppDataStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Employee Staff Directory', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: RefreshIndicator(
            color: kPremiumGold,
            onRefresh: () async {
              await _store.refreshFromSupabase();
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 80.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInSlide(
                        index: 0,
                        child: HeroBanner(
                          title: 'Staff Directory',
                          subtitle: '${_store.employees.length} Team Members Registered',
                          badge: 'Workforce',
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_store.employees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No employees found in directory.', style: TextStyle(color: kPremiumMuted, fontSize: 16)),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _store.employees.length,
                          itemBuilder: (context, index) {
                            final emp = _store.employees[index];
                            return FadeInSlide(
                              index: index + 1,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: PremiumAvatar(
                                      label: emp.name,
                                      style: AvatarStyle.gradient,
                                      size: 48,
                                    ),
                                    title: Text(
                                      emp.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 16),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${emp.role} • ${emp.department}',
                                        style: const TextStyle(color: kPremiumMuted, fontSize: 13),
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: kPremiumGold),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => EmployeeDetailsPage(employee: emp)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
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
