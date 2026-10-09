import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/blood_request_model.dart';
import '../../providers/request_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditBloodRequestScreen extends StatefulWidget {
  final BloodRequestModel request;

  const EditBloodRequestScreen({
    super.key,
    required this.request,
  });

  @override
  State<EditBloodRequestScreen> createState() => _EditBloodRequestScreenState();
}

class _EditBloodRequestScreenState extends State<EditBloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hospitalNameController;
  late TextEditingController _hospitalAddressController;
  late TextEditingController _notesController;
  late int _units;
  late String _urgency;

  @override
  void initState() {
    super.initState();
    _hospitalNameController = TextEditingController(text: widget.request.hospitalName);
    _hospitalAddressController = TextEditingController(text: widget.request.hospitalAddress);
    _notesController = TextEditingController(text: widget.request.additionalNotes);
    _units = widget.request.unitsRequired;
    _urgency = widget.request.urgency;
  }

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    final success = await requestProvider.updateRequest(
      requestId: widget.request.id,
      unitsRequired: _units,
      urgency: _urgency,
      hospitalName: _hospitalNameController.text.trim(),
      hospitalAddress: _hospitalAddressController.text.trim(),
      additionalNotes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood request updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage ?? 'Update failed'),
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
        title: const Text('Edit Blood Request'),
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
                Text(
                  'Patient: ${widget.request.patientName} (${widget.request.bloodGroup})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Units Required',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
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
                          Text('$_units', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                const Text(
                  'Urgency Priority',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['Emergency', 'Urgent', 'Standard'].map((u) {
                    final isSel = _urgency == u;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(u),
                          selected: isSel,
                          selectedColor: AppColors.recipientPrimary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _urgency = u;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _hospitalNameController,
                  label: 'Hospital Name',
                  prefixIcon: Icons.local_hospital_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Enter hospital name' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _hospitalAddressController,
                  label: 'Hospital Address / Ward',
                  prefixIcon: Icons.location_on_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Enter hospital address' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  label: 'Clinical Notes',
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: 'Save Changes',
                  customColor: AppColors.recipientPrimary,
                  isLoading: requestProvider.isLoading,
                  onPressed: _handleUpdate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
