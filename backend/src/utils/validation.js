/**
 * LifeLink Validation Utilities
 * Validates Donor and Recipient form fields on the backend.
 */

const VALID_BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const VALID_URGENCIES = ['Emergency', 'Urgent', 'Standard'];

/**
 * 1. Full Name Validation
 * - Required
 * - Must not be empty or only spaces
 * - Allow letters and spaces
 * - Reject numbers and inappropriate special characters
 * - Trim unnecessary spaces
 */
function validateFullName(name) {
  if (name === undefined || name === null || typeof name !== 'string') {
    return { valid: false, message: 'Please enter your full name' };
  }
  const trimmed = name.trim().replace(/\s+/g, ' ');
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your full name' };
  }
  if (!/^[a-zA-Z\s]+$/.test(trimmed)) {
    return { valid: false, message: 'Full name must contain only letters and spaces' };
  }
  if (trimmed.length < 2) {
    return { valid: false, message: 'Full name must be at least 2 characters long' };
  }
  return { valid: true, value: trimmed };
}

/**
 * 2. Email Address Validation
 * - Required
 * - Must be a valid email format
 * - Convert/handle email consistently
 * - Show a clear error for invalid email addresses
 */
function validateEmail(email) {
  if (email === undefined || email === null || typeof email !== 'string') {
    return { valid: false, message: 'Please enter your email address' };
  }
  const trimmed = email.trim().toLowerCase();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your email address' };
  }
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  if (!emailRegex.test(trimmed)) {
    return { valid: false, message: 'Please enter a valid email address (e.g. name@example.com)' };
  }
  return { valid: true, value: trimmed };
}

/**
 * 3. Phone Number Validation
 * - Required
 * - Must contain only valid phone number characters
 * - Validate the expected phone number length and format (9-15 digits)
 * - Reject letters and invalid special characters
 */
function validatePhone(phone) {
  if (phone === undefined || phone === null || typeof phone !== 'string') {
    return { valid: false, message: 'Please enter your phone number' };
  }
  const trimmed = phone.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your phone number' };
  }
  // Allow optional leading '+', numbers, spaces, hyphens, and parentheses
  if (!/^\+?[0-9\s\-()]+$/.test(trimmed)) {
    return { valid: false, message: 'Phone number must contain only numbers and valid formatting' };
  }
  const digitsOnly = trimmed.replace(/[^0-9]/g, '');
  if (digitsOnly.length < 9 || digitsOnly.length > 15) {
    return { valid: false, message: 'Please enter a valid phone number (9-15 digits)' };
  }
  return { valid: true, value: trimmed };
}

/**
 * 4. Blood Group Validation
 * - Required
 * - User must select a blood group
 * - Do not allow the default placeholder value to be submitted
 * - Allow only valid blood groups: A+, A-, B+, B-, AB+, AB-, O+, O-
 */
function validateBloodGroup(bloodGroup) {
  if (bloodGroup === undefined || bloodGroup === null || typeof bloodGroup !== 'string') {
    return { valid: false, message: 'Please select a blood group' };
  }
  const trimmed = bloodGroup.trim();
  if (
    trimmed.length === 0 ||
    trimmed.toLowerCase() === 'select blood group' ||
    trimmed === '--' ||
    trimmed === 'placeholder'
  ) {
    return { valid: false, message: 'Please select a blood group' };
  }
  if (!VALID_BLOOD_GROUPS.includes(trimmed)) {
    return {
      valid: false,
      message: 'Please select a valid blood group (A+, A-, B+, B-, AB+, AB-, O+, O-)',
    };
  }
  return { valid: true, value: trimmed };
}

/**
 * 5. City Validation
 * - Required
 * - Must not be empty or only spaces
 * - Validate that the input is a reasonable city name
 * - Reject numbers where appropriate
 */
function validateCity(city) {
  if (city === undefined || city === null || typeof city !== 'string') {
    return { valid: false, message: 'Please enter your city' };
  }
  const trimmed = city.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your city' };
  }
  if (/[0-9]/.test(trimmed)) {
    return { valid: false, message: 'City name cannot contain numbers' };
  }
  if (!/^[a-zA-Z\s.'-]+$/.test(trimmed)) {
    return { valid: false, message: 'City name must contain only letters and spaces' };
  }
  if (trimmed.length < 2) {
    return { valid: false, message: 'City name must be at least 2 characters' };
  }
  return { valid: true, value: trimmed };
}

/**
 * 6. Living Address Validation
 * - Required
 * - Must not be empty or only spaces
 * - Trim leading/trailing spaces
 * - Set a reasonable minimum length so incomplete addresses are rejected
 */
