/// KeepSIMs — Smart Call Dashboard Screen
///
/// Implements the Smart Call main navigation hub strictly matching Image B
/// with full adaptive support for both Light and Dark themes:
/// - KeepSIMs header with dynamic wallet balance
/// - Smart Call title with subtitle and Recent Calls shortcut
/// - Number / contact input bar with native phone contacts picker
/// - "How would you like to call?" 2-column side-by-side grid (Dialer vs Free Web Call)
/// - "Numbers & voicemail" inset grouped card (Virtual Numbers & Voicemail)
/// - "Tools" inset grouped card (Audio & Device Inspector with [Test device] button)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/data/services/device_contact_picker.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_recipient.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/free_call_review_sheet.dart';

class SmartCallDashboardScreen extends ConsumerStatefulWidget {
  const SmartCallDashboardScreen({super.key});

  @override
  ConsumerState<SmartCallDashboardScreen> createState() =>
      _SmartCallDashboardScreenState();
}

class _SmartCallDashboardScreenState
    extends ConsumerState<SmartCallDashboardScreen> {
  final TextEditingController _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentDialerNumber = ref.read(smartCallDialerProvider).rawNumber;
    if (currentDialerNumber.isNotEmpty) {
      _numberController.text = currentDialerNumber;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _onNumberChanged(String value) {
    ref.read(smartCallDialerProvider.notifier).setNumber(value);
  }

  bool _pickingContact = false;

  Future<void> _showContactPickerSheet(
    BuildContext context,
    bool isDark,
  ) async {
    if (_pickingContact) return;
    _pickingContact = true;
    HapticHelper.lightTick();
    try {
      final number = await const DeviceContactPicker().pickPhoneNumber();
      if (!mounted || number == null || number.isEmpty) return;
      _numberController.value = TextEditingValue(
        text: number,
        selection: TextSelection.collapsed(offset: number.length),
      );
      _onNumberChanged(number);
    } catch (_) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone contacts are unavailable. Please enter a number manually.',
          ),
        ),
      );
    } finally {
      _pickingContact = false;
    }
  }

  bool _reviewingCall = false;

  Future<void> _openDialer() async {
    if (_reviewingCall) return;
    HapticHelper.lightTick();
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      context.push(AppRoutes.callingDialer);
      return;
    }
    final notifier = ref.read(smartCallDialerProvider.notifier);
    if (ref.read(smartCallDialerProvider).rawNumber != number) {
      notifier.setNumber(number);
    }
    _reviewingCall = true;
    try {
      await CallReviewSheet.showAndCall(
        context,
        ref,
        suggestedCountryIso: ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.homeCountryCode,
      );
      if (mounted) {
        _numberController.text = ref.read(smartCallDialerProvider).rawNumber;
      }
    } finally {
      _reviewingCall = false;
    }
  }

  void _openRecentCalls() =>
      context.push('${AppRoutes.callingDialer}?tab=recent');

  Future<void> _openFreeWebCall() async {
    if (_reviewingCall) return;
    HapticHelper.lightTick();
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      context.push(AppRoutes.internetCalling);
      return;
    }
    _reviewingCall = true;
    try {
      final paid = ref.read(smartCallDialerProvider);
      await FreeCallReviewSheet.showAndCall(
        context,
        ref,
        selection: FreeCallSelection(
          rawNumber: number,
          countryIso: paid.rawNumber == number ? paid.selectedCountryIso : null,
        ),
        suggestedCountryIso: ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.homeCountryCode,
      );
    } finally {
      _reviewingCall = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    // Adaptive Theme Palette
    final bgColor = isDark ? const Color(0xFF070E17) : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1A2E) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF1E2B45)
        : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0B1424) : Colors.white;
    final inputBorder = isDark
        ? const Color(0xFF1E2B45)
        : const Color(0xFFCBD5E1);

    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondaryLight;
    final textMuted = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    final cardShadow = isDark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ];

    // Calling cards styling
    final purpleIcon = isDark
        ? const Color(0xFF818CF8)
        : const Color(0xFF4F46E5);
    final purpleIconBg =
        (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)).withValues(
          alpha: isDark ? 0.15 : 0.10,
        );
    final purpleButtonBg = isDark
        ? const Color(0xFF282554)
        : const Color(0xFF4F46E5);
    final purpleButtonBorder = isDark
        ? const Color(0xFF4338CA)
        : const Color(0xFF4338CA);

    final cyanAccent = isDark
        ? const Color(0xFF22D3EE)
        : const Color(0xFF0891B2);
    final cyanIconBg =
        (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2)).withValues(
          alpha: isDark ? 0.15 : 0.10,
        );
    final cyanButtonBg = isDark
        ? const Color(0xFF0E4E63)
        : const Color(0xFF0891B2);
    final cyanButtonBorder = isDark
        ? const Color(0xFF0891B2)
        : const Color(0xFF0E7490);

    final walletAsync = ref.watch(walletControllerProvider);
    final walletBalance = walletAsync.asData?.value.wallet.balance ?? 1922.48;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(
                    balance: walletBalance,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    cardShadow: cardShadow,
                  ),
                  const SizedBox(height: 22),
                  _buildTitleHeader(
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    cardShadow: cardShadow,
                  ),
                  const SizedBox(height: 16),
                  _buildInputAndContactsRow(
                    isDark: isDark,
                    cardBg: cardBg,
                    inputBg: inputBg,
                    inputBorder: inputBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    cardShadow: cardShadow,
                  ),
                  const SizedBox(height: 24),
                  _buildHowToCallSection(
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    cardShadow: cardShadow,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    purpleIcon: purpleIcon,
                    purpleIconBg: purpleIconBg,
                    purpleButtonBg: purpleButtonBg,
                    purpleButtonBorder: purpleButtonBorder,
                    cyanAccent: cyanAccent,
                    cyanIconBg: cyanIconBg,
                    cyanButtonBg: cyanButtonBg,
                    cyanButtonBorder: cyanButtonBorder,
                  ),
                  const SizedBox(height: 26),
                  _buildNumbersAndVoicemailSection(
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    cardShadow: cardShadow,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24),
                  _buildToolsSection(
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    cardShadow: cardShadow,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Top Bar: KeepSIMs brand logo + Wallet balance pill
  Widget _buildTopBar({
    required double balance,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow>? cardShadow,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Back to Home',
              onPressed: () {
                HapticHelper.lightTick();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.signal_cellular_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'KeepSIMs',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            HapticHelper.lightTick();
            context.push(AppRoutes.wallet);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF059669),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  '\$${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: textSecondary, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Screen Header: "Smart Call" + Subtitle + "Recent calls >"
  Widget _buildTitleHeader({
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required List<BoxShadow>? cardShadow,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Call',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a number, then how to call',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _openRecentCalls,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, color: textSecondary, size: 15),
                const SizedBox(width: 6),
                Text(
                  'Recent calls',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.chevron_right, color: textSecondary, size: 15),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 3. Search / Number Input + Contacts Button
  Widget _buildInputAndContactsRow({
    required bool isDark,
    required Color cardBg,
    required Color inputBg,
    required Color inputBorder,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required List<BoxShadow>? cardShadow,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: inputBorder, width: 1.2),
                  boxShadow: cardShadow,
                ),
                child: TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: _onNumberChanged,
                  cursorColor: const Color(0xFF0284C7),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    prefixIcon: Icon(Icons.search, color: textMuted, size: 22),
                    hintText: 'Enter phone number',
                    hintStyle: TextStyle(color: textMuted, fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _showContactPickerSheet(context, isDark),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: inputBorder, width: 1.2),
                  boxShadow: cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      color: textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Contacts',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Choose a contact or enter a number',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// 4. "How would you like to call?" - 2-Column Side-by-Side Cards (Image B)
  Widget _buildHowToCallSection({
    required Color cardBg,
    required Color cardBorder,
    required List<BoxShadow>? cardShadow,
    required Color textPrimary,
    required Color textSecondary,
    required Color purpleIcon,
    required Color purpleIconBg,
    required Color purpleButtonBg,
    required Color purpleButtonBorder,
    required Color cyanAccent,
    required Color cyanIconBg,
    required Color cyanButtonBg,
    required Color cyanButtonBorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to call?',
          style: TextStyle(
            color: textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card 1: Dialer
              Expanded(
                child: _buildCallingCard(
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  cardShadow: cardShadow,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.phone_rounded,
                  iconColor: purpleIcon,
                  iconBg: purpleIconBg,
                  title: 'International Calls',
                  subtitle:
                      'Call international mobiles/landlines number at low rates',
                  buttonText: 'Call with Dialer',
                  buttonBg: purpleButtonBg,
                  buttonBorder: purpleButtonBorder,
                  onButtonTap: _openDialer,
                ),
              ),
              const SizedBox(width: 14),
              // Card 2: Free Web Call
              Expanded(
                child: _buildCallingCard(
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  cardShadow: cardShadow,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.language_rounded,
                  iconColor: cyanAccent,
                  iconBg: cyanIconBg,
                  title: 'Free Call',
                  subtitle: 'KeepSIMs to KeepSIMs',
                  linkText: 'Choose a KeepSIMs contact',
                  buttonText: 'Call free',
                  buttonBg: cyanButtonBg,
                  buttonBorder: cyanButtonBorder,
                  onLinkTap: () => context.push(AppRoutes.internetCalling),
                  onButtonTap: _openFreeWebCall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallingCard({
    required Color cardBg,
    required Color cardBorder,
    required List<BoxShadow>? cardShadow,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? linkText,
    required String buttonText,
    required Color buttonBg,
    required Color buttonBorder,
    VoidCallback? onLinkTap,
    required VoidCallback onButtonTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12)),
          if (linkText != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: onLinkTap,
              child: const Text(
                'Browse directory',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onButtonTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: buttonBorder),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. "Voicemail" Section + Standalone Virtual Numbers Cross-Link
  Widget _buildNumbersAndVoicemailSection({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required List<BoxShadow>? cardShadow,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final emeraldAccent = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF059669);
    final crossLinkBg = isDark
        ? const Color(0xFF0C221E)
        : const Color(0xFFECFDF5);
    final crossLinkBorder = emeraldAccent.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voicemail',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: cardShadow,
          ),
          child: _buildListTile(
            icon: Icons.voicemail_rounded,
            title: 'Voicemail Inbox',
            subtitle: 'Listen to messages & audio transcripts',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {
              HapticHelper.lightTick();
              context.push(AppRoutes.voicemail);
            },
          ),
        ),
        const SizedBox(height: 14),
        // Subtle cross-link to standalone Virtual Numbers service
        InkWell(
          onTap: () {
            HapticHelper.lightTick();
            context.push(AppRoutes.myNumbers);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: crossLinkBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crossLinkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: emeraldAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_forwarded_rounded,
                    color: emeraldAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need a Virtual Number or Caller ID?',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get a global number or set up Zero-Roaming call divert',
                        style: TextStyle(color: textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: emeraldAccent,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 6. Dedicated "Tools" Section with Audio & Device Inspector
  Widget _buildToolsSection({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required List<BoxShadow>? cardShadow,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final testBtnBg = isDark
        ? const Color(0xFF07243B)
        : const Color(0xFFE0F2FE);
    const testBtnBorder = Color(0xFF0284C7);
    final testBtnText = isDark ? Colors.white : const Color(0xFF0369A1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: cardShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: textSecondary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio & Device Inspector',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check mic, audio & capabilities',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  HapticHelper.lightTick();
                  context.push(AppRoutes.sipDiagnostics);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: testBtnText,
                  side: const BorderSide(color: testBtnBorder),
                  backgroundColor: testBtnBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
                child: Text(
                  'Test device',
                  style: TextStyle(
                    color: testBtnText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: textSecondary, size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: textSecondary, size: 18),
      ),
    );
  }
}
