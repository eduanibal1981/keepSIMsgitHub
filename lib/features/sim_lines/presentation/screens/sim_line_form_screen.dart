import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

class SimLineFormScreen extends ConsumerStatefulWidget {
  final String? id;

  const SimLineFormScreen({super.key, this.id});

  @override
  ConsumerState<SimLineFormScreen> createState() => _SimLineFormScreenState();
}

class _SimLineFormScreenState extends ConsumerState<SimLineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();

  Country? _selectedCountry;
  Carrier? _selectedCarrier;
  String _selectedIcon = 'sim_card';
  String _selectedTier = 'standard';

  bool _isEdit = false;
  bool _hasPrepopulated = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.id != null;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _prepopulate(List<SimLine> lines, List<Country> countries) {
    if (_hasPrepopulated || !_isEdit || countries.isEmpty) return;

    final line = lines.firstWhereOrNull((l) => l.id == widget.id);
    if (line == null) return;

    _nicknameController.text = line.nickname ?? '';
    _selectedIcon = line.avatarIcon;
    _selectedTier = line.protectionTier;

    if (line.countryId != null) {
      _selectedCountry = countries.firstWhereOrNull(
        (c) => c.id == line.countryId,
      );
    }

    if (_selectedCountry != null &&
        line.phoneNumber.startsWith(_selectedCountry!.dialingCode)) {
      _phoneController.text = line.phoneNumber
          .substring(_selectedCountry!.dialingCode.length)
          .trim();
    } else {
      _phoneController.text = line.phoneNumber;
    }

    _hasPrepopulated = true;
  }

  void _onPhoneChanged(String val, List<Country> countries) {
    // Basic auto-detection no longer needed since country is chosen first.
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(simLinesControllerProvider).valueOrNull ?? [];
    final countries = ref.watch(supportedCountriesProvider).valueOrNull ?? [];
    final user = ref.watch(authControllerProvider).valueOrNull;
    final globalTier = user?.subscriptionTier ?? 'standard';

    final existingLinesCount = _isEdit
        ? lines.where((l) => l.id != widget.id).length
        : lines.length;
    final lineOrdinalPosition = existingLinesCount + 1;

    if (_isEdit && !_hasPrepopulated) {
      _prepopulate(lines, countries);
    }

    // Carriers are dynamically retrieved based on selected country ID
    final carriers = _selectedCountry == null
        ? <Carrier>[]
        : ref
                  .watch(carriersForCountryProvider(_selectedCountry!.id))
                  .valueOrNull ??
              [];

    // Pre-populate carrier in edit mode if needed
    if (_isEdit &&
        _hasPrepopulated &&
        _selectedCarrier == null &&
        _selectedCountry != null &&
        carriers.isNotEmpty) {
      final line = lines.firstWhereOrNull((l) => l.id == widget.id);
      if (line != null && line.carrierId != null) {
        final matched = carriers.firstWhereOrNull(
          (c) => c.id == line.carrierId,
        );
        if (matched != null) {
          _selectedCarrier = matched;
        }
      }
    }

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Protected Line' : 'Protect New Line',
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Selection Lookups
                    _buildSectionHeader(context, 'COUNTRY OF HOME'),
                    const SizedBox(height: 12),
                    _buildCountryPicker(context, countries),
                    const SizedBox(height: 24),

                    // Phone Number Field
                    _buildSectionHeader(context, 'SIM PHONE NUMBER'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.lightPrimary.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry != null
                                    ? _selectedCountry!.flagEmoji
                                    : '🌐',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedCountry?.dialingCode ?? '+00',
                                style: TextStyle(
                                  color: context.onSurfaceColor,
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: context.onSurfaceColor,
                              fontSize: 16,
                              fontFamily: 'monospace',
                            ),
                            decoration: _buildInputDecoration(
                              context,
                              hintText: 'Your SIM card phone number',
                              icon: Icons.phone_android,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                if (_selectedCountry == null) {
                                  return 'Please select a country first';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Dynamic Carrier brand dropdown
                    _buildSectionHeader(context, 'CARRIER BRAND'),
                    const SizedBox(height: 12),
                    _buildCarrierPicker(carriers),
                    const SizedBox(height: 24),

                    // Custom Nickname
                    _buildSectionHeader(context, 'NICKNAME (OPTIONAL)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nicknameController,
                      style: TextStyle(color: context.onSurfaceColor, fontSize: 16),
                      decoration: _buildInputDecoration(
                        context,
                        hintText: 'e.g. My Egypt Orange SIM',
                        icon: Icons.label_outline,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Selector
                    _buildSectionHeader(context, 'SELECT AVATAR ICON'),
                    const SizedBox(height: 12),
                    _buildAvatarSelector(),
                    const SizedBox(height: 32),

                    // Protection Tier Dynamic Billing Info Card
                    _buildSectionHeader(context, 'PROTECTION BILLING DETAILS'),
                    const SizedBox(height: 12),
                    _buildDynamicBillingSection(globalTier, lineOrdinalPosition, widget.id),
                    const SizedBox(height: 48),

                    // Glowing Action Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveLine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shadowColor: AppColors.primary.withOpacity(0.5),
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isEdit
                              ? 'Save Changes'
                              : 'Activate Shield Protection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = context.isDarkMode;
    return Text(
      title,
      style: AppTextStyles.labelMedium.copyWith(
        color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
    String? prefixText,
  }) {
    final isDark = context.isDarkMode;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 16),
      prefixIcon: Icon(icon, color: isDark ? AppColors.primaryLight : AppColors.lightPrimary, size: 20),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
      errorStyle: const TextStyle(color: AppColors.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? AppColors.primary : AppColors.lightPrimary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  Widget _buildCountryPicker(BuildContext context, List<Country> countries) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: () => _showCountrySearchSheet(countries),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.lightPrimary.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Text(
              _selectedCountry != null
                  ? '${_selectedCountry!.flagEmoji} '
                  : '🌐 ',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCountry != null
                    ? '${_selectedCountry!.name} (${_selectedCountry!.dialingCode})'
                    : 'Select Country',
                style: TextStyle(
                  color: _selectedCountry != null
                      ? context.onSurfaceColor
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrierPicker(List<Carrier> carriers) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<Carrier>(
          value: _selectedCarrier,
          hint: Text(
            'Select Carrier brand',
            style: TextStyle(color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight, fontSize: 16),
          ),
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          style: TextStyle(color: context.onSurfaceColor, fontSize: 16),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          items: carriers.map((c) {
            return DropdownMenuItem<Carrier>(value: c, child: Text(c.name));
          }).toList(),
          onChanged: (carrier) {
            setState(() {
              _selectedCarrier = carrier;
            });
          },
          decoration: const InputDecoration(border: InputBorder.none),
          validator: (value) {
            if (value == null) {
              return 'Please select a carrier brand';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    final isDark = context.isDarkMode;
    final icons = ['sim_card', 'phone', 'person', 'home'];
    IconData getIcon(String key) {
      switch (key) {
        case 'phone':
          return Icons.phone_android;
        case 'person':
          return Icons.person;
        case 'home':
          return Icons.home_outlined;
        default:
          return Icons.sim_card;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: icons.map((iconKey) {
        final isSelected = _selectedIcon == iconKey;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedIcon = iconKey;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.primary : AppColors.lightPrimary).withOpacity(0.15)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: 2,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.lightPrimary.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(
              getIcon(iconKey),
              color: isSelected
                  ? (isDark ? AppColors.primaryLight : AppColors.lightPrimary)
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              size: 28,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicBillingSection(
    String globalTier,
    int ordinalPosition,
    String? currentLineId,
  ) {
    final isDark = context.isDarkMode;
    final bool isStarter = globalTier == 'standard';
    final bool isPremium = globalTier == 'premium';
    final bool isFree = globalTier == 'basic';

    String planName = 'Starter Plan';
    Color planColor = isDark ? AppColors.primary : AppColors.lightPrimary;
    if (isPremium) {
      planName = 'Premium Shield';
      planColor = isDark ? Colors.purpleAccent : Colors.purple;
    } else if (isFree) {
      planName = 'Free Plan';
      planColor = isDark ? Colors.blueAccent : Colors.blue;
    }

    if (ordinalPosition <= 2) {
      // Line is fully included in the base rate
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: planColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: planColor.withOpacity(isDark ? 0.05 : 0.08),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: planColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: planColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Included in $planName',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FREE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This is protected line #$ordinalPosition in your account. Your $planName includes 2 SIM lines in the base subscription price. No additional charges will apply!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    } else {
      // Dynamic Extra Line Billing Info (lines >= 3)
      final String extraRateText = isStarter ? '\$0.10/mo (\$1.20/yr)' : '\$0.20/mo (\$2.40/yr)';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orangeAccent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(isDark ? 0.03 : 0.06),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extra Line Surcharge',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active tier: $planName',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    extraRateText,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Protecting this 3rd or subsequent SIM line will add a dynamic surcharge of $extraRateText to your active $planName billing, prorated for the rest of your annual period.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            if (isStarter) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    context.push('/settings/subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Go Premium for Unlimited Lines',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildTierGrid() {
    final isDark = context.isDarkMode;
    final tiers = [
      {
        'key': 'basic',
        'name': 'Basic Protection',
        'desc': 'Keeps line active with minimal scheduled top-ups.',
      },
      {
        'key': 'standard',
        'name': 'Standard Shield',
        'desc': 'Optimized inactivity checker + buffer safety days.',
      },
      {
        'key': 'premium',
        'name': 'Premium Shield',
        'desc':
            'Fast automated grace extensions & detailed deactivation alert logs.',
      },
    ];

    return Column(
      children: tiers.map((tier) {
        final isSelected = _selectedTier == tier['key'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTier = tier['key']!;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.lightPrimary).withOpacity(0.1)
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: 2,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.lightPrimary.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: tier['key']!,
                    groupValue: _selectedTier,
                    activeColor: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTier = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier['name']!,
                          style: TextStyle(
                            color: context.onSurfaceColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier['desc']!,
                          style: TextStyle(
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
          ),
        );
      }).toList(),
    );
  }

  void _showCountrySearchSheet(List<Country> countries) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCountries = countries.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialingCode.contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: context.isDarkMode ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'Supported Countries',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        style: TextStyle(color: context.isDarkMode ? Colors.white : AppColors.textPrimaryLight),
                        decoration: InputDecoration(
                          hintText: 'Search country or code...',
                          hintStyle: TextStyle(color: context.isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                          prefixIcon: Icon(Icons.search, color: context.isDarkMode ? AppColors.primaryLight : AppColors.lightPrimary),
                          filled: true,
                          fillColor: context.isDarkMode ? AppColors.darkCard : const Color(0xFFEAEEF1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDarkMode ? AppColors.primary : AppColors.lightPrimary,
                            ),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: context.isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  onPressed: () {
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredCountries.isEmpty
                            ? Center(
                                child: Text(
                                  'No countries found',
                                  style: TextStyle(
                                    color: context.isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredCountries.length,
                                itemBuilder: (context, index) {
                                  final c = filteredCountries[index];
                                  final isSelected = _selectedCountry?.id == c.id;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (context.isDarkMode ? AppColors.primary.withOpacity(0.15) : AppColors.lightPrimary.withOpacity(0.15))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Text(
                                        c.flagEmoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      title: Text(
                                        c.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (context.isDarkMode ? AppColors.primaryLight : AppColors.lightPrimary)
                                              : (context.isDarkMode ? Colors.white : AppColors.textPrimaryLight),
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        c.dialingCode,
                                        style: TextStyle(
                                          color: context.isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: context.isDarkMode ? AppColors.primaryLight : AppColors.lightPrimary,
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _selectedCountry = c;
                                          _selectedCarrier = null; // Reset carrier
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveLine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a country'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String localNumber = _phoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    final fullPhoneNumber = '${_selectedCountry!.dialingCode}$localNumber';

    final currentLines = ref.read(simLinesControllerProvider).valueOrNull ?? [];
    final isDuplicate = currentLines.any(
      (l) => l.phoneNumber == fullPhoneNumber && l.id != widget.id,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This phone number is already protected in your account.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      final globalTier = user?.subscriptionTier ?? 'standard';
      final selectedProtectionTier = _isEdit ? _selectedTier : globalTier;

      if (_isEdit) {
        // Fetch current line copy to update
        final line = currentLines.firstWhereOrNull((l) => l.id == widget.id);
        if (line == null)
          throw StateError('SIM line not found for ID: ${widget.id}');

        final updatedLine = line.copyWith(
          phoneNumber: fullPhoneNumber,
          nickname: _nicknameController.text.isNotEmpty
              ? _nicknameController.text
              : null,
          avatarIcon: _selectedIcon,
          countryId: _selectedCountry?.id,
          carrierId: _selectedCarrier?.id,
          protectionTier: selectedProtectionTier,
        );

        await ref
            .read(simLinesControllerProvider.notifier)
            .updateSimLine(updatedLine);
      } else {
        await ref
            .read(simLinesControllerProvider.notifier)
            .addSimLine(
              phoneNumber: fullPhoneNumber,
              nickname: _nicknameController.text.isNotEmpty
                  ? _nicknameController.text
                  : null,
              avatarIcon: _selectedIcon,
              countryId: _selectedCountry?.id,
              carrierId: _selectedCarrier?.id,
              protectionTier: selectedProtectionTier,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'SIM line details saved successfully.'
                  : 'SIM card added to shield protection!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save SIM details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
