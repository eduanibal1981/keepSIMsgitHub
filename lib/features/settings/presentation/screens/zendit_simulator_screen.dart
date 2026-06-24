import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/topup/data/repositories/zendit_repository.dart';
import 'package:keep_sims/features/topup/data/models/top_up_result.dart';

class ZenditSimulatorScreen extends ConsumerStatefulWidget {
  const ZenditSimulatorScreen({super.key});

  @override
  ConsumerState<ZenditSimulatorScreen> createState() =>
      _ZenditSimulatorScreenState();
}

class _ZenditSimulatorScreenState extends ConsumerState<ZenditSimulatorScreen> {
  final TextEditingController _phoneController = TextEditingController(
    text: '96891234567',
  );
  final TextEditingController _countryController = TextEditingController(
    text: 'OM',
  );
  final TextEditingController _amountController = TextEditingController(
    text: '5.00',
  );

  final ZenditRepository _repository = ZenditRepository();

  bool _isLoading = false;
  String _status = 'Idle';
  TopUpResult? _result;

  List<dynamic> _availableOffers = [];
  bool _isFetchingOffers = false;
  Map<String, dynamic>? _matchedOffer;
  String _lastFetchedCountry = '';

  @override
  void initState() {
    super.initState();
    _countryController.addListener(_onCountryChanged);
    _amountController.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOffersForCountry(_countryController.text.trim());
    });
  }

  void _onCountryChanged() {
    final country = _countryController.text.trim().toUpperCase();
    if (country.length == 2 && country != _lastFetchedCountry) {
      _fetchOffersForCountry(country);
    } else if (country.length != 2) {
      setState(() {
        _availableOffers = [];
        _matchedOffer = null;
      });
    }
  }

  void _onAmountChanged() {
    _updateMatchedOffer();
  }

  Future<void> _fetchOffersForCountry(String country) async {
    if (country.length != 2) return;
    _lastFetchedCountry = country;
    setState(() {
      _isFetchingOffers = true;
      _matchedOffer = null;
    });

    final offers = await _repository.fetchOffersForCountry(country);

    if (mounted && _countryController.text.trim().toUpperCase() == country) {
      setState(() {
        _availableOffers = offers;
        _isFetchingOffers = false;
      });
      _updateMatchedOffer();
    }
  }

  void _updateMatchedOffer() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0 || _availableOffers.isEmpty) {
      setState(() {
        _matchedOffer = null;
      });
      return;
    }

    Map<String, dynamic>? bestOffer;
    double minDiff = double.infinity;

    for (final offer in _availableOffers) {
      final price = offer['price'];
      if (price == null) continue;

      final priceFixed = price['fixed'] as int? ?? 0;
      final divisor = price['currencyDivisor'] as int? ?? 100;
      final offerUsd = priceFixed / divisor;

      final diff = (offerUsd - amount).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestOffer = offer;
      }
    }

    setState(() {
      _matchedOffer = bestOffer;
    });
  }

  @override
  void dispose() {
    _countryController.removeListener(_onCountryChanged);
    _amountController.removeListener(_onAmountChanged);
    _phoneController.dispose();
    _countryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _executeTopUp() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final country = _countryController.text.trim();
    if (amount <= 0 ||
        _phoneController.text.isEmpty ||
        country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid details')),
      );
      return;
    }

    if (country.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country Code must be a 2-letter ISO code (e.g., EG, OM)')),
      );
      return;
    }

    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    const dialCodes = {
      'EG': '20',
      'OM': '968',
      'AE': '971',
      'SA': '966',
      'QA': '974',
      'BH': '973',
      'KW': '965',
      'US': '1',
      'GB': '44',
    };
    final expectedPrefix = dialCodes[country.toUpperCase()];
    if (expectedPrefix != null && !cleanPhone.startsWith(expectedPrefix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number prefix does not match Country Code ($country). Expected prefix: +$expectedPrefix',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Connecting to Zendit Sandbox...';
      _result = null;
    });

    await HapticHelper.mediumImpact();

    final result = await _repository.executeRecharge(
      phoneNumber: _phoneController.text,
      countryCode: _countryController.text,
      amount: amount,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = result;
        _status = result.success ? 'Success' : 'Failed';
      });
      if (result.success) {
        await HapticHelper.successFeedback();
      } else {
        await HapticHelper.errorFeedback();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Zendit Sandbox',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.onSurfaceColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputForm(),
            const SizedBox(height: 24),
            _buildStatusPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.dividerColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recharge Configuration',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country Code (e.g. OM, EG)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(2),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                isDense: true,
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_isFetchingOffers) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (_matchedOffer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.primaryColor.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Best Match Offer Details',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPreviewRow(
                      'Offer ID',
                      _matchedOffer!['offerId'] ?? 'N/A',
                    ),
                    const SizedBox(height: 4),
                    _buildPreviewRow(
                      'Retail Price (USD)',
                      '\$${((_matchedOffer!['price']?['fixed'] as int? ?? 0) / (_matchedOffer!['price']?['currencyDivisor'] as int? ?? 100)).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 4),
                    _buildPreviewRow(
                      'Sent Benefits (Local)',
                      '${((_matchedOffer!['send']?['fixed'] as int? ?? 0) / (_matchedOffer!['send']?['currencyDivisor'] as int? ?? 100)).toStringAsFixed(2)} ${_matchedOffer!['send']?['currency'] ?? ""}',
                    ),
                  ],
                ),
              ),
            ] else if (_countryController.text.trim().length == 2 && _availableOffers.isEmpty && !_isFetchingOffers) ...[
              const SizedBox(height: 16),
              Text(
                'No offers available for this country code.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _executeTopUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Execute Sandbox Top-Up',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      elevation: 0,
      color: _isLoading
          ? Colors.grey.withOpacity(0.1)
          : (_result?.success == true
                ? Colors.green.withOpacity(0.1)
                : (_result?.success == false
                      ? Colors.red.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:', style: AppTextStyles.titleMedium),
                Text(
                  _status,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isLoading
                        ? AppColors.primary
                        : (_result?.success == true
                              ? Colors.green
                              : (_result?.success == false
                                    ? Colors.red
                                    : Colors.grey)),
                  ),
                ),
              ],
            ),
            if (_result != null) ...[
              const Divider(height: 24),
              if (_result!.success) ...[
                _buildResultRow('Transaction ID', _result!.transactionId),
                const SizedBox(height: 8),
                _buildResultRow(
                  'Amount Topped Up',
                  '\$${_result!.amountToppedUp?.toStringAsFixed(2) ?? "0.00"}',
                ),
                if (_result!.localBenefit != null) ...[
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Local Benefit Sent',
                    _result!.localBenefit!,
                  ),
                ],
              ] else ...[
                _buildResultRow(
                  'Error',
                  _result!.errorMessage ?? 'Unknown error',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
