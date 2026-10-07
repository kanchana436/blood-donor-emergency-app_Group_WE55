import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/core/utils/validators.dart';

void main() {
  group('Donor & Recipient Form Validation Test Suite', () {
    // -------------------------------------------------------------------------
    // TEST 1: Empty Form Submission
    // -------------------------------------------------------------------------
    test('1. Empty form submission triggers required error on all fields', () {
      expect(FormValidators.validateFullName(''), 'Please enter your full name');
      expect(FormValidators.validateFullName('   '), 'Please enter your full name');
      expect(FormValidators.validateFullName(null), 'Please enter your full name');

      expect(FormValidators.validateEmail(''), 'Please enter your email address');
      expect(FormValidators.validateEmail('   '), 'Please enter your email address');
      expect(FormValidators.validateEmail(null), 'Please enter your email address');

      expect(FormValidators.validatePhone(''), 'Please enter your phone number');
      expect(FormValidators.validatePhone('   '), 'Please enter your phone number');
      expect(FormValidators.validatePhone(null), 'Please enter your phone number');

      expect(FormValidators.validateBloodGroup(null), 'Please select a blood group');
      expect(FormValidators.validateBloodGroup(''), 'Please select a blood group');
      expect(FormValidators.validateBloodGroup('   '), 'Please select a blood group');

      expect(FormValidators.validateCity(''), 'Please enter your city');
      expect(FormValidators.validateCity('   '), 'Please enter your city');
      expect(FormValidators.validateCity(null), 'Please enter your city');

      expect(FormValidators.validateLivingAddress(''), 'Please enter your living address');
      expect(FormValidators.validateLivingAddress('   '), 'Please enter your living address');
      expect(FormValidators.validateLivingAddress(null), 'Please enter your living address');

      expect(FormValidators.validateBodyWeight(''), 'Please enter your body weight');
      expect(FormValidators.validateBodyWeight('   '), 'Please enter your body weight');
      expect(FormValidators.validateBodyWeight(null), 'Please enter your body weight');
    });

    // -------------------------------------------------------------------------
    // TEST 2: Invalid Full Name
    // -------------------------------------------------------------------------
    test('2. Invalid full name rejects numbers, special characters, and short names', () {
      expect(
        FormValidators.validateFullName('John123'),
        'Full name must contain only letters and spaces',
      );
      expect(
        FormValidators.validateFullName('Alex@Silva!'),
        'Full name must contain only letters and spaces',
      );
      expect(
        FormValidators.validateFullName('Jane_Doe'),
        'Full name must contain only letters and spaces',
      );
      expect(
        FormValidators.validateFullName('A'),
        'Full name must be at least 2 characters long',
      );

      // Valid names should pass
      expect(FormValidators.validateFullName('Alexander Silva'), isNull);
      expect(FormValidators.validateFullName('Mary Jane Watson'), isNull);
      expect(FormValidators.validateFullName('  Kasun Fernando  '), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Invalid Email
    // -------------------------------------------------------------------------
    test('3. Invalid email format shows clear error message', () {
      expect(
        FormValidators.validateEmail('notanemail'),
        'Please enter a valid email address (e.g. name@example.com)',
      );
      expect(
        FormValidators.validateEmail('test@'),
        'Please enter a valid email address (e.g. name@example.com)',
      );
      expect(
        FormValidators.validateEmail('test@domain'),
        'Please enter a valid email address (e.g. name@example.com)',
      );
      expect(
        FormValidators.validateEmail('@domain.com'),
        'Please enter a valid email address (e.g. name@example.com)',
      );
      expect(
        FormValidators.validateEmail('user name@example.com'),
        'Please enter a valid email address (e.g. name@example.com)',
      );

      // Valid emails should pass
      expect(FormValidators.validateEmail('donor@lifelink.org'), isNull);
      expect(FormValidators.validateEmail('alex.silva@gmail.com'), isNull);
      expect(FormValidators.validateEmail('  john_doe+test@domain.co.uk  '), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Invalid Phone Number
    // -------------------------------------------------------------------------
    test('5. Invalid phone number rejects letters, symbols, and incorrect length', () {
      expect(
        FormValidators.validatePhone('077123456a'),
        'Phone number must contain only numbers and valid formatting',
      );
      expect(
        FormValidators.validatePhone('+94 77 123 456@'),
        'Phone number must contain only numbers and valid formatting',
      );
      expect(
        FormValidators.validatePhone('12345'),
        'Please enter a valid phone number (9-15 digits)',
      );
      expect(
        FormValidators.validatePhone('12345678901234567'),
        'Please enter a valid phone number (9-15 digits)',
      );

      // Valid phones should pass
      expect(FormValidators.validatePhone('+94 77 123 4567'), isNull);
      expect(FormValidators.validatePhone('0771234567'), isNull);
      expect(FormValidators.validatePhone('+1-555-123-4567'), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 6: Missing / Placeholder Blood Group
    // -------------------------------------------------------------------------
    test('6. Missing or placeholder blood group is strictly rejected', () {
      expect(
        FormValidators.validateBloodGroup('Select Blood Group'),
        'Please select a blood group',
      );
      expect(
        FormValidators.validateBloodGroup('--'),
        'Please select a blood group',
      );
      expect(
        FormValidators.validateBloodGroup('placeholder'),
        'Please select a blood group',
      );
      expect(
        FormValidators.validateBloodGroup('C+'),
        'Please select a valid blood group (A+, A-, B+, B-, AB+, AB-, O+, O-)',
      );
      expect(
        FormValidators.validateBloodGroup('XYZ'),
        'Please select a valid blood group (A+, A-, B+, B-, AB+, AB-, O+, O-)',
      );

      // All 8 valid blood groups must pass
      final validGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
      for (final group in validGroups) {
        expect(FormValidators.validateBloodGroup(group), isNull);
      }
    });

    // -------------------------------------------------------------------------
    // TEST 7: Invalid City
    // -------------------------------------------------------------------------
    test('7. Invalid city rejects numbers, special characters, and short names', () {
      expect(
        FormValidators.validateCity('Colombo123'),
        'City name cannot contain numbers',
      );
      expect(
        FormValidators.validateCity('Kandy#4'),
        'City name cannot contain numbers',
      );
      expect(
        FormValidators.validateCity('Galle!'),
        'City name must contain only letters and spaces',
      );
      expect(
        FormValidators.validateCity('C'),
        'City name must be at least 2 characters',
      );

      // Valid cities should pass
      expect(FormValidators.validateCity('Colombo'), isNull);
      expect(FormValidators.validateCity('Kandy'), isNull);
      expect(FormValidators.validateCity('Mount Lavinia'), isNull);
      expect(FormValidators.validateCity("St. John's"), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Empty / Incomplete Living Address
    // -------------------------------------------------------------------------
    test('8. Living address rejects incomplete entries under 5 characters', () {
      expect(
        FormValidators.validateLivingAddress('abc'),
        'Living address must be at least 5 characters',
      );
      expect(
        FormValidators.validateLivingAddress('12'),
        'Living address must be at least 5 characters',
      );
      expect(
        FormValidators.validateLivingAddress('   ab   '),
        'Living address must be at least 5 characters',
      );

      // Valid addresses should pass
      expect(FormValidators.validateLivingAddress('No 45, Galle Road, Colombo 03'), isNull);
      expect(FormValidators.validateLivingAddress('Main Street, Kandy'), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Invalid Body Weight
    // -------------------------------------------------------------------------
    test('9. Invalid body weight rejects letters, negative/zero, and outside range (50-200kg)', () {
      expect(
        FormValidators.validateBodyWeight('abc'),
        'Body weight must contain numbers only',
      );
      expect(
        FormValidators.validateBodyWeight('65kg'),
        'Body weight must contain numbers only',
      );
      expect(
        FormValidators.validateBodyWeight('0'),
        'Body weight must be greater than 0 kg',
      );
      expect(
        FormValidators.validateBodyWeight('-10'),
        'Body weight must contain numbers only',
      );
      expect(
        FormValidators.validateBodyWeight('35'),
        'Body weight must be at least 50 kg for blood donation eligibility',
      );
      expect(
        FormValidators.validateBodyWeight('49.9'),
        'Body weight must be at least 50 kg for blood donation eligibility',
      );
      expect(
        FormValidators.validateBodyWeight('250'),
        'Body weight must not exceed 200 kg',
      );
      expect(
        FormValidators.validateBodyWeight('500'),
        'Body weight must not exceed 200 kg',
      );

      // Valid weights within 50 - 200 kg must pass
      expect(FormValidators.validateBodyWeight('50'), isNull);
      expect(FormValidators.validateBodyWeight('65.5'), isNull);
      expect(FormValidators.validateBodyWeight('78'), isNull);
      expect(FormValidators.validateBodyWeight('200'), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Valid Donor Registration Data
    // -------------------------------------------------------------------------
    test('10. Valid donor registration passes all field validations completely', () {
      const name = 'Alexander Silva';
      const email = 'alex.silva@lifelink.org';
      const phone = '+94 77 123 4567';
      const bloodGroup = 'O+';
      const city = 'Colombo';
      const address = 'No 45, Galle Road, Colombo 03';
      const weight = '68.5';

      expect(FormValidators.validateFullName(name), isNull);
      expect(FormValidators.validateEmail(email), isNull);
      expect(FormValidators.validatePhone(phone), isNull);
      expect(FormValidators.validateBloodGroup(bloodGroup), isNull);
      expect(FormValidators.validateCity(city), isNull);
      expect(FormValidators.validateLivingAddress(address), isNull);
      expect(FormValidators.validateBodyWeight(weight), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 11: Sri Lankan NIC / ID Number Validation
    // -------------------------------------------------------------------------
    test('11. Sri Lankan NIC validates Old NIC (9 digits + V/X) and New NIC (12 digits)', () {
      // Required & Empty check
      expect(FormValidators.validateIdNumber(null), 'Please enter your ID Number');
      expect(FormValidators.validateIdNumber(''), 'Please enter your ID Number');
      expect(FormValidators.validateIdNumber('   '), 'Please enter your ID Number');

      // Valid Old NIC (9 digits + V or X, case-insensitive)
      expect(FormValidators.validateIdNumber('901234567V'), isNull);
      expect(FormValidators.validateIdNumber('901234567v'), isNull);
      expect(FormValidators.validateIdNumber('901234567X'), isNull);
      expect(FormValidators.validateIdNumber('901234567x'), isNull);
      expect(FormValidators.validateIdNumber('  901234567V  '), isNull);

      // Valid New NIC (exactly 12 digits)
      expect(FormValidators.validateIdNumber('199012345678'), isNull);
      expect(FormValidators.validateIdNumber('200112345678'), isNull);
      expect(FormValidators.validateIdNumber('  199012345678  '), isNull);

      // Invalid formats as specified in requirements
      expect(
        FormValidators.validateIdNumber('90123456V'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('9012345678V'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('19901234567'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('1990123456789'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );

      // Reject other letters, hyphens, spaces, and special characters
      expect(
        FormValidators.validateIdNumber('901234567A'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('901234567-V'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('1990 1234 5678'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );
      expect(
        FormValidators.validateIdNumber('901234567@'),
        'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
      );

      // Normalization check
      expect(FormValidators.normalizeIdNumber('901234567v'), '901234567V');
      expect(FormValidators.normalizeIdNumber('  901234567x  '), '901234567X');
      expect(FormValidators.normalizeIdNumber('  199012345678  '), '199012345678');
    });
  });
}
