import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/blood_group_selector.dart';
import '../donor/donor_main_navigation.dart';
import '../recipient/recipient_main_navigation.dart';

class RegisterScreen extends StatefulWidget {
  final String role; // 'donor' | 'recipient' | 'manager'

  const RegisterScreen({
    super.key,
    required this.role,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _weightController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Blood group must be explicitly selected by the user (no placeholder pre-selection)
  String? _selectedBloodGroup;

  Color get _themeColor {
    return widget.role == 'donor'
        ? AppColors.donorPrimary
        : AppColors.recipientPrimary;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _weightController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // 1. Frontend Form Validation - Do not send request if validation fails
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final isDonor = widget.role == 'donor';
    final weight = isDonor && _weightController.text.trim().isNotEmpty
        ? double.tryParse(_weightController.text.trim())
        : null;

    final success = await authProvider.register(
      name: _nameController.text.trim(),
      idNumber: FormValidators.normalizeIdNumber(_idNumberController.text),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      role: widget.role,
      bloodGroup: _selectedBloodGroup,
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      weightKg: weight,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDonor
                      ? 'Donor account registered successfully!'
                      : 'Recipient account registered successfully!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );

      if (isDonor) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DonorMainNavigation()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RecipientMainNavigation()),
        );
      }
    } else {
      final errorMsg = authProvider.errorMessage ?? 'Registration failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDonor = widget.role == 'donor';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDonor ? 'Create Donor Account' : 'Create Recipient Account',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isDonor
                      ? 'Join the community of lifesavers. Quick, verified, and safe.'
                      : 'Create an account to request blood units and track emergency responses.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // 1. Full Name
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'e.g. Alexander Silva',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: FormValidators.validateFullName,
                ),
                const SizedBox(height: 18),

                // ID Number
                CustomTextField(
                  controller: _idNumberController,
                  label: 'ID Number',
                  hintText: 'e.g. 199012345678 or 901234567V',
                  prefixIcon: Icons.badge_outlined,
                  onChanged: (_) {
                    if (authProvider.errorMessage != null) {
                      authProvider.clearError();
                    }
                  },
                  validator: FormValidators.validateIdNumber,
                ),
                const SizedBox(height: 18),

                // 2. Email Address
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hintText: 'e.g. name@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (authProvider.errorMessage != null) {
                      authProvider.clearError();
                    }
                  },
                  validator: FormValidators.validateEmail,
                ),
                const SizedBox(height: 18),

                // 3. Phone Number
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hintText: 'e.g. +94 77 123 4567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: FormValidators.validatePhone,
                ),
                const SizedBox(height: 20),

                // 4. Blood Group Selection
                FormField<String>(
                  validator: (val) => FormValidators.validateBloodGroup(_selectedBloodGroup),
                  builder: (fieldState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isDonor ? 'Select Blood Group' : 'Patient Blood Group',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        BloodGroupSelector(
                          selectedGroup: _selectedBloodGroup,
                          activeColor: _themeColor,
                          onSelected: (group) {
                            setState(() {
                              _selectedBloodGroup = group;
                            });
                            fieldState.didChange(group);
                          },
                        ),
                        if (fieldState.hasError) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                              const SizedBox(width: 6),
                              Text(
                                fieldState.errorText!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 5. City
                CustomTextField(
                  controller: _cityController,
                  label: 'City',
                  hintText: 'e.g. Colombo',
                  prefixIcon: Icons.location_city_outlined,
                  validator: FormValidators.validateCity,
                ),
                const SizedBox(height: 18),

                // 6. Living Address
                CustomTextField(
                  controller: _addressController,
                  label: 'Living Address',
                  hintText: 'e.g. No 45, Galle Road, Colombo 03',
                  prefixIcon: Icons.home_outlined,
                  validator: FormValidators.validateLivingAddress,
                ),
                const SizedBox(height: 18),

                // 7. Body Weight (Required for donors)
                if (isDonor) ...[
                  CustomTextField(
                    controller: _weightController,
                    label: 'Body Weight (kg)',
                    hintText: 'e.g. 65',
                    prefixIcon: Icons.monitor_weight_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    suffixText: 'kg',
                    validator: FormValidators.validateBodyWeight,
                  ),
                  const SizedBox(height: 18),
                ],

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Minimum 6 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: FormValidators.validatePassword,
                ),
                const SizedBox(height: 18),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (value) => FormValidators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 22),

                // Backend Error Banner
                if (authProvider.errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authProvider.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                CustomButton(
                  text: 'Create Account',
                  customColor: _themeColor,
                  isLoading: authProvider.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: _themeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
