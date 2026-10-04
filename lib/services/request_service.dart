import 'package:uuid/uuid.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_model.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';
import 'mock_data_store.dart';

class RequestService {
  final ApiService _apiService = ApiService();
  final MockDataStore _dataStore = MockDataStore();
  final Uuid _uuid = const Uuid();

  // CRUD #11: Create Blood Request
  Future<BloodRequestModel> createBloodRequest({
    required String requesterId,
    required String requesterName,
    required String patientName,
    required String bloodGroup,
    required int unitsRequired,
    required String urgency,
    required String hospitalName,
    required String hospitalAddress,
    required String contactPhone,
    String additionalNotes = '',
    double latitude = 6.9271,
    double longitude = 79.8612,
    DateTime? requiredBefore,
  }) async {
    final body = {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'unitsRequired': unitsRequired,
      'urgency': urgency,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'contactPhone': contactPhone,
      'additionalNotes': additionalNotes,
      'latitude': latitude,
      'longitude': longitude,
      'requiredBefore': requiredBefore?.toIso8601String(),
    };

    final response = await _apiService.post(ApiConstants.requests, body);
    if (response.success && response.data != null) {
      return BloodRequestModel.fromJson(response.data);
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final newRequest = BloodRequestModel(
      id: 'req_${_uuid.v4().substring(0, 8)}',
      requesterId: requesterId,
      requesterName: requesterName,
      patientName: patientName,
      bloodGroup: bloodGroup,
      unitsRequired: unitsRequired,
      urgency: urgency,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      contactPhone: contactPhone,
      additionalNotes: additionalNotes,
      latitude: latitude,
      longitude: longitude,
      requiredBefore: requiredBefore ?? DateTime.now().add(const Duration(hours: 12)),
      status: 'Open',
      createdAt: DateTime.now(),
      matchedDonorsCount: 3,
      acceptedDonorsCount: 0,
      matchedDonors: [],
    );

    // Run backend/mock matching algorithm
    final potentialDonors = _dataStore.getMatchingDonorsForRequest(newRequest);
    final requestWithMatches = newRequest.copyWith(
      matchedDonors: potentialDonors,
      matchedDonorsCount: potentialDonors.length,
    );

    _dataStore.requests.insert(0, requestWithMatches);
    return requestWithMatches;
  }

  // CRUD #12: Read Blood Requests
  Future<List<BloodRequestModel>> getBloodRequests({
    String? bloodGroup,
    String? urgency,
    String? status,
  }) async {
    final queryParams = <String>[];
    if (bloodGroup != null && bloodGroup.isNotEmpty) queryParams.add('bloodGroup=$bloodGroup');
    if (urgency != null && urgency.isNotEmpty && urgency != 'All') queryParams.add('urgency=$urgency');
    if (status != null && status.isNotEmpty && status != 'All') queryParams.add('status=$status');

    final endpoint = queryParams.isNotEmpty
        ? '${ApiConstants.requests}?${queryParams.join('&')}'
        : ApiConstants.requests;

    final response = await _apiService.get(endpoint);
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => BloodRequestModel.fromJson(item))
          .toList();
    }

    // Mock fallback with filtering
    return _dataStore.requests.where((r) {
      if (bloodGroup != null && bloodGroup.isNotEmpty && r.bloodGroup != bloodGroup) {
        return false;
      }
      if (urgency != null && urgency.isNotEmpty && urgency != 'All' && r.urgency != urgency) {
        return false;
      }
      if (status != null && status.isNotEmpty && status != 'All' && r.status != status) {
        return false;
      }
      return true;
    }).toList();
  }

  // Read My Submitted Requests (Recipient)
  Future<List<BloodRequestModel>> getMyRequests(String requesterId) async {
    final response = await _apiService.get('${ApiConstants.myRequests}?userId=$requesterId');
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => BloodRequestModel.fromJson(item))
          .toList();
    }

    // Fallback try
    final fallback = await _apiService.get(ApiConstants.myRequests);
    if (fallback.success && fallback.data != null && fallback.data is List) {
      return (fallback.data as List)
          .map((item) => BloodRequestModel.fromJson(item))
          .toList();
    }

    // Mock fallback
    return _dataStore.requests
        .where((r) => r.requesterId == requesterId)
        .toList();
  }

  // Read Request By ID
  Future<BloodRequestModel?> getRequestById(String requestId) async {
    final response = await _apiService.get('${ApiConstants.requests}/$requestId');
    if (response.success && response.data != null) {
      return BloodRequestModel.fromJson(response.data);
    }

    // Mock fallback
    try {
      return _dataStore.requests.firstWhere((r) => r.id == requestId);
    } catch (_) {
      return null;
    }
  }

  // CRUD #13: Read Matching Results (Potential Donors returned by backend matching engine)
  Future<List<DonorResponseModel>> getMatchingDonors(String requestId) async {
    final endpoint = ApiConstants.matchingDonors.replaceAll('{id}', requestId);
    final response = await _apiService.get(endpoint);
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => DonorResponseModel.fromJson(item))
          .toList();
    }

    // Mock fallback
    final req = await getRequestById(requestId);
    if (req != null) {
      if (req.matchedDonors.isNotEmpty) {
        return req.matchedDonors;
      }
      return _dataStore.getMatchingDonorsForRequest(req);
    }
    return [];
  }

  // CRUD #14: Update Blood Request
  Future<BloodRequestModel> updateBloodRequest({
    required String requestId,
    int? unitsRequired,
    String? urgency,
    String? hospitalName,
    String? hospitalAddress,
    String? additionalNotes,
    String? status,
  }) async {
    final body = <String, dynamic>{
      if (unitsRequired != null) 'unitsRequired': unitsRequired,
      if (urgency != null) 'urgency': urgency,
      if (hospitalName != null) 'hospitalName': hospitalName,
      if (hospitalAddress != null) 'hospitalAddress': hospitalAddress,
      if (additionalNotes != null) 'additionalNotes': additionalNotes,
      if (status != null) 'status': status,
    };

    final response = await _apiService.put('${ApiConstants.requests}/$requestId', body);
    if (response.success && response.data != null) {
      return BloodRequestModel.fromJson(response.data);
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final index = _dataStore.requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final updated = _dataStore.requests[index].copyWith(
        unitsRequired: unitsRequired,
        urgency: urgency,
        hospitalName: hospitalName,
        hospitalAddress: hospitalAddress,
        additionalNotes: additionalNotes,
        status: status,
      );
      _dataStore.requests[index] = updated;
      return updated;
    }
    throw Exception('Request not found');
  }

  // CRUD #15: Cancel/Delete Blood Request
  Future<bool> cancelBloodRequest(String requestId) async {
    final endpoint = ApiConstants.cancelRequest.replaceAll('{id}', requestId);
    final response = await _apiService.post(endpoint, {});
    if (response.success) {
      return true;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final index = _dataStore.requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _dataStore.requests[index] = _dataStore.requests[index].copyWith(status: 'Cancelled');
      return true;
    }
    return false;
  }

  // Fulfill Request
  Future<bool> fulfillBloodRequest(String requestId) async {
    final endpoint = ApiConstants.fulfillRequest.replaceAll('{id}', requestId);
    final response = await _apiService.post(endpoint, {});
    if (response.success) {
      return true;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final index = _dataStore.requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _dataStore.requests[index] = _dataStore.requests[index].copyWith(status: 'Fulfilled');
      return true;
    }
    return false;
  }
}
