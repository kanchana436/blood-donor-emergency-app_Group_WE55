import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../widgets/custom_button.dart';
import 'donor_main_navigation.dart';

class DonationConfirmationScreen extends StatefulWidget {
  final BloodRequestModel request;

  const DonationConfirmationScreen({
    super.key,
    required this.request,
  });

  @override
  State<DonationConfirmationScreen> createState() => _DonationConfirmationScreenState();
}

class _DonationConfirmationScreenState extends State<DonationConfirmationScreen> {
  bool _isCompleting = false;

  Future<void> _handleCompleteDonation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;

    setState(() {
      _isCompleting = true;
    });

    final success = await donorProvider.completeDonation(
      donorId: authProvider.currentUser!.id,
      requestId: widget.request.id,
      hospitalName: widget.request.hospitalName,
      patientName: widget.request.patientName,
      bloodGroup: widget.request.bloodGroup,
      units: widget.request.unitsRequired,
    );

    if (!mounted) return;

    setState(() {
      _isCompleting = false;
    });

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFA000), size: 28),
              SizedBox(width: 10),
              Text('Donation Logged!'),
            ],
          ),
          content: Text(
            'Your donation of ${widget.request.unitsRequired} unit(s) at ${widget.request.hospitalName} has been recorded in your history. You saved up to ${widget.request.unitsRequired * 3} lives!',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DonorMainNavigation(initialIndex: 2)),
                  (route) => false,
                );
              },
              child: const Text('View History', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DonorMainNavigation()),
              (route) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.donorPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: AppColors.donorPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thank you for stepping up!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You accepted the request for ${widget.request.patientName}. The requester and hospital medical staff have been notified.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Destination summary card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: AppColors.donorPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.request.hospitalName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                widget.request.hospitalAddress,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Contact Requester:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          widget.request.contactPhone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.donorPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Donor Checklist
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Quick Donation Checklist',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCheckItem('Bring a valid Photo ID / National Identity Card.'),
                    _buildCheckItem('Drink 500ml water and eat a light meal prior.'),
                    _buildCheckItem('Report to Blood Bank reception upon arrival.'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Mark Donation Completed',
                icon: Icons.check_circle_outline,
                isLoading: _isCompleting,
                onPressed: _handleCompleteDonation,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Back to Home',
                variant: ButtonVariant.outline,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DonorMainNavigation()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
