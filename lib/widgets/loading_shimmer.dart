import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LoadingShimmer extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;
  final int count;

  const LoadingShimmer({
    super.key,
    this.height = 110,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.count = 3,
  });

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: List.generate(
            widget.count,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              height: widget.height,
              width: widget.width,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(_animation.value),
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
            ),
          ),
        );
      },
    );
  }
}
