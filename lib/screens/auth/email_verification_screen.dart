import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../widgets/custom_button.dart';
import '../donor/donor_main_navigation.dart';
import '../donor/donor_profile_setup_screen.dart';
import '../recipient/recipient_main_navigation.dart';
import '../manager/manager_main_navigation.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String role; // 'donor' or 'recipient'

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.role = 'donor',
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // 5-minute expiration timer (300 seconds)
  Timer? _expiryTimer;
  int _expiryRemainingSeconds = 300;

  // 60-second resend cooldown timer
  Timer? _resendTimer;
  int _resendRemainingSeconds = 60;

  String? _errorMessage;

  Color get _themeColor =>
      widget.role == 'donor' ? AppColors.donorPrimary : AppColors.recipientPrimary;

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
    _startResendTimer();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    setState(() {
      _expiryRemainingSeconds = 300;
    });
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiryRemainingSeconds > 0) {
        setState(() {
          _expiryRemainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendRemainingSeconds = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendRemainingSeconds > 0) {
        setState(() {
          _resendRemainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode {
    return _controllers.map((c) => c.text.trim()).join();
  }

  bool get _isOtpExpired => _expiryRemainingSeconds <= 0;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleVerifyOtp() async {
    setState(() {
      _errorMessage = null;
    });

    final code = _otpCode;

    // Validation: Empty OTP
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    // Validation: OTP must contain exactly 6 digits
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of your verification code.';
      });
      return;
    }

    if (_isOtpExpired) {
      setState(() {
        _errorMessage = 'Verification code has expired. Please tap Resend Code.';
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);

    final success = await authProvider.verifyEmailOtp(
      email: widget.email,
      otp: code,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Email verified successfully! Registration complete.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

      final user = authProvider.currentUser;
      if (user?.role == 'manager' || user?.role == 'admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ManagerMainNavigation()),
          (route) => false,
        );
      } else if (widget.role == 'donor' && user != null) {
        await donorProvider.loadDonorData(user.id);
        if (!mounted) return;

        if (donorProvider.profile == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => DonorProfileSetupScreen(userId: user.id),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DonorMainNavigation()),
            (route) => false,
          );
        }
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RecipientMainNavigation()),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Verification failed. Please check your code.';
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendRemainingSeconds > 0) return;

    setState(() {
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resendEmailOtp(email: widget.email);

    if (!mounted) return;

    if (success) {
      // Clear input fields
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      // Reset timers
      _startExpiryTimer();
      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A new 6-digit verification code has been sent to your email.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Failed to resend code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Email Verification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // Icon Badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _themeColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      color: _themeColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We have sent a 6-digit verification code to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email_outlined, size: 16, color: _themeColor),
                        const SizedBox(width: 8),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 6-digit OTP Inputs
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int index = 0; index < 6; index++) ...[
                            _buildOtpDigitBox(index),
                            if (index < 5) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Countdown Expiry Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isOtpExpired
                          ? AppColors.error.withOpacity(0.08)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOtpExpired
                            ? AppColors.error.withOpacity(0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOtpExpired
                              ? Icons.timer_off_outlined
                              : Icons.access_time_rounded,
                          size: 16,
                          color: _isOtpExpired ? AppColors.error : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOtpExpired
                              ? 'Code expired'
                              : 'Code expires in ${_formatTime(_expiryRemainingSeconds)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isOtpExpired ? AppColors.error : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Verify Button
                  CustomButton(
                    text: 'Verify & Activate Account',
                    customColor: _themeColor,
                    isLoading: authProvider.isLoading,
                    onPressed: _handleVerifyOtp,
                  ),

                  const SizedBox(height: 24),

                  // Resend Option with Cooldown
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive code? ",
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: _resendRemainingSeconds > 0 || authProvider.isLoading
                            ? null
                            : _handleResendOtp,
                        child: Text(
                          _resendRemainingSeconds > 0
                              ? 'Resend in ${_resendRemainingSeconds}s'
                              : 'Resend Code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _resendRemainingSeconds > 0
                                ? AppColors.textMuted
                                : _themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].selection = TextSelection.fromPosition(
              TextPosition(offset: _controllers[index - 1].text.length),
            );
          }
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _themeColor, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _errorMessage = null;
            });
            if (value.isNotEmpty) {
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
              }
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }
}
