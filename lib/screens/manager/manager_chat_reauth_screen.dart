import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import 'manager_donor_chat_screen.dart';

class ManagerChatReauthScreen extends StatefulWidget {
  const ManagerChatReauthScreen({super.key});
  @override
  State<ManagerChatReauthScreen> createState() =>
      _ManagerChatReauthScreenState();
}

class _ManagerChatReauthScreenState extends State<ManagerChatReauthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().clearAccess();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<ChatProvider>();
    final pending = p.verify(_email.text.trim(), _password.text);
    _password.clear();
    if (await pending && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ManagerDonorChatScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Verification')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Re-enter your own manager credentials to access donor chat for 15 minutes.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email Address'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 16),
            if (p.error != null)
              Text(p.error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: p.loading ? null : _verify,
              child: Text(p.loading ? 'Verifying…' : 'Verify & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
