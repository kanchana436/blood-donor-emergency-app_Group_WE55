import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/models/blood_stock_model.dart';
import 'package:lifelink/providers/blood_stock_provider.dart';
import 'package:lifelink/services/blood_stock_service.dart';
import 'package:lifelink/screens/manager/blood_stock_management_screen.dart';

// Test-only service; the app service always calls the real authenticated API.
class TestStockService extends BloodStockService {
  int saves = 0;
  bool fail = false;
  Completer<void>? pending;
  final record = BloodStockModel(
    id: 'test-id',
    bloodGroup: 'O+',
    availableUnits: 2,
    location: 'Test bank',
    status: 'Available',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  @override
  Future<List<BloodStockModel>> getAll({String? bloodGroup}) async => [record];

  @override
  Future<BloodStockModel> save({
    String? id,
    required String bloodGroup,
    required int availableUnits,
    required String location,
    required String status,
  }) async {
    saves++;
    if (pending != null) await pending!.future;
    if (fail)
      throw Exception('Stock already exists for this blood group and location');
    return record;
  }
}

Future<void> openForm(
  WidgetTester tester,
  BloodStockProvider provider, {
  BloodStockModel? stock,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => BloodStockFormDialog(stock: stock),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create requires blood group, units and location', (
    tester,
  ) async {
    final service = TestStockService();
    await openForm(tester, BloodStockProvider(service: service));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Blood group is required'), findsOneWidget);
    expect(find.text('Units are required'), findsOneWidget);
    expect(find.text('Location is required'), findsOneWidget);
    expect(service.saves, 0);
  });

  testWidgets('units reject text, fractions, negatives and zero on create', (
    tester,
  ) async {
    final service = TestStockService();
    await openForm(tester, BloodStockProvider(service: service));
    for (final entry in {
      'abc': 'Enter a whole number',
      '1.5': 'Enter a whole number',
      '-1': 'Units cannot be negative',
      '0': 'New stock must have at least 1 unit',
    }.entries) {
      await tester.enterText(find.byType(TextFormField).first, entry.key);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
    expect(service.saves, 0);
  });

  testWidgets(
    'edit accepts zero, disables double submit and shows API errors',
    (tester) async {
      final service = TestStockService()
        ..fail = true
        ..pending = Completer<void>();
      final provider = BloodStockProvider(service: service);
      await openForm(tester, provider, stock: service.record);
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(provider.isSaving, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        await provider.save(
          id: 'test-id',
          bloodGroup: 'O+',
          availableUnits: 0,
          location: 'Test bank',
          status: 'Unavailable',
        ),
        false,
      );
      expect(service.saves, 1);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(provider.isSaving, false);
      expect(
        find.text('Stock already exists for this blood group and location'),
        findsOneWidget,
      );
      expect(find.text('Edit blood stock'), findsOneWidget);
    },
  );

  test('switching accounts clears stock state', () async {
    final provider = BloodStockProvider(service: TestStockService());
    provider.setUser('manager-1');
    await provider.load(bloodGroup: 'O+');
    expect(provider.stocks.length, 1);
    provider.setUser('manager-2');
    expect(provider.stocks, isEmpty);
    expect(provider.bloodGroupFilter, isNull);
  });
}
