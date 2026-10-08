import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/models/verification_queue_model.dart';
import 'package:lifelink/services/verification_queue_service.dart';
import 'package:lifelink/providers/verification_queue_provider.dart';
import 'package:lifelink/screens/manager/verification_queue_management_screen.dart';
class FakeQueue extends VerificationQueueService {
  String state = 'Pending';
  String? filter, note;
  int creates = 0, deletes = 0;
  bool fail = false;
  Completer<void>? pending;
  VerificationQueueModel get record => VerificationQueueModel(id: 'id', submittedById: 'user', verificationType: 'Donor', title: 'Donor verification', status: state, managerNote: note, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));
  @override
  Future<List<VerificationQueueModel>> getAll({String? status}) async { filter = status; return deletes > 0 || (status != null && status != state) ? [] : [record]; }
  @override
  Future<VerificationQueueModel?> getMyVerification() async => creates == 0 ? null : record;
  @override
  Future<VerificationQueueModel> getById(String id) async => record;
  @override
  Future<VerificationQueueModel> submitDonorVerification() async { creates++; if (pending != null) await pending!.future; if (fail) throw Exception('Create failed'); return record; }
  @override
  Future<VerificationQueueModel> review(String id, String status, String? note) async { state = status; this.note = note; return record; }
  @override
  Future<void> delete(String id) async { deletes++; }
}
Future<void> mount(WidgetTester tester, VerificationQueueProvider p, Widget child) => tester.pumpWidget(ChangeNotifierProvider.value(value: p, child: MaterialApp(home: child)));
void main() {
  test('donor submission and status use the existing provider', () async {
    final service = FakeQueue();
    final provider = VerificationQueueProvider(service: service)..setUser('donor');
    await provider.fetchMyVerificationStatus();
    expect(provider.hasLoadedMyVerification, true);
    expect(await provider.submitDonorVerification(), true);
    expect(provider.myVerification?.status, 'Pending');
    provider.setUser('another-donor');
    expect(provider.myVerification, isNull);
  });
  testWidgets('list, details, filters and delete confirmation', (tester) async {
    final s = FakeQueue(); final p = VerificationQueueProvider(service: s);
    await mount(tester, p, const VerificationQueueManagementScreen()); await tester.pumpAndSettle();
    expect(find.text('Add verification'), findsNothing);
    await tester.tap(find.text('Donor verification')); await tester.pumpAndSettle(); expect(find.textContaining('Submitted by: user'), findsOneWidget);
    await tester.tap(find.text('Close')); await tester.pumpAndSettle();
    await tester.tap(find.text('Approved')); await tester.pumpAndSettle(); expect(s.filter, 'Approved'); expect(find.text('No verifications found'), findsOneWidget);
    await tester.tap(find.text('All')); await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); await tester.pumpAndSettle(); await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(s.deletes, 0);
    await tester.tap(find.text('Delete')); await tester.pumpAndSettle(); await tester.tap(find.text('Delete').last); await tester.pumpAndSettle(); expect(s.deletes, 1);
  });
  test('reviews refresh list and retain notes; switching users clears data', () async {
    final s = FakeQueue(); final p = VerificationQueueProvider(service: s)..setUser('manager');
    for (final status in ['Approved', 'Rejected']) { expect(await p.review('id', status, 'Checked'), true); expect(p.items.single.status, status); expect(p.items.single.managerNote, 'Checked'); }
    p.setUser('other'); expect(p.items, isEmpty); expect(p.statusFilter, null);
  });
  test('double submit blocked and API failure surfaced', () async {
    final s = FakeQueue()..pending = Completer<void>()..fail = true;
    final p = VerificationQueueProvider(service: s); final first = p.submitDonorVerification();
    expect(await p.submitDonorVerification(), false); expect(s.creates, 1);
    s.pending!.complete(); expect(await first, false); expect(p.myVerificationError, 'Create failed'); expect(p.isSaving, false);
  });
}
