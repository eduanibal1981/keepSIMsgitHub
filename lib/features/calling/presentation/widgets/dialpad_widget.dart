/// KeepSIMs — Custom Glassmorphic Dialpad
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';

class DialpadWidget extends StatelessWidget {
  final Function(String digit) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onLongDeletePressed;

  const DialpadWidget({
    super.key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    this.onLongDeletePressed,
  });

  static const List<Map<String, String>> keys = [
    {'digit': '1', 'letters': ''},
    {'digit': '2', 'letters': 'ABC'},
    {'digit': '3', 'letters': 'DEF'},
    {'digit': '4', 'letters': 'GHI'},
    {'digit': '5', 'letters': 'JKL'},
    {'digit': '6', 'letters': 'MNO'},
    {'digit': '7', 'letters': 'PQRS'},
    {'digit': '8', 'letters': 'TUV'},
    {'digit': '9', 'letters': 'WXYZ'},
    {'digit': '*', 'letters': ''},
    {'digit': '0', 'letters': '+'},
    {'digit': '#', 'letters': ''},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < 4; r++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int c = 0; c < 3; c++) ...[
                _buildDialKey(keys[r * 3 + c]),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDialKey(Map<String, String> keyInfo) {
    final digit = keyInfo['digit']!;
    final letters = keyInfo['letters']!;

    return InkWell(
      onTap: () => onKeyPressed(digit),
      onLongPress: digit == '0' ? () => onKeyPressed('+') : null,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkCard,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
