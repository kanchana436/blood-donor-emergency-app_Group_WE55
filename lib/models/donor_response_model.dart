class DonorResponseModel {
  final String id;
  final String requestId;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String donorBloodGroup;
  final String status; // 'Pending', 'Accepted', 'Declined'
  final DateTime respondedAt;
  final double distanceKm;
  final String? note;

  DonorResponseModel({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.donorName,
    required this.donorPhone,
    required this.donorBloodGroup,
    required this.status,
    DateTime? respondedAt,
    this.distanceKm = 2.5,
    this.note,
  }) : respondedAt = respondedAt ?? DateTime.now();

  factory DonorResponseModel.fromJson(Map<String, dynamic> json) {
    return DonorResponseModel(
      id: json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      donorId: json['donorId'] ?? '',
      donorName: json['donorName'] ?? '',
      donorPhone: json['donorPhone'] ?? '',
      donorBloodGroup: json['donorBloodGroup'] ?? 'O+',
      status: json['status'] ?? 'Pending',
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt']) ?? DateTime.now()
          : DateTime.now(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'donorId': donorId,
      'donorName': donorName,
      'donorPhone': donorPhone,
      'donorBloodGroup': donorBloodGroup,
      'status': status,
      'respondedAt': respondedAt.toIso8601String(),
      'distanceKm': distanceKm,
      'note': note,
    };
  }

  DonorResponseModel copyWith({
    String? id,
    String? requestId,
    String? donorId,
    String? donorName,
    String? donorPhone,
    String? donorBloodGroup,
    String? status,
    DateTime? respondedAt,
    double? distanceKm,
    String? note,
  }) {
    return DonorResponseModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      donorPhone: donorPhone ?? this.donorPhone,
      donorBloodGroup: donorBloodGroup ?? this.donorBloodGroup,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      note: note ?? this.note,
    );
  }
}
