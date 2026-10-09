import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/donor_availability_model.dart';
import '../../providers/donor_provider.dart';
import '../../providers/donor_availability_provider.dart';
import '../../widgets/empty_state_view.dart';

class DonorAvailabilityScreen extends StatefulWidget {
  const DonorAvailabilityScreen({super.key});

  @override
  State<DonorAvailabilityScreen> createState() => _DonorAvailabilityScreenState();
}

class _DonorAvailabilityScreenState extends State<DonorAvailabilityScreen> {
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DonorAvailabilityProvider>().load();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openForm([DonorAvailabilityModel? existing]) async {
    String? donorCity;
    try {
      donorCity = context.read<DonorProvider>().profile?.city;
    } catch (_) {}

    final saved = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => DonorAvailabilityFormDialog(
        existing: existing,
        defaultCity: donorCity,
      ),
    );

    if (mounted && saved == true) {
      _showSnackBar(
        existing == null
            ? 'Availability schedule created successfully'
            : 'Availability schedule updated successfully',
      );
    }
  }

  Future<void> _confirmDelete(DonorAvailabilityModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
            SizedBox(width: 10),
            Text('Delete Schedule?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove this ${record.status.toLowerCase()} schedule?',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period: ${_formatDate(record.availableFrom)} - ${record.availableUntil != null ? _formatDate(record.availableUntil!) : "Ongoing"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (record.city != null) ...[
                    const SizedBox(height: 4),
                    Text('Location: ${record.city}', style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This record will be deactivated from active donor search and preserved in your history audit log.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Schedule'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final provider = context.read<DonorAvailabilityProvider>();
    final success = await provider.delete(record.id);

    if (mounted) {
      if (success) {
        _showSnackBar('Availability schedule deleted successfully');
      } else {
        _showSnackBar(provider.errorMessage ?? 'Failed to delete schedule', isError: true);
      }
    }
  }

  String _formatDate(DateTime date) => _dateFormat.format(date);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DonorAvailabilityProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Donor Availability',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: provider.showHistory ? 'Hide History' : 'Show History',
            icon: Icon(
              provider.showHistory ? Icons.history_toggle_off : Icons.history_rounded,
              color: provider.showHistory ? AppColors.donorPrimary : AppColors.textSecondary,
            ),
            onPressed: provider.isLoading ? null : provider.toggleHistory,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: provider.isLoading || provider.isSaving ? null : provider.load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.donorPrimary,
        foregroundColor: Colors.white,
        onPressed: provider.isSaving ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Set Availability',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        color: AppColors.donorPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            // Top Status Overview Card
            _buildCurrentStatusHeroCard(provider),
            const SizedBox(height: 20),

            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: AppColors.donorPrimary),
              ),

            if (provider.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppColors.error),
                      onPressed: provider.load,
                    ),
                  ],
                ),
              ),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.showHistory ? 'All Schedules (Audit Log)' : 'Active Availability Schedules',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.records.length} ${provider.records.length == 1 ? "record" : "records"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!provider.isLoading && provider.records.isEmpty)
              EmptyStateView(
                icon: Icons.event_available_rounded,
                title: provider.showHistory ? 'No availability history' : 'No active schedules set',
                message: provider.showHistory
                    ? 'You have not recorded any availability schedules yet.'
                    : 'Set your availability schedule so local patients and hospitals know when you can donate.',
                buttonText: 'Set Availability Now',
                onButtonPressed: () => _openForm(),
              ),

            // Availability List Cards
            for (final record in provider.records) ...[
              _buildAvailabilityCard(record, provider),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusHeroCard(DonorAvailabilityProvider provider) {
    final isAvailableNow = provider.isCurrentlyAvailable;
    final currentRecord = provider.currentRecord;

    Color themeColor;
    String statusTitle;
    String statusSubtitle;
    IconData icon;

    if (isAvailableNow) {
      themeColor = AppColors.success;
      statusTitle = 'Currently Available';
      statusSubtitle = currentRecord != null
          ? 'Active until ${currentRecord.availableUntil != null ? _formatDate(currentRecord.availableUntil!) : "further notice"} (${currentRecord.city ?? "General"})'
          : 'You are visible to verified recipients and emergency alerts';
      icon = Icons.check_circle_rounded;
    } else if (currentRecord != null && currentRecord.status == 'Unavailable') {
      themeColor = AppColors.urgent;
      statusTitle = 'Temporarily Unavailable';
      statusSubtitle = 'Paused until ${currentRecord.availableUntil != null ? _formatDate(currentRecord.availableUntil!) : "schedule ends"}. You will not receive emergency alerts.';
      icon = Icons.pause_circle_filled_rounded;
    } else {
      themeColor = AppColors.textSecondary;
      statusTitle = 'No Active Schedule';
      statusSubtitle = 'Tap "Set Availability" to define when you can donate blood.';
      icon = Icons.schedule_rounded;
    }

    return InkWell(
      onTap: provider.isSaving ? null : () => _openForm(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: themeColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (currentRecord?.notes != null && currentRecord!.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: ${currentRecord.notes}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildAvailabilityCard(DonorAvailabilityModel record, DonorAvailabilityProvider provider) {
    final isAvailable = record.isAvailable;
    final isCurrent = record.isEffectiveNow;
    final isExpired = record.isExpired;
    final isFuture = record.isFuture;

    Color badgeColor;
    String badgeText;

    if (!record.isActive) {
      badgeColor = AppColors.textMuted;
      badgeText = 'Deleted / Inactive';
    } else if (isCurrent) {
      badgeColor = isAvailable ? AppColors.success : AppColors.urgent;
      badgeText = isAvailable ? 'Active Now' : 'Unavailable Now';
    } else if (isFuture) {
      badgeColor = AppColors.standard;
      badgeText = 'Upcoming';
    } else if (isExpired) {
      badgeColor = AppColors.textMuted;
      badgeText = 'Expired';
    } else {
      badgeColor = isAvailable ? AppColors.success : AppColors.urgent;
      badgeText = record.status;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? badgeColor.withOpacity(0.5) : AppColors.border,
          width: isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isAvailable ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isAvailable ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date Range
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatDate(record.availableFrom)}  ➔  ${record.availableUntil != null ? _formatDate(record.availableUntil!) : "Indefinite / Ongoing"}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Location
            if (record.city != null && record.city!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    record.city!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Notes
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.notes!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            const Divider(height: 20, color: AppColors.border),

            // Actions row (Edit & Delete)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (record.isActive) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: provider.isSaving ? null : () => _openForm(record),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: provider.isSaving ? null : () => _confirmDelete(record),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  const Text(
                    'Preserved for audit trail',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CREATE / EDIT AVAILABILITY FORM DIALOG
// =============================================================================
class DonorAvailabilityFormDialog extends StatefulWidget {
  final DonorAvailabilityModel? existing;
  final String? defaultCity;

  const DonorAvailabilityFormDialog({
    super.key,
    this.existing,
    this.defaultCity,
  });

  @override
  State<DonorAvailabilityFormDialog> createState() => _DonorAvailabilityFormDialogState();
}

class _DonorAvailabilityFormDialogState extends State<DonorAvailabilityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  late String _status;
  late DateTime _availableFrom;
  DateTime? _availableUntil;
  late bool _hasEndDate;
  late TextEditingController _cityController;
  late TextEditingController _notesController;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _status = item?.status ?? 'Available';
    _availableFrom = item?.availableFrom ?? DateTime.now();
    _availableUntil = item?.availableUntil;
    _hasEndDate = item?.availableUntil != null;
    _cityController = TextEditingController(text: item?.city ?? widget.defaultCity ?? 'Colombo');
    _notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _availableFrom = picked;
        // If end date is earlier than new from date, adjust end date
        if (_availableUntil != null && _availableUntil!.isBefore(_availableFrom)) {
          _availableUntil = _availableFrom.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _pickUntilDate() async {
    final initial = _availableUntil ?? _availableFrom.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_availableFrom) ? _availableFrom : initial,
      firstDate: _availableFrom,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _availableUntil = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_hasEndDate && _availableUntil != null && _availableUntil!.isBefore(_availableFrom)) {
      setState(() {
        _errorMessage = 'Available Until date cannot be earlier than Available From date';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final provider = context.read<DonorAvailabilityProvider>();
    bool success;

    if (widget.existing == null) {
      success = await provider.create(
        status: _status,
        availableFrom: _availableFrom,
        availableUntil: _hasEndDate ? _availableUntil : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
    } else {
      success = await provider.update(
        widget.existing!.id,
        status: _status,
        availableFrom: _availableFrom,
        availableUntil: _hasEndDate ? _availableUntil : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = provider.errorMessage ?? 'Failed to save availability schedule';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isEditing ? 'Edit Availability Schedule' : 'Set Availability Schedule',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error message banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                // Status Segmented Selector
                const Text(
                  'Availability Status',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _submitting
                            ? null
                            : () => setState(() => _status = 'Available'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _status == 'Available'
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _status == 'Available' ? AppColors.success : AppColors.border,
                              width: _status == 'Available' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: _status == 'Available' ? AppColors.success : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Available',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _status == 'Available' ? AppColors.success : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _submitting
                            ? null
                            : () => setState(() => _status = 'Unavailable'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _status == 'Unavailable'
                                ? AppColors.urgent.withOpacity(0.12)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _status == 'Unavailable' ? AppColors.urgent : AppColors.border,
                              width: _status == 'Unavailable' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pause_circle_filled_rounded,
                                size: 18,
                                color: _status == 'Unavailable' ? AppColors.urgent : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Unavailable',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _status == 'Unavailable' ? AppColors.urgent : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Available From Date Picker
                const Text(
                  'Available From *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _submitting ? null : _pickFromDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateFormat.format(_availableFrom),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Has End Date Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Specify an End Date',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _hasEndDate ? 'Schedule ends on selected date' : 'Ongoing indefinitely until changed',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _hasEndDate,
                  activeColor: AppColors.donorPrimary,
                  onChanged: _submitting
                      ? null
                      : (val) {
                          setState(() {
                            _hasEndDate = val;
                            if (val && _availableUntil == null) {
                              _availableUntil = _availableFrom.add(const Duration(days: 7));
                            }
                          });
                        },
                ),

                // Available Until Date Picker (if end date specified)
                if (_hasEndDate) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Available Until *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _submitting ? null : _pickUntilDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _availableUntil != null
                                ? _dateFormat.format(_availableUntil!)
                                : 'Select End Date',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const Icon(Icons.event_rounded, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // City / Location
                const Text(
                  'City / Location',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cityController,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    hintText: 'e.g. Colombo, Kandy',
                    prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes / Additional info
                const Text(
                  'Notes (Optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Available weekdays after 5:00 PM, or on call for emergency',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.donorPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isEditing ? 'Update Schedule' : 'Save Schedule',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
