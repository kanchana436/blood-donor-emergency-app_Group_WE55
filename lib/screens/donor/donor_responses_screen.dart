import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/donor_provider.dart';
import '../../widgets/blood_group_badge.dart';
import '../../widgets/empty_state_view.dart';

class DonorResponsesScreen extends StatefulWidget {
  const DonorResponsesScreen({super.key});

  @override
  State<DonorResponsesScreen> createState() => _DonorResponsesScreenState();
}

class _DonorResponsesScreenState extends State<DonorResponsesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final donorProvider = Provider.of<DonorProvider>(context);
    final allResponses = donorProvider.myResponses;

    final acceptedList = allResponses
        .where((r) => r.status.toLowerCase() == 'accepted')
        .toList();
    final declinedList = allResponses
        .where((r) => r.status.toLowerCase() == 'declined')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Commitments'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.donorPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.donorPrimary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Accepted (${acceptedList.length})'),
            Tab(text: 'Declined (${declinedList.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResponseList(acceptedList, true),
          _buildResponseList(declinedList, false),
        ],
      ),
    );
  }

  Widget _buildResponseList(List<dynamic> items, bool isAccepted) {
    if (items.isEmpty) {
      return EmptyStateView(
        icon: isAccepted ? Icons.volunteer_activism_outlined : Icons.remove_circle_outline,
        title: isAccepted ? 'No Accepted Requests' : 'No Declined Requests',
        message: isAccepted
            ? 'When you accept an emergency blood request, it will appear here for fast tracking.'
            : 'Requests you choose to decline will be saved here for your records.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final badgeColor = isAccepted ? AppColors.success : AppColors.textMuted;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              BloodGroupBadge(bloodGroup: item.donorBloodGroup),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Request #${item.requestId.replaceAll('req_', '')}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Responded: ${DateFormatter.format(item.respondedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.note != null && item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${item.note}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
