import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/blood_campaign_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blood_campaign_provider.dart';

class CampaignFormDialog extends StatefulWidget {
  final BloodCampaign? campaignToEdit;

  const CampaignFormDialog({
    super.key,
    this.campaignToEdit,
  });

  static Future<bool?> show(BuildContext context, {BloodCampaign? campaign}) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => CampaignFormDialog(campaignToEdit: campaign),
    );
  }

  @override
  State<CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<CampaignFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _organizerController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _hospitalController;
  late TextEditingController _locationController;
  late TextEditingController _cityController;
  late TextEditingController _targetDonorsController;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _selectedStatus = 'Upcoming';
  bool _isSubmitting = false;
  String? _formErrorMessage;

  final List<String> _statusOptions = ['Upcoming', 'Ongoing', 'Completed', 'Cancelled'];
  final List<String> _commonCities = [
    'Colombo',
    'Kandy',
    'Galle',
    'Gampaha',
    'Kurunegala',
    'Jaffna',
    'Matara',
    'Negombo',
    'Anuradhapura',
    'Ratnapura',
    'Badulla',
    'Kalutara',
  ];

  // Design tokens aligned with LifeLink Design System
  static const Color _primaryRed = Color(0xFFDC2626);
  static const Color _primaryRedLight = Color(0xFFFEE2E2);
  static const Color _bgNeutral = Color(0xFFF9FAFB);
  static const Color _textSlate = Color(0xFF1F2937);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderLight = Color(0xFFE5E7EB);
  static const Color _borderFocus = Color(0xFFDC2626);
  static const Color _borderInput = Color(0xFFD1D5DB);

  @override
  void initState() {
    super.initState();
    final c = widget.campaignToEdit;
    final authUser = context.read<AuthProvider>().currentUser;

    _nameController = TextEditingController(text: c?.campaignName ?? '');
    _descController = TextEditingController(text: c?.description ?? '');
    _organizerController = TextEditingController(
      text: c?.organizerName ?? (authUser?.name ?? ''),
    );
    _phoneController = TextEditingController(
      text: c?.contactNumber ?? (authUser?.phone ?? ''),
    );
    _emailController = TextEditingController(
      text: c?.email ?? (authUser?.email ?? ''),
    );
    _hospitalController = TextEditingController(text: c?.hospitalOrBloodBank ?? '');
    _locationController = TextEditingController(text: c?.location ?? '');
    _cityController = TextEditingController(text: c?.city ?? 'Colombo');
    _targetDonorsController = TextEditingController(
      text: c?.targetDonors != null ? c!.targetDonors.toString() : '',
    );

    if (c != null) {
      _selectedDate = c.campaignDate;
      _startTime = _parseTimeString(c.startTime);
      _endTime = _parseTimeString(c.endTime);
      _selectedStatus = c.status;
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 7));
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 16, minute: 0);
      _selectedStatus = 'Upcoming';
    }
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.endsWith('PM');
      final isAm = clean.endsWith('AM');
      final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = digits.split(':');
      if (parts.length < 2) return null;
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _organizerController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _hospitalController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _targetDonorsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: widget.campaignToEdit != null ? DateTime(2020) : now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryRed,
              onPrimary: Colors.white,
              onSurface: _textSlate,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryRed,
              onPrimary: Colors.white,
              onSurface: _textSlate,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 16, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryRed,
              onPrimary: Colors.white,
              onSurface: _textSlate,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _formErrorMessage = null);

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _formErrorMessage = 'Please check the required fields marked in red.';
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _formErrorMessage = 'Please select a campaign date.';
      });
      return;
    }

    if (_startTime == null || _endTime == null) {
      setState(() {
        _formErrorMessage = 'Please select both start and end time.';
      });
      return;
    }

    if (_timeToMinutes(_endTime!) <= _timeToMinutes(_startTime!)) {
      setState(() {
        _formErrorMessage = 'End time must be later than start time.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<BloodCampaignProvider>();
    final isEditing = widget.campaignToEdit != null;

    final data = <String, dynamic>{
      'campaignName': _nameController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'organizerName': _organizerController.text.trim(),
      'contactNumber': _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'hospitalOrBloodBank': _hospitalController.text.trim().isEmpty ? null : _hospitalController.text.trim(),
      'location': _locationController.text.trim(),
      'city': _cityController.text.trim(),
      'campaignDate': _selectedDate!.toIso8601String(),
      'startTime': _formatTimeOfDay(_startTime!),
      'endTime': _formatTimeOfDay(_endTime!),
      'targetDonors': _targetDonorsController.text.trim().isEmpty
          ? null
          : int.tryParse(_targetDonorsController.text.trim()),
      'status': _selectedStatus,
    };

    bool success = false;
    try {
      if (isEditing) {
        success = await provider.updateCampaign(widget.campaignToEdit!.id, data);
      } else {
        success = await provider.createCampaign(data);
      }
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Blood Campaign updated successfully!'
                : 'Blood Campaign created successfully!',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _formErrorMessage = provider.errorMessage ?? 'Operation failed. Please try again.';
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: _textMuted)
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderInput),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderInput),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: _primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _primaryRedLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: _primaryRed),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _textSlate,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: _borderLight, thickness: 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.campaignToEdit != null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _borderLight, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------------------------------------------------------------
            // Header
            // -------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _primaryRed,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryRed.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.edit_calendar_rounded
                          : Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Blood Campaign' : 'Create Blood Campaign',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textSlate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing
                              ? 'Update schedule, venue, and organizer details'
                              : 'Set up an official blood drive for donors to join',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: _textMuted),
                    tooltip: 'Close',
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _borderLight),

            // -------------------------------------------------------------
            // Scrollable Form Body
            // -------------------------------------------------------------
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 460;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_formErrorMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _formErrorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(() => _formErrorMessage = null),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ---------------- Section A: Campaign Details ----------------
                          _buildSectionHeader('Campaign Details', Icons.campaign_rounded),
                          _buildFieldLabel('Campaign Name', isRequired: true),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 14, color: _textSlate),
                            decoration: _inputDecoration(
                              hintText: 'e.g. LifeLink Annual Blood Drive',
                              prefixIcon: Icons.campaign_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Campaign Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _buildFieldLabel('Description'),
                          TextFormField(
                            controller: _descController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14, color: _textSlate),
                            decoration: _inputDecoration(
                              hintText: 'Provide drive goals, guidelines, or patient emergency details...',
                              prefixIcon: Icons.notes_rounded,
                            ),
                          ),

                          // ---------------- Section B: Organizer Information ----------------
                          _buildSectionHeader('Organizer Information', Icons.person_rounded),
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Organizer Name', isRequired: true),
                                      TextFormField(
                                        controller: _organizerController,
                                        style: const TextStyle(fontSize: 14, color: _textSlate),
                                        decoration: _inputDecoration(
                                          hintText: 'Coordinator / Staff Name',
                                          prefixIcon: Icons.person_outline_rounded,
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Organizer Name is required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Blood Bank / Organization'),
                                      TextFormField(
                                        controller: _hospitalController,
                                        style: const TextStyle(fontSize: 14, color: _textSlate),
                                        decoration: _inputDecoration(
                                          hintText: 'e.g. National Blood Bank',
                                          prefixIcon: Icons.local_hospital_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Contact Number', isRequired: true),
                                      TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(fontSize: 14, color: _textSlate),
                                        decoration: _inputDecoration(
                                          hintText: '+94 77 123 4567',
                                          prefixIcon: Icons.phone_outlined,
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Contact Number is required';
                                          }
                                          final digits = val.replaceAll(RegExp(r'\D'), '');
                                          if (digits.length < 7 || digits.length > 15) {
                                            return 'Enter 7-15 digits';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Email Address'),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        style: const TextStyle(fontSize: 14, color: _textSlate),
                                        decoration: _inputDecoration(
                                          hintText: 'campaign@bloodbank.org',
                                          prefixIcon: Icons.mail_outline_rounded,
                                        ),
                                        validator: (val) {
                                          if (val != null && val.trim().isNotEmpty) {
                                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                            if (!emailRegex.hasMatch(val.trim())) {
                                              return 'Invalid email format';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildFieldLabel('Organizer Name', isRequired: true),
                            TextFormField(
                              controller: _organizerController,
                              style: const TextStyle(fontSize: 14, color: _textSlate),
                              decoration: _inputDecoration(
                                hintText: 'Coordinator / Staff Name',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Organizer Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel('Blood Bank / Organization'),
                            TextFormField(
                              controller: _hospitalController,
                              style: const TextStyle(fontSize: 14, color: _textSlate),
                              decoration: _inputDecoration(
                                hintText: 'e.g. National Blood Bank',
                                prefixIcon: Icons.local_hospital_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel('Contact Number', isRequired: true),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 14, color: _textSlate),
                              decoration: _inputDecoration(
                                hintText: '+94 77 123 4567',
                                prefixIcon: Icons.phone_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Contact Number is required';
                                }
                                final digits = val.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 7 || digits.length > 15) {
                                  return 'Enter 7-15 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel('Email Address'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 14, color: _textSlate),
                              decoration: _inputDecoration(
                                hintText: 'campaign@bloodbank.org',
                                prefixIcon: Icons.mail_outline_rounded,
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Invalid email format';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],

                          // ---------------- Section C: Location ----------------
                          _buildSectionHeader('Location', Icons.location_on_rounded),
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Campaign Location', isRequired: true),
                                      TextFormField(
                                        controller: _locationController,
                                        style: const TextStyle(fontSize: 14, color: _textSlate),
                                        decoration: _inputDecoration(
                                          hintText: 'e.g. BMICH Main Exhibition Hall A',
                                          prefixIcon: Icons.place_outlined,
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Location is required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('City', isRequired: true),
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: _commonCities.contains(_cityController.text)
                                            ? _cityController.text
                                            : 'Colombo',
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                                        decoration: _inputDecoration(
                                          prefixIcon: Icons.location_city_rounded,
                                        ),
                                        items: _commonCities.map((city) {
                                          return DropdownMenuItem(
                                            value: city,
                                            child: Text(city, style: const TextStyle(fontSize: 14, color: _textSlate)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _cityController.text = val);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildFieldLabel('Campaign Location', isRequired: true),
                            TextFormField(
                              controller: _locationController,
                              style: const TextStyle(fontSize: 14, color: _textSlate),
                              decoration: _inputDecoration(
                                hintText: 'e.g. BMICH Main Exhibition Hall A',
                                prefixIcon: Icons.place_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Location is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel('City', isRequired: true),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _commonCities.contains(_cityController.text)
                                  ? _cityController.text
                                  : 'Colombo',
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                              decoration: _inputDecoration(
                                prefixIcon: Icons.location_city_rounded,
                              ),
                              items: _commonCities.map((city) {
                                return DropdownMenuItem(
                                  value: city,
                                  child: Text(city, style: const TextStyle(fontSize: 14, color: _textSlate)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _cityController.text = val);
                                }
                              },
                            ),
                          ],

                          // ---------------- Section D: Date and Time ----------------
                          _buildSectionHeader('Date & Time', Icons.calendar_month_rounded),
                          _buildFieldLabel('Campaign Date', isRequired: true),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _borderInput),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: _primaryRed),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedDate != null
                                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                          : 'Select Campaign Date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedDate != null ? _textSlate : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Start Time', isRequired: true),
                                    InkWell(
                                      onTap: _pickStartTime,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _borderInput),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time_rounded, size: 18, color: _textMuted),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _startTime != null ? _formatTimeOfDay(_startTime!) : 'Select Time',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textSlate,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('End Time', isRequired: true),
                                    InkWell(
                                      onTap: _pickEndTime,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _borderInput),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.schedule_rounded, size: 18, color: _textMuted),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _endTime != null ? _formatTimeOfDay(_endTime!) : 'Select Time',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textSlate,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ---------------- Section E: Targets & Status ----------------
                          _buildSectionHeader('Targets & Status', Icons.tune_rounded),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Target Donors (optional)'),
                                    TextFormField(
                                      controller: _targetDonorsController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 14, color: _textSlate),
                                      decoration: _inputDecoration(
                                        hintText: 'e.g. 150',
                                        prefixIcon: Icons.group_outlined,
                                      ),
                                      validator: (val) {
                                        if (val != null && val.trim().isNotEmpty) {
                                          final num = int.tryParse(val.trim());
                                          if (num == null || num <= 0) {
                                            return 'Must be positive';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Campaign Status'),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _selectedStatus,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                                      decoration: _inputDecoration(
                                        prefixIcon: Icons.flag_outlined,
                                      ),
                                      items: _statusOptions.map((st) {
                                        return DropdownMenuItem(
                                          value: st,
                                          child: Text(st, style: const TextStyle(fontSize: 14, color: _textSlate)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedStatus = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _borderLight),

            // -------------------------------------------------------------
            // Footer & Action Buttons
            // -------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              color: _bgNeutral,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_formErrorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formErrorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;

                  final cancelButton = OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: _borderInput),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(80, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  );

                  final submitButton = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryRed,
                      disabledBackgroundColor: const Color(0xFFFCA5A5),
                      minimumSize: const Size(120, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      elevation: 0,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isEditing ? Icons.check_circle_outline_rounded : Icons.add_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    label: Text(
                      isEditing ? 'Save Changes' : 'Create Campaign',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        submitButton,
                        const SizedBox(height: 8),
                        cancelButton,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      submitButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
