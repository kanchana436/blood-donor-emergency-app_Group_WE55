class BloodStockModel {
  final int? notificationsSent;
  final String id;
  final String bloodGroup;
  final int availableUnits;
  final String location;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const statuses = ['Available', 'Unavailable', 'Reserved'];

  const BloodStockModel({
    this.notificationsSent,
    required this.id,
    required this.bloodGroup,
    required this.availableUnits,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BloodStockModel.fromJson(Map<String, dynamic> json) =>
      BloodStockModel(
        notificationsSent: json['notificationsSent'] as int?,
        id: json['id'] as String,
        bloodGroup: json['bloodGroup'] as String,
        availableUnits: json['availableUnits'] as int,
        location: json['location'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
