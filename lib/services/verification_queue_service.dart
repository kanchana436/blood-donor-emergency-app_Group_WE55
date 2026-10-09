import '../core/constants/api_constants.dart';
import '../models/verification_queue_model.dart';
import 'api_service.dart';
class VerificationQueueService {
  final ApiService _api = ApiService();
  static const endpoint = ApiConstants.verificationQueue;
  dynamic _data(ApiResponse<dynamic> response) {
    if (!response.success) throw Exception(response.message ?? 'Verification operation failed');
    return response.data;
  }
  VerificationQueueModel _model(dynamic data) => VerificationQueueModel.fromJson(Map<String, dynamic>.from(data));
  Future<List<VerificationQueueModel>> getAll({String? status}) async {
    final path = Uri(path: endpoint, queryParameters: status == null ? null : {'status': status}).toString();
    return (_data(await _api.get(path)) as List).map(_model).toList();
  }
  Future<VerificationQueueModel> getById(String id) async => _model(_data(await _api.get('$endpoint/${Uri.encodeComponent(id)}')));
  Future<VerificationQueueModel> submitDonorVerification() async => _model(_data(await _api.post(endpoint, {})));
  Future<VerificationQueueModel?> getMyVerification() async {
    final records = (_data(await _api.get('$endpoint/mine')) as List).map(_model).toList();
    if (records.isEmpty) return null;
    final updates = records.where((item) => item.verificationType == 'DonorProfileUpdate').toList();
    final relevant = updates.isEmpty ? records : updates;
    // Prefer profile changes over older manual verification requests.
    return relevant.firstWhere((item) => item.status == 'Pending', orElse: () => relevant.first);
  }
  Future<VerificationQueueModel> review(String id, String status, String? note) async => _model(_data(await _api.patch('$endpoint/${Uri.encodeComponent(id)}', {'status': status, 'managerNote': note})));
  Future<void> delete(String id) async { _data(await _api.delete('$endpoint/${Uri.encodeComponent(id)}')); }
}
