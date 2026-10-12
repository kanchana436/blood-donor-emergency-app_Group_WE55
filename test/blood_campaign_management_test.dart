import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lifelink/models/blood_campaign_model.dart';
import 'package:lifelink/models/user_model.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/providers/blood_campaign_provider.dart';
import 'package:lifelink/screens/campaigns/campaign_details_screen.dart';
import 'package:lifelink/screens/campaigns/campaign_form_dialog.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel? _user;
  FakeAuthProvider([this._user]);

  @override
  UserModel? get currentUser => _user ?? UserModel(
        id: 'usr_mgr_1',
        idNumber: '901234567V',
        name: 'Manager Silva',
        email: 'manager@lifelink.org',
        phone: '+94771234567',
        role: 'manager',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BloodCampaign Model Tests', () {
    test('fromJson and toJson serializes and deserializes correctly', () {
      final json = {
        'id': 'camp_001',
        'campaignName': 'National Blood Drive',
        'description': 'Annual lifesaving campaign',
        'organizerId': 'usr_mgr_1',
        'organizerName': 'Dr. Silva',
        'contactNumber': '+94771234567',
        'email': 'silva@bloodbank.org',
        'hospitalOrBloodBank': 'National Blood Transfusion Service',
        'location': 'BMICH Hall A',
        'city': 'Colombo',
        'campaignDate': '2026-11-20T00:00:00.000Z',
        'startTime': '09:00 AM',
        'endTime': '04:00 PM',
        'targetDonors': 200,
        'status': 'Upcoming',
        'isActive': true,
      };

      final campaign = BloodCampaign.fromJson(json);

      expect(campaign.id, 'camp_001');
      expect(campaign.campaignName, 'National Blood Drive');
      expect(campaign.organizerName, 'Dr. Silva');
      expect(campaign.contactNumber, '+94771234567');
      expect(campaign.targetDonors, 200);
      expect(campaign.isUpcoming, isTrue);
      expect(campaign.isOngoing, isFalse);
      expect(campaign.isCompleted, isFalse);
      expect(campaign.isCancelled, isFalse);

      final serialized = campaign.toJson();
      expect(serialized['campaignName'], 'National Blood Drive');
      expect(serialized['city'], 'Colombo');
      expect(serialized['targetDonors'], 200);
      expect(serialized['status'], 'Upcoming');
    });

    test('copyWith updates fields correctly', () {
      final original = BloodCampaign(
        id: 'camp_001',
        campaignName: 'Drive',
        organizerId: 'u1',
        organizerName: 'Org',
        contactNumber: '+94771234567',
        location: 'Hall',
        city: 'Colombo',
        campaignDate: DateTime(2026, 11, 20),
        startTime: '09:00 AM',
        endTime: '04:00 PM',
        status: 'Upcoming',
      );

      final updated = original.copyWith(
        campaignName: 'Updated Drive',
        status: 'Ongoing',
        targetDonors: 150,
      );

      expect(updated.id, 'camp_001');
      expect(updated.campaignName, 'Updated Drive');
      expect(updated.status, 'Ongoing');
      expect(updated.isOngoing, isTrue);
      expect(updated.targetDonors, 150);
    });
  });

  group('BloodCampaignProvider Filtering and Authorization Tests', () {
    late BloodCampaignProvider provider;

    setUp(() {
      provider = BloodCampaignProvider();
      // Inject sample data directly into provider campaigns via reflection or test subclass
    });

    test('Role authorization checks operate correctly', () {
      final campaign = BloodCampaign(
        id: 'c1',
        campaignName: 'Test Drive',
        organizerId: 'org_user_1',
        organizerName: 'Test Org',
        contactNumber: '+94771234567',
        location: 'Center',
        city: 'Colombo',
        campaignDate: DateTime(2026, 11, 20),
        startTime: '09:00 AM',
        endTime: '04:00 PM',
      );

      // Donors can create campaigns and cannot manage other's campaign
      provider.setUser('donor_user_2', 'donor');
      expect(provider.canCreateCampaign, isTrue);
      expect(provider.canManageCampaign(campaign), isFalse);

      // The creator/organizer CAN manage their own campaign
      provider.setUser('org_user_1', 'donor');
      expect(provider.canManageCampaign(campaign), isTrue);

      // Manager/Admin can create and manage any campaign
      provider.setUser('manager_user_99', 'manager');
      expect(provider.canCreateCampaign, isTrue);
      expect(provider.canManageCampaign(campaign), isTrue);
    });
  });

  group('Blood Campaign Widget Tests', () {
    Widget buildTestApp({
      required Widget child,
      String userRole = 'manager',
      String userId = 'usr_mgr_1',
    }) {
      final authProvider = FakeAuthProvider(UserModel(
        id: userId,
        idNumber: '901234567V',
        name: 'Manager Silva',
        email: 'manager@lifelink.org',
        phone: '+94771234567',
        role: userRole,
      ));

      final campaignProvider = BloodCampaignProvider();
      campaignProvider.setUser(userId, userRole);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<BloodCampaignProvider>.value(value: campaignProvider),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('CampaignDetailsScreen renders full campaign info', (tester) async {
      final sampleCampaign = BloodCampaign(
        id: 'camp_101',
        campaignName: 'Grand Colombo Blood Drive',
        description: 'Join the annual blood drive to save lives.',
        organizerId: 'usr_mgr_1',
        organizerName: 'Colombo Red Cross',
        contactNumber: '+94 11 234 5678',
        email: 'redcross@lifelink.org',
        hospitalOrBloodBank: 'National Blood Bank',
        location: 'Viharamahadevi Amphitheatre',
        city: 'Colombo',
        campaignDate: DateTime(2026, 11, 28),
        startTime: '08:30 AM',
        endTime: '04:30 PM',
        targetDonors: 300,
        status: 'Upcoming',
      );

      await tester.pumpWidget(
        buildTestApp(
          child: CampaignDetailsScreen(campaign: sampleCampaign),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Campaign Details'), findsOneWidget);
      expect(find.text('Grand Colombo Blood Drive'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('Target: 300 Donors'), findsOneWidget);
      expect(find.text('Viharamahadevi Amphitheatre'), findsOneWidget);
      expect(find.text('Colombo'), findsOneWidget);
      expect(find.text('Colombo Red Cross'), findsOneWidget);
      expect(find.text('+94 11 234 5678'), findsOneWidget);
      expect(find.text('Edit Campaign'), findsOneWidget);
      expect(find.text('Cancel Campaign'), findsOneWidget);
    });

    testWidgets('CampaignFormDialog renders input fields and validates requirements', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CampaignFormDialog.show(ctx),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Create Blood Campaign'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);

      // Tap submit with empty required fields
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Campaign Name is required'), findsOneWidget);
    });
  });
}
