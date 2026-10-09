import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = ApiConstants.baseUrl;
  String? _authToken;

  String get baseUrl => _baseUrl;
  String? get authToken => _authToken;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString(ApiConstants.tokenKey);
      final savedUrl = prefs.getString(ApiConstants.baseUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = savedUrl;
      }
    } catch (_) {
      // Graceful fallback if SharedPreferences is not supported on this platform
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.baseUrlKey, url);
    } catch (_) {}
  }

  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(ApiConstants.tokenKey, token);
      } else {
        await prefs.remove(ApiConstants.tokenKey);
      }
    } catch (_) {}
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<ApiResponse<dynamic>> get(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
      );
    }
  }

  Future<ApiResponse<dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
      );
    }
  }

  Future<ApiResponse<dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http
          .put(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
      );
    }
  }

  Future<ApiResponse<dynamic>> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http
          .patch(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
      );
    }
  }

  Future<ApiResponse<dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http
          .delete(uri, headers: _buildHeaders())
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
      );
    }
  }

  ApiResponse<dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: decoded['data'] ?? decoded,
          message: decoded['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          data: decoded,
          message: decoded['message'] ?? 'Request failed with code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (_) {
      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: 'Response status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}
