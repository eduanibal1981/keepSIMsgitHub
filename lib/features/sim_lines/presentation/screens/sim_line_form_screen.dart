import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
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
      _selectedCountry = countries.firstWhereOrNull((c) => c.id == line.countryId);
    }

    if (_selectedCountry != null && line.phoneNumber.startsWith(_selectedCountry!.dialingCode)) {
      _phoneController.text = line.phoneNumber.substring(_selectedCountry!.dialingCode.length).trim();
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

    if (_isEdit && !_hasPrepopulated) {
      _prepopulate(lines, countries);
    }

    // Carriers are dynamically retrieved based on selected country ID
    final carriers = _selectedCountry == null
        ? <Carrier>[]
        : ref.watch(carriersForCountryProvider(_selectedCountry!.id)).valueOrNull ?? [];

    // Pre-populate carrier in edit mode if needed
    if (_isEdit && _hasPrepopulated && _selectedCarrier == null && _selectedCountry != null && carriers.isNotEmpty) {
      final line = lines.firstWhereOrNull((l) => l.id == widget.id);
      if (line != null && line.carrierId != null) {
        final matched = carriers.firstWhereOrNull((c) => c.id == line.carrierId);
        if (matched != null) {
          _selectedCarrier = matched;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Protected Line' : 'Protect New Line',
          style: AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimaryDark),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Selection Lookups
                    _buildSectionHeader('COUNTRY OF HOME'),
                    const SizedBox(height: 12),
                    _buildCountryPicker(countries),
                    const SizedBox(height: 24),

                    // Phone Number Field
                    _buildSectionHeader('SIM PHONE NUMBER'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.darkCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.darkBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry != null ? _selectedCountry!.flagEmoji : '🌐',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedCountry?.dialingCode ?? '+00',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                            decoration: _buildInputDecoration(
                              hintText: '100 123 4567',
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
                    _buildSectionHeader('CARRIER BRAND'),
                    const SizedBox(height: 12),
                    _buildCarrierPicker(carriers),
                    const SizedBox(height: 24),

                    // Custom Nickname
                    _buildSectionHeader('NICKNAME (OPTIONAL)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nicknameController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: _buildInputDecoration(
                        hintText: 'e.g. My Egypt Orange SIM',
                        icon: Icons.label_outline,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Selector
                    _buildSectionHeader('SELECT AVATAR ICON'),
                    const SizedBox(height: 12),
                    _buildAvatarSelector(),
                    const SizedBox(height: 32),

                    // Protection Tier Selection Card Grid
                    _buildSectionHeader('PROTECTION SERVICE TIER'),
                    const SizedBox(height: 12),
                    _buildTierGrid(),
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
                          _isEdit ? 'Save Changes' : 'Activate Shield Protection',
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.primaryLight,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData icon, String? prefixText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 16),
      prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
      filled: true,
      fillColor: AppColors.darkCard,
      errorStyle: const TextStyle(color: AppColors.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
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

  Widget _buildCountryPicker(List<Country> countries) {
    return InkWell(
      onTap: () => _showCountrySearchSheet(countries),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Text(
              _selectedCountry != null ? '${_selectedCountry!.flagEmoji} ' : '🌐 ',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCountry != null
                    ? '${_selectedCountry!.name} (${_selectedCountry!.dialingCode})'
                    : 'Select Country',
                style: TextStyle(
                  color: _selectedCountry != null ? Colors.white : AppColors.textTertiaryDark,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrierPicker(List<Carrier> carriers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<Carrier>(
          value: _selectedCarrier,
          hint: const Text(
            'Select Carrier brand',
            style: TextStyle(color: AppColors.textTertiaryDark, fontSize: 16),
          ),
          dropdownColor: AppColors.darkSurface,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryDark),
          items: carriers.map((c) {
            return DropdownMenuItem<Carrier>(
              value: c,
              child: Text(c.name),
            );
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
              color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.darkBorder,
                width: 2,
              ),
            ),
            child: Icon(
              getIcon(iconKey),
              color: isSelected ? AppColors.primaryLight : AppColors.textSecondaryDark,
              size: 28,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTierGrid() {
    final tiers = [
      {'key': 'basic', 'name': 'Basic Protection', 'desc': 'Keeps line active with minimal scheduled top-ups.'},
      {'key': 'standard', 'name': 'Standard Shield', 'desc': 'Optimized inactivity checker + buffer safety days.'},
      {'key': 'premium', 'name': 'Premium Shield', 'desc': 'Fast automated grace extensions & detailed deactivation alert logs.'},
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
                color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.darkBorder,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: tier['key']!,
                    groupValue: _selectedTier,
                    activeColor: AppColors.primaryLight,
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
                            color: isSelected ? Colors.white : AppColors.textPrimaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier['desc']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : AppColors.textSecondaryDark,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supported Countries',
                style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final c = countries[index];
                    return ListTile(
                      leading: Text(c.flagEmoji, style: const TextStyle(fontSize: 24)),
                      title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      subtitle: Text(c.dialingCode, style: const TextStyle(color: AppColors.textSecondaryDark)),
                      onTap: () {
                        setState(() {
                          _selectedCountry = c;
                          _selectedCarrier = null; // Reset carrier
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEdit) {
        // Fetch current line copy to update
        final currentLines = ref.read(simLinesControllerProvider).valueOrNull ?? [];
        final line = currentLines.firstWhereOrNull((l) => l.id == widget.id);
        if (line == null) throw StateError('SIM line not found for ID: ${widget.id}');
        
        String localNumber = _phoneController.text.trim();
        if (localNumber.startsWith('0')) {
          localNumber = localNumber.substring(1);
        }
        final fullPhoneNumber = '${_selectedCountry!.dialingCode}$localNumber';
        
        final updatedLine = line.copyWith(
          phoneNumber: fullPhoneNumber,
          nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
          avatarIcon: _selectedIcon,
          countryId: _selectedCountry?.id,
          carrierId: _selectedCarrier?.id,
          protectionTier: _selectedTier,
        );

        await ref.read(simLinesControllerProvider.notifier).updateSimLine(updatedLine);
      } else {
        String localNumber = _phoneController.text.trim();
        if (localNumber.startsWith('0')) {
          localNumber = localNumber.substring(1);
        }
        final fullPhoneNumber = '${_selectedCountry!.dialingCode}$localNumber';
        
        await ref.read(simLinesControllerProvider.notifier).addSimLine(
              phoneNumber: fullPhoneNumber,
              nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
              avatarIcon: _selectedIcon,
              countryId: _selectedCountry?.id,
              carrierId: _selectedCarrier?.id,
              protectionTier: _selectedTier,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'SIM line details saved successfully.' : 'SIM card added to shield protection!'),
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
