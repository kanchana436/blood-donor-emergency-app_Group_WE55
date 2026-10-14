import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../chat/private_chat_screen.dart';
import 'manager_chat_reauth_screen.dart';

class ManagerDonorChatScreen extends StatefulWidget {
  const ManagerDonorChatScreen({super.key});
  @override
  State<ManagerDonorChatScreen> createState() => _ManagerDonorChatScreenState();
}

class _ManagerDonorChatScreenState extends State<ManagerDonorChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().loadDonors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Same-City Donors'),
        actions: [
          IconButton(
            onPressed: p.loading ? null : p.loadDonors,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (p.loading) const LinearProgressIndicator(),
          if (p.error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(p.error!)),
          if (p.needsVerification)
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ManagerChatReauthScreen(),
                ),
              ),
              child: const Text('Verify again'),
            ),
          if (!p.loading && p.donors.isEmpty && p.error == null)
            const Expanded(
              child: Center(
                child: Text('No active donors in your branch city.'),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: p.donors.length,
              itemBuilder: (_, i) {
                final d = p.donors[i];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(d.name),
                  subtitle: Text('${d.bloodGroup} • ${d.city}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: p.loading
                      ? null
                      : () async {
                          if (await p.open(donorId: d.userId) &&
                              context.mounted) {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivateChatScreen(),
                              ),
                            );
                            if (context.mounted) p.loadDonors();
                          }
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
