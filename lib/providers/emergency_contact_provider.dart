import 'package:flutter/foundation.dart';

import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';

class EmergencyContactProvider extends ChangeNotifier {
  EmergencyContactProvider({EmergencyContactService? service})
    : _service = service ?? EmergencyContactService();
  final EmergencyContactService _service;
  List<EmergencyContactModel> _contacts = [];
  bool _loading = false, _saving = false;
  String? _error, _userId;
  int _session = 0, _loadVersion = 0;
  List<EmergencyContactModel> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _error;
  void setUser(String? id) {
    if (id == _userId) return;
    _userId = id;
    _session++;
    _loadVersion++;
    _contacts = [];
    _loading = _saving = false;
    _error = null;
  }

  Future<void> load() async {
    if (_userId == null) return;
    final version = ++_loadVersion;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final contacts = await _service.getAll();
      if (version == _loadVersion) _contacts = contacts;
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
      await load(); // A refresh error must not misreport a persisted write as failed.
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

  Future<bool> save({String? id, required Map<String, dynamic> fields}) =>
      _mutate(() async {
        await _service.save(id: id, fields: fields);
      });
  Future<bool> setPrimary(EmergencyContactModel contact, bool value) =>
      save(id: contact.id, fields: {'isPrimary': value});
  Future<bool> delete(String id) => _mutate(() => _service.delete(id));
}
