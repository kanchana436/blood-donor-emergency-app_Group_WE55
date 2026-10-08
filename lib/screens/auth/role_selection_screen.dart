import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'donor'; // 'donor' | 'recipient' | 'manager'

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.donorPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'WELCOME TO LIFELINK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.donorPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'How will you use LifeLink?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your primary role. You can switch between roles or link profiles anytime in Settings.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _buildRoleCard(
                      id: 'donor',
                      title: 'Blood Donor',
                      subtitle:
                          'I want to register my blood group, receive local emergency alerts, and save lives.',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.donorPrimary,
                      badge: 'DONATE & RESCUE',
                    ),
                    const SizedBox(height: 14),
                    _buildRoleCard(
                      id: 'recipient',
                      title: 'Recipient / Caregiver',
                      subtitle:
                          'I need to create urgent blood requests for surgery, trauma, or medical treatments.',
                      icon: Icons.volunteer_activism_rounded,
                      color: AppColors.recipientPrimary,
                      badge: 'REQUEST & TRACK',
                    ),
                    const SizedBox(height: 14),
                    _buildRoleCard(
                      id: 'manager',
                      title: 'Blood Bank / Hospital',
                      subtitle:
                          'Coordinate hospital inventory, verify donors, and dispatch urgent transfusions.',
                      icon: Icons.local_hospital_rounded,
                      color: AppColors.success,
                      badge: 'CLINICAL OVERVIEW',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Continue as ${_getRoleDisplayName(_selectedRole)}',
                customColor: _getRoleColor(_selectedRole),
                onPressed: () {
                  authProvider.setActiveRole(_selectedRole);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(role: _selectedRole),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'donor':
        return 'Donor';
      case 'recipient':
        return 'Recipient';
      case 'manager':
        return 'Coordinator';
      default:
        return 'User';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'donor':
        return AppColors.donorPrimary;
      case 'recipient':
        return AppColors.recipientPrimary;
      case 'manager':
        return AppColors.success;
      default:
        return AppColors.donorPrimary;
    }
  }

  Widget _buildRoleCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    final isSelected = _selectedRole == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = id;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? color : AppColors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
