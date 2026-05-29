/// SIM Shield — Onboarding Screen
///
/// A premium, dark-themed 4-step animated onboarding wizard.
/// Collects user details, country, currency, protection tier, and smart preferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 2 Data
  final TextEditingController _nameController = TextEditingController();
  String _selectedCountryCode = 'EG';
  String _selectedCurrency = 'USD';

  // Step 3 Data
  String _selectedTier = 'standard';

  // Step 4 Data
  final bool _isPowerUser = false;
  bool _agreedToTerms = false;

  final List<Map<String, String>> _countries = [
    {'code': 'EG', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': 'SA', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': 'AE', 'name': 'United Arab Emirates', 'flag': '🇦🇪'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'PH', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': 'JO', 'name': 'Jordan', 'flag': '🇯🇴'},
    {'code': 'PK', 'name': 'Pakistan', 'flag': '🇵🇰'},
  ];

  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar (\$)'},
    {'code': 'EUR', 'name': 'Euro (€)'},
    {'code': 'GBP', 'name': 'British Pound (£)'},
    {'code': 'SAR', 'name': 'Saudi Riyal (SR)'},
    {'code': 'EGP', 'name': 'Egyptian Pound (EGP)'},
    {'code': 'AED', 'name': 'UAE Dirham (AED)'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill user name from auth profile if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(authControllerProvider).valueOrNull;
      if (profile?.fullName != null && profile!.fullName!.isNotEmpty) {
        _nameController.text = profile.fullName!;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the Terms of Service to proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name.'),
          backgroundColor: AppColors.error,
        ),
      );
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    final result = await ref
        .read(profileControllerProvider.notifier)
        .completeOnboarding(
          fullName: name,
          homeCountryCode: _selectedCountryCode,
          preferredCurrency: _selectedCurrency,
          isPowerUser: _isPowerUser,
          subscriptionTier: _selectedTier,
        );

    if (mounted && result is Failure<UserProfile>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header / Step Progress Indicator ───────────────────────
            _buildHeader(),

            // ── Main Page Carousel ────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildStepWelcome(),
                  _buildStepProfile(),
                  _buildStepTiers(),
                  _buildStepSmartPreferences(),
                ],
              ),
            ),

            // ── Footer Navigation Buttons ──────────────────────────────
            _buildFooter(profileState.isLoading),
          ],
        ),
      ),
    );
  }

  // ── Header Widget ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Setup Protection',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Step ${_currentPage + 1} of 4',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Clean custom linear progress indicator
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width:
                    MediaQuery.of(context).size.width *
                        ((_currentPage + 1) / 4) -
                    48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Welcome Screen ──────────────────────────────────────
  Widget _buildStepWelcome() {
    return GestureDetector(
      onTap: _nextPage,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white, // Seamless white background
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/startinwhite.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.shield_rounded,
                    color: AppColors.primary,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to KeepSIMs',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keep your international SIM cards protected from carrier deactivation due to inactivity automatically.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Start'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Step 2: Personalize Profile Screen ───────────────────────────
  Widget _buildStepProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Personalize Profile',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us who you are and select your defaults to let us tailor currency displays and geo-tracking features.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Name Input
          Text(
            'Full Name',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'John Doe',
              hintStyle: TextStyle(color: AppColors.textTertiaryDark),
              filled: true,
              fillColor: AppColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              prefixIcon: Icon(
                Icons.person_rounded,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Home Country Dropdown
          Text(
            'Home Country',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                dropdownColor: AppColors.darkSurface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondaryDark,
                ),
                isExpanded: true,
                items: _countries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Row(
                      children: [
                        Text(
                          country['flag']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          country['name']!,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCountryCode = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Currency Dropdown
          Text(
            'Preferred Currency',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: AppColors.darkSurface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondaryDark,
                ),
                isExpanded: true,
                items: _currencies.map((curr) {
                  return DropdownMenuItem<String>(
                    value: curr['code'],
                    child: Text(
                      curr['name']!,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCurrency = val;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Choose Protection Tier Screen ────────────────────────
  Widget _buildStepTiers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Select Protection Plan',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your account-wide protection plan. Upgrade, downgrade, or cancel at any time.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Free Plan Card
          _buildTierCard(
            id: 'basic',
            title: 'Free Plan',
            price: '\$0',
            period: 'Always free',
            desc:
                'Essential manual monitoring for a single line.',
            color: Colors.blueAccent,
            features: [
              'Protect 1 SIM line maximum',
              'Mobile push notifications only',
              'Telegram recharge requests',
              'Manual in-app checks',
            ],
          ),
          const SizedBox(height: 16),

          // Starter Plan Card
          _buildTierCard(
            id: 'standard',
            title: 'Starter Plan',
            price: '\$0.20',
            period: 'mo base',
            desc:
                'Includes 2 SIM lines. Extra lines: \$0.10/mo each (annually). Max 5 lines.',
            color: AppColors.primary,
            features: [
              'Includes 2 lines in base (\$2.40/yr)',
              'Extra lines: \$0.10/mo (\$1.20/yr) each',
              'Protect up to 5 SIM lines max',
              'Push, WhatsApp, Telegram, Email alerts',
              'WhatsApp & Telegram recharge requests',
              'Travel / Home modes active',
              '1× secure line verification check',
            ],
          ),
          const SizedBox(height: 16),

          // Premium Shield Card
          _buildTierCard(
            id: 'premium',
            title: 'Premium Shield',
            price: '\$0.40',
            period: 'mo base',
            desc:
                'Includes 2 SIM lines. Extra lines: \$0.20/mo each (annually). Unlimited lines.',
            color: Colors.purpleAccent,
            isPopular: true,
            features: [
              'Includes 2 lines in base (\$4.80/yr)',
              'Extra lines: \$0.20/mo (\$2.40/yr) each',
              'Protect unlimited SIM lines',
              'All standard notification channels',
              'Fully automated in-app recharge',
              'Smart Geolocation deactivation freeze',
              'Baqa (local calls + data detection)',
              'Unlimited secure line verifications',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String id,
    required String title,
    required String price,
    required String period,
    required String desc,
    required Color color,
    bool isPopular = false,
    required List<String> features,
  }) {
    final bool isSelected = _selectedTier == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTier = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.darkBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              if (isPopular)
                Positioned(
                  right: -12,
                  top: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      'POPULAR',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? color : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : AppColors.textTertiaryDark,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              price,
                              style: AppTextStyles.headlineLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '/$period',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.3,
                      ),
                    ),
                    const Divider(color: AppColors.darkBorder, height: 24),
                    Column(
                      children: features.map((feat) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_rounded, color: color, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feat,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 4: Smart Preferences Screen ──────────────────────────────
  Widget _buildStepSmartPreferences() {
    final selectedCountry = _countries.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => {'code': '', 'name': '', 'flag': ''},
    );

    final selectedCurrency = _currencies.firstWhere(
      (curr) => curr['code'] == _selectedCurrency,
      orElse: () => {'code': '', 'name': ''},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Smart Preferences',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm your configuration and accept the terms of service to activate active line shield guards.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Selection Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Review Configuration',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSummaryRow(
                  label: 'Full Name',
                  value: _nameController.text.trim().isEmpty
                      ? 'Not specified'
                      : _nameController.text.trim(),
                  icon: Icons.person_rounded,
                ),
                const Divider(color: AppColors.darkBorder, height: 24),
                _buildSummaryRow(
                  label: 'Home Country',
                  value: '${selectedCountry['flag']} ${selectedCountry['name']}',
                  icon: Icons.public_rounded,
                ),
                const Divider(color: AppColors.darkBorder, height: 24),
                _buildSummaryRow(
                  label: 'Preferred Currency',
                  value: selectedCurrency['name'] ?? _selectedCurrency,
                  icon: Icons.payments_rounded,
                ),
                const Divider(color: AppColors.darkBorder, height: 24),
                _buildSummaryRow(
                  label: 'Selected Plan',
                  value: _selectedTier == 'basic'
                      ? 'Free Plan (\$0)'
                      : (_selectedTier == 'standard'
                          ? 'Starter Plan (\$0.20/mo base)'
                          : 'Premium Shield (\$0.40/mo base)'),
                  icon: Icons.shield_rounded,
                  valueColor: _selectedTier == 'basic'
                      ? Colors.blueAccent
                      : (_selectedTier == 'standard'
                          ? AppColors.primary
                          : Colors.purpleAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Terms Acceptance Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                _agreedToTerms = !_agreedToTerms;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _agreedToTerms
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: _agreedToTerms
                          ? AppColors.primary
                          : AppColors.darkBorder,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _agreedToTerms
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I confirm that I understand and agree to the SIM Shield Terms of Service and Privacy Policy. I authorize smart checks on my protected lines.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryDark,
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

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: AppColors.textSecondaryDark,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Footer Navigation Buttons ────────────────────────────────────
  Widget _buildFooter(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Back Button
          if (_currentPage > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _prevPage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.darkBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ),
            ),

          // Next / Submit Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (isLoading)
                    ? null
                    : (_currentPage == 3)
                    ? _submit
                    : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _currentPage == 0
                            ? 'Start'
                            : (_currentPage == 3 ? 'Start Protecting' : 'Continue'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