function validateLivingAddress(address) {
  if (address === undefined || address === null || typeof address !== 'string') {
    return { valid: false, message: 'Please enter your living address' };
  }
  const trimmed = address.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your living address' };
  }
  if (trimmed.length < 5) {
    return { valid: false, message: 'Living address must be at least 5 characters' };
  }
  return { valid: true, value: trimmed };
}

/**
 * 7. Body Weight Validation
 * - Required
 * - Must contain numbers only / valid numeric value
 * - Reject letters and invalid characters
 * - Must be greater than 0
 * - Add a reasonable minimum and maximum range for a donor's body weight (50 - 200 kg)
 * - Display the unit as kg
 * - Prevent unrealistic values from being submitted
 */
function validateBodyWeight(weight) {
  if (weight === undefined || weight === null || weight === '') {
    return { valid: false, message: 'Please enter your body weight' };
  }
  const stringVal = String(weight).trim();
  if (stringVal.length === 0) {
    return { valid: false, message: 'Please enter your body weight' };
  }
  if (!/^\d+(\.\d+)?$/.test(stringVal)) {
    return { valid: false, message: 'Body weight must contain numbers only' };
  }
  const numericVal = parseFloat(stringVal);
  if (isNaN(numericVal) || numericVal <= 0) {
    return { valid: false, message: 'Body weight must be greater than 0 kg' };
  }
  if (numericVal < 50) {
    return {
      valid: false,
      message: 'Body weight must be at least 50 kg for blood donation eligibility',
    };
  }
  if (numericVal > 200) {
    return { valid: false, message: 'Body weight must not exceed 200 kg' };
  }
  return { valid: true, value: numericVal };
}

/**
 * Sri Lankan NIC / ID Number Validation
 * Accept only:
 * - Old NIC: 9 digits followed by V or X (case-insensitive: e.g. 901234567V, 901234567X)
 * - New NIC: exactly 12 digits (e.g. 199012345678)
 */
function validateIdNumber(idNumber) {
  if (idNumber === undefined || idNumber === null || typeof idNumber !== 'string') {
    return { valid: false, message: 'Please enter your ID Number' };
  }
  const trimmed = idNumber.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please enter your ID Number' };
  }
  const upper = trimmed.toUpperCase();
  const oldNicRegex = /^[0-9]{9}[VX]$/;
  const newNicRegex = /^[0-9]{12}$/;

  if (!oldNicRegex.test(upper) && !newNicRegex.test(upper)) {
    return {
      valid: false,
      message: 'Please enter a valid Sri Lankan NIC (e.g. 901234567V or 199012345678)',
    };
  }
  return { valid: true, value: upper };
}

/**
 * Password Validation
 * - Required
 * - Minimum 6 characters
 */
function validatePassword(password, fieldName = 'Password') {
  if (password === undefined || password === null || typeof password !== 'string') {
    return { valid: false, message: `${fieldName} is required` };
  }
  const trimmed = password.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: `${fieldName} is required` };
  }
  if (password.length < 6) {
    return { valid: false, message: `${fieldName} must be at least 6 characters` };
  }
  return { valid: true, value: password };
}

/**
 * Units Required Validation
 * - Required
 * - Must be a whole number from 1 to 10
 */
function validateUnitsRequired(units) {
  if (units === undefined || units === null || units === '') {
    return { valid: false, message: 'Units required is required' };
  }
  const stringVal = String(units).trim();
  if (stringVal.length === 0) {
    return { valid: false, message: 'Units required is required' };
  }
  if (!/^\d+$/.test(stringVal)) {
    return { valid: false, message: 'Units required must be a whole number' };
  }
  const numericVal = parseInt(stringVal, 10);
  if (numericVal < 1 || numericVal > 10) {
    return { valid: false, message: 'Units required must be between 1 and 10' };
  }
  return { valid: true, value: numericVal };
}

/**
 * Urgency Level Validation
 * - Required
 * - Must be one of: Emergency, Urgent, Standard
 */
function validateUrgency(urgency) {
  if (urgency === undefined || urgency === null || typeof urgency !== 'string') {
    return { valid: false, message: 'Please select an urgency level' };
  }
  const trimmed = urgency.trim();
  if (trimmed.length === 0) {
    return { valid: false, message: 'Please select an urgency level' };
  }
  const matched = VALID_URGENCIES.find(
    (u) => u.toLowerCase() === trimmed.toLowerCase()
  );
  if (!matched) {
    return {
      valid: false,
      message: 'Urgency must be one of: Emergency, Urgent, Standard',
    };
  }
  return { valid: true, value: matched };
}

module.exports = {
  VALID_BLOOD_GROUPS,
  VALID_URGENCIES,
  validateFullName,
  validateEmail,
  validatePhone,
  validateBloodGroup,
  validateCity,
  validateLivingAddress,
  validateBodyWeight,
  validateIdNumber,
  validatePassword,
  validateUnitsRequired,
  validateUrgency,
};

