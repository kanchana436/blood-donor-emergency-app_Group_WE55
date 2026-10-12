class BloodCampaign {
  final String id;
  final String campaignName;
  final String? description;
  final String organizerId;
  final String organizerName;
  final String contactNumber;
  final String? email;
  final String? hospitalOrBloodBank;
  final String location;
  final String city;
  final DateTime campaignDate;
  final String startTime;
  final String endTime;
  final int? targetDonors;
  final String status;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? organizer;

  const BloodCampaign({
    required this.id,
    required this.campaignName,
    this.description,
    required this.organizerId,
    required this.organizerName,
    required this.contactNumber,
    this.email,
    this.hospitalOrBloodBank,
    required this.location,
    required this.city,
    required this.campaignDate,
    required this.startTime,
    required this.endTime,
    this.targetDonors,
    this.status = 'Upcoming',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.organizer,
  });

  bool get isUpcoming => status.toLowerCase() == 'upcoming';
  bool get isOngoing => status.toLowerCase() == 'ongoing';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  factory BloodCampaign.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['campaignDate'] != null
          ? DateTime.parse(json['campaignDate'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    DateTime? parsedUpdatedAt;
    if (json['updatedAt'] != null) {
      try {
        parsedUpdatedAt = DateTime.parse(json['updatedAt'].toString());
      } catch (_) {}
    }

    int? parsedTargetDonors;
    if (json['targetDonors'] != null) {
      parsedTargetDonors = int.tryParse(json['targetDonors'].toString());
    }

    return BloodCampaign(
      id: json['id']?.toString() ?? '',
      campaignName: json['campaignName']?.toString() ?? '',
      description: json['description']?.toString(),
      organizerId: json['organizerId']?.toString() ?? '',
      organizerName: json['organizerName']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      email: json['email']?.toString(),
      hospitalOrBloodBank: json['hospitalOrBloodBank']?.toString(),
      location: json['location']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      campaignDate: parsedDate,
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      targetDonors: parsedTargetDonors,
      status: json['status']?.toString() ?? 'Upcoming',
      isActive: json['isActive'] == null ? true : (json['isActive'] == true || json['isActive'] == 'true'),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      organizer: json['organizer'] is Map<String, dynamic> ? json['organizer'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignName': campaignName,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'contactNumber': contactNumber,
      'email': email,
      'hospitalOrBloodBank': hospitalOrBloodBank,
      'location': location,
      'city': city,
      'campaignDate': campaignDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'targetDonors': targetDonors,
      'status': status,
      'isActive': isActive,
    };
  }

  BloodCampaign copyWith({
    String? id,
    String? campaignName,
    String? description,
    String? organizerId,
    String? organizerName,
    String? contactNumber,
    String? email,
    String? hospitalOrBloodBank,
    String? location,
    String? city,
    DateTime? campaignDate,
    String? startTime,
    String? endTime,
    int? targetDonors,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? organizer,
  }) {
    return BloodCampaign(
      id: id ?? this.id,
      campaignName: campaignName ?? this.campaignName,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      hospitalOrBloodBank: hospitalOrBloodBank ?? this.hospitalOrBloodBank,
      location: location ?? this.location,
      city: city ?? this.city,
      campaignDate: campaignDate ?? this.campaignDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      targetDonors: targetDonors ?? this.targetDonors,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizer: organizer ?? this.organizer,
    );
  }
}
