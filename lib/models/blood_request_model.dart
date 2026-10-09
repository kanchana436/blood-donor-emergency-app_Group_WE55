import 'donor_response_model.dart';

class BloodRequestModel {
  final String id;
  final String requesterId;
  final String requesterName;
  final String patientName;
  final String bloodGroup;
  final int unitsRequired;
  final String urgency; // 'Emergency', 'Urgent', 'Standard'
  final String hospitalName;
  final String hospitalAddress;
  final double latitude;
  final double longitude;
  final String contactPhone;
  final String additionalNotes;
  final String status; // 'Open', 'InProgress', 'Fulfilled', 'Cancelled'
  final DateTime createdAt;
  final DateTime? requiredBefore;
  final int matchedDonorsCount;
  final int acceptedDonorsCount;
  final List<DonorResponseModel> matchedDonors;

  BloodRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsRequired,
    required this.urgency,
    required this.hospitalName,
    required this.hospitalAddress,
    this.latitude = 6.9271,
    this.longitude = 79.8612,
    required this.contactPhone,
    this.additionalNotes = '',
    this.status = 'Open',
    DateTime? createdAt,
    this.requiredBefore,
    this.matchedDonorsCount = 0,
    this.acceptedDonorsCount = 0,
    this.matchedDonors = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory BloodRequestModel.fromJson(Map<String, dynamic> json) {
    var donorsList = <DonorResponseModel>[];
    if (json['matchedDonors'] != null && json['matchedDonors'] is List) {
      donorsList = (json['matchedDonors'] as List)
          .map((d) => DonorResponseModel.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    return BloodRequestModel(
      id: json['id'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      patientName: json['patientName'] ?? '',
      bloodGroup: json['bloodGroup'] ?? 'O+',
      unitsRequired: json['unitsRequired'] ?? 1,
      urgency: json['urgency'] ?? 'Emergency',
      hospitalName: json['hospitalName'] ?? '',
      hospitalAddress: json['hospitalAddress'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 79.8612,
      contactPhone: json['contactPhone'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
      status: json['status'] ?? 'Open',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      requiredBefore: json['requiredBefore'] != null
          ? DateTime.tryParse(json['requiredBefore'])
          : null,
      matchedDonorsCount: json['matchedDonorsCount'] ?? donorsList.length,
      acceptedDonorsCount: json['acceptedDonorsCount'] ??
          donorsList.where((d) => d.status.toLowerCase() == 'accepted').length,
      matchedDonors: donorsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'unitsRequired': unitsRequired,
      'urgency': urgency,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'latitude': latitude,
      'longitude': longitude,
      'contactPhone': contactPhone,
      'additionalNotes': additionalNotes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'requiredBefore': requiredBefore?.toIso8601String(),
      'matchedDonorsCount': matchedDonorsCount,
      'acceptedDonorsCount': acceptedDonorsCount,
      'matchedDonors': matchedDonors.map((d) => d.toJson()).toList(),
    };
  }

  BloodRequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? patientName,
    String? bloodGroup,
    int? unitsRequired,
    String? urgency,
    String? hospitalName,
    String? hospitalAddress,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? additionalNotes,
    String? status,
    DateTime? createdAt,
    DateTime? requiredBefore,
    int? matchedDonorsCount,
    int? acceptedDonorsCount,
    List<DonorResponseModel>? matchedDonors,
  }) {
    return BloodRequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      patientName: patientName ?? this.patientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      unitsRequired: unitsRequired ?? this.unitsRequired,
      urgency: urgency ?? this.urgency,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactPhone: contactPhone ?? this.contactPhone,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      requiredBefore: requiredBefore ?? this.requiredBefore,
      matchedDonorsCount: matchedDonorsCount ?? this.matchedDonorsCount,
      acceptedDonorsCount: acceptedDonorsCount ?? this.acceptedDonorsCount,
      matchedDonors: matchedDonors ?? this.matchedDonors,
    );
  }
}
