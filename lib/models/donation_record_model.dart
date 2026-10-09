class DonationRecordModel {
  final String id;
  final String donorId;
  final String requestId;
  final String hospitalName;
  final String patientName;
  final String bloodGroup;
  final int units;
  final DateTime donationDate;
  final String status; // 'Completed', 'Verified'
  final String? certificateUrl;

  DonationRecordModel({
    required this.id,
    required this.donorId,
    required this.requestId,
    required this.hospitalName,
    required this.patientName,
    required this.bloodGroup,
    this.units = 1,
    DateTime? donationDate,
    this.status = 'Completed',
    this.certificateUrl,
  }) : donationDate = donationDate ?? DateTime.now();

  factory DonationRecordModel.fromJson(Map<String, dynamic> json) {
    return DonationRecordModel(
      id: json['id'] ?? '',
      donorId: json['donorId'] ?? '',
      requestId: json['requestId'] ?? '',
      hospitalName: json['hospitalName'] ?? '',
      patientName: json['patientName'] ?? '',
      bloodGroup: json['bloodGroup'] ?? 'O+',
      units: json['units'] ?? 1,
      donationDate: json['donationDate'] != null
          ? DateTime.tryParse(json['donationDate']) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'Completed',
      certificateUrl: json['certificateUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donorId': donorId,
      'requestId': requestId,
      'hospitalName': hospitalName,
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'units': units,
      'donationDate': donationDate.toIso8601String(),
      'status': status,
      'certificateUrl': certificateUrl,
    };
  }
}
