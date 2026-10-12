import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/blood_campaign_model.dart';
import '../../providers/blood_campaign_provider.dart';
import 'campaign_form_dialog.dart';

class CampaignDetailsScreen extends StatefulWidget {
  final BloodCampaign campaign;

  const CampaignDetailsScreen({
    super.key,
    required this.campaign,
  });

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {
  late BloodCampaign _campaign;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
  }

  Future<void> _refreshDetails() async {
    setState(() => _isRefreshing = true);
    final provider = context.read<BloodCampaignProvider>();
    final updated = await provider.getCampaignDetails(_campaign.id);
    if (mounted) {
      if (updated != null) {
        setState(() => _campaign = updated);
      }
      setState(() => _isRefreshing = false);
    }
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

  Future<void> _handleEdit() async {
    final result = await CampaignFormDialog.show(context, campaign: _campaign);
    if (result == true && mounted) {
      _refreshDetails();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text('Cancel & Archive Campaign?'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Text(
            'Are you sure you want to cancel and archive "${_campaign.campaignName}"?\n\nThis will mark the campaign as Cancelled and remove it from active listings while preserving historical attendance and donation audit records.',
            style: const TextStyle(height: 1.4, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Campaign'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<BloodCampaignProvider>();
      final success = await provider.deleteCampaign(_campaign.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Campaign cancelled and archived successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Failed to delete campaign'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BloodCampaignProvider>();
    final canManage = provider.canManageCampaign(_campaign);
    final statusColor = _getStatusColor(_campaign.status);

    final dateStr =
        '${_campaign.campaignDate.year}-${_campaign.campaignDate.month.toString().padLeft(2, '0')}-${_campaign.campaignDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Campaign Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDetails,
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              tooltip: 'Edit Campaign',
              onPressed: _handleEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Cancel & Archive Campaign',
              onPressed: _handleDelete,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Banner Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _campaign.status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_campaign.targetDonors != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.donorPrimaryLight.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group_outlined, size: 16, color: AppColors.donorPrimary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Target: ${_campaign.targetDonors} Donors',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.donorPrimaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _campaign.campaignName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_campaign.hospitalOrBloodBank != null &&
                            _campaign.hospitalOrBloodBank!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.local_hospital, size: 16, color: AppColors.donorPrimary),
                              const SizedBox(width: 6),
                              Text(
                                _campaign.hospitalOrBloodBank!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_campaign.description != null &&
                            _campaign.description!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _campaign.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date & Venue Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Schedule & Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Campaign Date',
                          value: dateStr,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.access_time_filled_outlined,
                          label: 'Campaign Hours',
                          value: '${_campaign.startTime} - ${_campaign.endTime}',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Venue Location',
                          value: _campaign.location,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.location_city_outlined,
                          label: 'City',
                          value: _campaign.city,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Organizer & Contact Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organizer & Contact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.person_pin_outlined,
                          label: 'Organizer',
                          value: _campaign.organizerName,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Contact Number',
                          value: _campaign.contactNumber,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            tooltip: 'Copy Phone',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _campaign.contactNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone number copied to clipboard')),
                              );
                            },
                          ),
                        ),
                        if (_campaign.email != null && _campaign.email!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email Address',
                            value: _campaign.email!,
                            trailing: IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              tooltip: 'Copy Email',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _campaign.email!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Email copied to clipboard')),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                if (canManage) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.donorPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit Campaign'),
                              onPressed: _handleEdit,
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel Campaign'),
                              onPressed: _handleDelete,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel Campaign'),
                              onPressed: _handleDelete,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.donorPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit Campaign'),
                              onPressed: _handleEdit,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.donorPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share Campaign Information'),
                    onPressed: () {
                      final info =
                          '🩸 ${_campaign.campaignName}\n📅 Date: $dateStr (${_campaign.startTime} - ${_campaign.endTime})\n📍 Location: ${_campaign.location}, ${_campaign.city}\n📞 Contact: ${_campaign.contactNumber}';
                      Clipboard.setData(ClipboardData(text: info));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Campaign details copied to share!')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.donorPrimary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
