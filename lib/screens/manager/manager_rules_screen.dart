import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'manager_main_navigation.dart';

class ManagerRulesScreen extends StatefulWidget {
  const ManagerRulesScreen({super.key});
  static const rules = [
    'Blood stock information must be accurate and updated responsibly.',
    'Managers may only manage blood stock assigned to their authorized Blood Bank / Hospital branch.',
    'Donor and recipient information must be treated as confidential.',
    'Personal information must not be copied, shared, exported, or disclosed without authorization.',
    'Donor Chat may only be used for legitimate blood donation, blood availability, verification, or hospital-related communication.',
    'Managers must never request passwords, OTP codes, banking details, or unnecessary sensitive information through chat.',
    'Managers must communicate respectfully and professionally.',
    'Verification requests must be reviewed responsibly before approval or rejection.',
    'Managers must not falsify or misuse blood stock information.',
    'Manager accounts and login credentials must not be shared.',
    'Chat access requires manager re-authentication and may only be used by the authorized account holder.',
    'Suspected misuse, unauthorized access, or incorrect information must be reported to the system administrator.',
    'Managers must follow organizational privacy, security, and blood-bank operating policies.',
  ];
  @override
  State<ManagerRulesScreen> createState() => _ManagerRulesScreenState();
}

class _ManagerRulesScreenState extends State<ManagerRulesScreen> {
  bool _accepted = false, _saving = false;
  String? _error;
  Future<void> _continue() async {
    if (!_accepted || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().acceptManagerRules();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ManagerMainNavigation()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Manager Rules & Regulations'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('LifeLink application / organizational rules'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ManagerRulesScreen.rules.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${i + 1}. ${ManagerRulesScreen.rules[i]}',
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            CheckboxListTile(
              value: _accepted,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _accepted = v ?? false),
              title: const Text(
                'I have read and accept all Rules & Regulations',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _accepted && !_saving ? _continue : null,
                  child: Text(_saving ? 'Saving…' : 'Accept & Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
