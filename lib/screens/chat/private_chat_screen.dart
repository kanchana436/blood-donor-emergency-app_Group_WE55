import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../manager/manager_chat_reauth_screen.dart';

// Also serves as the donor's conversation entry/list; managers are never browsable here.
class PrivateChatScreen extends StatefulWidget {
  final bool donorEntry;
  const PrivateChatScreen({super.key, this.donorEntry = false});
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _text = TextEditingController();
  bool _showConversations = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = context.read<ChatProvider>();
      if (widget.donorEntry) await p.open();
      if (mounted && p.current != null) p.refresh();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _text.text;
    if (await context.read<ChatProvider>().send(value) &&
        mounted &&
        _text.text == value) {
      _text.clear();
    }
  }

  Widget _bubble(ChatMessage m, String? userId) {
    final mine = m.senderId == userId;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine
                  ? 'You'
                  : widget.donorEntry
                  ? 'Manager'
                  : 'Donor',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(m.message),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, HH:mm').format(m.createdAt.toLocal()),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final id = context.watch<AuthProvider>().currentUser?.id;
    final chat = p.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.donorEntry
              ? 'Blood Bank Chat'
              : chat?.donorName ?? 'Private Chat',
        ),
        actions: [
          if (widget.donorEntry)
            IconButton(
              tooltip: 'Your conversations',
              icon: const Icon(Icons.forum_outlined),
              onPressed: p.loading
                  ? null
                  : () async {
                      await p.loadConversations();
                      if (mounted) setState(() => _showConversations = true);
                    },
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: p.loading
                ? null
                : () {
                    if (chat == null) {
                      p.open();
                    } else {
                      p.refresh();
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (p.loading) const LinearProgressIndicator(),
            if (chat != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${chat.branchName} • ${chat.city}'),
              ),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  p.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (p.needsVerification && !widget.donorEntry)
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const ManagerChatReauthScreen(),
                  ),
                ),
                child: const Text('Verify again'),
              ),
            if (_showConversations)
              Expanded(
                child: ListView(
                  children: [
                    if (p.conversations.isEmpty)
                      const ListTile(title: Text('No eligible conversations.')),
                    for (final c in p.conversations)
                      ListTile(
                        title: Text(c.branchName),
                        subtitle: Text(c.managerName),
                        onTap: () async {
                          if (await p.open(conversation: c) && mounted) {
                            setState(() => _showConversations = false);
                            p.refresh();
                          }
                        },
                      ),
                  ],
                ),
              )
            else ...[
              if (p.hasOlder)
                TextButton(
                  onPressed: p.loading ? null : () => p.refresh(older: true),
                  child: const Text('Load earlier messages'),
                ),
              Expanded(
                child: p.messages.isEmpty
                    ? Center(
                        child: Text(
                          chat == null
                              ? 'Open or refresh your Blood Bank Chat to begin.'
                              : 'No messages yet. Start the conversation.',
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: p.messages.length,
                        itemBuilder: (_, i) =>
                            _bubble(p.messages[p.messages.length - 1 - i], id),
                      ),
              ),
              if (chat != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send',
                        onPressed: p.sending || p.loading ? null : _send,
                        icon: const Icon(Icons.send),
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
}
