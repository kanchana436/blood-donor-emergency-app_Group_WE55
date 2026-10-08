import 'package:flutter/foundation.dart';

import '../models/blood_stock_model.dart';
import '../services/blood_stock_service.dart';

class BloodStockProvider extends ChangeNotifier {
  BloodStockProvider({BloodStockService? service})
    : _service = service ?? BloodStockService();
  final BloodStockService _service;
  List<BloodStockModel> _stocks = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _userId;
  String? _filter;
  int _generation = 0;

  List<BloodStockModel> get stocks => List.unmodifiable(_stocks);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _error;
  String? get bloodGroupFilter => _filter;

  // ProxyProvider invokes this during rebuild; its dependents rebuild themselves.
  void setUser(String? id) {
    if (_userId == id) return;
    _userId = id;
    _generation++;
    _stocks = [];
    _loading = false;
    _saving = false;
    _error = null;
    _filter = null;
  }

  Future<void> load({String? bloodGroup}) async {
    _filter = bloodGroup;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.getAll(bloodGroup: bloodGroup);
      if (generation == _generation) _stocks = result;
    } catch (e) {
      if (generation == _generation) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (_saving) return false;
    final userId = _userId;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      if (userId != _userId) return false;
      // Refresh failure must not report a persisted write as failed.
      await load(bloodGroup: _filter);
      return true;
    } catch (e) {
      if (userId == _userId) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      return false;
    } finally {
      if (userId == _userId) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save({
    String? id,
    required String bloodGroup,
    required int availableUnits,
    required String location,
    required String status,
  }) => _mutate(() async {
    await _service.save(
      id: id,
      bloodGroup: bloodGroup,
      availableUnits: availableUnits,
      location: location,
      status: status,
    );
  });

  Future<bool> delete(String id) => _mutate(() => _service.delete(id));
}
