import 'package:flutter/material.dart';
import '../core/constants/blood_types.dart';
import '../core/theme/app_colors.dart';

class BloodGroupSelector extends StatelessWidget {
  final String? selectedGroup;
  final ValueChanged<String> onSelected;
  final Color? activeColor;

  const BloodGroupSelector({
    super.key,
    required this.selectedGroup,
    required this.onSelected,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = activeColor ?? AppColors.donorPrimary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: BloodTypes.all.map((group) {
        final isSelected = selectedGroup == group;

        return InkWell(
          onTap: () => onSelected(group),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? themeColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? themeColor : AppColors.border,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: themeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              group,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
