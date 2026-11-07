import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFBFAFD), AppColors.backgroundBottom],
          stops: [0, .60, 1],
        ),
      ),
      child: child,
    );
  }
}
