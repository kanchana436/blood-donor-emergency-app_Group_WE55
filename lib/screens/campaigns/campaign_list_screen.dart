import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/blood_campaign_model.dart';
import '../../providers/blood_campaign_provider.dart';
import 'campaign_details_screen.dart';
import 'campaign_form_dialog.dart';

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ['All', 'Upcoming', 'Ongoing', 'Completed'];
  final List<String> _cities = [
    'All Cities',
    'Colombo',
    'Kandy',
    'Galle',
    'Gampaha',
    'Kurunegala',
    'Jaffna',
    'Matara',
    'Negombo',
    'Anuradhapura',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BloodCampaignProvider>().fetchCampaigns();
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final selectedTab = _tabs[_tabController.index];
    final provider = context.read<BloodCampaignProvider>();
    if (selectedTab == 'All') {
      provider.setSelectedStatus(null);
    } else {
      provider.setSelectedStatus(selectedTab);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return AppColors.success;
      case 'upcoming':
        return AppColors.standard;
      case 'completed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.standard;
    }
  }

  Future<void> _pickFilterDate() async {
    final provider = context.read<BloodCampaignProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      provider.setSelectedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BloodCampaignProvider>();
    final canCreate = provider.canCreateCampaign;
    final campaigns = provider.filteredCampaigns;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blood Donation Campaigns'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => provider.fetchCampaigns(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.donorPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.donorPrimary,
          indicatorWeight: 3,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.donorPrimary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Create Campaign',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final created = await CampaignFormDialog.show(context);
                if (created == true) {
                  provider.fetchCampaigns();
                }
              },
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search campaign name, location or hospital...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (val) => provider.setSearchQuery(val),
                ),
                const SizedBox(height: 10),

                // Filter row (City dropdown + Date picker + Clear)
                Row(
                  children: [
                    // City Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: provider.selectedCity ?? 'All Cities',
                            items: _cities.map((city) {
                              return DropdownMenuItem(
                                value: city,
                                child: Text(city, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == 'All Cities') {
                                provider.setSelectedCity(null);
                              } else {
                                provider.setSelectedCity(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date filter chip
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickFilterDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: provider.selectedDate != null
                                ? AppColors.donorPrimaryLight.withValues(alpha: 0.3)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: provider.selectedDate != null
                                  ? AppColors.donorPrimary
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: provider.selectedDate != null
                                    ? AppColors.donorPrimary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  provider.selectedDate != null
                                      ? '${provider.selectedDate!.month}/${provider.selectedDate!.day}'
                                      : 'Filter Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: provider.selectedDate != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: provider.selectedDate != null
                                        ? AppColors.donorPrimaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (provider.selectedCity != null ||
                        provider.selectedDate != null ||
                        provider.searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.filter_alt_off_outlined, color: AppColors.error),
                        tooltip: 'Clear filters',
                        onPressed: () {
                          _searchController.clear();
                          provider.clearFilters();
                          _tabController.animateTo(0);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Campaign List Content
          Expanded(
            child: _buildBody(provider, campaigns),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BloodCampaignProvider provider, List<BloodCampaign> campaigns) {
    if (provider.isLoading && provider.campaigns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.campaigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => provider.fetchCampaigns(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (campaigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.donorPrimaryLight.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 54,
                  color: AppColors.donorPrimary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Blood Campaigns Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'There are no campaigns matching your current filter criteria.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (provider.selectedCity != null ||
                  provider.selectedDate != null ||
                  provider.searchQuery.isNotEmpty ||
                  provider.selectedStatus != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Reset All Filters'),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearFilters();
                    _tabController.animateTo(0);
                  },
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.donorPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Create Campaign',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final created = await CampaignFormDialog.show(context);
                  if (created == true) {
                    provider.fetchCampaigns();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchCampaigns(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: campaigns.length,
        itemBuilder: (context, index) {
          final campaign = campaigns[index];
          return _buildCampaignCard(context, campaign, provider);
        },
      ),
    );
  }

  Widget _buildCampaignCard(
    BuildContext context,
    BloodCampaign campaign,
    BloodCampaignProvider provider,
  ) {
    final statusColor = _getStatusColor(campaign.status);
    final dateStr =
        '${campaign.campaignDate.year}-${campaign.campaignDate.month.toString().padLeft(2, '0')}-${campaign.campaignDate.day.toString().padLeft(2, '0')}';
    final canManage = provider.canManageCampaign(campaign);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CampaignDetailsScreen(campaign: campaign),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge & Target Donors or Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          campaign.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (campaign.targetDonors != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Target: ${campaign.targetDonors} donors',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          await CampaignFormDialog.show(context, campaign: campaign);
                          provider.fetchCampaigns();
                        } else if (val == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            useRootNavigator: true,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Campaign?'),
                              content: Text('Archive and cancel "${campaign.campaignName}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteCampaign(campaign.id);
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit Campaign')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Cancel & Archive', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Campaign Name
              Text(
                campaign.campaignName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Date & Time
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.donorPrimary),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${campaign.startTime} - ${campaign.endTime}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Location & City
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${campaign.location}, ${campaign.city}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Organizer
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'By: ${campaign.organizerName}${campaign.hospitalOrBloodBank != null ? ' (${campaign.hospitalOrBloodBank})' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // View Details Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.donorPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    label: const Icon(Icons.arrow_forward, size: 16),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CampaignDetailsScreen(campaign: campaign),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
