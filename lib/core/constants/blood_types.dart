class BloodTypes {
  static const List<String> all = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  /// Mapping of which donor types can donate to which recipient types
  static const Map<String, List<String>> canDonateTo = {
    'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // Universal donor
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A+', 'A-', 'AB+', 'AB-'],
    'A+': ['A+', 'AB+'],
    'B-': ['B+', 'B-', 'AB+', 'AB-'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB+', 'AB-'],
    'AB+': ['AB+'], // Can only donate to AB+
  };

  /// Mapping of which donor types a recipient can receive from
  static const Map<String, List<String>> canReceiveFrom = {
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // Universal recipient
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
  };

  static bool isCompatible({required String donorGroup, required String recipientGroup}) {
    final allowed = canDonateTo[donorGroup];
    if (allowed == null) return false;
    return allowed.contains(recipientGroup);
  }
}
