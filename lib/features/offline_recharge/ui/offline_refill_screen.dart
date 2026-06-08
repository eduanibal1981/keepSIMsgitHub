import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import '../controller/offline_refill_controller.dart';
import '../model/offline_refill_model.dart';

class OfflineRefillScreen extends ConsumerStatefulWidget {
  final String? simLineId;
  const OfflineRefillScreen({super.key, this.simLineId});

  @override
  ConsumerState<OfflineRefillScreen> createState() =>
      _OfflineRefillScreenState();
}

class _OfflineRefillScreenState extends ConsumerState<OfflineRefillScreen> {
  bool _isInit = false;
  bool _isEnabled = true;
  double _refillAmount = 10.00;
  String? _selectedSimLineId;
  String? _customPhoneNumber;

  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _loadSettings(OfflineRefillSettings settings) {
    if (_isInit) return;
    _isEnabled = true;
    _refillAmount = settings.defaultRefillAmount;
    _selectedSimLineId = widget.simLineId ?? settings.targetSimLineId;
    _customPhoneNumber = settings.customPhoneNumber;
    _phoneController.text = _customPhoneNumber ?? '';
    _isInit = true;
  }

  String _getCarrierLabel(String? carrierId) {
    if (carrierId == null) return 'CARRIER';
    final cid = carrierId.toLowerCase();
    if (cid.contains('ooredoo')) return 'OOREDOO';
    if (cid.contains('omantel')) return 'OMANTEL';
    if (cid.contains('vodafone')) return 'VODAFONE';
    if (cid.contains('orange')) return 'ORANGE';
    return 'CARRIER';
  }

