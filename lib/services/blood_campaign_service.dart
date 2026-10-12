import '../core/constants/api_constants.dart';
import '../models/blood_campaign_model.dart';
import 'api_service.dart';

class BloodCampaignService {
  final ApiService _api = ApiService();

  dynamic _data(ApiResponse<dynamic> response) {
    if (!response.success) {
      throw Exception(
        response.message ?? 'Unable to complete blood campaign operation',
      );
    }
    return response.data;
  }

  String _path(String id) =>
      '${ApiConstants.campaigns}/${Uri.encodeComponent(id)}';

  Future<List<BloodCampaign>> getCampaigns({
    String? city,
    String? status,
    String? date,
    String? search,
  }) async {
    final queryParams = <String>[];
    if (city != null && city.trim().isNotEmpty) {
      queryParams.add('city=${Uri.encodeComponent(city.trim())}');
    }
    if (status != null && status.trim().isNotEmpty) {
      queryParams.add('status=${Uri.encodeComponent(status.trim())}');
    }
    if (date != null && date.trim().isNotEmpty) {
      queryParams.add('date=${Uri.encodeComponent(date.trim())}');
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search.trim())}');
    }

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _api.get('${ApiConstants.campaigns}$queryString');

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to load blood campaigns');
    }

    final dataList = (response.data is List)
        ? (response.data as List)
        : ((response.data is Map && response.data['data'] is List)
            ? (response.data['data'] as List)
            : <dynamic>[]);

    return dataList
        .map((item) => BloodCampaign.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BloodCampaign> getCampaignById(String id) async {
    final response = await _api.get(_path(id));
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return BloodCampaign.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<BloodCampaign> createCampaign(Map<String, dynamic> body) async {
    final response = await _api.post(ApiConstants.campaigns, body);
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return BloodCampaign.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<BloodCampaign> updateCampaign(String id, Map<String, dynamic> body) async {
    final response = await _api.put(_path(id), body);
    final data = _data(response);
    final recordMap = (data is Map && data['data'] is Map) ? data['data'] : data;
    return BloodCampaign.fromJson(Map<String, dynamic>.from(recordMap));
  }

  Future<void> deleteCampaign(String id) async {
    final response = await _api.delete(_path(id));
    _data(response);
  }
}
