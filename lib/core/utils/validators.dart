import '../constants/blood_types.dart';

/// Centralized Form Validators for LifeLink Donor and Recipient forms
class FormValidators {
  /// 1. Full Name Validation
  /// - Required
  /// - Must not be empty or only spaces
  /// - Allow letters and spaces
  /// - Reject numbers and inappropriate special characters
  /// - Trim unnecessary spaces
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return 'Full name must contain only letters and spaces';
    }
    if (trimmed.length < 2) {
      return 'Full name must be at least 2 characters long';
    }
    return null;
  }

  /// 2. Email Address Validation
  /// - Required
  /// - Must be a valid email format
  /// - Convert/handle email consistently
  /// - Show a clear error for invalid email addresses
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final trimmed = value.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. name@example.com)';
    }
    return null;
  }

  /// 3. Phone Number Validation
  /// - Required
  /// - Must contain only valid phone number characters
  /// - Validate the expected phone number length and format (9-15 digits)
  /// - Reject letters and invalid special characters
  /// - Show a clear error message for invalid numbers
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    final trimmed = value.trim();
    // Only allow optional leading '+', numbers, spaces, hyphens, and parentheses
    if (!RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(trimmed)) {
      return 'Phone number must contain only numbers and valid formatting';
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 9 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number (9-15 digits)';
    }
    return null;
  }

  /// 4. Blood Group Validation
  /// - Required
  /// - User must select a blood group
  /// - Do not allow the default placeholder value to be submitted
  /// - Allow only valid blood groups: A+, A-, B+, B-, AB+, AB-, O+, O-
  static String? validateBloodGroup(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select a blood group';
    }
    final trimmed = value.trim();
    if (trimmed.toLowerCase() == 'select blood group' ||
        trimmed == '--' ||
        trimmed == 'placeholder' ||
        trimmed == 'none') {
      return 'Please select a blood group';
    }
    if (!BloodTypes.all.contains(trimmed)) {
      return 'Please select a valid blood group (A+, A-, B+, B-, AB+, AB-, O+, O-)';
    }
    return null;
  }

  /// 5. City Validation
  /// - Required
  /// - Must not be empty or only spaces
  /// - Validate that the input is a reasonable city name
  /// - Reject numbers where appropriate
  static String? validateCity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your city';
    }
    final trimmed = value.trim();
    if (RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'City name cannot contain numbers';
    }
    if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(trimmed)) {
      return 'City name must contain only letters and spaces';
    }
    if (trimmed.length < 2) {
      return 'City name must be at least 2 characters';
    }
    return null;
  }

  /// 6. Living Address Validation
  /// - Required
  /// - Must not be empty or only spaces
  /// - Trim leading/trailing spaces
  /// - Set a reasonable minimum length so incomplete addresses are rejected
  static String? validateLivingAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your living address';
    }
    final trimmed = value.trim();
    if (trimmed.length < 5) {
      return 'Living address must be at least 5 characters';
    }
    return null;
  }

  /// 7. Body Weight Validation
  /// - Required
  /// - Must contain numbers only / valid numeric value
  /// - Reject letters and invalid characters
  /// - Must be greater than 0
  /// - Add a reasonable minimum and maximum range for a donor's body weight (50-200 kg)
  /// - Display the unit as kg
  /// - Prevent unrealistic values from being submitted
  static String? validateBodyWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your body weight';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) {
      return 'Body weight must contain numbers only';
    }
    final weight = double.tryParse(trimmed);
    if (weight == null || weight <= 0) {
      return 'Body weight must be greater than 0 kg';
    }
    if (weight < 50) {
      return 'Body weight must be at least 50 kg for blood donation eligibility';
    }
    if (weight > 200) {
      return 'Body weight must not exceed 200 kg';
    }
    return null;
  }

  /// ID Number Validation (Sri Lankan NIC)
  /// Accept only:
  /// - Old NIC: 9 digits followed by V or X (case-insensitive: e.g. 901234567V, 901234567X)
  /// - New NIC: exactly 12 digits (e.g. 199012345678)
  static String? validateIdNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your ID Number';
    }
    final trimmed = value.trim();
    final upper = trimmed.toUpperCase();

    final oldNicRegex = RegExp(r'^[0-9]{9}[VX]$');
    final newNicRegex = RegExp(r'^[0-9]{12}$');

    if (!oldNicRegex.hasMatch(upper) && !newNicRegex.hasMatch(upper)) {
      return 'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)';
    }
    return null;
  }

  /// Normalizes Sri Lankan NIC to uppercase
  static String normalizeIdNumber(String value) {
    return value.trim().toUpperCase();
  }

  /// Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Current Password Validation
  static String? validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your current password';
    }
    return null;
  }

  /// New Password Validation
  static String? validateNewPassword(String? value, String currentPassword) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value == currentPassword) {
      return 'New password must be different from current password';
    }
    return null;
  }

  /// Confirm Password Validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Hospital Name Validation
  /// - Required
  /// - Trimmed
  /// - Minimum 3 characters
  /// - Maximum 100 characters
  static String? validateHospitalName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the hospital name';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Hospital name must be at least 3 characters';
    }
    if (trimmed.length > 100) {
      return 'Hospital name must not exceed 100 characters';
    }
    return null;
  }
}

/// Type alias for validator referencing
typedef Validators = FormValidators;
