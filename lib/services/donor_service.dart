import 'package:uuid/uuid.dart';
import '../models/donor_profile_model.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_model.dart';
import '../models/donation_record_model.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/blood_types.dart';
import 'api_service.dart';
import 'mock_data_store.dart';

class DonorService {
  final ApiService _apiService = ApiService();
  final MockDataStore _dataStore = MockDataStore();
  final Uuid _uuid = const Uuid();

  // Search / Filter Donors by Location, Blood Group, Availability
  Future<List<DonorProfileModel>> searchDonors({
    String? city,
    String? bloodGroup,
    bool? isAvailable = true,
  }) async {
    final queryParams = <String, String>{};
    if (city != null && city.trim().isNotEmpty) {
      queryParams['city'] = city.trim();
    }
    if (bloodGroup != null && bloodGroup != 'All') {
      queryParams['bloodGroup'] = bloodGroup;
    }
    if (isAvailable != null) {
      queryParams['isAvailable'] = isAvailable.toString();
    }

    final queryString = queryParams.isNotEmpty
        ? '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final response = await _apiService.get('${ApiConstants.searchDonors}$queryString');
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => DonorProfileModel.fromJson(item))
          .toList();
    }

    // Mock fallback when offline or during test suites
    return _dataStore.searchDonors(
      city: city,
      bloodGroup: bloodGroup,
      isAvailable: isAvailable,
    );
  }

  // CRUD #5: Create Donor Profile
  Future<DonorProfileModel> createDonorProfile({
    required String userId,
    required String bloodGroup,
    required String city,
    String address = '',
    bool isAvailable = true,
    double latitude = 6.9271,
    double longitude = 79.8612,
    double? weightKg,
  }) async {
    final body = {
      'userId': userId,
      'bloodGroup': bloodGroup,
      'city': city,
      'address': address,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'weightKg': weightKg,
    };

    final response = await _apiService.post(ApiConstants.donorProfile, body);
    if (response.success && response.data != null) {
      final profile = DonorProfileModel.fromJson(response.data);
      _dataStore.donorProfiles[userId] = profile;
      return profile;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final newProfile = DonorProfileModel(
      id: 'dp_${_uuid.v4().substring(0, 8)}',
      userId: userId,
      bloodGroup: bloodGroup,
      city: city,
      address: address,
      isAvailable: isAvailable,
      latitude: latitude,
      longitude: longitude,
      weightKg: weightKg,
      totalDonations: 0,
      livesSaved: 0,
      eligibilityStatus: 'Eligible',
    );
    _dataStore.donorProfiles[userId] = newProfile;
    return newProfile;
  }

  // CRUD #6: Read Donor Profile
  Future<DonorProfileModel?> getDonorProfile(String userId) async {
    final response = await _apiService.get('${ApiConstants.donorProfile}?userId=$userId');
    if (response.success && response.data != null) {
      final profile = DonorProfileModel.fromJson(response.data);
      _dataStore.donorProfiles[userId] = profile;
      return profile;
    }

    // Mock fallback only for THIS userId specifically
    if (_dataStore.donorProfiles.containsKey(userId)) {
      return _dataStore.donorProfiles[userId];
    }
    return null;
  }

  // CRUD #7: Update Donor Profile
  Future<DonorProfileModel> updateDonorProfile({
    required String userId,
    String? bloodGroup,
    bool? isAvailable,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? lastDonationDate,
    double? weightKg,
  }) async {
    final body = <String, dynamic>{
      'userId': userId,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (city != null) 'city': city,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastDonationDate != null) 'lastDonationDate': lastDonationDate.toIso8601String(),
      if (weightKg != null) 'weightKg': weightKg,
    };

    final response = await _apiService.put(ApiConstants.updateDonorProfile, body);
    if (response.success && response.data != null) {
      final updated = DonorProfileModel.fromJson(response.data);
      _dataStore.donorProfiles[userId] = updated;
      return updated;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback only for THIS userId specifically
    var profile = _dataStore.donorProfiles[userId];
    if (profile != null) {
      final updated = profile.copyWith(
        bloodGroup: bloodGroup,
        isAvailable: isAvailable,
        city: city,
        address: address,
        latitude: latitude,
        longitude: longitude,
        lastDonationDate: lastDonationDate,
        weightKg: weightKg,
      );
      _dataStore.donorProfiles[userId] = updated;
      return updated;
    }

    throw Exception('Donor profile not found');
  }

  // Get Compatible Requests for Donor
  Future<List<BloodRequestModel>> getCompatibleRequests(String donorBloodGroup) async {
    final response = await _apiService.get(ApiConstants.donorCompatibleRequests);
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => BloodRequestModel.fromJson(item))
          .toList();
    }

    // Mock fallback: Filter active requests compatible with donorBloodGroup
    return _dataStore.requests.where((req) {
      if (req.status.toLowerCase() == 'cancelled') return false;
      return BloodTypes.isCompatible(
        donorGroup: donorBloodGroup,
        recipientGroup: req.bloodGroup,
      );
    }).toList();
  }

  // CRUD #8: Update Donor Response — Accept / Decline
  Future<DonorResponseModel> respondToRequest({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorPhone,
    required String donorBloodGroup,
    required String status, // 'Accepted' or 'Declined'
    String? note,
  }) async {
    final body = {
      'requestId': requestId,
      'donorId': donorId,
      'status': status,
      if (note != null) 'note': note,
    };

    final response = await _apiService.post(ApiConstants.respondToRequest, body);
    if (response.success && response.data != null) {
      return DonorResponseModel.fromJson(response.data);
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final responseModel = DonorResponseModel(
      id: 'dr_${_uuid.v4().substring(0, 8)}',
      requestId: requestId,
      donorId: donorId,
      donorName: donorName,
      donorPhone: donorPhone,
      donorBloodGroup: donorBloodGroup,
      status: status,
      respondedAt: DateTime.now(),
      distanceKm: 2.1,
      note: note,
    );

    // Update request's matched donors list
    final reqIndex = _dataStore.requests.indexWhere((r) => r.id == requestId);
    if (reqIndex != -1) {
      final req = _dataStore.requests[reqIndex];
      final updatedList = List<DonorResponseModel>.from(req.matchedDonors);
      final existingIdx = updatedList.indexWhere((d) => d.donorId == donorId);
      if (existingIdx != -1) {
        updatedList[existingIdx] = responseModel;
      } else {
        updatedList.add(responseModel);
      }

      final acceptedCount = updatedList.where((d) => d.status.toLowerCase() == 'accepted').length;

      _dataStore.requests[reqIndex] = req.copyWith(
        matchedDonors: updatedList,
        matchedDonorsCount: updatedList.length,
        acceptedDonorsCount: acceptedCount,
        status: status.toLowerCase() == 'accepted' ? 'InProgress' : req.status,
      );
    }

    return responseModel;
  }

  // CRUD #9: Create Donation Record
  Future<DonationRecordModel> createDonationRecord({
    required String donorId,
    required String requestId,
    required String hospitalName,
    required String patientName,
    required String bloodGroup,
    int units = 1,
  }) async {
    final body = {
      'donorId': donorId,
      'requestId': requestId,
      'hospitalName': hospitalName,
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'units': units,
    };

    final response = await _apiService.post(ApiConstants.donationRecords, body);
    if (response.success && response.data != null) {
      return DonationRecordModel.fromJson(response.data);
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final record = DonationRecordModel(
      id: 'don_${_uuid.v4().substring(0, 8)}',
      donorId: donorId,
      requestId: requestId,
      hospitalName: hospitalName,
      patientName: patientName,
      bloodGroup: bloodGroup,
      units: units,
      donationDate: DateTime.now(),
      status: 'Completed',
    );
    _dataStore.donationHistory.insert(0, record);

    if (_dataStore.donorProfiles.containsKey(donorId)) {
      final p = _dataStore.donorProfiles[donorId]!;
      _dataStore.donorProfiles[donorId] = p.copyWith(
        totalDonations: p.totalDonations + 1,
        livesSaved: p.livesSaved + (units * 3),
        lastDonationDate: DateTime.now(),
      );
    }

    return record;
  }

  // CRUD #10: Read Donation History
  Future<List<DonationRecordModel>> getDonationHistory(String donorId) async {
    final response = await _apiService.get('${ApiConstants.donationRecords}?donorId=$donorId');
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => DonationRecordModel.fromJson(item))
          .toList();
    }

    // Fallback try
    final fallback = await _apiService.get(ApiConstants.donationRecords);
    if (fallback.success && fallback.data != null && fallback.data is List) {
      return (fallback.data as List)
          .map((item) => DonationRecordModel.fromJson(item))
          .toList();
    }

    // Mock fallback
    return _dataStore.donationHistory;
  }

  // Read donor responses (accepted/declined)
  Future<List<DonorResponseModel>> getDonorResponses(String donorId) async {
    final response = await _apiService.get(ApiConstants.donorResponses);
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => DonorResponseModel.fromJson(item))
          .toList();
    }

    // Mock fallback: scan all requests' matched donors
    final results = <DonorResponseModel>[];
    for (final req in _dataStore.requests) {
      for (final resp in req.matchedDonors) {
        if (resp.donorId == donorId) {
          results.add(resp);
        }
      }
    }
    return results;
  }
}
