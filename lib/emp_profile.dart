import 'package:flutter/material.dart';


class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double horizontalPadding = isDesktop ? 40 : isTablet ? 30 : 20;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
          child: Column(
            children: [

            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF8E7CFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),

              child: Column(
                children: [

                  // Profile Picture
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 55,
                      color: Colors.deepPurple,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'John Doe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Business Administrator',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Edit Profile Button
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Business Information
            _sectionTitle('Business Information'),

            const SizedBox(height: 10),

            _infoTile(
              icon: Icons.business,
              title: 'Business Name',
              subtitle: 'Project Life Solutions',
            ),

            _infoTile(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'john@example.com',
            ),

            _infoTile(
              icon: Icons.phone,
              title: 'Phone',
              subtitle: '+91 98765 43210',
            ),

            _infoTile(
              icon: Icons.location_on,
              title: 'Business Location',
              subtitle: 'Gujarat, India',
            ),

            const SizedBox(height: 25),

            // Account Settings
            _sectionTitle('Account Settings'),

            const SizedBox(height: 10),

            _settingTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage your notifications',
              onTap: () {},
            ),

            _settingTile(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'Password and account security',
              onTap: () {},
            ),

            _settingTile(
              icon: Icons.business_center_outlined,
              title: 'Business Settings',
              subtitle: 'Manage business preferences',
              onTap: () {},
            ),

            _settingTile(
              icon: Icons.people_outline,
              title: 'Team Management',
              subtitle: 'Manage employees and permissions',
              onTap: () {},
            ),

            const SizedBox(height: 25),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 50,

              child: OutlinedButton.icon(
                onPressed: () {
                  // Logout logic
                },

                icon: const Icon(Icons.logout),

                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                    color: Colors.red,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

  // Section Title
  static Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Business Information Tile
  static Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [

          CircleAvatar(
            backgroundColor: Colors.deepPurple.withValues(
              alpha: 0.1,
            ),

            child: Icon(
              icon,
              color: Colors.deepPurple,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Settings Tile
  static Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),

      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(
            alpha: 0.1,
          ),

          child: Icon(
            icon,
            color: Colors.deepPurple,
          ),
        ),

        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(subtitle),

        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
      ),
    );
  }
}

