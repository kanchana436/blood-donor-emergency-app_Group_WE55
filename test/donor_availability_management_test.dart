import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lifelink/models/donor_availability_model.dart';
import 'package:lifelink/models/user_model.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/providers/donor_availability_provider.dart';
import 'package:lifelink/services/donor_availability_service.dart';
import 'package:lifelink/screens/donor/donor_availability_screen.dart';

// Test-only fake service for isolated Flutter unit and widget testing
class TestAvailabilityService extends DonorAvailabilityService {
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  bool shouldFail = false;
  String errorMessage = 'Failed operation';
  List<DonorAvailabilityModel> records = [];

  @override
  Future<DonorAvailabilityResponse> getMyAvailabilities({
    bool includeHistory = false,
  }) async {
    if (shouldFail) throw Exception(errorMessage);

    final active = records.where((r) => r.isActive).toList();
    final current = active.isNotEmpty ? active.first : null;

    return DonorAvailabilityResponse(
      currentStatus: current?.status ?? 'Not Scheduled',
      isCurrentlyAvailable: current?.isAvailable ?? false,
      currentRecord: current,
      records: includeHistory ? records : active,
    );
  }

  @override
  Future<DonorAvailabilityModel> create({
    required String status,
    required DateTime availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) async {
    createCalls++;
    if (shouldFail) throw Exception(errorMessage);
    final rec = DonorAvailabilityModel(
      id: 'test_avail_1',
      donorId: 'donor_user_id',
      status: status,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      city: city ?? 'Colombo',
      notes: notes,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    records.add(rec);
    return rec;
  }

  @override
  Future<DonorAvailabilityModel> update({
    required String id,
    String? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) async {
    updateCalls++;
    if (shouldFail) throw Exception(errorMessage);
    final index = records.indexWhere((r) => r.id == id);
    if (index >= 0) {
      final updated = records[index].copyWith(
        status: status,
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        city: city,
        notes: notes,
      );
      records[index] = updated;
      return updated;
    }
    throw Exception('Record not found');
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    if (shouldFail) throw Exception(errorMessage);
    final index = records.indexWhere((r) => r.id == id);
    if (index >= 0) {
      records[index] = records[index].copyWith(isActive: false);
    }
  }
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        id: 'donor_user_id',
        idNumber: '851234567V',
        name: 'Alexander Silva',
        email: 'alexander@lifelink.org',
        phone: '+94 77 123 4567',
        role: 'donor',
        isActive: true,
        isEmailVerified: true,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DonorAvailabilityModel tests', () {
    test('JSON serialization and helper getters work properly', () {
      final now = DateTime.now();
      final model = DonorAvailabilityModel(
        id: 'avail_101',
        donorId: 'user_101',
        status: 'Available',
        availableFrom: now.subtract(const Duration(hours: 1)),
        availableUntil: now.add(const Duration(days: 5)),
        city: 'Colombo',
        notes: 'Evenings preferred',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(model.isAvailable, true);
      expect(model.isEffectiveNow, true);
      expect(model.isExpired, false);
      expect(model.isFuture, false);

      final json = model.toJson();
      expect(json['status'], 'Available');
      expect(json['city'], 'Colombo');
      expect(json['notes'], 'Evenings preferred');

      final fromJson = DonorAvailabilityModel.fromJson(json);
      expect(fromJson.id, model.id);
      expect(fromJson.status, model.status);
    });

    test('Expired and future availability detection', () {
      final now = DateTime.now();
      final expired = DonorAvailabilityModel(
        id: 'exp_1',
        donorId: 'user_101',
        status: 'Available',
        availableFrom: now.subtract(const Duration(days: 10)),
        availableUntil: now.subtract(const Duration(days: 3)),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(expired.isExpired, true);
      expect(expired.isEffectiveNow, false);

      final future = DonorAvailabilityModel(
        id: 'fut_1',
        donorId: 'user_101',
        status: 'Available',
        availableFrom: now.add(const Duration(days: 3)),
        availableUntil: now.add(const Duration(days: 10)),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(future.isFuture, true);
      expect(future.isEffectiveNow, false);
    });
  });

  group('DonorAvailabilityProvider CRUD tests', () {
    late TestAvailabilityService service;
    late DonorAvailabilityProvider provider;

    setUp(() {
      service = TestAvailabilityService();
      provider = DonorAvailabilityProvider(service: service);
      provider.setUser('donor_user_id');
    });

    test('loads empty state and creates availability', () async {
      await provider.load();
      expect(provider.records.isEmpty, true);
      expect(provider.currentStatus, 'Not Scheduled');

      final success = await provider.create(
        status: 'Available',
        availableFrom: DateTime.now(),
        availableUntil: DateTime.now().add(const Duration(days: 7)),
        city: 'Colombo',
        notes: 'Available anytime',
      );

      expect(success, true);
      expect(service.createCalls, 1);
      expect(provider.records.length, 1);
      expect(provider.records.first.status, 'Available');
      expect(provider.isCurrentlyAvailable, true);
    });

    test('updates existing availability record', () async {
      await provider.create(
        status: 'Available',
        availableFrom: DateTime.now(),
        city: 'Kandy',
      );

      final recordId = provider.records.first.id;
      final updateSuccess = await provider.update(
        recordId,
        status: 'Unavailable',
        notes: 'Traveling abroad',
      );

      expect(updateSuccess, true);
      expect(service.updateCalls, 1);
      expect(provider.records.first.status, 'Unavailable');
      expect(provider.records.first.notes, 'Traveling abroad');
    });

    test('deletes availability record', () async {
      await provider.create(
        status: 'Available',
        availableFrom: DateTime.now(),
      );
      expect(provider.records.length, 1);

      final recordId = provider.records.first.id;
      final deleteSuccess = await provider.delete(recordId);

      expect(deleteSuccess, true);
      expect(service.deleteCalls, 1);
      expect(provider.records.length, 0); // Active list is empty after soft delete
    });
  });

  group('DonorAvailabilityScreen Widget tests', () {
    testWidgets('renders current status hero card and empty state', (tester) async {
      final service = TestAvailabilityService();
      final provider = DonorAvailabilityProvider(service: service);
      provider.setUser('donor_user_id');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
            ChangeNotifierProvider<DonorAvailabilityProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: DonorAvailabilityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Donor Availability'), findsOneWidget);
      expect(find.text('No Active Schedule'), findsOneWidget);
      expect(find.text('No active schedules set'), findsOneWidget);
      expect(find.text('Set Availability'), findsOneWidget);
    });

    testWidgets('renders schedule list card and shows delete confirmation dialog', (tester) async {
      final service = TestAvailabilityService();
      service.records.add(
        DonorAvailabilityModel(
          id: 'avail_test_card',
          donorId: 'donor_user_id',
          status: 'Available',
          availableFrom: DateTime.now().subtract(const Duration(hours: 1)),
          availableUntil: DateTime.now().add(const Duration(days: 5)),
          city: 'Galle',
          notes: 'Available for emergencies only',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final provider = DonorAvailabilityProvider(service: service);
      provider.setUser('donor_user_id');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
            ChangeNotifierProvider<DonorAvailabilityProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: DonorAvailabilityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card elements
      expect(find.text('Currently Available'), findsOneWidget);
      expect(find.text('Galle'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.text('Delete Schedule?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Schedule'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog closed and card still exists
      expect(find.text('Delete Schedule?'), findsNothing);
      expect(service.deleteCalls, 0);
    });

    testWidgets('opens form dialog with input fields when Set Availability tapped', (tester) async {
      final service = TestAvailabilityService();
      final provider = DonorAvailabilityProvider(service: service);
      provider.setUser('donor_user_id');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
            ChangeNotifierProvider<DonorAvailabilityProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: DonorAvailabilityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Set Availability FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Form dialog should be open
      expect(find.text('Set Availability Schedule'), findsOneWidget);
      expect(find.text('Availability Status'), findsOneWidget);
      expect(find.text('Available From *'), findsOneWidget);
      expect(find.text('Specify an End Date'), findsOneWidget);
      expect(find.text('City / Location'), findsOneWidget);
      expect(find.text('Notes (Optional)'), findsOneWidget);
      expect(find.text('Save Schedule'), findsOneWidget);
    });
  });
}
