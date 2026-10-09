import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/blood_group_selector.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'request_tracking_screen.dart';

class CreateBloodRequestScreen extends StatefulWidget {
  const CreateBloodRequestScreen({super.key});

  @override
  State<CreateBloodRequestScreen> createState() => _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _hospitalNameController = TextEditingController(text: 'National Hospital of Sri Lanka');
  final _hospitalAddressController = TextEditingController(text: 'Regent Street, Colombo 10');
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedBloodGroup = 'O+';
  int _units = 2;
  String _selectedUrgency = 'Emergency'; // 'Emergency', 'Urgent', 'Standard'

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser != null) {
      _phoneController.text = auth.currentUser!.phone;
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;
    final user = authProvider.currentUser!;

    final newRequest = await requestProvider.createBloodRequest(
      requesterId: user.id,
      requesterName: user.name,
      patientName: _patientNameController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      unitsRequired: _units,
      urgency: _selectedUrgency,
      hospitalName: _hospitalNameController.text.trim(),
      hospitalAddress: _hospitalAddressController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      additionalNotes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (newRequest != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood request created! Donors in your area have been notified.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RequestTrackingScreen(request: newRequest),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage ?? 'Failed to submit request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Blood Request'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.recipientPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.recipientPrimary.withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.recipientPrimary, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your emergency request is automatically broadcast to nearby compatible donors.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.recipientPrimaryDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Patient Name
                CustomTextField(
                  controller: _patientNameController,
                  label: 'Patient Full Name',
                  hintText: 'e.g. Kavindu Perera',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: Validators.validateFullName,
                ),
                const SizedBox(height: 18),

                // Blood Group
                const Text(
                  'Required Blood Group',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                BloodGroupSelector(
                  selectedGroup: _selectedBloodGroup,
                  activeColor: AppColors.recipientPrimary,
                  onSelected: (group) {
                    setState(() {
                      _selectedBloodGroup = group;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Units Stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Typically 1-4 units per procedure',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _units > 1
                                ? () {
                                    setState(() {
                                      _units--;
                                    });
                                  }
                                : null,
                          ),
                          Text(
                            '$_units',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _units < 10
                                ? () {
                                    setState(() {
                                      _units++;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Urgency Selector
                const Text(
                  'Urgency Level',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildUrgencyChip('Emergency', AppColors.emergency, Icons.bolt),
                    const SizedBox(width: 8),
                    _buildUrgencyChip('Urgent', AppColors.urgent, Icons.alarm),
                    const SizedBox(width: 8),
                    _buildUrgencyChip('Standard', AppColors.standard, Icons.calendar_today_outlined),
                  ],
                ),
                const SizedBox(height: 20),

                // Hospital Quick Picker & Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hospital Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    PopupMenuButton<Map<String, dynamic>>(
                      icon: const Row(
                        children: [
                          Text('Select nearby', style: TextStyle(fontSize: 12, color: AppColors.recipientPrimary, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_drop_down, color: AppColors.recipientPrimary),
                        ],
                      ),
                      onSelected: (hospital) {
                        setState(() {
                          _hospitalNameController.text = hospital['name'];
                          _hospitalAddressController.text = hospital['address'];
                        });
                      },
                      itemBuilder: (ctx) => LocationService.recognizedHospitals
                          .map((h) => PopupMenuItem(
                                value: h,
                                child: Text(h['name']),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                CustomTextField(
                  controller: _hospitalNameController,
                  hintText: 'e.g. Asiri Central Hospital',
                  prefixIcon: Icons.local_hospital_outlined,
                  validator: Validators.validateHospitalName,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _hospitalAddressController,
                  label: 'Hospital Address / Ward Details',
                  hintText: 'e.g. Ward 4B, 3rd Floor, Norris Canal Rd',
                  prefixIcon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the hospital address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _phoneController,
                  label: 'Emergency Contact Phone',
                  hintText: '+94 77 123 4567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _notesController,
                  label: 'Clinical Notes & Reason',
                  hintText: 'e.g. Scheduled for emergency trauma surgery at 8 AM.',
                  prefixIcon: Icons.note_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: 'Submit Emergency Request',
                  customColor: AppColors.recipientPrimary,
                  isLoading: requestProvider.isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String label, Color color, IconData icon) {
    final isSelected = _selectedUrgency == label;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedUrgency = label;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
