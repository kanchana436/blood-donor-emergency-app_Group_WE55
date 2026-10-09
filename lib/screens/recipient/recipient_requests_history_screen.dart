import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/request_card.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/loading_shimmer.dart';
import 'request_tracking_screen.dart';

class RecipientRequestsHistoryScreen extends StatefulWidget {
  const RecipientRequestsHistoryScreen({super.key});

  @override
  State<RecipientRequestsHistoryScreen> createState() => _RecipientRequestsHistoryScreenState();
}

class _RecipientRequestsHistoryScreenState extends State<RecipientRequestsHistoryScreen> {
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final reqProvider = Provider.of<RequestProvider>(context);

    final requests = reqProvider.myRequests.where((r) {
      if (_selectedStatus == 'All') return true;
      return r.status.toLowerCase() == _selectedStatus.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Request History'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.currentUser != null) {
            await reqProvider.loadMyRequests(auth.currentUser!.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter chips
              Row(
                children: ['All', 'Open', 'InProgress', 'Fulfilled', 'Cancelled'].map((status) {
                  final isSel = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSel,
                      selectedColor: AppColors.recipientPrimary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              if (reqProvider.isLoading)
                const LoadingShimmer(count: 3)
              else if (requests.isEmpty)
                EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'No Requests Found',
                  message: 'No blood requests match the selected "$_selectedStatus" filter.',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return RequestCard(
                      request: req,
                      showActionButton: true,
                      actionButtonText: 'Track Progress',
                      onActionPressed: () {
                        reqProvider.selectRequest(req);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestTrackingScreen(request: req),
                          ),
                        );
                      },
                      onTap: () {
                        reqProvider.selectRequest(req);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestTrackingScreen(request: req),
                          ),
                        );
                      },
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
}
