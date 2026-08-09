import 'package:flutter/material.dart';

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
          content: Text('Please fill all fields'),
        ),
      );

      return;
    }

    // Update the client data
    widget.client['name'] = nameController.text.trim();
    widget.client['company'] =
        companyController.text.trim();
    widget.client['email'] =
        emailController.text.trim();
    widget.client['phone'] =
        phoneController.text.trim();
    widget.client['status'] = selectedStatus;

    // Return updated client
    Navigator.pop(context, widget.client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text(
          'Edit Client',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,

        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Profile Icon
            Center(
              child: CircleAvatar(
                radius: 45,

                backgroundColor:
                    Colors.deepPurple.withValues(
                  alpha: 0.1,
                ),

                child: Text(
                  nameController.text.isNotEmpty
                      ? nameController.text[0]
                          .toUpperCase()
                      : '?',

                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Client Information',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            // Client Name
            TextField(
              controller: nameController,

              decoration: InputDecoration(
                labelText: 'Client Name',
                prefixIcon: const Icon(
                  Icons.person,
                ),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Company
            TextField(
              controller: companyController,

              decoration: InputDecoration(
                labelText: 'Company Name',
                prefixIcon: const Icon(
                  Icons.business,
                ),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Email
            TextField(
              controller: emailController,

              keyboardType:
                  TextInputType.emailAddress,

              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(
                  Icons.email,
                ),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Phone
            TextField(
              controller: phoneController,

              keyboardType:
                  TextInputType.phone,

              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(
                  Icons.phone,
                ),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(15),
              ),

              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStatus,

                  isExpanded: true,

                  icon: const Icon(
                    Icons.arrow_drop_down,
                  ),

                  items: const [
                    DropdownMenuItem(
                      value: 'Active',
                      child: Text('Active'),
                    ),

                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
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

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,

              child: ElevatedButton.icon(
                onPressed: saveClient,

                icon: const Icon(
                  Icons.save,
                ),

                label: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.deepPurple,

                  foregroundColor:
                      Colors.white,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Cancel
            SizedBox(
              width: double.infinity,
              height: 52,

              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },

                child: const Text(
                  'Cancel',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
