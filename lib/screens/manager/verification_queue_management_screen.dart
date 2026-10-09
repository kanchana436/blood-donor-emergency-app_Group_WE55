import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/verification_queue_model.dart';
import '../../providers/verification_queue_provider.dart';
class VerificationQueueManagementScreen extends StatefulWidget {
  const VerificationQueueManagementScreen({super.key});
  @override
  State<VerificationQueueManagementScreen> createState() => _QueueState();
}
class _QueueState extends State<VerificationQueueManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<VerificationQueueProvider>().load(); });
  }
  Future<void> details(VerificationQueueModel item) async {
    try {
      final d = await context.read<VerificationQueueProvider>().getById(item.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(d.donorName ?? d.title),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Donor: ${d.donorName ?? d.submittedById}'),
            Text('NIC / ID: ${d.donorIdNumber ?? "Not provided"}'),
            Text('Phone: ${d.donorPhone ?? "Not provided"}'),
            Text('Email: ${d.donorEmail ?? "Not provided"}'),
            Text('Verification Type: ${d.typeLabel}'), Text('Status: ${d.status}'),
            Text('Submitted: ${d.createdAt.toLocal()}'),
            if (d.description != null) Text(d.description!),
            VerificationChangesView(item: d),
            Text('Manager Note: ${d.managerNote ?? "Not provided"}'),
            if (d.reviewedAt != null) Text('Reviewed: ${d.reviewedAt!.toLocal()}'),
          ],
        ))),
        actions: [
          if (d.status == 'Pending') ...[
            TextButton(onPressed: () { Navigator.pop(ctx); showDialog<bool>(context: context, builder: (_) => VerificationQueueFormDialog(item: d, initialStatus: 'Approved')); }, child: const Text('Approve')),
            TextButton(onPressed: () { Navigator.pop(ctx); showDialog<bool>(context: context, builder: (_) => VerificationQueueFormDialog(item: d, initialStatus: 'Rejected')); }, child: const Text('Reject')),
          ],
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  Future<void> delete(VerificationQueueModel item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete verification?'), content: Text('Delete "${item.title}"?'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (yes == true && mounted) await context.read<VerificationQueueProvider>().delete(item.id);
  }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerificationQueueProvider>();
    return Scaffold(appBar: AppBar(title: const Text('Verification Queue Management')),
      body: Column(children: [
        Wrap(spacing: 8, children: [for (final s in ['All', ...VerificationQueueModel.statuses]) ChoiceChip(label: Text(s), selected: (p.statusFilter ?? 'All') == s, onSelected: (_) => p.load(status: s == 'All' ? null : s))]),
        if (p.errorMessage != null) Padding(padding: const EdgeInsets.all(12), child: Text(p.errorMessage!)),
        if (p.isLoading) const LinearProgressIndicator(),
        Expanded(child: RefreshIndicator(onRefresh: () => p.load(status: p.statusFilter), child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 100), children: [
          if (p.items.isEmpty && !p.isLoading) const Padding(padding: EdgeInsets.all(24), child: Text('No verifications found')),
          for (final item in p.items) Card(child: Column(children: [ListTile(title: Text(item.donorName ?? item.title), subtitle: Text('${item.typeLabel}\nChanged fields: ${item.changedFields.isEmpty ? "None" : item.changedFields.map(VerificationQueueModel.fieldLabel).join(", ")}\nStatus: ${item.status}\nSubmitted: ${item.createdAt.toLocal()}'), onTap: () => details(item)),
            Wrap(spacing: 8, children: [TextButton(onPressed: p.isSaving ? null : () => showDialog<bool>(context: context, builder: (_) => VerificationQueueFormDialog(item: item)), child: const Text('Review')),
              TextButton(onPressed: p.isSaving ? null : () => delete(item), child: const Text('Delete'))])]))
        ]))) ]));
  }
}
class VerificationQueueFormDialog extends StatefulWidget {
  final VerificationQueueModel item;
  final String? initialStatus;
  const VerificationQueueFormDialog({super.key, required this.item, this.initialStatus});
  @override
  State<VerificationQueueFormDialog> createState() => _FormState();
}
class _FormState extends State<VerificationQueueFormDialog> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  String status = 'Pending';
  String? error;
  static const labels = {'managerNote': 'Manager note (optional)'};
  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) { fields[key] = TextEditingController(text: key == 'managerNote' ? widget.item.managerNote : null); }
    status = widget.initialStatus ?? widget.item.status;
  }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final p = context.read<VerificationQueueProvider>();
    final ok = await p.review(widget.item.id, status, fields['managerNote']!.text.trim().isEmpty ? null : fields['managerNote']!.text.trim());
    if (!mounted) return;
    if (ok) { Navigator.pop(context, true); } else { setState(() => error = p.errorMessage ?? 'Operation failed'); }
  }
  @override
  Widget build(BuildContext context) {
    final saving = context.watch<VerificationQueueProvider>().isSaving;
    return PopScope(canPop: !saving, child: AlertDialog(title: const Text('Review verification'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.item.donorName ?? widget.item.title),
        VerificationChangesView(item: widget.item),
        for (final key in ['managerNote'])
          Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: fields[key], enabled: !saving, maxLength: 10000, decoration: InputDecoration(labelText: labels[key]))),
        DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: [for (final s in (widget.item.status == 'Pending' ? VerificationQueueModel.statuses : [widget.item.status])) DropdownMenuItem(value: s, child: Text(s))], onChanged: saving ? null : (v) => setState(() => status = v!)),
        if (error != null) Text(error!),
      ])))), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Save'))]));
  }
}

class VerificationChangesView extends StatelessWidget {
  final VerificationQueueModel item;
  const VerificationChangesView({super.key, required this.item});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.changedFields.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Changed Details', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final field in item.changedFields) Card(child: Padding(
        padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(VerificationQueueModel.fieldLabel(field), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Old: ${VerificationQueueModel.displayValue(item.oldValues[field])}'),
          Text('New: ${VerificationQueueModel.displayValue(item.newValues[field])}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        ]),
      )),
    ],
  );
}
