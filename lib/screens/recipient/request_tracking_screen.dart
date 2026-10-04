import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/blood_request_model.dart';
import '../../providers/request_provider.dart';
import '../../widgets/blood_group_badge.dart';
import '../../widgets/custom_button.dart';
import 'edit_blood_request_screen.dart';

class RequestTrackingScreen extends StatefulWidget {
  final BloodRequestModel request;

  const RequestTrackingScreen({
    super.key,
    required this.request,
  });

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false)
          .fetchMatchingDonors(widget.request.id);
    });
  }

  void _showCancelDialog() {
    final reqProvider = Provider.of<RequestProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Blood Request?'),
        content: const Text(
          'Are you sure you want to cancel this request? Notified donors will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await reqProvider.cancelRequest(widget.request.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request cancelled.')),
                  );
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  void _fulfillRequest() async {
    final reqProvider = Provider.of<RequestProvider>(context, listen: false);
    final success = await reqProvider.fulfillRequest(widget.request.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request marked as fulfilled! Thank you.'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqProvider = Provider.of<RequestProvider>(context);
    final matchingDonors = reqProvider.matchingDonors;
    final req = reqProvider.selectedRequest ?? widget.request;

    final isFulfilled = req.status.toLowerCase() == 'fulfilled';
    final isCancelled = req.status.toLowerCase() == 'cancelled';
    final hasAcceptedDonor = matchingDonors.any((d) => d.status.toLowerCase() == 'accepted');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Request Tracking'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isCancelled && !isFulfilled)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 22),
              tooltip: 'Edit Request',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditBloodRequestScreen(request: req),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  BloodGroupBadge(bloodGroup: req.bloodGroup, isLarge: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.recipientPrimary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                req.urgency.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.recipientPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFulfilled
                                    ? AppColors.success.withOpacity(0.1)
                                    : isCancelled
                                        ? AppColors.error.withOpacity(0.1)
                                        : AppColors.urgent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                req.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isFulfilled
                                      ? AppColors.success
                                      : isCancelled
                                          ? AppColors.error
                                          : AppColors.urgent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          req.patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${req.unitsRequired} Units • ${req.hospitalName}',
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
            ),
            const SizedBox(height: 16),

            // 4-Stage Live Timeline
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
                    'Progress Timeline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineStep(
                    title: 'Request Created',
                    subtitle: 'Broadcasted to nearby hospitals & donors',
                    time: DateFormatter.timeAgo(req.createdAt),
                    isDone: true,
                    isActive: false,
                  ),
                  _buildTimelineStep(
                    title: 'Donors Notified',
                    subtitle: '${matchingDonors.length} suitable donors matched by blood group & distance',
                    time: 'Instant',
                    isDone: true,
                    isActive: false,
                  ),
                  _buildTimelineStep(
                    title: 'Donor Accepted',
                    subtitle: hasAcceptedDonor
                        ? '1 donor confirmed attendance and is en route'
                        : 'Awaiting donor confirmations',
                    time: hasAcceptedDonor ? 'Active' : 'Pending',
                    isDone: hasAcceptedDonor,
                    isActive: !hasAcceptedDonor && !isCancelled && !isFulfilled,
                  ),
                  _buildTimelineStep(
                    title: 'Blood Transfusion Complete',
                    subtitle: 'Units received & validated at hospital blood bank',
                    time: isFulfilled ? 'Completed' : 'Upcoming',
                    isDone: isFulfilled,
                    isActive: hasAcceptedDonor && !isFulfilled && !isCancelled,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Matching Donors Engine Results
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Matching Donors Dispatched',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${matchingDonors.length} Candidates',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.recipientPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (matchingDonors.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Searching for available compatible donors in a 15km radius...',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchingDonors.length,
                itemBuilder: (context, index) {
                  final donor = matchingDonors[index];
                  final isAccepted = donor.status.toLowerCase() == 'accepted';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAccepted ? const Color(0xFFF1F8E9) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAccepted ? AppColors.success : AppColors.border,
                        width: isAccepted ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        BloodGroupBadge(bloodGroup: donor.donorBloodGroup),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    donor.donorName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAccepted
                                          ? AppColors.success.withOpacity(0.15)
                                          : AppColors.urgent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      donor.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isAccepted ? AppColors.success : AppColors.urgent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.near_me_outlined, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${donor.distanceKm.toStringAsFixed(1)} km away',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 10),
                                  if (donor.note != null)
                                    Expanded(
                                      child: Text(
                                        donor.note!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.success,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isAccepted)
                          IconButton(
                            icon: const Icon(Icons.phone_in_talk, color: AppColors.success),
                            tooltip: 'Call Donor',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dialing ${donor.donorName} (${donor.donorPhone})...'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Action Buttons
            if (!isFulfilled && !isCancelled) ...[
              CustomButton(
                text: 'Mark Request as Fulfilled',
                icon: Icons.check_circle_rounded,
                customColor: AppColors.success,
                onPressed: _fulfillRequest,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Cancel Blood Request',
                variant: ButtonVariant.outline,
                customColor: AppColors.error,
                onPressed: _showCancelDialog,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required String time,
    required bool isDone,
    required bool isActive,
    bool isLast = false,
  }) {
    final dotColor = isDone
        ? AppColors.success
        : isActive
            ? AppColors.urgent
            : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : isActive
                        ? const Icon(Icons.radio_button_checked, size: 14, color: Colors.white)
                        : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: isDone ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDone || isActive ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
