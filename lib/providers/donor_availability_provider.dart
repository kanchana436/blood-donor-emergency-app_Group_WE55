import 'package:flutter/foundation.dart';
import '../models/donor_availability_model.dart';
import '../services/donor_availability_service.dart';

class DonorAvailabilityProvider extends ChangeNotifier {
  DonorAvailabilityProvider({DonorAvailabilityService? service})
      : _service = service ?? DonorAvailabilityService();

  final DonorAvailabilityService _service;

  List<DonorAvailabilityModel> _records = [];
  DonorAvailabilityModel? _currentRecord;
  String _currentStatus = 'Not Scheduled';
  bool _isCurrentlyAvailable = false;
  bool _loading = false;
  bool _saving = false;
  bool _showHistory = false;
  String? _error;
  String? _userId;
  int _session = 0;
  int _loadVersion = 0;

  List<DonorAvailabilityModel> get records => List.unmodifiable(_records);
  DonorAvailabilityModel? get currentRecord => _currentRecord;
  String get currentStatus => _currentStatus;
  bool get isCurrentlyAvailable => _isCurrentlyAvailable;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get showHistory => _showHistory;
  String? get errorMessage => _error;

  void setUser(String? id) {
    if (id == _userId) return;
    _userId = id;
    _session++;
    _loadVersion++;
    _records = [];
    _currentRecord = null;
    _currentStatus = 'Not Scheduled';
    _isCurrentlyAvailable = false;
    _loading = _saving = false;
    _showHistory = false;
    _error = null;
  }

  void toggleHistory() {
    _showHistory = !_showHistory;
    load();
  }

  Future<void> load({bool? includeHistory}) async {
    if (_userId == null) return;
    final version = ++_loadVersion;
    final withHistory = includeHistory ?? _showHistory;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _service.getMyAvailabilities(includeHistory: withHistory);
      if (version == _loadVersion) {
        _records = res.records;
        _currentRecord = res.currentRecord;
        _currentStatus = res.currentStatus;
        _isCurrentlyAvailable = res.isCurrentlyAvailable;
      }
    } catch (e) {
      if (version == _loadVersion) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (version == _loadVersion) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (_saving || _userId == null) return false;
    final session = _session;
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await operation();
      if (session != _session) return false;
      await load();
      return true;
    } catch (e) {
      if (session == _session) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      return false;
    } finally {
      if (session == _session) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> create({
    required String status,
    required DateTime availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) =>
      _mutate(() async {
        await _service.create(
          status: status,
          availableFrom: availableFrom,
          availableUntil: availableUntil,
          city: city,
          notes: notes,
        );
      });

  Future<bool> update(
    String id, {
    String? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) =>
      _mutate(() async {
        await _service.update(
          id: id,
          status: status,
          availableFrom: availableFrom,
          availableUntil: availableUntil,
          city: city,
          notes: notes,
        );
      });

  Future<bool> delete(String id) => _mutate(() => _service.delete(id));
}
