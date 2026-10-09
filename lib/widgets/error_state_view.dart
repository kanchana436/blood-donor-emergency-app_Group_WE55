import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'custom_button.dart';

class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({
    super.key,
    this.title = 'Unable to Load Data',
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 38,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              width: 160,
              height: 46,
            ),
          ],
        ),
      ),
    );
  }
}
