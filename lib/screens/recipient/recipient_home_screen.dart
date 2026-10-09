import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/request_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';
import '../notifications/notifications_screen.dart';
import 'create_blood_request_screen.dart';
import 'request_tracking_screen.dart';

class RecipientHomeScreen extends StatefulWidget {
  const RecipientHomeScreen({super.key});

  @override
  State<RecipientHomeScreen> createState() => _RecipientHomeScreenState();
}

class _RecipientHomeScreenState extends State<RecipientHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reqProvider = Provider.of<RequestProvider>(context, listen: false);
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (auth.currentUser != null) {
      await reqProvider.loadMyRequests(auth.currentUser!.id);
      await notifProvider.loadNotifications(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final user = authProvider.currentUser;
    final myRequests = requestProvider.myRequests;

    final activeCount = myRequests.where((r) => r.status.toLowerCase() != 'cancelled').length;
    final inProgressCount = myRequests.where((r) => r.status.toLowerCase() == 'inprogress').length;

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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.recipientPrimary),
                  SizedBox(width: 4),
                  Text(
                    'Colombo Region',
                    style: TextStyle(
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
        color: AppColors.recipientPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Hello, ${user?.name.split(' ').first ?? 'Sarah'} 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Coordinate emergency blood requests and live donor responses.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Hero Emergency Blood Request Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.recipientPrimary.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'NEED BLOOD URGENTLY?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Dispatch emergency blood alerts to compatible donors nearby.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateBloodRequestScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.recipientPrimary,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      label: const Text(
                        'Create Blood Request',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Recipient Stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'My Requests',
                      value: '$activeCount',
                      icon: Icons.assignment_outlined,
                      color: AppColors.recipientPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Donors Matched',
                      value: '$inProgressCount',
                      icon: Icons.people_alt_outlined,
                      color: AppColors.success,
                      subtitle: 'In Progress',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Requests Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Active Requests',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${myRequests.length} Total',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (requestProvider.isLoading) ...[
                const LoadingShimmer(count: 2),
              ] else if (requestProvider.errorMessage != null) ...[
                ErrorStateView(
                  message: requestProvider.errorMessage!,
                  onRetry: _loadData,
                ),
              ] else if (myRequests.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.bloodtype_outlined,
                  title: 'No Blood Requests Yet',
                  message:
                      'Tap "Create Blood Request" above to dispatch emergency notifications to suitable blood donors.',
                  buttonText: 'Create Blood Request',
                  onButtonPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateBloodRequestScreen(),
                      ),
                    );
                  },
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myRequests.length,
                  itemBuilder: (context, index) {
                    final req = myRequests[index];
                    return RequestCard(
                      request: req,
                      showActionButton: true,
                      actionButtonText: 'Track (${req.matchedDonorsCount} Donors)',
                      onActionPressed: () {
                        requestProvider.selectRequest(req);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestTrackingScreen(request: req),
                          ),
                        );
                      },
                      onTap: () {
                        requestProvider.selectRequest(req);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestTrackingScreen(request: req),
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
