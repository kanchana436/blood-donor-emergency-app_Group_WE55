import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String resetToken;
  final Color themeColor;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
    this.themeColor = AppColors.donorPrimary,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    // Validate form inputs
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    final success = await authProvider.resetPassword(
      resetToken: widget.resetToken,
      newPassword: newPass,
      confirmPassword: confirmPass,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Password reset successfully. Please log in with your new password.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );

      // Return to Login screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  authProvider.errorMessage ?? 'Failed to reset password.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Header
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      color: widget.themeColor,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Create New Password',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Set a secure new password for ${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // New Password Field
                CustomTextField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hintText: 'Enter new password (min. 6 characters)',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: FormValidators.validatePassword,
                ),
                const SizedBox(height: 20),

                // Confirm New Password Field
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  hintText: 'Re-enter your new password',
                  prefixIcon: Icons.check_circle_outline_rounded,
                  isPassword: true,
                  validator: (val) => FormValidators.validateConfirmPassword(
                    val,
                    _newPasswordController.text,
                  ),
                ),
                const SizedBox(height: 16),

                // Password Requirements Helper
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirementItem('Must be at least 6 characters long'),
                      const SizedBox(height: 4),
                      _buildRequirementItem('Both passwords must match'),
                      const SizedBox(height: 4),
                      _buildRequirementItem('Must be different from your old password'),
                    ],
                  ),
                ),

                // Submit Button
                CustomButton(
                  text: 'Reset Password',
                  customColor: widget.themeColor,
                  isLoading: authProvider.isLoading,
                  onPressed: _handleResetPassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
