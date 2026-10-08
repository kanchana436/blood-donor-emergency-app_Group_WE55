class VerificationQueueModel {
  static const statuses = ['Pending', 'Approved', 'Rejected'];
  final String id, submittedById, verificationType, title, status;
  final String? referenceId, description, managerNote, reviewedById;
  final DateTime? reviewedAt;
  final DateTime createdAt, updatedAt;
  const VerificationQueueModel({required this.id, required this.submittedById,
    required this.verificationType, required this.title, required this.status,
    this.referenceId, this.description, this.managerNote, this.reviewedById,
    this.reviewedAt, required this.createdAt, required this.updatedAt});
  factory VerificationQueueModel.fromJson(Map<String, dynamic> json) => VerificationQueueModel(
    id: json['id'] as String, submittedById: json['submittedById'] as String,
    verificationType: json['verificationType'] as String, title: json['title'] as String,
    status: json['status'] as String, referenceId: json['referenceId'] as String?,
    description: json['description'] as String?, managerNote: json['managerNote'] as String?,
    reviewedById: json['reviewedById'] as String?,
    reviewedAt: json['reviewedAt'] == null ? null : DateTime.parse(json['reviewedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String), updatedAt: DateTime.parse(json['updatedAt'] as String));
}
