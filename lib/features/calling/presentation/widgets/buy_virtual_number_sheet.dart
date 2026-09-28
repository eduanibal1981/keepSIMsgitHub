import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/available_virtual_number_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/screens/my_numbers_screen.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class BuyVirtualNumberSheet extends ConsumerStatefulWidget {
  const BuyVirtualNumberSheet({super.key});

  static Future<VirtualDidNumber?> show(BuildContext context) {
    HapticHelper.lightTick();
    return showModalBottomSheet<VirtualDidNumber>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BuyVirtualNumberSheet(),
    );
  }

  @override
  ConsumerState<BuyVirtualNumberSheet> createState() =>
      _BuyVirtualNumberSheetState();
}

class _BuyVirtualNumberSheetState
    extends ConsumerState<BuyVirtualNumberSheet> {
  String _selectedCountryCode = 'US';
  String _selectedCountryName = 'United States';
  final TextEditingController _areaCodeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  List<AvailableVirtualNumber> _availableNumbers = [];

  AvailableVirtualNumber? _selectedNumberForCheckout;
  bool _isPurchasing = false;

  final List<Map<String, String>> _countries = [
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchNumbers();
  }

  @override
  void dispose() {
    _areaCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchNumbers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedNumberForCheckout = null;
    });

    try {
      final repo = ref.read(callingRepositoryProvider);
      final results = await repo.searchAvailableNumbers(
        countryCode: _selectedCountryCode,
        limit: 15,
        areaCode: _areaCodeController.text.trim().isNotEmpty
            ? _areaCodeController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _availableNumbers = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmPurchase(AvailableVirtualNumber num) async {
    setState(() {
      _isPurchasing = true;
    });
    HapticHelper.mediumImpact();

    try {
      final repo = ref.read(callingRepositoryProvider);
      final provisioned = await repo.purchaseVirtualNumber(
        phoneNumber: num.phoneNumber,
        countryCode: num.countryCode,
        countryName: _selectedCountryName,
      );

      // Refresh providers
      ref.invalidate(virtualDidsProvider);
      ref.invalidate(walletControllerProvider);

      HapticHelper.successFeedback();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Virtual Number ${provisioned.phoneNumber} activated successfully!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, provisioned);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        HapticHelper.errorFeedback();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);
    final walletBalance = walletState.value?.wallet.balance ?? 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buy Virtual DID Number',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Telnyx Wholesale + App Fee (intelcallfee rule)',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Country Selector Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _countries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final c = _countries[idx];
                  final isSelected = c['code'] == _selectedCountryCode;
                  return ChoiceChip(
                    label: Text('${c['flag']} ${c['name']}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCountryCode = c['code']!;
                          _selectedCountryName = c['name']!;
                        });
                        _fetchNumbers();
                      }
                    },
                    backgroundColor: AppColors.darkCard,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.darkBorder,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Search Area Code Input & Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _areaCodeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Filter area code (e.g. 754, 448)',
                          hintStyle:
                              TextStyle(color: Colors.white38, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _fetchNumbers(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.search, color: AppColors.primary),
                    tooltip: 'Search',
                    onPressed: _fetchNumbers,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Content: Number List or Checkout
            Expanded(
              child: _selectedNumberForCheckout != null
                  ? _buildCheckoutConfirmation(
                      _selectedNumberForCheckout!, walletBalance)
                  : _buildNumbersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumbersList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Searching carrier inventory...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                onPressed: _fetchNumbers,
              ),
            ],
          ),
        ),
      );
    }

    if (_availableNumbers.isEmpty) {
      return const Center(
        child: Text(
          'No numbers available matching this criteria.\nTry another country or area code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _availableNumbers.length,
      itemBuilder: (ctx, idx) {
        final item = _availableNumbers[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Text(
              item.flagEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(
              item.phoneNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
            ),
            subtitle: Row(
              children: [
                if (item.locationDisplay.isNotEmpty) ...[
                  Text(
                    item.locationDisplay,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Voice + SMS',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${item.totalMonthlyUsd.toStringAsFixed(2)}/mo',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '+${item.appFeePercent.toInt()}% tier fee',
                  style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                ),
              ],
            ),
            onTap: () {
              HapticHelper.lightTick();
              setState(() {
                _selectedNumberForCheckout = item;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildCheckoutConfirmation(
      AvailableVirtualNumber item, double walletBalance) {
    final hasEnoughBalance = walletBalance >= item.totalMonthlyUsd;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to List link
          InkWell(
            onTap: () {
              setState(() {
                _selectedNumberForCheckout = null;
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  'Choose different number',
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selected Number Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Text(item.flagEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.phoneNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '$_selectedCountryName • ${item.locationDisplay}',
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AVAILABLE',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pricing Breakdown (Telnyx + App Fee)
          const Text(
            'Transparent Pricing Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Telnyx Wholesale Monthly',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '\$${item.wholesaleMonthlyUsd.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'KeepSIMs App Fee',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.userTier.toUpperCase()} (${item.appFeePercent.toInt()}%)',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '+\$${item.appFeeUsd.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Monthly Charge',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '\$${item.totalMonthlyUsd.toStringAsFixed(2)} / mo',
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Wallet Balance Check
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasEnoughBalance
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasEnoughBalance
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasEnoughBalance ? Icons.account_balance_wallet : Icons.warning_amber,
                  color: hasEnoughBalance ? const Color(0xFF22C55E) : Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KeepSIMs Wallet: \$${walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        hasEnoughBalance
                            ? 'Sufficient balance for initial purchase.'
                            : 'Need \$${(item.totalMonthlyUsd - walletBalance).toStringAsFixed(2)} more to purchase.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!hasEnoughBalance)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.wallet);
                    },
                    child: const Text('Top Up'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confirm Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnoughBalance
                    ? AppColors.primary
                    : Colors.white24,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (!hasEnoughBalance || _isPurchasing)
                  ? null
                  : () => _confirmPurchase(item),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Activate Number (\$${item.totalMonthlyUsd.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Billed from your KeepSIMs wallet. Automatically renews every 30 days. You can cancel or release your number at any time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
