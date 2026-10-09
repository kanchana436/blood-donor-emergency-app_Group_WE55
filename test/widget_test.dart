import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/constants/blood_types.dart';
import 'package:lifelink/models/user_model.dart';
import 'package:lifelink/models/blood_request_model.dart';
import 'package:lifelink/services/mock_data_store.dart';
import 'package:lifelink/services/location_service.dart';
import 'package:lifelink/main.dart';

void main() {
  group('Blood Type Compatibility Tests', () {
    test('O- should be universal donor for all blood types', () {
      for (final type in BloodTypes.all) {
        expect(
          BloodTypes.isCompatible(donorGroup: 'O-', recipientGroup: type),
          isTrue,
          reason: 'O- must be able to donate to $type',
        );
      }
    });

    test('AB+ should be universal recipient from all blood types', () {
      for (final type in BloodTypes.all) {
        expect(
          BloodTypes.isCompatible(donorGroup: type, recipientGroup: 'AB+'),
          isTrue,
          reason: 'AB+ must be able to receive from $type',
        );
      }
    });

    test('A+ cannot donate to O+ or B+', () {
      expect(
        BloodTypes.isCompatible(donorGroup: 'A+', recipientGroup: 'O+'),
        isFalse,
      );
      expect(
        BloodTypes.isCompatible(donorGroup: 'A+', recipientGroup: 'B+'),
        isFalse,
      );
    });
  });

  group('Location Service Tests', () {
    test('Haversine distance calculation is accurate', () {
      final locationService = LocationService();
      // Distance between Colombo (6.9271, 79.8612) and NHSL (6.9202, 79.8687) is approx 1.1 - 1.2 km
      final distance = locationService.calculateDistance(6.9271, 79.8612, 6.9202, 79.8687);
      expect(distance, greaterThan(0.5));
      expect(distance, lessThan(2.0));
    });
  });

  group('Model Serialization Tests', () {
    test('UserModel serialization and deserialization', () {
      final user = UserModel(
        id: 'usr_test_1',
        name: 'Kasun Test',
        email: 'kasun@test.com',
        phone: '+94 77 123 4567',
        role: 'donor',
      );

      final json = user.toJson();
      final fromJson = UserModel.fromJson(json);

      expect(fromJson.id, equals(user.id));
      expect(fromJson.name, equals(user.name));
      expect(fromJson.email, equals(user.email));
      expect(fromJson.role, equals(user.role));
    });

    test('BloodRequestModel serialization', () {
      final req = BloodRequestModel(
        id: 'req_test_1',
        requesterId: 'usr_recip',
        requesterName: 'Sarah',
        patientName: 'Kavindu',
        bloodGroup: 'O+',
        unitsRequired: 2,
        urgency: 'Emergency',
        hospitalName: 'NHSL',
        hospitalAddress: 'Colombo 10',
        contactPhone: '+94 71 000 0000',
      );

      final json = req.toJson();
      final fromJson = BloodRequestModel.fromJson(json);

      expect(fromJson.id, equals(req.id));
      expect(fromJson.patientName, equals(req.patientName));
      expect(fromJson.unitsRequired, equals(2));
      expect(fromJson.urgency, equals('Emergency'));
    });
  });

  group('MockDataStore CRUD and Matching Tests', () {
    test('Matching algorithm returns compatible donors for emergency request', () {
      final store = MockDataStore();
      final testReq = BloodRequestModel(
        id: 'req_match_test',
        requesterId: 'usr_recip_202',
        requesterName: 'Sarah Perera',
        patientName: 'Test Patient',
        bloodGroup: 'O+',
        unitsRequired: 1,
        urgency: 'Emergency',
        hospitalName: 'NHSL',
        hospitalAddress: 'Colombo',
        contactPhone: '+94 71 987 6543',
      );

      final matches = store.getMatchingDonorsForRequest(testReq);
      expect(matches, isNotEmpty);
      for (final match in matches) {
        expect(
          BloodTypes.isCompatible(donorGroup: match.donorBloodGroup, recipientGroup: 'O+'),
          isTrue,
        );
      }
    });
  });

  testWidgets('LifeLinkApp builds and renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeLinkApp());
    expect(find.text('LifeLink'), findsOneWidget);
    expect(find.text('BLOOD DONATION & EMERGENCY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
