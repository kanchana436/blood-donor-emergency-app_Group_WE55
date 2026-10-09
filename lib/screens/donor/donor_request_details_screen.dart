import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/blood_types.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../widgets/blood_group_badge.dart';
import '../../widgets/custom_button.dart';
import 'donation_confirmation_screen.dart';

class DonorRequestDetailsScreen extends StatefulWidget {
  final BloodRequestModel request;

  const DonorRequestDetailsScreen({
    super.key,
    required this.request,
  });

  @override
  State<DonorRequestDetailsScreen> createState() => _DonorRequestDetailsScreenState();
}

class _DonorRequestDetailsScreenState extends State<DonorRequestDetailsScreen> {
  bool _isResponding = false;

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return AppColors.emergency;
      case 'urgent':
        return AppColors.urgent;
      default:
        return AppColors.standard;
    }
  }

  Future<void> _handleResponse(String status) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;
    final user = authProvider.currentUser!;

    setState(() {
      _isResponding = true;
    });

    final success = await donorProvider.respondToRequest(
      requestId: widget.request.id,
      donorId: user.id,
      donorName: user.name,
      donorPhone: user.phone,
      status: status,
      note: status == 'Accepted' ? 'Donor accepted and is preparing to arrive.' : 'Donor unavailable.',
    );

    if (!mounted) return;

    setState(() {
      _isResponding = false;
    });

    if (success) {
      if (status == 'Accepted') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DonationConfirmationScreen(request: widget.request),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined. Thank you for letting us know.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(donorProvider.errorMessage ?? 'Failed to send response'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donorProvider = Provider.of<DonorProvider>(context);
    final donorBloodGroup = donorProvider.profile?.bloodGroup ?? 'O+';
    final urgencyColor = _getUrgencyColor(widget.request.urgency);

    final isCompatible = BloodTypes.isCompatible(
      donorGroup: donorBloodGroup,
      recipientGroup: widget.request.bloodGroup,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verified Request'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency & Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: urgencyColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 14, color: urgencyColor),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.request.urgency.toUpperCase()} PRIORITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: urgencyColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      BloodGroupBadge(
                        bloodGroup: widget.request.bloodGroup,
                        isLarge: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.patientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Requested by: ${widget.request.requesterName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Posted ${DateFormatter.timeAgo(widget.request.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  // Compatibility check explanation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCompatible
                          ? AppColors.success.withOpacity(0.08)
                          : AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompatible ? Icons.check_circle_rounded : Icons.info_outline,
                          size: 20,
                          color: isCompatible ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isCompatible
                                ? 'Compatibility Match: Your $donorBloodGroup blood type is 100% compatible with patient’s ${widget.request.bloodGroup} group.'
                                : 'Compatibility Notice: $donorBloodGroup may have restricted compatibility with ${widget.request.bloodGroup}.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isCompatible ? AppColors.success : AppColors.warning,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hospital Location Card with Map Preview
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hospital & Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.donorPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: AppColors.donorPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            const SizedBox(height: 2),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          '1.8 km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Styled Map Preview Box
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.donorPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.request.hospitalName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Additional Medical Notes
            if (widget.request.additionalNotes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Case Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.request.additionalNotes,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons (Accept / Decline)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: CustomButton(
                    text: 'Decline',
                    variant: ButtonVariant.outline,
                    isLoading: _isResponding,
                    onPressed: () => _handleResponse('Declined'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    text: 'Accept Request',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isResponding,
                    onPressed: () => _handleResponse('Accepted'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
