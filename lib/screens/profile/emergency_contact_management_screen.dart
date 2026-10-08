import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/emergency_contact_provider.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_state_view.dart';

class EmergencyContactManagementScreen extends StatefulWidget {
  const EmergencyContactManagementScreen({super.key});
  @override
  State<EmergencyContactManagementScreen> createState() =>
      _EmergencyContactManagementScreenState();
}

class _EmergencyContactManagementScreenState
    extends State<EmergencyContactManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EmergencyContactProvider>().load();
    });
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  Future<void> _form([EmergencyContactModel? contact]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EmergencyContactFormDialog(contact: contact),
    );
    if (mounted && saved == true) {
      _message(
        contact == null
            ? 'Emergency contact added'
            : 'Emergency contact updated',
      );
    }
  }

  Future<void> _delete(EmergencyContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Emergency Contact?'),
        content: Text('Delete ${contact.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<EmergencyContactProvider>();
    final success = await provider.delete(contact.id);
    if (mounted) {
      _message(
        success
            ? 'Emergency contact deleted'
            : provider.errorMessage ?? 'Unable to delete contact',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergencyContactProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isLoading || provider.isSaving
                ? null
                : provider.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isSaving ? null : () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.errorMessage != null)
              ErrorStateView(
                message: provider.errorMessage!,
                onRetry: provider.load,
              ),
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                provider.contacts.isEmpty)
              const EmptyStateView(
                icon: Icons.contact_emergency_outlined,
                title: 'No emergency contacts',
                message: 'Add someone we can contact in an emergency.',
              ),
            for (final contact in provider.contacts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(contact.relationship),
                      Text(contact.phone),
                      if (contact.alternatePhone != null)
                        Text('Alternate: ${contact.alternatePhone}'),
                      if (contact.address != null) Text(contact.address!),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Primary Contact'),
                        value: contact.isPrimary,
                        onChanged: provider.isSaving
                            ? null
                            : (value) async {
                                final success = await provider.setPrimary(
                                  contact,
                                  value,
                                );
                                if (mounted) {
                                  _message(
                                    success
                                        ? 'Primary contact updated'
                                        : provider.errorMessage ?? 'Unable to update primary contact',
                                  );
                                }
                              },
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _form(contact),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _delete(contact),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmergencyContactFormDialog extends StatefulWidget {
  const EmergencyContactFormDialog({super.key, this.contact});
  final EmergencyContactModel? contact;
  @override
  State<EmergencyContactFormDialog> createState() =>
      _EmergencyContactFormDialogState();
}

class _EmergencyContactFormDialogState
    extends State<EmergencyContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late bool _primary;
  bool _submitting = false;
  String? _error;
  static const _labels = [
    'Full Name',
    'Relationship',
    'Phone',
    'Alternate Phone',
    'Address',
  ];
  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _controllers = [
      contact?.fullName,
      contact?.relationship,
      contact?.phone,
      contact?.alternatePhone,
      contact?.address,
    ].map((value) => TextEditingController(text: value ?? '')).toList();
    _primary = contact?.isPrimary ?? false;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final provider = context.read<EmergencyContactProvider>();
    final success = await provider.save(
      id: widget.contact?.id,
      fields: {
        'fullName': _controllers[0].text.trim(),
        'relationship': _controllers[1].text.trim(),
        'phone': _controllers[2].text.trim(),
        'alternatePhone': _controllers[3].text.trim(),
        'address': _controllers[4].text.trim(),
        'isPrimary': _primary,
      },
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = provider.errorMessage ?? 'Unable to save contact';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: Text(
        widget.contact == null
            ? 'Add Emergency Contact'
            : 'Edit Emergency Contact',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _controllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _controllers[i],
                      enabled: !_submitting,
                      decoration: InputDecoration(labelText: _labels[i]),
                      keyboardType: i == 2 || i == 3
                          ? TextInputType.phone
                          : TextInputType.text,
                      maxLines: i == 4 ? 2 : 1,
                      maxLength: i == 4 ? 1000 : 200,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (i < 3 && text.isEmpty) {
                          return '${_labels[i]} is required';
                        }
                        if ((i == 2 || i == 3) && text.isNotEmpty) {
                          return FormValidators.validatePhone(text);
                        }
                        return null;
                      },
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Primary Contact'),
                  value: _primary,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _primary = value),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _save,
          child: Text(_submitting ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
