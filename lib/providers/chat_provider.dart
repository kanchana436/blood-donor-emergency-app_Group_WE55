import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service;
  ChatProvider({ChatService? service}) : _service = service ?? ChatService();
  String? _session;
  int _generation = 0;
  List<ChatDonor> donors = [];
  List<ChatConversation> conversations = [];
  List<ChatMessage> messages = [];
  ChatConversation? current;
  bool loading = false,
      sending = false,
      needsVerification = false,
      hasOlder = false;
  String? error;
  void setSession(String? session) {
    if (_session == session) return;
    _session = session;
    clearAccess();
  }

  void clearAccess() {
    _generation++;
    _service.clearAccess();
    donors = [];
    conversations = [];
    messages = [];
    current = null;
    error = null;
    loading = false;
    sending = false;
    needsVerification = false;
    hasOlder = false;
  }

  Future<bool> _run(Future<void> Function(int generation) action) async {
    if (loading) return false;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action(generation);
      return generation == _generation;
    } catch (e) {
      if (generation == _generation) {
        error = e.toString().replaceFirst('Exception: ', '');
        if (e is ChatAccessException) {
          needsVerification = true;
          donors = [];
          conversations = [];
          messages = [];
          current = null;
        }
      }
      return false;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> verify(String email, String password) {
    clearAccess();
    return _run((g) async {
      await _service.verify(email, password);
      if (g != _generation) _service.clearAccess();
    });
  }

  Future<bool> loadDonors() => _run((g) async {
    final result = await _service.donors();
    if (g == _generation) donors = result;
  });
  Future<bool> loadConversations() => _run((g) async {
    final result = await _service.conversations();
    if (g == _generation) conversations = result;
  });
  Future<bool> open({String? donorId, ChatConversation? conversation}) =>
      _run((g) async {
        final result = conversation ?? await _service.open(donorId: donorId);
        final items = await _service.messages(result.id);
        if (g == _generation) {
          current = result;
          messages = items;
          hasOlder = items.length == 100;
        }
      });
  Future<bool> refresh({bool older = false}) => _run((g) async {
    final chat = current;
    if (chat == null) return;
    final items = await _service.messages(
      chat.id,
      before: older && messages.isNotEmpty ? messages.first.id : null,
    );
    if (g == _generation) {
      messages = older ? [...items, ...messages] : items;
      hasOlder = items.length == 100;
    }
    for (final m in items.where(
      (m) => !m.isRead && m.senderId != _session?.split(':').first,
    )) {
      if (g != _generation) return;
      await _service.read(m.id);
    }
  });
  Future<bool> send(String text) async {
    if (sending ||
        current == null ||
        text.trim().isEmpty ||
        text.trim().length > 2000) {
      return false;
    }
    final g = _generation;
    final id = current!.id;
    sending = true;
    error = null;
    notifyListeners();
    try {
      await _service.send(id, text.trim());
      if (g != _generation) return false;
      await refresh();
      return true;
    } catch (e) {
      if (g == _generation) {
        error = e.toString().replaceFirst('Exception: ', '');
        if (e is ChatAccessException) {
          needsVerification = true;
          messages = [];
          current = null;
        }
      }
      return false;
    } finally {
      if (g == _generation) {
        sending = false;
        notifyListeners();
      }
    }
  }
}
