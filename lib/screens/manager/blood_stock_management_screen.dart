import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/blood_types.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/blood_stock_model.dart';
import '../../providers/blood_stock_provider.dart';
import '../../widgets/blood_group_badge.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';

class BloodStockManagementScreen extends StatefulWidget {
  const BloodStockManagementScreen({super.key});

  @override
  State<BloodStockManagementScreen> createState() =>
      _BloodStockManagementScreenState();
}

class _BloodStockManagementScreenState
    extends State<BloodStockManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BloodStockProvider>().load();
    });
  }

  Future<void> _edit([BloodStockModel? stock]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BloodStockFormDialog(stock: stock),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stock == null ? 'Blood stock added' : 'Blood stock updated',
        ),
      ),
    );
  }

  Future<void> _delete(BloodStockModel stock) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete blood stock?'),
        content: Text(
          'Remove ${stock.bloodGroup} stock at ${stock.location}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<BloodStockProvider>();
    final deleted = await provider.delete(stock.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Blood stock deleted'
              : provider.errorMessage ?? 'Unable to delete stock',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BloodStockProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Stock Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isSaving
                ? null
                : () => provider.load(bloodGroup: provider.bloodGroupFilter),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isSaving ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add stock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: provider.bloodGroupFilter ?? 'All',
              decoration: const InputDecoration(
                labelText: 'Filter by blood group',
              ),
              items: ['All', ...BloodTypes.all]
                  .map(
                    (group) =>
                        DropdownMenuItem(value: group, child: Text(group)),
                  )
                  .toList(),
              onChanged: provider.isSaving
                  ? null
                  : (value) => provider.load(
                      bloodGroup: value == 'All' ? null : value,
                    ),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null
                ? ErrorStateView(
                    message: provider.errorMessage!,
                    onRetry: () =>
                        provider.load(bloodGroup: provider.bloodGroupFilter),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        provider.load(bloodGroup: provider.bloodGroupFilter),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      children: provider.stocks.isEmpty
                          ? [
                              const EmptyStateView(
                                title: 'No blood stock',
                                message: 'Add a stock record or choose another blood group.',
                                icon: Icons.bloodtype_outlined,
                              ),
                            ]
                          : provider.stocks
                                .map(
                                  (stock) => Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              BloodGroupBadge(
                                                bloodGroup: stock.bloodGroup,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '${stock.availableUnits} units',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Edit stock',
                                                onPressed: provider.isSaving
                                                    ? null
                                                    : () => _edit(stock),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete stock',
                                                onPressed: provider.isSaving
                                                    ? null
                                                    : () => _delete(stock),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            stock.location,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text('Status: ${stock.status}'),
                                          Text(
                                            'Last updated: ${DateFormatter.format(stock.updatedAt.toLocal())}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class BloodStockFormDialog extends StatefulWidget {
  final BloodStockModel? stock;
  const BloodStockFormDialog({super.key, this.stock});

  @override
  State<BloodStockFormDialog> createState() => _BloodStockFormDialogState();
}

class _BloodStockFormDialogState extends State<BloodStockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _units;
  late final TextEditingController _location;
  String? _group;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _units = TextEditingController(
      text: widget.stock?.availableUnits.toString() ?? '',
    );
    _location = TextEditingController(text: widget.stock?.location ?? '');
    _group = widget.stock?.bloodGroup;
    _status = widget.stock?.status ?? 'Available';
  }

  @override
  void dispose() {
    _units.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<BloodStockProvider>();
    if (provider.isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final saved = await provider.save(
      id: widget.stock?.id,
      bloodGroup: _group!,
      availableUnits: int.parse(_units.text.trim()),
      location: _location.text.trim(),
      status: _status!,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(
        () => _error = provider.errorMessage ?? 'Unable to save blood stock',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<BloodStockProvider>().isSaving;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(
          widget.stock == null ? 'Add blood stock' : 'Edit blood stock',
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _group,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                    items: BloodTypes.all
                        .map(
                          (group) => DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          ),
                        )
                        .toList(),
                    onChanged: saving ? null : (value) => _group = value,
                    validator: (value) =>
                        value == null ? 'Blood group is required' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _units,
                    label: 'Available units',
                    readOnly: saving,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Units are required';
                      }
                      final units = int.tryParse(value.trim());
                      if (units == null) return 'Enter a whole number';
                      if (units < 0) return 'Units cannot be negative';
                      if (widget.stock == null && units == 0) {
                        return 'New stock must have at least 1 unit';
                      }
                      if (units > 2147483647) {
                        return 'Units cannot exceed 2147483647';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _location,
                    label: 'Location / blood bank',
                    readOnly: saving,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Location is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: BloodStockModel.statuses
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: saving ? null : (value) => _status = value,
                    validator: (value) =>
                        value == null ? 'Status is required' : null,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: widget.stock == null ? 'Add' : 'Save',
            width: 120,
            isLoading: saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
