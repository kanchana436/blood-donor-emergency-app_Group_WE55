import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_model.dart';
import '../services/request_service.dart';

class RequestProvider with ChangeNotifier {
  final RequestService _requestService = RequestService();

  List<BloodRequestModel> _allRequests = [];
  List<BloodRequestModel> _myRequests = [];
  BloodRequestModel? _selectedRequest;
  List<DonorResponseModel> _matchingDonors = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Filter state
  String _selectedBloodGroupFilter = 'All';
  String _selectedUrgencyFilter = 'All';

  List<BloodRequestModel> get allRequests => _allRequests;
  List<BloodRequestModel> get myRequests => _myRequests;
  BloodRequestModel? get selectedRequest => _selectedRequest;
  List<DonorResponseModel> get matchingDonors => _matchingDonors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedBloodGroupFilter => _selectedBloodGroupFilter;
  String get selectedUrgencyFilter => _selectedUrgencyFilter;

  // Active emergency requests (urgency == 'Emergency' && status == 'Open')
  List<BloodRequestModel> get activeEmergencies => _allRequests
      .where((r) => r.urgency == 'Emergency' && r.status == 'Open')
      .toList();

  Future<void> loadAllRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allRequests = await _requestService.getBloodRequests(
        bloodGroup: _selectedBloodGroupFilter == 'All' ? null : _selectedBloodGroupFilter,
        urgency: _selectedUrgencyFilter == 'All' ? null : _selectedUrgencyFilter,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMyRequests(String requesterId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myRequests = await _requestService.getMyRequests(requesterId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void setFilter({String? bloodGroup, String? urgency}) {
    if (bloodGroup != null) _selectedBloodGroupFilter = bloodGroup;
    if (urgency != null) _selectedUrgencyFilter = urgency;
    loadAllRequests();
  }

  void selectRequest(BloodRequestModel request) {
    _selectedRequest = request;
    notifyListeners();
    fetchMatchingDonors(request.id);
  }

  Future<void> fetchMatchingDonors(String requestId) async {
    try {
      _matchingDonors = await _requestService.getMatchingDonors(requestId);
      notifyListeners();
    } catch (_) {}
  }

  Future<BloodRequestModel?> getRequestById(String requestId) async {
    return await _requestService.getRequestById(requestId);
  }

  Future<BloodRequestModel?> createBloodRequest({
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newRequest = await _requestService.createBloodRequest(
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
      );

      _myRequests.insert(0, newRequest);
      _allRequests.insert(0, newRequest);
      _isLoading = false;
      notifyListeners();
      return newRequest;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateRequest({
    required String requestId,
    int? unitsRequired,
    String? urgency,
    String? hospitalName,
    String? hospitalAddress,
    String? additionalNotes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _requestService.updateBloodRequest(
        requestId: requestId,
        unitsRequired: unitsRequired,
        urgency: urgency,
        hospitalName: hospitalName,
        hospitalAddress: hospitalAddress,
        additionalNotes: additionalNotes,
      );

      _updateLocalRequest(updated);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    try {
      final success = await _requestService.cancelBloodRequest(requestId);
      if (success) {
        final index = _myRequests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _myRequests[index] = _myRequests[index].copyWith(status: 'Cancelled');
        }
        final allIndex = _allRequests.indexWhere((r) => r.id == requestId);
        if (allIndex != -1) {
          _allRequests[allIndex] = _allRequests[allIndex].copyWith(status: 'Cancelled');
        }
        if (_selectedRequest?.id == requestId) {
          _selectedRequest = _selectedRequest!.copyWith(status: 'Cancelled');
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> fulfillRequest(String requestId) async {
    try {
      final success = await _requestService.fulfillBloodRequest(requestId);
      if (success) {
        final index = _myRequests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _myRequests[index] = _myRequests[index].copyWith(status: 'Fulfilled');
        }
        if (_selectedRequest?.id == requestId) {
          _selectedRequest = _selectedRequest!.copyWith(status: 'Fulfilled');
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _updateLocalRequest(BloodRequestModel updated) {
    final myIdx = _myRequests.indexWhere((r) => r.id == updated.id);
    if (myIdx != -1) _myRequests[myIdx] = updated;

    final allIdx = _allRequests.indexWhere((r) => r.id == updated.id);
    if (allIdx != -1) _allRequests[allIdx] = updated;

    if (_selectedRequest?.id == updated.id) {
      _selectedRequest = updated;
    }
  }
}
