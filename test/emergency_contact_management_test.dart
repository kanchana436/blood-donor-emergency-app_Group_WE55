import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/models/emergency_contact_model.dart';
import 'package:lifelink/providers/emergency_contact_provider.dart';
import 'package:lifelink/services/emergency_contact_service.dart';
import 'package:lifelink/screens/profile/emergency_contact_management_screen.dart';

// Test-only transport; production always uses the authenticated REST API.
class TestContactService extends EmergencyContactService {
  int saves = 0, deletes = 0;
  Map<String, dynamic>? saved;
  Completer<void>? pending;
  bool fail = false;
  List<EmergencyContactModel> records = [];
  final record = EmergencyContactModel(
    id: 'contact',
    userId: 'user',
    fullName: 'Test Contact',
    relationship: 'Sibling',
    phone: '94771234567',
    isPrimary: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  @override
  Future<List<EmergencyContactModel>> getAll() async => records;
  @override
  Future<EmergencyContactModel> save({
    String? id,
    required Map<String, dynamic> fields,
  }) async {
    saves++;
    saved = fields;
    if (pending != null) await pending!.future;
    if (fail) throw Exception('Duplicate phone');
    return record;
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    records = [];
  }
}

Future<void> form(
  WidgetTester tester,
  EmergencyContactProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(body: EmergencyContactFormDialog()),
      ),
    ),
  );
}

Future<void> fill(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), ' Test Contact ');
  await tester.enterText(fields.at(1), ' Sibling ');
  await tester.enterText(fields.at(2), '077 1234567');
}

void main() {
  test('phone formats share one canonical value', () {
    for (final value in [
      '0771234567',
      '+94 (77) 123-4567',
      '0094 77 1234567',
      '94771234567',
    ]) {
      expect(EmergencyContactService.normalizePhone(value), '94771234567');
    }
  });
  testWidgets('required and phone validation block submission', (tester) async {
    final service = TestContactService();
    await form(
      tester,
      EmergencyContactProvider(service: service)..setUser('user'),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Full Name is required'), findsOneWidget);
    expect(find.text('Relationship is required'), findsOneWidget);
    expect(find.text('Phone is required'), findsOneWidget);
    await fill(tester);
    await tester.enterText(find.byType(TextFormField).at(3), 'bad');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(service.saves, 0);
    expect(
      find.text('Phone number must contain only numbers and valid formatting'),
      findsOneWidget,
    );
  });
  testWidgets(
    'save trims fields, blocks repeat submission and displays server errors',
    (tester) async {
      final service = TestContactService()
        ..pending = Completer<void>()
        ..fail = true;
      await form(
        tester,
        EmergencyContactProvider(service: service)..setUser('user'),
      );
      await fill(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Saving…'));
      await tester.pump();
      expect(service.saves, 1);
      expect(service.saved!['fullName'], 'Test Contact');
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Duplicate phone'), findsOneWidget);
    },
  );
  test(
    'account changes discard pending results and block repeated writes',
    () async {
      final service = TestContactService()..pending = Completer<void>();
      final provider = EmergencyContactProvider(service: service)
        ..setUser('user');
      final write = provider.save(fields: {'isPrimary': true});
      expect(await provider.save(fields: {'isPrimary': false}), false);
      provider.setUser('other');
      service.pending!.complete();
      expect(await write, false);
      expect(provider.contacts, isEmpty);
      expect(provider.isSaving, false);
      provider.dispose();
    },
  );
  testWidgets('empty state and deletion require confirmation', (tester) async {
    final service = TestContactService();
    service.records = [service.record];
    final provider = EmergencyContactProvider(service: service)
      ..setUser('user');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: EmergencyContactManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Contact'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deletes, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.deletes, 1);
    expect(find.text('No emergency contacts'), findsOneWidget);
  });
}
