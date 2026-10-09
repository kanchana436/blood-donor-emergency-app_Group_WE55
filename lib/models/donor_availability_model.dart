class DonorAvailabilityModel {
  final String id;
  final String donorId;
  final String status;
  final DateTime availableFrom;
  final DateTime? availableUntil;
  final String? city;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DonorAvailabilityModel({
    required this.id,
    required this.donorId,
    required this.status,
    required this.availableFrom,
    this.availableUntil,
    this.city,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAvailable => status == 'Available';

  bool get isEffectiveNow {
    if (!isActive) return false;
    final now = DateTime.now();
    final from = availableFrom;
    final until = availableUntil;
    return (now.isAfter(from) || now.isAtSameMomentAs(from)) &&
        (until == null || now.isBefore(until) || now.isAtSameMomentAs(until));
  }

  bool get isExpired {
    if (availableUntil == null) return false;
    return DateTime.now().isAfter(availableUntil!);
  }

  bool get isFuture {
    return DateTime.now().isBefore(availableFrom);
  }

  factory DonorAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return DonorAvailabilityModel(
      id: json['id'] as String,
      donorId: json['donorId'] as String,
      status: (json['status'] as String?) ?? 'Available',
      availableFrom: DateTime.parse(json['availableFrom'] as String),
      availableUntil: json['availableUntil'] != null
          ? DateTime.parse(json['availableUntil'] as String)
          : null,
      city: json['city'] as String?,
      notes: json['notes'] as String?,
      isActive: (json['isActive'] as bool?) ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'donorId': donorId,
        'status': status,
        'availableFrom': availableFrom.toIso8601String(),
        'availableUntil': availableUntil?.toIso8601String(),
        'city': city,
        'notes': notes,
        'isActive': isActive,
      };

  DonorAvailabilityModel copyWith({
    String? id,
    String? donorId,
    String? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? city,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DonorAvailabilityModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      status: status ?? this.status,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
