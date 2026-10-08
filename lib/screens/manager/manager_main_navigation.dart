import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'blood_stock_management_screen.dart';
import 'verification_queue_management_screen.dart';

class ManagerMainNavigation extends StatefulWidget {
  const ManagerMainNavigation({super.key});

  @override
  State<ManagerMainNavigation> createState() => _ManagerMainNavigationState();
}

class _ManagerMainNavigationState extends State<ManagerMainNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role;
    if (role != 'manager' && role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Manager or admin access required')),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Manager Dashboard')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Blood Bank / Hospital',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.bloodtype_outlined,
                      color: AppColors.success,
                    ),
                    title: const Text('Blood Stock Management'),
                    subtitle: const Text(
                      'Manage blood groups, available units and stock status',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BloodStockManagementScreen(),
                      ),
                    ),
                  ),
                ),
                Card(child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Verification Queue Management'),
                  subtitle: const Text('Review, approve and reject verifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VerificationQueueManagementScreen(),
                  )),
                )),
              ],
            ),
          ),
          if (_index == 1) const ProfileScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
