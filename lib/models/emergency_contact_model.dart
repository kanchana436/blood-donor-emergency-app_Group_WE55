class EmergencyContactModel {
  final String id, userId, fullName, relationship, phone;
  final String? alternatePhone, address;
  final bool isPrimary;
  final DateTime createdAt, updatedAt;

  const EmergencyContactModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.relationship,
    required this.phone,
    this.alternatePhone,
    this.address,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) =>
      EmergencyContactModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        relationship: json['relationship'] as String,
        phone: json['phone'] as String,
        alternatePhone: json['alternatePhone'] as String?,
        address: json['address'] as String?,
        isPrimary: json['isPrimary'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
