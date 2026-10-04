import 'package:flutter/material.dart';
import '../models/donor_profile_model.dart';
import '../models/blood_request_model.dart';
import '../models/donor_response_model.dart';
import '../models/donation_record_model.dart';
import '../services/donor_service.dart';

class DonorProvider with ChangeNotifier {
  final DonorService _donorService = DonorService();

  DonorProfileModel? _profile;
  List<BloodRequestModel> _compatibleRequests = [];
  List<DonationRecordModel> _donationHistory = [];
  List<DonorResponseModel> _myResponses = [];

  bool _isLoading = false;
  String? _errorMessage;

  DonorProfileModel? get profile => _profile;
  List<BloodRequestModel> get compatibleRequests => _compatibleRequests;
  List<DonationRecordModel> get donationHistory => _donationHistory;
  List<DonorResponseModel> get myResponses => _myResponses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Total lives impacted calculation
  int get livesImpacted => (_profile?.livesSaved ?? 0);
  int get totalDonations => (_profile?.totalDonations ?? 0);

  Future<void> loadDonorData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _donorService.getDonorProfile(userId);
      if (_profile != null) {
        _compatibleRequests = await _donorService.getCompatibleRequests(_profile!.bloodGroup);
        _donationHistory = await _donorService.getDonationHistory(userId);
        _myResponses = await _donorService.getDonorResponses(userId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> setupProfile({
    required String userId,
    required String bloodGroup,
    required String city,
    String address = '',
    bool isAvailable = true,
    double? weightKg,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _donorService.createDonorProfile(
        userId: userId,
        bloodGroup: bloodGroup,
        city: city,
        address: address,
        isAvailable: isAvailable,
        weightKg: weightKg,
      );
      _isLoading = false;
      notifyListeners();

      // Refresh secondary data in background
      _donorService.getCompatibleRequests(bloodGroup).then((reqs) {
        _compatibleRequests = reqs;
        notifyListeners();
      }).catchError((_) {});

      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleAvailability(String userId, bool isAvailable) async {
    if (_profile == null) return;
    try {
      _profile = await _donorService.updateDonorProfile(
        userId: userId,
        isAvailable: isAvailable,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateProfileDetails({
    required String userId,
    String? bloodGroup,
    String? city,
    String? address,
    bool? isAvailable,
    double? weightKg,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _donorService.updateDonorProfile(
        userId: userId,
        bloodGroup: bloodGroup,
        city: city,
        address: address,
        isAvailable: isAvailable,
        weightKg: weightKg,
      );
      _isLoading = false;
      notifyListeners();

      if (bloodGroup != null) {
        _donorService.getCompatibleRequests(bloodGroup).then((reqs) {
          _compatibleRequests = reqs;
          notifyListeners();
        }).catchError((_) {});
      }
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToRequest({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorPhone,
    required String status, // 'Accepted' or 'Declined'
    String? note,
  }) async {
    if (_profile == null) return false;

    try {
      final response = await _donorService.respondToRequest(
        requestId: requestId,
        donorId: donorId,
        donorName: donorName,
        donorPhone: donorPhone,
        donorBloodGroup: _profile!.bloodGroup,
        status: status,
        note: note,
      );

      // Update local responses
      final existingIndex = _myResponses.indexWhere((r) => r.requestId == requestId);
      if (existingIndex != -1) {
        _myResponses[existingIndex] = response;
      } else {
        _myResponses.insert(0, response);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeDonation({
    required String donorId,
    required String requestId,
    required String hospitalName,
    required String patientName,
    required String bloodGroup,
    int units = 1,
  }) async {
    try {
      final record = await _donorService.createDonationRecord(
        donorId: donorId,
        requestId: requestId,
        hospitalName: hospitalName,
        patientName: patientName,
        bloodGroup: bloodGroup,
        units: units,
      );
      _donationHistory.insert(0, record);

      if (_profile != null) {
        _profile = _profile!.copyWith(
          totalDonations: _profile!.totalDonations + 1,
          livesSaved: _profile!.livesSaved + (units * 3),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
