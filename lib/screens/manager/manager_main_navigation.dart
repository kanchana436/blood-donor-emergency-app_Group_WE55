import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'blood_stock_management_screen.dart';

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
          const BloodStockManagementScreen(),
          if (_index == 1) const ProfileScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bloodtype_outlined),
            label: 'Blood Stock',
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
