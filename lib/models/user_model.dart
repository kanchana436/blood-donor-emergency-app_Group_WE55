class UserModel {
  final String id;
  final String idNumber;
  final String name;
  final String email;
  final String phone;
  final String role; // 'donor', 'recipient', 'manager'
  final bool isActive;
  final bool isEmailVerified;
  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.idNumber = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.isEmailVerified = false,
    this.fcmToken,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      idNumber: (json['idNumber'] ?? json['id_number'] ?? '').toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'donor',
      isActive: json['isActive'] ?? (json['status'] != 'DEACTIVATED'),
      isEmailVerified: json['isEmailVerified'] == true || json['is_email_verified'] == true,
      fcmToken: json['fcmToken'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isDeactivated => !isActive;
  String get status => isActive ? 'ACTIVE' : 'DEACTIVATED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idNumber': idNumber,
      'id_number': idNumber,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? idNumber,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    bool? isEmailVerified,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
