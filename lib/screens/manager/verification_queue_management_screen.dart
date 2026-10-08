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
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(d.title),
        content: SingleChildScrollView(child: Text('ID: ${d.id}\nSubmitted by: ${d.submittedById}\nType: ${d.verificationType}\nReference: ${d.referenceId ?? "—"}\nDescription: ${d.description ?? "—"}\nStatus: ${d.status}\nManager note: ${d.managerNote ?? "—"}\nReviewed by: ${d.reviewedById ?? "—"}\nReviewed at: ${d.reviewedAt?.toLocal() ?? "—"}\nCreated: ${d.createdAt.toLocal()}\nUpdated: ${d.updatedAt.toLocal()}')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
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
          for (final item in p.items) Card(child: Column(children: [ListTile(title: Text(item.title), subtitle: Text('${item.verificationType} • ${item.status}'), onTap: () => details(item)),
            Wrap(spacing: 8, children: [TextButton(onPressed: p.isSaving ? null : () => showDialog<bool>(context: context, builder: (_) => VerificationQueueFormDialog(item: item)), child: const Text('Review')),
              TextButton(onPressed: p.isSaving ? null : () => delete(item), child: const Text('Delete'))])]))
        ]))) ]));
  }
}
class VerificationQueueFormDialog extends StatefulWidget {
  final VerificationQueueModel item;
  const VerificationQueueFormDialog({super.key, required this.item});
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
    status = widget.item.status;
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
        Text(widget.item.title),
        for (final key in ['managerNote'])
          Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: fields[key], enabled: !saving, maxLength: 10000, decoration: InputDecoration(labelText: labels[key]))),
        DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: [for (final s in VerificationQueueModel.statuses) DropdownMenuItem(value: s, child: Text(s))], onChanged: saving ? null : (v) => setState(() => status = v!)),
        if (error != null) Text(error!),
      ])))), actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Save'))]));
  }
}
