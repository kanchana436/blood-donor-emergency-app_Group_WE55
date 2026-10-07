import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/donor_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/blood_group_selector.dart';
import 'donor_main_navigation.dart';

class DonorProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String? initialBloodGroup;

  const DonorProfileSetupScreen({
    super.key,
    required this.userId,
    this.initialBloodGroup,
  });

  @override
  State<DonorProfileSetupScreen> createState() => _DonorProfileSetupScreenState();
}

class _DonorProfileSetupScreenState extends State<DonorProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBloodGroup;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _weightController;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final currentProfile = donorProvider.profile;

    if (currentProfile != null && currentProfile.userId == widget.userId) {
      _selectedBloodGroup = currentProfile.bloodGroup;
      _cityController = TextEditingController(text: currentProfile.city);
      _addressController = TextEditingController(text: currentProfile.address);
      _weightController = TextEditingController(
        text: currentProfile.weightKg != null
            ? (currentProfile.weightKg! % 1 == 0
                ? currentProfile.weightKg!.toInt().toString()
                : currentProfile.weightKg!.toString())
            : '',
      );
      _isAvailable = currentProfile.isAvailable;
    } else {
      _selectedBloodGroup = widget.initialBloodGroup;
      _cityController = TextEditingController(text: '');
      _addressController = TextEditingController(text: '');
      _weightController = TextEditingController(text: '');
      _isAvailable = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserProfile();
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    await donorProvider.loadDonorData(widget.userId);
    if (!mounted) return;
    final profile = donorProvider.profile;
    if (profile != null && profile.userId == widget.userId) {
      setState(() {
        _selectedBloodGroup = profile.bloodGroup;
        _cityController.text = profile.city;
        _addressController.text = profile.address;
        _weightController.text = profile.weightKg != null
            ? (profile.weightKg! % 1 == 0
                ? profile.weightKg!.toInt().toString()
                : profile.weightKg!.toString())
            : '';
        _isAvailable = profile.isAvailable;
      });
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final weight = double.tryParse(_weightController.text.trim());

    final success = await donorProvider.setupProfile(
      userId: widget.userId,
      bloodGroup: _selectedBloodGroup!,
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      isAvailable: _isAvailable,
      weightKg: weight,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DonorMainNavigation()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(donorProvider.errorMessage ?? 'Failed to save donor profile'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donorProvider = Provider.of<DonorProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Donor Profile Setup'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.donorPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.donorPrimary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.donorPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your profile helps the dispatch system match you with emergency requests nearby.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.donorPrimaryDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Blood Group
                FormField<String>(
                  validator: (val) => FormValidators.validateBloodGroup(_selectedBloodGroup),
                  builder: (fieldState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Select Blood Group',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BloodGroupSelector(
                          selectedGroup: _selectedBloodGroup,
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
                const SizedBox(height: 24),

                // Availability Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available for Matching',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAvailable ? 'Ready to receive alerts' : 'Temporarily paused',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isAvailable ? AppColors.success : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: _isAvailable,
                        activeColor: AppColors.donorPrimary,
                        onChanged: (val) {
                          setState(() {
                            _isAvailable = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. City
                CustomTextField(
                  controller: _cityController,
                  label: 'City / Region',
                  hintText: 'e.g. Colombo',
                  prefixIcon: Icons.location_city_outlined,
                  validator: FormValidators.validateCity,
                ),
                const SizedBox(height: 16),

                // 6. Living Address
                CustomTextField(
                  controller: _addressController,
                  label: 'Living Address',
                  hintText: 'e.g. Street name, area',
                  prefixIcon: Icons.home_outlined,
                  validator: FormValidators.validateLivingAddress,
                ),
                const SizedBox(height: 16),

                // 7. Body Weight
                CustomTextField(
                  controller: _weightController,
                  label: 'Body Weight (kg)',
                  hintText: 'e.g. 65',
                  prefixIcon: Icons.monitor_weight_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  suffixText: 'kg',
                  validator: FormValidators.validateBodyWeight,
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Complete Profile & Continue',
                  isLoading: donorProvider.isLoading,
                  onPressed: _handleSave,
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
