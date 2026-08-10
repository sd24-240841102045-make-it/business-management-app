import 'package:flutter/material.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class EditClientPage extends StatefulWidget {
  final Map<String, dynamic> client;

  const EditClientPage({
    super.key,
    required this.client,
  });

  @override
  State<EditClientPage> createState() => _EditClientPageState();
}

class _EditClientPageState extends State<EditClientPage> {
  late TextEditingController nameController;
  late TextEditingController companyController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  String selectedStatus = 'Active';

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.client['name'],
    );

    companyController = TextEditingController(
      text: widget.client['company'],
    );

    emailController = TextEditingController(
      text: widget.client['email'],
    );

    phoneController = TextEditingController(
      text: widget.client['phone'],
    );

    selectedStatus = widget.client['status'] ?? 'Active';
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void saveClient() {
    if (nameController.text.trim().isEmpty ||
        companyController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    widget.client['name'] = nameController.text.trim();
    widget.client['company'] = companyController.text.trim();
    widget.client['email'] = emailController.text.trim();
    widget.client['phone'] = phoneController.text.trim();
    widget.client['status'] = selectedStatus;

    Navigator.pop(context, widget.client);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Edit Client Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: kPremiumGold,
            ),
          ),
          centerTitle: true,
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
              bottom: MediaQuery.of(context).padding.bottom + 50.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Center(
                        child: PremiumAvatar(
                          label: nameController.text.isNotEmpty ? nameController.text : 'C',
                          style: AvatarStyle.gradient,
                          size: 80,
                          radius: 40,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Client Account Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPremiumGold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Client Name
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Client Name',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.person_outline, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumSurface.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: kPremiumGold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Company Name
                      TextField(
                        controller: companyController,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.business_outlined, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumSurface.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: kPremiumGold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Email Address
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.email_outlined, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumSurface.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: kPremiumGold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Phone Number
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.phone_outlined, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumSurface.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: kPremiumGold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Account Status Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPremiumSurface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.toggle_on_outlined, color: kPremiumGold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  dropdownColor: kPremiumSurface,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Active',
                                      child: Text('Active Account', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Inactive',
                                      child: Text('Inactive Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedStatus = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Save Action Button
                      GoldButton(
                        label: 'Save Changes',
                        icon: Icons.save_outlined,
                        onPressed: saveClient,
                      ),

                      const SizedBox(height: 12),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPremiumMuted),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: kPremiumMuted, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
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
