import '../models/user_model.dart';
import '../models/donor_profile_model.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_model.dart';
import '../models/donation_record_model.dart';
import '../models/notification_model.dart';
import '../core/constants/blood_types.dart';

class MockDataStore {
  static final MockDataStore _instance = MockDataStore._internal();
  factory MockDataStore() => _instance;

  MockDataStore._internal() {
    _initializeSeedData();
  }

  // Collections
  final List<UserModel> users = [];
  final Map<String, DonorProfileModel> donorProfiles = {}; // userId -> DonorProfile
  final List<BloodRequestModel> requests = [];
  final List<DonationRecordModel> donationHistory = [];
  final List<NotificationModel> notifications = [];

  void _initializeSeedData() {
    // Current Donor User
    final donorUser = UserModel(
      id: 'usr_donor_101',
      name: 'Alexander Silva',
      email: 'alexander@lifelink.org',
      phone: '+94 77 123 4567',
      role: 'donor',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    );
    users.add(donorUser);

    donorProfiles[donorUser.id] = DonorProfileModel(
      id: 'dp_101',
      userId: donorUser.id,
      bloodGroup: 'O+',
      isAvailable: true,
      city: 'Colombo',
      address: 'No 45, Galle Road, Colombo 03',
      latitude: 6.9271,
      longitude: 79.8612,
      lastDonationDate: DateTime.now().subtract(const Duration(days: 95)),
      totalDonations: 4,
      livesSaved: 12,
      eligibilityStatus: 'Eligible',
      weightKg: 72.5,
    );

    // Current Recipient User
    final recipientUser = UserModel(
      id: 'usr_recip_202',
      name: 'Sarah Perera',
      email: 'sarah.p@lifelink.org',
      phone: '+94 71 987 6543',
      role: 'recipient',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );
    users.add(recipientUser);

    // Additional Potential Donors for matching
    final matchedDonorsList = [
      DonorResponseModel(
        id: 'dr_01',
        requestId: 'req_001',
        donorId: 'usr_donor_101',
        donorName: 'Alexander Silva',
        donorPhone: '+94 77 123 4567',
        donorBloodGroup: 'O+',
        status: 'Pending',
        distanceKm: 1.8,
        respondedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      DonorResponseModel(
        id: 'dr_02',
        requestId: 'req_001',
        donorId: 'usr_donor_102',
        donorName: 'Kasun Fernando',
        donorPhone: '+94 76 555 4321',
        donorBloodGroup: 'O+',
        status: 'Accepted',
        distanceKm: 3.2,
        respondedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        note: 'On the way to hospital, ETA 20 mins',
      ),
      DonorResponseModel(
        id: 'dr_03',
        requestId: 'req_001',
        donorId: 'usr_donor_103',
        donorName: 'Nipuni Wickramasinghe',
        donorPhone: '+94 70 888 9999',
        donorBloodGroup: 'O-',
        status: 'Pending',
        distanceKm: 4.5,
        respondedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    // Seed Blood Requests
    requests.addAll([
      BloodRequestModel(
        id: 'req_001',
        requesterId: recipientUser.id,
        requesterName: 'Sarah Perera',
        patientName: 'Kavindu Perera (Emergency Surgery)',
        bloodGroup: 'O+',
        unitsRequired: 2,
        urgency: 'Emergency',
        hospitalName: 'National Hospital of Sri Lanka',
        hospitalAddress: 'Regent Street, Colombo 10',
        latitude: 6.9202,
        longitude: 79.8687,
        contactPhone: '+94 71 987 6543',
        additionalNotes: 'Immediate bypass surgery scheduled. 2 units O+ required urgently.',
        status: 'Open',
        createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
        requiredBefore: DateTime.now().add(const Duration(hours: 6)),
        matchedDonorsCount: 3,
        acceptedDonorsCount: 1,
        matchedDonors: matchedDonorsList,
      ),
      BloodRequestModel(
        id: 'req_002',
        requesterId: 'usr_recip_203',
        requesterName: 'Dr. Rohan Mendis',
        patientName: 'Dilani Samarasinghe (ICU)',
        bloodGroup: 'A+',
        unitsRequired: 3,
        urgency: 'Urgent',
        hospitalName: 'Asiri Central Hospital',
        hospitalAddress: 'Norris Canal Rd, Colombo 10',
        latitude: 6.9240,
        longitude: 79.8655,
        contactPhone: '+94 77 345 6789',
        additionalNotes: 'Post-operative recovery in ICU. Platelets and whole blood needed.',
        status: 'Open',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        requiredBefore: DateTime.now().add(const Duration(hours: 18)),
        matchedDonorsCount: 4,
        acceptedDonorsCount: 2,
      ),
      BloodRequestModel(
        id: 'req_003',
        requesterId: recipientUser.id,
        requesterName: 'Sarah Perera',
        patientName: 'Nalaka Bandara',
        bloodGroup: 'B+',
        unitsRequired: 1,
        urgency: 'Standard',
        hospitalName: 'Lanka Hospitals',
        hospitalAddress: 'Elvitigala Mawatha, Colombo 05',
        latitude: 6.8969,
        longitude: 79.8804,
        contactPhone: '+94 71 987 6543',
        additionalNotes: 'Routine transfusion for Thalassemia patient.',
        status: 'Fulfilled',
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        matchedDonorsCount: 2,
        acceptedDonorsCount: 1,
      ),
    ]);

    // Seed Donation History
    donationHistory.addAll([
      DonationRecordModel(
        id: 'don_001',
        donorId: donorUser.id,
        requestId: 'req_003',
        hospitalName: 'National Hospital of Sri Lanka',
        patientName: 'Chaminda Rathnayake',
        bloodGroup: 'O+',
        units: 1,
        donationDate: DateTime.now().subtract(const Duration(days: 95)),
        status: 'Completed',
        certificateUrl: 'https://lifelink.org/certificates/don_001.pdf',
      ),
      DonationRecordModel(
        id: 'don_002',
        donorId: donorUser.id,
        requestId: 'req_past_002',
        hospitalName: 'Castle Street Hospital for Women',
        patientName: 'Manoja Jayawardena',
        bloodGroup: 'O+',
        units: 1,
        donationDate: DateTime.now().subtract(const Duration(days: 210)),
        status: 'Completed',
        certificateUrl: 'https://lifelink.org/certificates/don_002.pdf',
      ),
      DonationRecordModel(
        id: 'don_003',
        donorId: donorUser.id,
        requestId: 'req_past_003',
        hospitalName: 'Lady Ridgeway Hospital for Children',
        patientName: 'Baby Senuri',
        bloodGroup: 'O+',
        units: 1,
        donationDate: DateTime.now().subtract(const Duration(days: 340)),
        status: 'Completed',
        certificateUrl: 'https://lifelink.org/certificates/don_003.pdf',
      ),
    ]);

    // Seed Notifications
    notifications.addAll([
      NotificationModel(
        id: 'notif_001',
        userId: donorUser.id,
        title: 'Emergency Blood Request Nearby!',
        message: 'A patient at National Hospital urgently needs 2 units of O+ blood (1.8 km away).',
        type: 'emergency',
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        isRead: false,
        relatedRequestId: 'req_001',
      ),
      NotificationModel(
        id: 'notif_002',
        userId: recipientUser.id,
        title: 'Donor Accepted Your Request!',
        message: 'Kasun Fernando accepted your blood request for Kavindu Perera. ETA 20 mins.',
        type: 'accepted',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isRead: false,
        relatedRequestId: 'req_001',
      ),
      NotificationModel(
        id: 'notif_003',
        userId: donorUser.id,
        title: 'Donation Eligibility Reminder',
        message: 'You have been eligible to donate blood since last week. Check nearby requests.',
        type: 'reminder',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
      NotificationModel(
        id: 'notif_004',
        userId: donorUser.id,
        title: 'Thank You for Saving 3 Lives!',
        message: 'Your previous blood donation at National Hospital was successfully transfused.',
        type: 'match',
        timestamp: DateTime.now().subtract(const Duration(days: 90)),
        isRead: true,
        relatedRequestId: 'req_003',
      ),
    ]);
  }

  // --- Matching Engine ---
  List<DonorResponseModel> getMatchingDonorsForRequest(BloodRequestModel request) {
    // If request already has matched donors stored, return them
    if (request.matchedDonors.isNotEmpty) {
      return request.matchedDonors;
    }

    // Otherwise find eligible donors compatible with request.bloodGroup
    final matches = <DonorResponseModel>[];
    for (final entry in donorProfiles.entries) {
      final profile = entry.value;
      if (profile.isAvailable &&
          BloodTypes.isCompatible(
            donorGroup: profile.bloodGroup,
            recipientGroup: request.bloodGroup,
          )) {
        final user = users.firstWhere(
          (u) => u.id == profile.userId,
          orElse: () => UserModel(
            id: profile.userId,
            name: 'Anonymous Donor',
            email: '',
            phone: '+94 77 000 0000',
            role: 'donor',
          ),
        );

        matches.add(
          DonorResponseModel(
            id: 'dr_${DateTime.now().millisecondsSinceEpoch}_${matches.length}',
            requestId: request.id,
            donorId: user.id,
            donorName: user.name,
            donorPhone: user.phone,
            donorBloodGroup: profile.bloodGroup,
            status: 'Pending',
            distanceKm: 2.1 + (matches.length * 1.3),
            respondedAt: DateTime.now(),
          ),
        );
      }
    }
    return matches;
  }
}
