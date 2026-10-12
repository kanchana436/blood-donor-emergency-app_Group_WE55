import '../core/constants/api_constants.dart';
import '../models/emergency_contact_model.dart';
import 'api_service.dart';

class EmergencyContactService {
  final ApiService _api = ApiService();
  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (RegExp(r'^0[0-9]{9}$').hasMatch(digits)) {
      digits = '94${digits.substring(1)}';
    }
    return digits;
  }

  dynamic _data(ApiResponse<dynamic> response) {
    if (!response.success) {
      throw Exception(
        response.message ?? 'Unable to complete emergency contact operation',
      );
    }
    return response.data;
  }

  String _path(String id) =>
      '${ApiConstants.emergencyContacts}/${Uri.encodeComponent(id)}';
  Future<List<EmergencyContactModel>> getAll() async {
    final data = _data(await _api.get(ApiConstants.emergencyContacts)) as List;
    return data
        .map(
          (item) =>
              EmergencyContactModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<EmergencyContactModel> getById(String id) async =>
      EmergencyContactModel.fromJson(
        Map<String, dynamic>.from(_data(await _api.get(_path(id)))),
      );
  Future<EmergencyContactModel> save({
    String? id,
    required Map<String, dynamic> fields,
  }) async {
    final body = Map<String, dynamic>.from(fields);
    for (final field in [
      'fullName',
      'relationship',
      'phone',
      'alternatePhone',
      'address',
    ]) {
      if (body[field] is String) {
        final value = (body[field] as String).trim();
        body[field] =
            value.isEmpty && ['alternatePhone', 'address'].contains(field)
            ? null
            : value;
      }
    }
    for (final field in ['phone', 'alternatePhone']) {
      if (body[field] is String) {
        body[field] = normalizePhone(body[field] as String);
      }
    }
    final response = id == null
        ? await _api.post(ApiConstants.emergencyContacts, body)
        : await _api.patch(_path(id), body);
    return EmergencyContactModel.fromJson(
      Map<String, dynamic>.from(_data(response)),
    );
  }

  Future<void> delete(String id) async {
    _data(await _api.delete(_path(id)));
  }
}
