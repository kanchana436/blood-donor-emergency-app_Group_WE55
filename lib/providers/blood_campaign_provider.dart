import 'package:flutter/foundation.dart';
import '../models/blood_campaign_model.dart';
import '../services/blood_campaign_service.dart';

class BloodCampaignProvider extends ChangeNotifier {
  final BloodCampaignService _service = BloodCampaignService();

  List<BloodCampaign> _campaigns = [];
  BloodCampaign? _selectedCampaign;
  bool _isLoading = false;
  String? _errorMessage;

  String? _currentUserId;
  String? _currentUserRole;

  // Filter state
  String _searchQuery = '';
  String? _selectedCity;
  String? _selectedStatus;
  DateTime? _selectedDate;

  List<BloodCampaign> get campaigns => _campaigns;
  BloodCampaign? get selectedCampaign => _selectedCampaign;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String? get selectedCity => _selectedCity;
  String? get selectedStatus => _selectedStatus;
  DateTime? get selectedDate => _selectedDate;

  bool get canCreateCampaign => true;

  bool canManageCampaign(BloodCampaign campaign) {
    if (_currentUserRole == 'manager' || _currentUserRole == 'admin') return true;
    if (_currentUserId != null && _currentUserId == campaign.organizerId) return true;
    return false;
  }

  void setUser(String? userId, [String? role]) {
    _currentUserId = userId;
    _currentUserRole = role;
    notifyListeners();
  }

  List<BloodCampaign> get filteredCampaigns {
    return _campaigns.where((campaign) {
      if (!campaign.isActive) return false;

      // Status filter
      if (_selectedStatus != null &&
          _selectedStatus!.isNotEmpty &&
          _selectedStatus != 'All') {
        if (campaign.status.toLowerCase() != _selectedStatus!.toLowerCase()) {
          return false;
        }
      }

      // City filter
      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        if (!campaign.city.toLowerCase().contains(_selectedCity!.toLowerCase())) {
          return false;
        }
      }

      // Date filter
      if (_selectedDate != null) {
        final cDate = campaign.campaignDate;
        final isSameDate = cDate.year == _selectedDate!.year &&
            cDate.month == _selectedDate!.month &&
            cDate.day == _selectedDate!.day;
        if (!isSameDate) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = campaign.campaignName.toLowerCase().contains(query);
        final matchesLoc = campaign.location.toLowerCase().contains(query);
        final matchesCity = campaign.city.toLowerCase().contains(query);
        final matchesOrganizer =
            campaign.organizerName.toLowerCase().contains(query);
        final matchesHospital = campaign.hospitalOrBloodBank != null &&
            campaign.hospitalOrBloodBank!.toLowerCase().contains(query);
        final matchesDesc = campaign.description != null &&
            campaign.description!.toLowerCase().contains(query);

        if (!matchesName &&
            !matchesLoc &&
            !matchesCity &&
            !matchesOrganizer &&
            !matchesHospital &&
            !matchesDesc) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<BloodCampaign> get upcomingCampaigns =>
      filteredCampaigns.where((c) => c.isUpcoming).toList();

  List<BloodCampaign> get ongoingCampaigns =>
      filteredCampaigns.where((c) => c.isOngoing).toList();

  List<BloodCampaign> get completedCampaigns =>
      filteredCampaigns.where((c) => c.isCompleted).toList();

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setSelectedCity(String? city) {
    _selectedCity = city;
    notifyListeners();
  }

  void setSelectedStatus(String? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSelectedDate(DateTime? date) {
    _selectedDate = date;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCity = null;
    _selectedStatus = null;
    _selectedDate = null;
    notifyListeners();
  }

  Future<void> fetchCampaigns() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _service.getCampaigns();
      _campaigns = list;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BloodCampaign?> getCampaignDetails(String id) async {
    try {
      final campaign = await _service.getCampaignById(id);
      _selectedCampaign = campaign;
      notifyListeners();
      return campaign;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> createCampaign(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _service.createCampaign(data);
      _campaigns.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCampaign(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _service.updateCampaign(id, data);
      final idx = _campaigns.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _campaigns[idx] = updated;
      }
      if (_selectedCampaign?.id == id) {
        _selectedCampaign = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCampaign(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteCampaign(id);
      // Remove from active list or mark inactive
      _campaigns.removeWhere((c) => c.id == id);
      if (_selectedCampaign?.id == id) {
        _selectedCampaign = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
