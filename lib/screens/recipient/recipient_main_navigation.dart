import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'recipient_home_screen.dart';
import 'nearby_donors_map_screen.dart';
import 'recipient_requests_history_screen.dart';
import '../profile/profile_screen.dart';

class RecipientMainNavigation extends StatefulWidget {
  final int initialIndex;

  const RecipientMainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<RecipientMainNavigation> createState() => _RecipientMainNavigationState();
}

class _RecipientMainNavigationState extends State<RecipientMainNavigation> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    RecipientHomeScreen(),
    NearbyDonorsMapScreen(),
    RecipientRequestsHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.recipientPrimary,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Donors Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history_rounded),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
