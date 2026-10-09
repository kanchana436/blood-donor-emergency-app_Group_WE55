import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class BloodGroupBadge extends StatelessWidget {
  final String bloodGroup;
  final double size;
  final bool isLarge;

  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.size = 44,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = isLarge ? 56.0 : size;

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: AppColors.donorPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.donorPrimary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              bloodGroup,
              style: TextStyle(
                fontSize: isLarge ? 20 : 16,
                fontWeight: FontWeight.w800,
                color: AppColors.donorPrimary,
                height: 1.1,
              ),
            ),
            if (isLarge)
              const Text(
                'BLOOD',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.donorPrimary,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
