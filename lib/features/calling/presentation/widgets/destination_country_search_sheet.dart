/// KeepSIMs — Destination Country Search Sheet
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';

class DestinationCountrySearchSheet extends StatefulWidget {
  final List<CallRate> rates;
  final CallRate? selectedRate;

  const DestinationCountrySearchSheet({
    super.key,
    required this.rates,
    this.selectedRate,
  });

  static Future<CallRate?> show(
    BuildContext context, {
    required List<CallRate> rates,
    CallRate? selectedRate,
  }) {
    return showModalBottomSheet<CallRate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DestinationCountrySearchSheet(
        rates: rates,
        selectedRate: selectedRate,
      ),
    );
  }

  @override
  State<DestinationCountrySearchSheet> createState() =>
      _DestinationCountrySearchSheetState();
}

class _DestinationCountrySearchSheetState
    extends State<DestinationCountrySearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CallRate> _filteredRates = [];

  @override
  void initState() {
    super.initState();
    _filteredRates = widget.rates;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredRates = widget.rates);
      return;
    }

    final cleanQuery = query.replaceAll('+', '');

    setState(() {
      _filteredRates = widget.rates.where((r) {
        final nameMatch = r.countryName.toLowerCase().contains(query);
        final codeMatch = r.countryCode.toLowerCase().contains(query);
        final prefixClean = r.phonePrefix.replaceAll('+', '').toLowerCase();
        final prefixMatch =
            prefixClean.contains(cleanQuery) ||
            r.phonePrefix.toLowerCase().contains(query);
        return nameMatch || codeMatch || prefixMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorder, width: 1.5),
          left: BorderSide(color: AppColors.darkBorder),
          right: BorderSide(color: AppColors.darkBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Destination Country',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Live pay-per-second calling rates',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // ── Search Input ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search country or code (e.g. Egypt, +20)...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Results List ──
          Expanded(
            child: _filteredRates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public_off_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No destinations match "${_searchController.text}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Try searching by country name or dial code',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filteredRates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final rate = _filteredRates[index];
                      final isSelected =
                          widget.selectedRate?.id == rate.id ||
                          (widget.selectedRate != null &&
                              widget.selectedRate!.phonePrefix ==
                                  rate.phonePrefix &&
                              widget.selectedRate!.countryCode ==
                                  rate.countryCode);

                      return InkWell(
                        onTap: () => Navigator.of(context).pop(rate),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.darkCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.darkBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Flag Emoji
                              Text(
                                rate.flagEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),

                              // Country Name & Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            rate.countryName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.9,
                                                    ),
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Prefix Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBg,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primary
                                                        .withValues(alpha: 0.4)
                                                  : AppColors.darkBorder,
                                            ),
                                          ),
                                          child: Text(
                                            rate.phonePrefix,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '\$${rate.ratePerMinute.toStringAsFixed(3)}/min  •  \$${rate.ratePerSecond.toStringAsFixed(4)}/s',
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Selection Checkmark
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
