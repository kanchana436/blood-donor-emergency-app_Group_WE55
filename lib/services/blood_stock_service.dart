import '../core/constants/api_constants.dart';
import '../models/blood_stock_model.dart';
import 'api_service.dart';

class BloodStockService {
  final ApiService _api = ApiService();

  dynamic _data(ApiResponse<dynamic> response) {
    if (!response.success) {
      throw Exception(
        response.message ?? 'Unable to complete blood stock operation',
      );
    }
    return response.data;
  }

  Future<List<BloodStockModel>> getAll({String? bloodGroup}) async {
    final endpoint = Uri(
      path: ApiConstants.bloodStock,
      queryParameters: bloodGroup == null ? null : {'bloodGroup': bloodGroup},
    ).toString();
    final data = _data(await _api.get(endpoint)) as List;
    return data
        .map(
          (item) => BloodStockModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<BloodStockModel> getById(String id) async => BloodStockModel.fromJson(
    Map<String, dynamic>.from(
      _data(
        await _api.get('${ApiConstants.bloodStock}/${Uri.encodeComponent(id)}'),
      ),
    ),
  );

  Future<BloodStockModel> save({
    String? id,
    required String bloodGroup,
    required int availableUnits,
    required String location,
    required String status,
  }) async {
    final body = {
      'bloodGroup': bloodGroup,
      'availableUnits': availableUnits,
      'location': location.trim(),
      'status': status,
    };
    final response = id == null
        ? await _api.post(ApiConstants.bloodStock, body)
        : await _api.patch(
            '${ApiConstants.bloodStock}/${Uri.encodeComponent(id)}',
            body,
          );
    return BloodStockModel.fromJson(Map<String, dynamic>.from(_data(response)));
  }

  Future<void> delete(String id) async {
    _data(
      await _api.delete(
        '${ApiConstants.bloodStock}/${Uri.encodeComponent(id)}',
      ),
    );
  }
}
