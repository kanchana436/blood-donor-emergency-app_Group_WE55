import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/donor_profile_model.dart';
import '../../services/donor_service.dart';
import '../../services/mock_data_store.dart';
import '../../widgets/blood_group_badge.dart';

class NearbyDonorsMapScreen extends StatefulWidget {
  const NearbyDonorsMapScreen({super.key});

  @override
  State<NearbyDonorsMapScreen> createState() => _NearbyDonorsMapScreenState();
}

class _NearbyDonorsMapScreenState extends State<NearbyDonorsMapScreen> {
  final DonorService _donorService = DonorService();
  final TextEditingController _cityController = TextEditingController();

  double _radiusKm = 10.0;
  String _selectedBloodGroup = 'All';
  String _selectedAvailability = 'Available'; // 'Available', 'All'

  List<DonorProfileModel> _donors = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadDonors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cityQuery = _cityController.text.trim();
    final bool? isAvail = _selectedAvailability == 'Available' ? true : null;

    try {
      final results = await _donorService.searchDonors(
        city: cityQuery.isNotEmpty ? cityQuery : null,
        bloodGroup: _selectedBloodGroup == 'All' ? null : _selectedBloodGroup,
        isAvailable: isAvail,
      );

      if (mounted) {
        setState(() {
          _donors = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _clearFilters() {
    _cityController.clear();
    setState(() {
      _selectedBloodGroup = 'All';
      _selectedAvailability = 'Available';
    });
    _loadDonors();
  }

  @override
  Widget build(BuildContext context) {
    final mockStore = MockDataStore();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby Donors & Map'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Styled Map Visualization Area
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: _MapGridPainter(),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.recipientPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 24),
                    ),
                  ),
                  // Simulated donor markers
                  Positioned(
                    top: 30,
                    left: 50,
                    child: _buildDonorMarker('O+', 1.8),
                  ),
                  Positioned(
                    top: 50,
                    right: 60,
                    child: _buildDonorMarker('A+', 3.2),
                  ),
                  Positioned(
                    bottom: 25,
                    left: 90,
                    child: _buildDonorMarker('B+', 4.1),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _cityController.text.trim().isNotEmpty
                            ? 'Location: ${_cityController.text.trim()}'
                            : 'Location: Sri Lanka',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search by City Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_city_rounded, size: 18, color: AppColors.recipientPrimary),
                      SizedBox(width: 6),
                      Text(
                        'Search by City',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _loadDonors(),
                          decoration: InputDecoration(
                            hintText: 'Enter city',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.recipientPrimary),
                            suffixIcon: _cityController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                                    onPressed: () {
                                      _cityController.clear();
                                      _loadDonors();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.recipientPrimary, width: 1.5),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const Key('btn_search_city'),
                        onPressed: _loadDonors,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.recipientPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, size: 18),
                            SizedBox(width: 4),
                            Text('Search', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (_cityController.text.trim().isNotEmpty || _selectedBloodGroup != 'All' || _selectedAvailability != 'Available') ...[
                        const SizedBox(width: 6),
                        IconButton(
                          key: const Key('btn_clear_filters'),
                          tooltip: 'Clear filters',
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Combined Filters: Blood Group & Availability
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Blood Group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Availability filter toggle
                      Row(
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          DropdownButton<String>(
                            value: _selectedAvailability,
                            isDense: true,
                            underline: const SizedBox(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.recipientPrimary,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Available', child: Text('Available Only')),
                              DropdownMenuItem(value: 'All', child: Text('All Donors')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedAvailability = val;
                                });
                                _loadDonors();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((bg) {
                        final isSel = _selectedBloodGroup == bg;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(bg),
                            selected: isSel,
                            selectedColor: AppColors.recipientPrimary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedBloodGroup = bg;
                              });
                              _loadDonors();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Radius Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Text(
                    'Radius:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_radiusKm.toInt()} km',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.recipientPrimary,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 2,
                      max: 30,
                      divisions: 14,
                      activeColor: AppColors.recipientPrimary,
                      onChanged: (val) {
                        setState(() {
                          _radiusKm = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Results Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Eligible Donors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_donors.length} Found',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.recipientPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Error banner if any
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.emergency.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.emergency, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.emergency, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading state
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.recipientPrimary),
                ),
              )
            // Empty State: "No donors found in this location."
            else if (_donors.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.recipientPrimary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        size: 36,
                        color: AppColors.recipientPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No donors found in this location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cityController.text.trim().isNotEmpty
                          ? 'No active donors found in "${_cityController.text.trim()}". Try another city or clear the filter.'
                          : 'No eligible donors matched the selected filters. Please adjust your criteria.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Show All Eligible Donors'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.recipientPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            // Donors List View
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _donors.length,
                itemBuilder: (context, index) {
                  final donor = _donors[index];
                  final userName = donor.userName ??
                      mockStore.users
                          .firstWhere(
                            (u) => u.id == donor.userId,
                            orElse: () => mockStore.users.first,
                          )
                          .name;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        BloodGroupBadge(bloodGroup: donor.bloodGroup),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${donor.city} • Approx 2.4 km away',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${donor.totalDonations} Past Donations • ${donor.livesSaved} Lives Saved',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Direct alert dispatched to $userName!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.recipientPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(60, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorMarker(String bloodGroup, double distance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.donorPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(
            bloodGroup,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
