import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/services/analytics_service.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

enum PayPalCheckoutStatus {
  idle,
  creatingOrder,
  awaitingApproval,
  capturing,
  success,
  failed,
}

class PayPalCheckoutScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? paymentReason;
  final VoidCallback? onSuccess;
  final String paymentKind;
  final String? plan;
  final String? simLineId;

  const PayPalCheckoutScreen({
    super.key,
    this.initialAmount,
    this.paymentReason,
    this.onSuccess,
    this.paymentKind = 'deposit',
    this.plan,
    this.simLineId,
  });

  @override
  ConsumerState<PayPalCheckoutScreen> createState() => _PayPalCheckoutScreenState();
}

class _PayPalCheckoutScreenState extends ConsumerState<PayPalCheckoutScreen>
    with WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController(text: '10.00');
  double _selectedDepositAmount = 10.00;
  PayPalCheckoutStatus _status = PayPalCheckoutStatus.idle;
  String? _orderId;
  String? _approveUrl;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;
  bool _isCapturingManually = false;

  /// Latches once the capture has been reported, so the four racing detectors
  /// cannot fire [widget.onSuccess] more than once.
  bool _successHandled = false;
  StreamSubscription<Uri>? _linkSub;
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  int _secondsAwaiting = 0;

  /// How long the approval can sit before the screen stops claiming everything
  /// is fine and offers the manual check instead.
  static const int _slowApprovalSeconds = 25;

  static const List<double> _presetAmounts = [10.0, 20.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForReturnDeepLink();
    final amt = widget.initialAmount ?? 10.0;
    _selectedDepositAmount = amt < 1.00 ? 1.00 : amt;
    _amountController.text = _selectedDepositAmount.toStringAsFixed(2);
    Future.microtask(() {
      ref.read(analyticsServiceProvider).logRechargeFunnelStep(
            'checkout_started',
            parameters: {'amount': _selectedDepositAmount},
          );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _stopWaitTimers();
    _realtimeChannel?.unsubscribe();
    _amountController.dispose();
    super.dispose();
  }

  /// The paypal-return function bounces the browser to
  /// `io.supabase.keepsims://payment-success`, which is what brings the app
  /// forward and lets us verify without the user having to press anything.
  void _listenForReturnDeepLink() {
    _linkSub = AppLinks().uriLinkStream.listen(
      (uri) {
        // The scheme is shared with Supabase's auth callback, so the host is
        // the only thing that says this link is ours.
        if (uri.host != 'payment-success') return;
        if (!mounted || _orderId == null) return;

        // A stale link from an earlier order must not resolve this one.
        final returned = uri.queryParameters['order_id'];
        if (returned != null && returned.isNotEmpty && returned != _orderId) return;

        // On iOS the SFSafariViewController stays up behind the app.
        closeInAppWebView();

        if (uri.queryParameters['status'] == 'cancel') {
          _onUserCancelled();
        } else {
          _verifyAfterReturn();
        }
      },
      onError: (_) {
        // A dead link stream only costs us the fast path; the lifecycle and
        // poll fallbacks still resolve the order.
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_status != PayPalCheckoutStatus.awaitingApproval) return;
    final orderId = _orderId;
    if (orderId == null) return;

    // The realtime socket does not survive backgrounding, and Postgres changes
    // that fired while we were away are never replayed on reconnect — so a
    // payment captured in the browser would otherwise leave this screen
    // spinning forever. Re-read the row, then re-arm the subscription.
    _refreshOrderStatus();
    _subscribeToOrderRealtime(orderId);
  }

  void _startWaitTimers() {
    _stopWaitTimers();
    _secondsAwaiting = 0;
    // Belt to the deep link's braces: covers a browser that never bounced back
    // and a webhook that landed while the socket was down.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshOrderStatus(),
    );
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsAwaiting++);
    });
  }

  void _stopWaitTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _onAmountSelected(double amount) {
    HapticHelper.lightTick();
    setState(() {
      _selectedDepositAmount = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  Future<void> _initiateCheckout() async {
    // 1. Biometric / Passcode Auth Guard Gate (Defect #7 fix)
    final authResult = await ref.read(paymentAuthGuardProvider).confirmPayment(
      reason: 'Authorize PayPal payment',
    );

    if (authResult != BiometricResult.success) {
      if (mounted && authResult == BiometricResult.lockedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.biometricLockout ??
                  'Biometric authentication locked due to too many failed attempts.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final rawAmt = double.tryParse(_amountController.text) ?? _selectedDepositAmount;
    final effectiveAmt = rawAmt < 1.00 ? 1.00 : rawAmt;

    setState(() {
      _status = PayPalCheckoutStatus.creatingOrder;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Create Order on Server (Server-priced for plan, floor clamped for deposit)
      // G10: device_id + platform ride in the body (not a header) so no CORS
      // preflight change is needed on mobile, and the function assesses device
      // risk before it ever asks PayPal for an order.
      final identity = ref.read(deviceIdentityServiceProvider);
      final response = await supabase.functions.invoke(
        'create-paypal-order',
        headers: await identity.appCheckHeaders(),
        body: {
          'kind': widget.paymentKind,
          'plan': widget.plan,
          'sim_line_id': widget.simLineId,
          'amount_usd': effectiveAmt,
          'device_id': await identity.deviceId(),
          'platform': identity.platform,
        },
      );

      if (response.status != 200) {
        final errText = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Server error (${response.status})';
        throw Exception(errText);
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['approval_url'] == null) {
        throw Exception(data['error'] ?? 'Failed to generate PayPal approval link');
      }

      _orderId = data['order_id'];
      _approveUrl = data['approval_url'];

      setState(() {
        _status = PayPalCheckoutStatus.awaitingApproval;
      });

      // 2. Subscribe Realtime stream on paypal_orders table for this order_id (BLOCKER 2 Realtime Stream)
      _subscribeToOrderRealtime(_orderId!);
      _startWaitTimers();

      // 3. Hand the approval URL to a Custom Tab (Android) / SFSafariViewController
      //    (iOS) rather than a full external browser: it keeps KeepSIMs framing
      //    around the payment and dismisses itself when paypal-return fires the
      //    payment-success deep link.
      await _openApprovalUrl();
    } catch (e) {
      _stopWaitTimers();
      if (mounted) {
        setState(() {
          _status = PayPalCheckoutStatus.failed;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _subscribeToOrderRealtime(String orderId) {
    _realtimeChannel?.unsubscribe();
    final supabase = Supabase.instance.client;

    _realtimeChannel = supabase
        .channel('paypal_order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'paypal_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == 'captured') {
              _onPaymentSuccess();
            } else if (newStatus == 'failed') {
              _stopWaitTimers();
              if (mounted) {
                setState(() {
                  _status = PayPalCheckoutStatus.failed;
                  _errorMessage = AppLocalizations.of(context)?.payPalPaymentFailed ??
                      'Payment failed or was cancelled.';
                });
              }
            }
          },
        )
        .subscribe();
  }

  /// Reopens the approval page. The order is still live at PayPal, so this is
  /// the right escape hatch when the tab was dismissed by accident.
  Future<void> _openApprovalUrl() async {
    final approveUrl = _approveUrl;
    if (approveUrl == null) return;
    final uri = Uri.parse(approveUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } else {
      throw Exception('Could not launch PayPal approval URL.');
    }
  }

  /// Reads the authoritative order status. Cheap, RLS-scoped, and read-only —
  /// safe to call from a poll, a resume, or a returning deep link.
  Future<void> _refreshOrderStatus() async {
    final orderId = _orderId;
    if (orderId == null || !mounted) return;
    if (_status == PayPalCheckoutStatus.success ||
        _status == PayPalCheckoutStatus.failed) {
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('paypal_orders')
          .select('status')
          .eq('order_id', orderId)
          .maybeSingle();
      if (!mounted) return;

      final status = row?['status'] as String?;
      if (status == 'captured') {
        _onPaymentSuccess();
      } else if (status == 'failed') {
        _stopWaitTimers();
        setState(() {
          _status = PayPalCheckoutStatus.failed;
          _errorMessage = AppLocalizations.of(context)?.payPalPaymentFailed ??
              'Payment failed or was cancelled.';
        });
      }
    } catch (_) {
      // Transient — the next poll tick tries again rather than showing the
      // user a network error over a payment that may well have succeeded.
    }
  }

  /// Runs when the browser hands us back a success return. The webhook usually
  /// beats us here; when it has not landed yet, capture is idempotent
  /// (ORDER_ALREADY_CAPTURED) so calling it costs nothing.
  Future<void> _verifyAfterReturn() async {
    if (_status == PayPalCheckoutStatus.success ||
        _status == PayPalCheckoutStatus.capturing) {
      return;
    }
    _stopWaitTimers();
    setState(() {
      _status = PayPalCheckoutStatus.capturing;
      _errorMessage = null;
    });

    await _refreshOrderStatus();
    if (!mounted || _status == PayPalCheckoutStatus.success) return;
    await _triggerManualCapture();
  }

  void _onUserCancelled() {
    _stopWaitTimers();
    _realtimeChannel?.unsubscribe();
    if (!mounted) return;
    setState(() {
      _status = PayPalCheckoutStatus.failed;
      _errorMessage = AppLocalizations.of(context)?.payPalPaymentCancelled ??
          'Payment cancelled. You have not been charged.';
    });
  }

  Future<void> _triggerManualCapture() async {
    if (_orderId == null || _isCapturingManually) return;
    HapticHelper.lightTick();

    setState(() {
      _isCapturingManually = true;
      _status = PayPalCheckoutStatus.capturing;
    });

    try {
      final supabase = Supabase.instance.client;
      final identity = ref.read(deviceIdentityServiceProvider);
      final response = await supabase.functions.invoke(
        'capture-paypal-order',
        headers: await identity.appCheckHeaders(),
        body: {
          'order_id': _orderId,
          'device_id': await identity.deviceId(),
          'platform': identity.platform,
        },
      );

      if (response.status == 200 && response.data['success'] == true) {
        _onPaymentSuccess();
      } else {
        final errText = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Capture failed (${response.status})';
        throw Exception(errText);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturingManually = false;
          _status = PayPalCheckoutStatus.awaitingApproval;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        // Back to waiting means back to watching: the capture may still land
        // via the webhook even though this attempt failed.
        _startWaitTimers();
      }
    }
  }

  void _onPaymentSuccess() {
    // Four callers race to report the same capture: the realtime UPDATE, the
    // resume re-read, the poll tick and the returning deep link. `mounted` is
    // not a guard against them — `onSuccess` opens by popping this route, and a
    // route is not unmounted until the end of the frame, so two callbacks in
    // one frame both pop. The second pop takes the *caller's* screen with it,
    // tearing down the widget that was midway through creating the SIM line
    // the payment had already been charged for.
    if (_successHandled) return;
    _successHandled = true;

    _stopWaitTimers();
    _realtimeChannel?.unsubscribe();
    HapticHelper.mediumImpact();
    ref.invalidate(walletControllerProvider);

    if (mounted) {
      setState(() {
        _status = PayPalCheckoutStatus.success;
      });
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final isDeposit = widget.paymentKind == 'deposit';

    final rawAmt = double.tryParse(_amountController.text) ?? _selectedDepositAmount;
    final hasRemainder = isDeposit && rawAmt > 0 && rawAmt < 1.00;
    final remainderAmount = hasRemainder ? (1.00 - rawAmt) : 0.0;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.payPalCheckoutTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.payment_rounded, size: 44, color: Color(0xFF003087)),
                    const SizedBox(height: 12),
                    Text(
                      widget.paymentReason ?? l10n.payPalWalletTopUp,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDeposit) ...[
                      // Preset Amount Chips (Defect #1 fix)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _presetAmounts.map((amt) {
                          final isSelected = (_selectedDepositAmount - amt).abs() < 0.01;
                          return ChoiceChip(
                            label: Text('\$${amt.toInt()}'),
                            selected: isSelected,
                            onSelected: (_) => _onAmountSelected(amt),
                            selectedColor: const Color(0xFF0070BA),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            setState(() => _selectedDepositAmount = parsed);
                          }
                        },
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: const Color(0xFF0070BA),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          border: InputBorder.none,
                        ),
                      ),
                      // G11 — what this deposit is worth in the user's own
                      // money. The field itself stays in dollars: accepting
                      // local input would mean dividing it back into USD, and
                      // that rounding lands inside the money path.
                      ApproxLocalText(
                        _selectedDepositAmount,
                        textAlign: TextAlign.center,
                      ),
                      if (hasRemainder)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Minimum PayPal charge is \$1.00 — \$${remainderAmount.toStringAsFixed(2)} remainder will stay in your wallet balance.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ] else ...[
                      if (widget.initialAmount != null) ...[
                        Text(
                          '\$${widget.initialAmount!.toStringAsFixed(2)}',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: const Color(0xFF0070BA),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ApproxLocalText(
                          widget.initialAmount!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildStatusWidget(isDark, l10n),
              const Spacer(),
              if (_status == PayPalCheckoutStatus.idle || _status == PayPalCheckoutStatus.failed)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _initiateCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070BA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.payPalPaySecurely,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              // While the tab is open the primary action is getting back to
              // PayPal, not forcing a capture — the capture resolves itself.
              if (_status == PayPalCheckoutStatus.awaitingApproval) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _openApprovalUrl,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(
                      l10n.payPalReopenButton,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070BA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                // Only offered once the automatic path has visibly had its
                // chance, so it reads as a rescue rather than a required step.
                if (_secondsAwaiting >= _slowApprovalSeconds)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: TextButton(
                      onPressed: _isCapturingManually ? null : _verifyAfterReturn,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0070BA),
                      ),
                      child: Text(
                        l10n.payPalForceCaptureButton,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
              if (_status == PayPalCheckoutStatus.capturing)
                const SizedBox(
                  height: 54,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (_status == PayPalCheckoutStatus.success)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.payPalDoneButton,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusWidget(bool isDark, AppLocalizations l10n) {
    switch (_status) {
      case PayPalCheckoutStatus.idle:
        return Text(
          l10n.payPalRedirectInfo,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        );
      case PayPalCheckoutStatus.creatingOrder:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.payPalCreatingOrder),
          ],
        );
      case PayPalCheckoutStatus.awaitingApproval:
        final isSlow = _secondsAwaiting >= _slowApprovalSeconds;
        return Column(
          children: [
            const Icon(Icons.open_in_browser_rounded, size: 40, color: Color(0xFF0070BA)),
            const SizedBox(height: 12),
            Text(
              l10n.payPalBrowserOpened,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isSlow ? l10n.payPalTakingLonger : l10n.payPalBrowserOpenedBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSlow
                    ? AppColors.warning
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        );
      case PayPalCheckoutStatus.capturing:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.payPalVerifying,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.payPalVerifyingBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        );
      case PayPalCheckoutStatus.success:
        return Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 12),
            Text(
              l10n.payPalPaymentConfirmed,
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case PayPalCheckoutStatus.failed:
        return Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? l10n.payPalPaymentFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ],
        );
    }
  }
}
