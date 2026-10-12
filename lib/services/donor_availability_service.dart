import '../core/constants/api_constants.dart';
import '../models/donor_availability_model.dart';
import 'api_service.dart';

class DonorAvailabilityResponse {
  final String currentStatus;
  final bool isCurrentlyAvailable;
  final DonorAvailabilityModel? currentRecord;
  final List<DonorAvailabilityModel> records;

  DonorAvailabilityResponse({
    required this.currentStatus,
    required this.isCurrentlyAvailable,
    this.currentRecord,
    required this.records,
  });
}

class DonorAvailabilityService {
  final ApiService _api = ApiService();

  dynamic _data(ApiResponse<dynamic> response) {
    if (!response.success) {
      throw Exception(
        response.message ?? 'Unable to complete donor availability operation',
      );
    }
    return response.data;
  }

  String _path(String id) =>
      '${ApiConstants.donorAvailability}/${Uri.encodeComponent(id)}';

  Future<DonorAvailabilityResponse> getMyAvailabilities({
    bool includeHistory = false,
  }) async {
    final query = includeHistory ? '?includeHistory=true' : '';
    final response = await _api.get('${ApiConstants.donorAvailability}/me$query');

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to load availability records');
    }

    final dataList = (response.data is List)
        ? (response.data as List)
        : ((response.data is Map && response.data['data'] is List)
            ? (response.data['data'] as List)
            : <dynamic>[]);

    final records = dataList
        .map((item) => DonorAvailabilityModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    DonorAvailabilityModel? currentRecord;
    String currentStatus = 'Not Scheduled';
    bool isCurrentlyAvailable = false;

    if (response.data is Map) {
      currentStatus = (response.data['currentStatus'] as String?) ?? 'Not Scheduled';
      isCurrentlyAvailable = (response.data['isCurrentlyAvailable'] as bool?) ?? false;
      if (response.data['currentRecord'] != null && response.data['currentRecord'] is Map) {
        currentRecord = DonorAvailabilityModel.fromJson(
          Map<String, dynamic>.from(response.data['currentRecord']),
        );
      }
    }

    // Client-side fallback if server didn't supply summary directly
    if (currentRecord == null && records.isNotEmpty) {
      final active = records.where((r) => r.isEffectiveNow).toList();
      if (active.isNotEmpty) {
        currentRecord = active.first;
        currentStatus = currentRecord.status;
        isCurrentlyAvailable = currentRecord.isAvailable;
      }
    }

    return DonorAvailabilityResponse(
      currentStatus: currentStatus,
      isCurrentlyAvailable: isCurrentlyAvailable,
      currentRecord: currentRecord,
      records: records,
    );
  }

  Future<DonorAvailabilityModel> getById(String id) async {
    final response = await _api.get(_path(id));
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return DonorAvailabilityModel.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<DonorAvailabilityModel> create({
    required String status,
    required DateTime availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      'availableFrom': availableFrom.toIso8601String(),
      if (availableUntil != null) 'availableUntil': availableUntil.toIso8601String(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    final response = await _api.post(ApiConstants.donorAvailability, body);
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return DonorAvailabilityModel.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<DonorAvailabilityModel> update({
    required String id,
    String? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (availableFrom != null) 'availableFrom': availableFrom.toIso8601String(),
      if (availableUntil != null) 'availableUntil': availableUntil.toIso8601String(),
      if (city != null) 'city': city.trim(),
      if (notes != null) 'notes': notes.trim(),
    };

    final response = await _api.put(_path(id), body);
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return DonorAvailabilityModel.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<void> delete(String id) async {
    final response = await _api.delete(_path(id));
    _data(response);
  }
}