  void _showSimLinePickerSheet(BuildContext context, List<dynamic> simLines) {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sim_card_rounded,
                      color: Colors.purpleAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Select Target SIM Line',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (simLines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No registered SIM lines found.',
                      style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: simLines.length,
                    itemBuilder: (context, index) {
                      final line = simLines[index];
                      final isSelected = line.id == _selectedSimLineId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.purpleAccent.withOpacity(isDark ? 0.08 : 0.1)
                              : (isDark ? AppColors.darkCard.withOpacity(0.4) : const Color(0xFFEAEEF1)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.purpleAccent
                                : (isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder),
                            width: 1.0,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedSimLineId = line.id;
                            });
                            Navigator.pop(context);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sim_card_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                          title: Text(
                            line.nickname ?? 'SIM Line',
                            style: TextStyle(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            line.phoneNumber,
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.purpleAccent,
                                )
                              : null,
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    // Check Premium subscription restriction
    final isPremium =
        user != null && user.subscriptionTier.toLowerCase() == 'premium';

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.onSurfaceColor,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Offline Refill (SMS/WA)',
          style: AppTextStyles.titleLarge.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isPremium
            ? _buildPremiumSettingsUI()
            : _buildNonPremiumPaywallUI(),
      ),
    );
  }

  // ── NON-PREMIUM PAYWALL UI ──────────────────────────────────────────
  Widget _buildNonPremiumPaywallUI() {
    final isDark = context.isDarkMode;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Glassmorphic Locked Shield Icon Card
          Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withOpacity(0.6) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.purpleAccent.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: Colors.purpleAccent,
              size: 80,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Offline Refill Protection',
            style: AppTextStyles.headlineMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PREMIUM EXCLUSIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Never get stranded without mobile data again. SIM Shield Premium allows you to refill your SIM card balance offline over standard local SMS or WhatsApp messages when you have zero internet connection.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Feature highlights List
          _buildFeatureHighlightRow(
            icon: Icons.wifi_off_rounded,
            title: '100% Offline Capability',
            subtitle:
                'Deducts from your SIM Shield wallet to credit your line via local SMS gateway failovers.',
          ),
          const SizedBox(height: 20),
          _buildFeatureHighlightRow(
            icon: Icons.dialpad_rounded,
            title: 'Dynamic USSD Plan Activation',
            subtitle:
                'Provides exact copy-paste dial codes (e.g., *900*1#) to activate Data+Call packages offline.',
          ),
          const SizedBox(height: 20),
          _buildFeatureHighlightRow(
            icon: Icons.sms_outlined,
            title: 'Dual-Channel Support',
            subtitle:
                'Text "REFILL" using standard SMS or WhatsApp depending on what cellular coverage is available.',
          ),
          const SizedBox(height: 48),
          // Upgrade Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => context.push('/settings/subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Upgrade to Premium',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlightRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.purpleAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PREMIUM CONFIGURATION SETTINGS UI ────────────────────────────────
  Widget _buildPremiumSettingsUI() {
    final settingsState = ref.watch(offlineRefillControllerProvider);
    final simLinesState = ref.watch(simLinesControllerProvider);
    final walletState = ref.watch(walletControllerProvider);
    final isDark = context.isDarkMode;

    return settingsState.when(
      data: (settings) {
        _loadSettings(settings);

        final simLines = simLinesState.valueOrNull ?? [];
        final walletBalance = walletState.valueOrNull?.wallet.balance ?? 0.00;

        // Find currently selected SIM line model to fetch carrier USSDSuggestions
        final activeSim = simLines.isEmpty
            ? null
            : simLines.firstWhere(
                (l) => l.id == _selectedSimLineId,
                orElse: () => simLines.first,
              );

        if (_selectedSimLineId == null && activeSim != null) {
          _selectedSimLineId = activeSim.id;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bot Details Info Card ──────────────────────────────
              if (_isEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard.withOpacity(0.3) : const Color(0xFFEAEEF1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.purpleAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to Trigger Offline Refill',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                          children: const [
                            TextSpan(
                              text:
                                  'If you have zero mobile data, send a standard SMS or WhatsApp message containing only ',
                            ),
                            TextSpan(
                              text: 'REFILL',
                              style: TextStyle(
                                color: Colors.deepOrangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' to our secure system gateway:'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isDark ? null : Border.all(color: AppColors.lightBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+1 (202) 555-0199',
                              style: TextStyle(
                                color: context.onSurfaceColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Target SIM Line Card (Interactive Selector) ─────────
              if (activeSim != null) ...[
                Text(
                  'TARGET SIM LINE',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showSimLinePickerSheet(context, simLines),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard.withOpacity(0.4) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.sim_card_rounded,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeSim.nickname ?? 'Target SIM Line',
                                style: TextStyle(
                                  color: context.onSurfaceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeSim.phoneNumber,
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activeSim.carrierId != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _getCarrierLabel(activeSim.carrierId),
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Change',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.purpleAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.purpleAccent,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Default Refill Amount Config ────────────────────────
              Text(
                'CONFIGURE CASH REFILL AMOUNT',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Refill Amount',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_refillAmount.toStringAsFixed(2)} USD',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.deepOrangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [5.0, 10.0, 25.0, 50.0].map((amt) {
                        final isSel = _refillAmount == amt;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _refillAmount = amt;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? Colors.deepOrangeAccent.withOpacity(0.12)
                                  : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFEAEEF1)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? Colors.deepOrangeAccent
                                    : Colors.transparent,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '\$${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isSel
                                    ? Colors.deepOrangeAccent
                                    : context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Current Wallet Balance Info Row
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: walletBalance < _refillAmount
                              ? AppColors.error
                              : AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wallet Balance: \$${walletBalance.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              color: walletBalance < _refillAmount
                                  ? AppColors.error
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (walletBalance < _refillAmount)
                          Text(
                            '⚠️ Low Balance',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── USSD Plan Suggestions Guide Card ───────────────────
              if (activeSim != null && activeSim.carrierId != null) ...[
                Text(
                  'LOCAL CARRIER PLAN SUGGESTIONS',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ref
                  .watch(carrierUssdSuggestionsProvider(activeSim.carrierId!))
                  .when(
                    data: (suggestions) {
                      if (suggestions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard.withOpacity(0.2) : const Color(0xFFEAEEF1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'No standard USSD dial codes found for this carrier. You will still receive the cash refill successfully on your line.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        );
                      }

                        return Container(
                          padding: const EdgeInsets.all(18.0),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard.withOpacity(0.4) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dynamic Dial Codes Preview',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: context.onSurfaceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'After the offline refill completes, the bot will suggest dialing these exact codes on your phone to instantly unlock Data+Calls offline:',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ...suggestions.map((s) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFEAEEF1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          s.ussdCode,
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.planName,
                                              style: TextStyle(
                                                color: context.onSurfaceColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Cost: \$${s.cost.toStringAsFixed(2)}',
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
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            color: Colors.deepOrangeAccent,
                          ),
                        ),
                      ),
                      error: (err, _) => Text(
                        'Failed to load carrier suggestions: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                const SizedBox(height: 24),
              ],

              // ── Custom Sender Phone Number Card ────────────────────
              Text(
                'WHATSAPP/SMS SENDER OVERRIDE',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Number',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If you trigger refills from a different number than your main profile phone, enter it below with country code (e.g. 96891234567).',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      style: TextStyle(color: context.onSurfaceColor),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter phone number (digits only)',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.3) : AppColors.textTertiaryLight,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black.withOpacity(0.15) : const Color(0xFFEAEEF1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // ── Save Configurations Button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final update = settings.copyWith(
                      isEnabled: true,
                      defaultRefillAmount: _refillAmount,
                      targetSimLineId: _selectedSimLineId,
                      customPhoneNumber: _phoneController.text.trim().isEmpty
                          ? null
                          : _phoneController.text.trim(),
                    );
                    final notifier = ref.read(
                      offlineRefillControllerProvider.notifier,
                    );
                    final success = await notifier.saveSettings(update);

                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Offline Refill settings saved successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    'Save Settings',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrangeAccent),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading settings: $err',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(offlineRefillControllerProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
