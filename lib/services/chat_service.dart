import '../models/chat_model.dart';
import 'api_service.dart';

class ChatAccessException implements Exception {
  final String message;
  ChatAccessException(this.message);
  @override
  String toString() => message;
}

class ChatService {
  final ApiService _api = ApiService();
  // Elevated token exists in memory only and never replaces the regular JWT.
  String? _chatToken;
  DateTime? _expiresAt;
  void clearAccess() {
    _chatToken = null;
    _expiresAt = null;
  }

  bool get hasManagerAccess =>
      _chatToken != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);
  Map<String, String> get _headers =>
      _chatToken == null ? {} : {'X-Manager-Chat-Token': _chatToken!};
  dynamic _data(ApiResponse<dynamic> response) {
    if (response.statusCode == 401) {
      clearAccess();
      throw ChatAccessException(response.message ?? 'Please verify again');
    }
    if (!response.success) {
      throw Exception(response.message ?? 'Chat operation failed');
    }
    return response.data;
  }

  Future<void> verify(String email, String password) async {
    clearAccess();
    final data = _data(
      await _api.post('/chat/manager/reauth', {
        'email': email,
        'password': password,
      }),
    );
    _chatToken = data['token'];
    _expiresAt = DateTime.now().add(Duration(seconds: data['expiresIn']));
  }

  Future<List<ChatDonor>> donors() async =>
      (_data(await _api.get('/chat/manager/donors', headers: _headers)) as List)
          .map((j) => ChatDonor.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<List<ChatConversation>> conversations() async =>
      (_data(await _api.get('/chat/conversations', headers: _headers)) as List)
          .map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<ChatConversation> open({String? donorId}) async =>
      ChatConversation.fromJson(
        Map<String, dynamic>.from(
          _data(
            await _api.post(
              '/chat/conversations',
              donorId == null ? {} : {'donorId': donorId},
              headers: _headers,
            ),
          ),
        ),
      );
  Future<List<ChatMessage>> messages(String id, {String? before}) async {
    final path = Uri(
      path: '/chat/conversations/$id/messages',
      queryParameters: before == null ? null : {'before': before},
    ).toString();
    return (_data(await _api.get(path, headers: _headers)) as List)
        .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<void> send(String id, String text) async {
    _data(
      await _api.post('/chat/conversations/$id/messages', {
        'message': text,
      }, headers: _headers),
    );
  }

  Future<void> read(String id) async {
    _data(await _api.patch('/chat/messages/$id/read', {}, headers: _headers));
  }
}
