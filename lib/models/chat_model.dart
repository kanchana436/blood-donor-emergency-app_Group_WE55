class ChatDonor {
  final String userId, name, city, bloodGroup;
  ChatDonor.fromJson(Map<String, dynamic> json)
    : userId = json['userId'],
      name = json['name'],
      city = json['city'],
      bloodGroup = json['bloodGroup'];
}

class ChatConversation {
  final String id, managerId, donorId, managerName, donorName, branchName, city;
  ChatConversation.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      managerId = json['managerId'],
      donorId = json['donorId'],
      managerName = json['managerName'],
      donorName = json['donorName'],
      branchName = json['branchName'],
      city = json['city'];
}

class ChatMessage {
  final String id, conversationId, senderId, message;
  final bool isRead;
  final DateTime createdAt;
  ChatMessage.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      conversationId = json['conversationId'],
      senderId = json['senderId'],
      message = json['message'],
      isRead = json['isRead'],
      createdAt = DateTime.parse(json['createdAt']);
}
