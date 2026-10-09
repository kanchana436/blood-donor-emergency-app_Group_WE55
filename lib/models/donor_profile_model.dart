class DonorProfileModel {
  final String id;
  final String userId;
  final String bloodGroup;
  final bool isAvailable;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime? lastDonationDate;
  final int totalDonations;
  final int livesSaved;
  final String eligibilityStatus; // 'Eligible', 'Deferred', 'Temporary Ineligible'
  final double? weightKg;
  final String? medicalConditions;
  final String? userName;
  final String? userPhone;

  DonorProfileModel({
    required this.id,
    required this.userId,
    required this.bloodGroup,
    this.isAvailable = true,
    required this.city,
    this.address = '',
    this.latitude = 6.9271, // Default Colombo / City coords
    this.longitude = 79.8612,
    this.lastDonationDate,
    this.totalDonations = 0,
    this.livesSaved = 0,
    this.eligibilityStatus = 'Eligible',
    this.weightKg,
    this.medicalConditions,
    this.userName,
    this.userPhone,
  });

  factory DonorProfileModel.fromJson(Map<String, dynamic> json) {
    String? name = json['name'] ?? json['userName'];
    String? phone = json['phone'] ?? json['userPhone'];
    if (name == null && json['user'] != null && json['user'] is Map) {
      name = json['user']['name'];
      phone = json['user']['phone'];
    }

    return DonorProfileModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      bloodGroup: json['bloodGroup'] ?? 'O+',
      isAvailable: json['isAvailable'] ?? true,
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 79.8612,
      lastDonationDate: json['lastDonationDate'] != null
          ? DateTime.tryParse(json['lastDonationDate'])
          : null,
      totalDonations: json['totalDonations'] ?? 0,
      livesSaved: json['livesSaved'] ?? 0,
      eligibilityStatus: json['eligibilityStatus'] ?? 'Eligible',
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      medicalConditions: json['medicalConditions'],
      userName: name,
      userPhone: phone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bloodGroup': bloodGroup,
      'isAvailable': isAvailable,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'lastDonationDate': lastDonationDate?.toIso8601String(),
      'totalDonations': totalDonations,
      'livesSaved': livesSaved,
      'eligibilityStatus': eligibilityStatus,
      'weightKg': weightKg,
      'medicalConditions': medicalConditions,
      'name': userName,
      'phone': userPhone,
    };
  }

  DonorProfileModel copyWith({
    String? id,
    String? userId,
    String? bloodGroup,
    bool? isAvailable,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? lastDonationDate,
    int? totalDonations,
    int? livesSaved,
    String? eligibilityStatus,
    double? weightKg,
    String? medicalConditions,
    String? userName,
    String? userPhone,
  }) {
    return DonorProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      isAvailable: isAvailable ?? this.isAvailable,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      totalDonations: totalDonations ?? this.totalDonations,
      livesSaved: livesSaved ?? this.livesSaved,
      eligibilityStatus: eligibilityStatus ?? this.eligibilityStatus,
      weightKg: weightKg ?? this.weightKg,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
    );
  }
}
