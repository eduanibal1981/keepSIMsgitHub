import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../controllers/return_trip_wizard_controller.dart';

class WizardStepArrivalDate extends StatelessWidget {
  final String countryName;
  final String? flagEmoji;
  final ReturnTripWizardState state;
  final ReturnTripWizardController controller;

  const WizardStepArrivalDate({
    super.key,
    required this.countryName,
    this.flagEmoji,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final currentDate = state.arrivalDate ?? DateTime.now();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    final presets = [
      {'label': 'Today', 'date': DateTime.now(), 'isAlready': false},
      {'label': 'Tomorrow', 'date': DateTime.now().add(const Duration(days: 1)), 'isAlready': false},
      {'label': 'In 3 Days', 'date': DateTime.now().add(const Duration(days: 3)), 'isAlready': false},
      {'label': 'In 1 Week', 'date': DateTime.now().add(const Duration(days: 7)), 'isAlready': false},
      {'label': 'Already Arrived', 'date': DateTime.now(), 'isAlready': true},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Country Flag
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      flagEmoji ?? '✈️',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'When are you landing in $countryName?',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'We will prepare your connectivity so data is ready when you arrive.',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Presets Chips
          Text(
            'Quick Presets',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((p) {
              final date = p['date'] as DateTime;
              final isAlready = p['isAlready'] as bool;
              final isSelected = isAlready
                  ? state.isAlreadyArrived
                  : (!state.isAlreadyArrived &&
                      currentDate.year == date.year &&
                      currentDate.month == date.month &&
                      currentDate.day == date.day);

              return ChoiceChip(
                label: Text(p['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    HapticHelper.lightTick();
                    controller.setArrivalDate(date, alreadyArrived: isAlready);
                  }
                },
                selectedColor: const Color(0xFF0284C7),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0284C7)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // Custom Date Picker Card
          Text(
            'Selected Arrival Date',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              HapticHelper.lightTick();
              final picked = await showDatePicker(
                context: context,
                initialDate: currentDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: isDark
                        ? ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF0284C7),
                              onPrimary: Colors.white,
                              surface: Color(0xFF182234),
                              onSurface: Colors.white,
                            ),
                          )
                        : ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF0284C7),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                          ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                controller.setArrivalDate(picked, alreadyArrived: false);
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF182234) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isAlreadyArrived
                              ? 'Already in $countryName'
                              : dateFormat.format(currentDate),
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.onSurfaceColor,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.isAlreadyArrived
                              ? 'Activate instant local data right now'
                              : 'Tap to change arrival date',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_calendar_rounded,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Information Note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0C4A6E).withValues(alpha: 0.25)
                  : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next, we will check your device capabilities to offer you the best eSIM or local carrier recharge pack for $countryName.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
