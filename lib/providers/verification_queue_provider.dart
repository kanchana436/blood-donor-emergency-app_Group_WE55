import 'package:flutter/foundation.dart';

import '../models/verification_queue_model.dart';
import '../services/verification_queue_service.dart';

class VerificationQueueProvider extends ChangeNotifier {
  VerificationQueueProvider({VerificationQueueService? service})
    : _service = service ?? VerificationQueueService();
  final VerificationQueueService _service;
  List<VerificationQueueModel> _items = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _userId;
  String? _filter;
  int _generation = 0;
  int _mineGeneration = 0;
  int _accountGeneration = 0;
  VerificationQueueModel? _myVerification;
  bool _mineLoading = false;
  bool _mineLoaded = false;
  String? _mineError;
  VerificationQueueModel? get myVerification => _myVerification;
  bool get isLoadingMyVerification => _mineLoading;
  bool get hasLoadedMyVerification => _mineLoaded;
  String? get myVerificationError => _mineError;

  List<VerificationQueueModel> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _error;
  String? get statusFilter => _filter;

  // ProxyProvider invokes this during rebuild; its dependents rebuild themselves.
  void setUser(String? id) {
    if (_userId == id) return;
    _userId = id;
    _generation++;
    _mineGeneration++;
    _accountGeneration++;
    _myVerification = null;
    _mineLoading = false;
    _mineLoaded = false;
    _mineError = null;
    _items = [];
    _loading = false;
    _saving = false;
    _error = null;
    _filter = null;
  }

  Future<void> load({String? status}) async {
    _filter = status;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.getAll(status: status);
      if (generation == _generation) _items = result;
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
      await load(status: _filter);
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

  Future<void> fetchMyVerificationStatus() async {
    final generation = ++_mineGeneration;
    _mineLoading = true;
    _mineError = null;
    notifyListeners();
    try {
      final record = await _service.getMyVerification();
      if (generation == _mineGeneration) {
        _myVerification = record;
        _mineLoaded = true;
      }
    } catch (e) {
      if (generation == _mineGeneration) _mineError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (generation == _mineGeneration) {
        _mineLoading = false;
        notifyListeners();
      }
    }
  }
  Future<bool> submitDonorVerification() async {
    if (_saving || _mineLoading) return false;
    final generation = _accountGeneration;
    _saving = true;
    _mineError = null;
    notifyListeners();
    try {
      final record = await _service.submitDonorVerification();
      if (generation != _accountGeneration) return false;
      _myVerification = record;
      _mineLoaded = true;
      return true;
    } catch (e) {
      if (generation == _accountGeneration) _mineError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      // Account changes reset saving and invalidate this response.
      if (generation == _accountGeneration) {
        _saving = false;
        notifyListeners();
      }
    }
  }
  Future<bool> review(String id, String status, String? note) => _mutate(() async {
    await _service.review(id, status, note);
  });
  Future<VerificationQueueModel> getById(String id) => _service.getById(id);
  Future<bool> delete(String id) => _mutate(() => _service.delete(id));
}
