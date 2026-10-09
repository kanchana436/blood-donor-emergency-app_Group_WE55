class VerificationQueueModel {
  static const statuses = ['Pending', 'Approved', 'Rejected'];
  final String id, submittedById, verificationType, title, status;
  final String? referenceId, description, managerNote, reviewedById;
  final Map<String, dynamic> oldValues, newValues;
  final List<String> changedFields;
  final String? donorName, donorIdNumber, donorPhone, donorEmail;
  String get typeLabel => verificationType == 'DonorProfileUpdate' ? 'Donor Profile Update' : 'Donor Profile Verification';
  static String fieldLabel(String field) => const {
    'name': 'Full Name', 'idNumber': 'NIC / ID Number', 'phone': 'Phone Number',
    'email': 'Email Address', 'bloodGroup': 'Blood Group', 'city': 'City / Region',
    'latitude': 'Latitude', 'longitude': 'Longitude', 'address': 'Address', 'weightKg': 'Body Weight (kg)', 'medicalConditions': 'Medical Conditions',
  }[field] ?? field;
  static String displayValue(dynamic value) => value == null || value.toString().isEmpty ? 'Not provided' : value.toString();
  final DateTime? reviewedAt;
  final DateTime createdAt, updatedAt;
  const VerificationQueueModel({required this.id, required this.submittedById,
    required this.verificationType, required this.title, required this.status,
    this.referenceId, this.description, this.managerNote, this.reviewedById,
    this.reviewedAt, required this.createdAt, required this.updatedAt,
    this.oldValues = const {}, this.newValues = const {}, this.changedFields = const [],
    this.donorName, this.donorIdNumber, this.donorPhone, this.donorEmail});
  factory VerificationQueueModel.fromJson(Map<String, dynamic> json) => VerificationQueueModel(
    oldValues: Map<String, dynamic>.from(json['oldValues'] ?? {}),
    newValues: Map<String, dynamic>.from(json['newValues'] ?? {}),
    changedFields: List<String>.from(json['changedFields'] ?? []),
    donorName: json['submittedBy']?['name'] as String?,
    donorIdNumber: json['submittedBy']?['idNumber'] as String?,
    donorPhone: json['submittedBy']?['phone'] as String?,
    donorEmail: json['submittedBy']?['email'] as String?,
    id: json['id'] as String, submittedById: json['submittedById'] as String,
    verificationType: json['verificationType'] as String, title: json['title'] as String,
    status: json['status'] as String, referenceId: json['referenceId'] as String?,
    description: json['description'] as String?, managerNote: json['managerNote'] as String?,
    reviewedById: json['reviewedById'] as String?,
    reviewedAt: json['reviewedAt'] == null ? null : DateTime.parse(json['reviewedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String), updatedAt: DateTime.parse(json['updatedAt'] as String));
}
