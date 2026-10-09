import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_queue_provider.dart';
import '../../providers/donor_provider.dart';
import '../../core/theme/app_colors.dart';
import 'donor_home_screen.dart';
import 'donor_responses_screen.dart';
import 'donation_history_screen.dart';
import '../profile/profile_screen.dart';

class DonorMainNavigation extends StatefulWidget {
  final int initialIndex;

  const DonorMainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<DonorMainNavigation> createState() => _DonorMainNavigationState();
}

class _DonorMainNavigationState extends State<DonorMainNavigation> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DonorHomeScreen(),
    DonorResponsesScreen(),
    DonationHistoryScreen(),
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
          if (index == 3 && context.read<AuthProvider>().currentUser?.role == 'donor') {
            context.read<VerificationQueueProvider>().fetchMyVerificationStatus();
            final auth = context.read<AuthProvider>();
            auth.refreshSavedProfile();
            context.read<DonorProvider>().loadDonorData(auth.currentUser!.id);
          }
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.donorPrimary,
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
            icon: Icon(Icons.handshake_outlined),
            activeIcon: Icon(Icons.handshake_rounded),
            label: 'Responses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history_rounded),
            label: 'History',
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
