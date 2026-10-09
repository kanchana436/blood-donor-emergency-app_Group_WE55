import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/blood_group_badge.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/request_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../notifications/notifications_screen.dart';
import 'donor_request_details_screen.dart';

class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      await donorProvider.loadDonorData(authProvider.currentUser!.id);
      await requestProvider.loadAllRequests();
      await notificationProvider.loadNotifications(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final donorProvider = Provider.of<DonorProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final user = authProvider.currentUser;
    final profile = donorProvider.profile;
    final donorBloodGroup = profile?.bloodGroup ?? 'O+';

    // Filter requests
    final filteredRequests = donorProvider.compatibleRequests.where((r) {
      if (_selectedFilter == 'Emergency') {
        return r.urgency.toLowerCase() == 'emergency';
      } else if (_selectedFilter == 'Urgent') {
        return r.urgency.toLowerCase() == 'urgent';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.donorPrimary),
                  const SizedBox(width: 4),
                  Text(
                    profile?.city ?? 'Colombo',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 24),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              ),
              if (notificationProvider.unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.emergency,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${notificationProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.donorPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome greeting & blood group badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${user?.name.split(' ').first ?? 'Alexander'} 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ready to save lives today?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  BloodGroupBadge(bloodGroup: donorBloodGroup),
                ],
              ),
              const SizedBox(height: 16),

              // Availability Switch Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (profile?.isAvailable ?? true)
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.textMuted.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        (profile?.isAvailable ?? true)
                            ? Icons.check_circle_rounded
                            : Icons.do_not_disturb_on_rounded,
                        color: (profile?.isAvailable ?? true)
                            ? AppColors.success
                            : AppColors.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available to Donate',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (profile?.isAvailable ?? true)
                                ? 'Active • You will receive nearby alerts'
                                : 'Paused • You will not be contacted',
                            style: TextStyle(
                              fontSize: 12,
                              color: (profile?.isAvailable ?? true)
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: profile?.isAvailable ?? true,
                      activeColor: AppColors.success,
                      onChanged: (val) {
                        if (user != null) {
                          donorProvider.toggleAvailability(user.id, val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Dispatch Alert Banner
              if (requestProvider.activeEmergencies.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final emergency = requestProvider.activeEmergencies.first;
                    return InkWell(
                      onTap: () {
                        requestProvider.selectRequest(emergency);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DonorRequestDetailsScreen(request: emergency),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emergency.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.bolt, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'EMERGENCY ALERT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  '1.8 km away',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${emergency.unitsRequired} Units ${emergency.bloodGroup} urgently needed at ${emergency.hospitalName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  emergency.patientName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Respond Now',
                                    style: TextStyle(
                                      color: AppColors.donorPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],

              // Impact Metrics
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Donations Made',
                      value: '${donorProvider.totalDonations}',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.donorPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Lives Impacted',
                      value: '${donorProvider.livesImpacted}',
                      icon: Icons.favorite_rounded,
                      color: AppColors.success,
                      subtitle: 'Approx.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Compatible Requests Header + Quick Filters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Compatible Requests',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${filteredRequests.length} Available',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter Chips
              Row(
                children: ['All', 'Emergency', 'Urgent'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: AppColors.donorPrimary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Requests List / Loading / Empty / Error States
              if (donorProvider.isLoading) ...[
                const LoadingShimmer(count: 3),
              ] else if (donorProvider.errorMessage != null) ...[
                ErrorStateView(
                  message: donorProvider.errorMessage!,
                  onRetry: _loadData,
                ),
              ] else if (filteredRequests.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No Matching Requests Right Now',
                  message:
                      'All current blood requirements in your area have been fulfilled or matched. We will notify you immediately when a need arises.',
                  buttonText: 'Refresh',
                  onButtonPressed: _loadData,
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final req = filteredRequests[index];
                    return RequestCard(
                      request: req,
                      showActionButton: true,
                      actionButtonText: 'View Details',
                      onTap: () {
                        requestProvider.selectRequest(req);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DonorRequestDetailsScreen(request: req),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
