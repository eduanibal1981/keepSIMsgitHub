import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

class PaypalSimulatorScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? paymentReason;
  final VoidCallback? onSuccess;
  final bool depositToWallet;

  const PaypalSimulatorScreen({
    super.key,
    this.initialAmount,
    this.paymentReason,
    this.onSuccess,
    this.depositToWallet = true,
  });

  @override
  ConsumerState<PaypalSimulatorScreen> createState() =>
      _PaypalSimulatorScreenState();
}

class _PaypalSimulatorScreenState extends ConsumerState<PaypalSimulatorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _amountController = TextEditingController(
    text: '2.00',
  );

  // Custom Card fields controllers
  final _cardFormKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  // Credentials
  final String _clientId =
      'AcNsq1nLW-edL2FvyKo29IaTGj8z0jN6eoetQVHd9I-_XWIKX9RZtGA1rUVHIibXi0EEra_xq_yoMgwG';
  final String _clientSecret =
      'EL1hsovnMcto49sP6ldoptaga6W6jcDOpM6qPku_zK992df5GpNX2EzytQBiCcFviG6_lxqNajOxT2g3';

  // State
  double _amount = 2.00;
  bool _isLoading = false;
  bool _isOfflineMock = false;
  String _paymentMethod = 'paypal'; // 'paypal' or 'card' (CardFields)

  String _status =
      'Idle'; // 'Idle', 'Authenticating', 'CreatingOrder', 'AwaitingPayment', 'Capturing', 'Success', 'Error'
  String? _accessToken;
  String? _orderId;
  String? _approveUrl;
  String? _errorMessage;

  // Response details for payloads tab
  String? _createResponseJson;
  String? _captureResponseJson;

  // Captured payout details
  double? _capturedFee;
  double? _capturedNet;

  // Card brand type
  String _cardBrand = 'generic'; // 'generic', 'visa', 'mastercard', 'amex'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _amount = widget.initialAmount ?? 2.00;
    _amountController.text = _amount.toStringAsFixed(2);
    _amountController.addListener(_onAmountChanged);
    _cardNumberController.addListener(_detectCardBrand);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.removeListener(_onAmountChanged);
    _cardNumberController.removeListener(_detectCardBrand);
    _amountController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_status == 'AwaitingPayment' && _orderId != null && _accessToken != null) {
        debugPrint('[PaypalSimulatorScreen] App resumed and in AwaitingPayment state. Automatically capturing payment...');
        _captureRealPayment();
      }
    }
  }

  void _onAmountChanged() {
    final val = double.tryParse(_amountController.text);
    if (val != null && val >= 0) {
      setState(() {
        _amount = val;
      });
    }
  }

  void _selectAmount(double amount) async {
    await HapticHelper.lightTick();
    _amountController.text = amount.toStringAsFixed(2);
    setState(() {
      _amount = amount;
    });
  }

  void _detectCardBrand() {
    final number = _cardNumberController.text.replaceAll(' ', '');
    setState(() {
      if (number.startsWith('4')) {
        _cardBrand = 'visa';
      } else if (number.startsWith(RegExp(r'5[1-5]'))) {
        _cardBrand = 'mastercard';
      } else if (number.startsWith('34') || number.startsWith('37')) {
        _cardBrand = 'amex';
      } else {
        _cardBrand = 'generic';
      }
    });
  }

  // Live Math: 3.49% + $0.49
  double get _calculatedFee {
    if (_amount <= 0) return 0.0;
    final variable = _amount * 0.0349;
    return double.parse((variable + 0.49).toStringAsFixed(2));
  }

  double get _calculatedNet {
    final net = _amount - _calculatedFee;
    return net < 0 ? 0.0 : double.parse(net.toStringAsFixed(2));
  }

  // ── CARD FIELDS TOKENIZATION FLOW (MOCK GATEWAY) ───────────

  Future<void> _startCardTokenizationFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _createResponseJson = null;
      _captureResponseJson = null;
      _capturedFee = null;
      _capturedNet = null;
      _status = 'Authenticating';
    });

    try {
      await HapticHelper.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 1000));

      setState(
        () => _status = 'CreatingOrder',
      ); // Simulates Braintree client-side token request
      await Future.delayed(const Duration(milliseconds: 1200));

      final lastFour = _cardNumberController.text.substring(
        _cardNumberController.text.length - 4,
      );
      final mockNonce =
          'tokencc_sf_${_cardBrand}_${DateTime.now().millisecondsSinceEpoch % 100000}';

      // 1. Mock Request Payload (Braintree Tokenize Card)
      final tokenizationRequest = {
        'client_key': 'sandbox_client_token_key_spec',
        'options': {'validate': true},
        'credit_card': {
          'number': _cardNumberController.text.replaceAll(' ', ''),
          'expiration_date': _cardExpiryController.text,
          'cvv': _cardCvvController.text,
          'cardholder_name': _cardHolderController.text,
        },
      };

      // 2. Mock Response Payload (Braintree Tokenize Card)
      final tokenizationResponse = {
        'creditCards': [
          {
            'nonce': mockNonce,
            'type': _cardBrand.toUpperCase(),
            'description': '${_cardBrand.toUpperCase()} ending in $lastFour',
            'details': {
              'cardType': _cardBrand.toUpperCase(),
              'lastFour': lastFour,
              'lastTwo': lastFour.substring(2),
            },
            'binData': {
              'commercial': 'Unknown',
              'debit': 'Yes',
              'durbinRegulated': 'Yes',
              'healthcare': 'No',
              'issuingBank': 'KeepSIMs Sandbox Bank',
              'countryOfIssuance': 'USA',
            },
          },
        ],
      };

      _createResponseJson =
          '/* Braintree Client-Side Card Tokenization (Direct UI) */\n\n'
          'POST https://api.sandbox.braintreegateway.com/merchants/sandbox_merchant/client_side/payment_methods/json\n\n'
          'Request:\n${const JsonEncoder.withIndent('  ').convert(tokenizationRequest)}\n\n'
          'Response:\n${const JsonEncoder.withIndent('  ').convert(tokenizationResponse)}';

      setState(
        () => _status = 'Capturing',
      ); // Simulates Server-side capture using Nonce
      await Future.delayed(const Duration(milliseconds: 1200));

      // Server capture payload
      final captureRequest = {
        'amount': _amount.toStringAsFixed(2),
        'payment_method_nonce': mockNonce,
        'options': {'submit_for_settlement': true},
      };

      final captureResponse = {
        'transaction': {
          'id':
              'tx_braintree_cc_${DateTime.now().millisecondsSinceEpoch % 1000000}',
          'status': 'submitted_for_settlement',
          'type': 'sale',
          'amount': _amount.toStringAsFixed(2),
          'merchantAccountId': 'usdMerchantAccount',
          'creditCard': {
            'token':
                'tok_saved_${DateTime.now().millisecondsSinceEpoch % 10000}',
            'bin': '411111',
            'last4': lastFour,
            'cardType': _cardBrand.toUpperCase(),
            'expirationMonth': _cardExpiryController.text.split('/')[0],
            'expirationYear': '20${_cardExpiryController.text.split('/')[1]}',
            'cardholderName': _cardHolderController.text,
          },
          'statusHistory': [
            {
              'timestamp': DateTime.now().toIso8601String(),
              'status': 'authorized',
            },
            {
              'timestamp': DateTime.now().toIso8601String(),
              'status': 'submitted_for_settlement',
            },
          ],
          'disputes': [],
          'currencyIsoCode': 'USD',
          'fees': {
            'paypal_fee': _calculatedFee.toStringAsFixed(2),
            'net_amount': _calculatedNet.toStringAsFixed(2),
          },
        },
      };

      _captureResponseJson =
          '/* Server-Side Sale Transaction Capture */\n\n'
          'POST https://api.sandbox.braintreegateway.com/merchants/sandbox_merchant/transactions\n\n'
          'Request:\n${const JsonEncoder.withIndent('  ').convert(captureRequest)}\n\n'
          'Response:\n${const JsonEncoder.withIndent('  ').convert(captureResponse)}';

      _capturedFee = _calculatedFee;
      _capturedNet = _calculatedNet;

      // Deposit into Wallet
      final success = await ref
          .read(walletControllerProvider.notifier)
          .deposit(
            _amount,
            description: 'Deposit via CardFields (Token: $mockNonce)',
          );

      if (success) {
        setState(() => _status = 'Success');
        await HapticHelper.successFeedback();
      } else {
        throw Exception(
          'Card tokenized and captured successfully, but failed to credit database wallet.',
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Error';
        _errorMessage = e.toString();
      });
      await HapticHelper.errorFeedback();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startRealCardPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _createResponseJson = null;
      _captureResponseJson = null;
      _capturedFee = null;
      _capturedNet = null;
    });

    try {
      await HapticHelper.mediumImpact();

      // 1. Authenticate with PayPal Sandbox (Fetch OAuth Access Token)
      setState(() => _status = 'Authenticating');
      final basicAuth = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
      final tokenRes = await http.post(
        Uri.parse('https://api-m.sandbox.paypal.com/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'Accept-Language': 'en_US',
        },
        body: 'grant_type=client_credentials',
      );

      if (tokenRes.statusCode != 200) {
        throw Exception(
          'OAuth failed (${tokenRes.statusCode}): ${tokenRes.body}',
        );
      }

      final tokenData = jsonDecode(tokenRes.body);
      _accessToken = tokenData['access_token'];

      // 2. Create Order with Direct Card Details
      setState(() => _status = 'CreatingOrder');

      final cleanCardNumber = _cardNumberController.text.replaceAll(' ', '');
      final rawExpiry = _cardExpiryController.text.split('/');
      final expiryMonth = rawExpiry[0];
      final expiryYear = '20${rawExpiry[1]}';

      final orderBody = {
        'intent': 'CAPTURE',
        'purchase_units': [
          {
            'amount': {
              'currency_code': 'USD',
              'value': _amount.toStringAsFixed(2),
            },
            'description': 'KeepSIMs Wallet Top-up',
          },
        ],
        'payment_source': {
          'card': {
            'name': _cardHolderController.text,
            'number': cleanCardNumber,
            'expiry': '$expiryYear-$expiryMonth',
            'security_code': _cardCvvController.text,
            'billing_address': {
              'address_line_1': '123 Main St',
              'admin_area_2': 'San Jose',
              'admin_area_1': 'CA',
              'postal_code': '95131',
              'country_code': 'US',
            },
          },
        },
      };

      final orderRes = await http.post(
        Uri.parse('https://api-m.sandbox.paypal.com/v2/checkout/orders'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'PayPal-Request-Id':
              'order_cc_${DateTime.now().microsecondsSinceEpoch}',
        },
        body: jsonEncode(orderBody),
      );

      final orderData = jsonDecode(orderRes.body);
      _createResponseJson =
          '/* PayPal Direct Card Order Creation (v2/checkout/orders) */\n\n'
          'POST https://api.sandbox.paypal.com/v2/checkout/orders\n\n'
          'Request:\n${const JsonEncoder.withIndent('  ').convert(orderBody)}\n\n'
          'Response:\n${const JsonEncoder.withIndent('  ').convert(orderData)}';

      if (orderRes.statusCode != 201 && orderRes.statusCode != 200) {
        throw Exception('Create Card Order failed: ${orderRes.body}');
      }

      _orderId = orderData['id'];
      final orderStatus = orderData['status'];

      if (orderStatus == 'PAYER_ACTION_REQUIRED') {
        // 3D Secure / SCA required
        final links = orderData['links'] as List;
        final approveLink = links.firstWhere(
          (l) => l['rel'] == 'approve' || l['rel'] == 'payer-action',
          orElse: () => null,
        );
        if (approveLink == null) {
          throw Exception('No 3D Secure approval link returned from PayPal.');
        }
        _approveUrl = approveLink['href'];
        setState(() => _status = 'AwaitingPayment');
        await HapticHelper.successFeedback();

        // Launch standard browser
        final approveUri = Uri.parse(_approveUrl!);
        if (await canLaunchUrl(approveUri)) {
          await launchUrl(approveUri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch browser for 3D Secure approval.');
        }
      } else if (orderStatus == 'COMPLETED') {
        // Already completed
        _capturedFee = _calculatedFee;
        _capturedNet = _calculatedNet;

        if (widget.depositToWallet) {
          final success = await ref
              .read(walletControllerProvider.notifier)
              .deposit(
                _amount,
                description:
                    widget.paymentReason ??
                    'Deposit via PayPal (Mock Order: $_orderId)',
              );

          if (success) {
            setState(() => _status = 'Success');
            await HapticHelper.successFeedback();
            if (widget.onSuccess != null) widget.onSuccess!();
          } else {
            throw Exception(
              'Failed to update wallet database after mock capture',
            );
          }
        } else {
          setState(() => _status = 'Success');
          await HapticHelper.successFeedback();
          if (widget.onSuccess != null) widget.onSuccess!();
        }
      } else {
        // Status is APPROVED or CREATED, we capture it immediately
        await _captureRealCardPaymentDirect(_orderId!, _accessToken!);
      }
    } catch (e) {
      setState(() {
        _status = 'Error';
        _errorMessage = e.toString();
      });
      await HapticHelper.errorFeedback();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureRealCardPaymentDirect(
    String orderId,
    String accessToken,
  ) async {
    setState(() => _status = 'Capturing');
    final captureRes = await http.post(
      Uri.parse(
        'https://api-m.sandbox.paypal.com/v2/checkout/orders/$orderId/capture',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'PayPal-Request-Id':
            'capture_cc_${DateTime.now().microsecondsSinceEpoch}',
      },
    );

    final captureData = jsonDecode(captureRes.body);
    _captureResponseJson =
        '/* PayPal Direct Card Capture (v2/checkout/orders/{id}/capture) */\n\n'
        'POST https://api.sandbox.paypal.com/v2/checkout/orders/$orderId/capture\n\n'
        'Response:\n${const JsonEncoder.withIndent('  ').convert(captureData)}';

    if (captureRes.statusCode != 201 && captureRes.statusCode != 200) {
      throw Exception('Capture failed: ${captureRes.body}');
    }

    // Parse PayPal Fee and Net Payout
    try {
      final captureDetails =
          captureData['purchase_units'][0]['payments']['captures'][0];
      final breakdown = captureDetails['seller_receivable_breakdown'];
      if (breakdown != null) {
        _capturedFee = double.tryParse(
          breakdown['paypal_fee']['value'].toString(),
        );
        _capturedNet = double.tryParse(
          breakdown['net_amount']['value'].toString(),
        );
      }
    } catch (_) {
      _capturedFee = _calculatedFee;
      _capturedNet = _calculatedNet;
    }

    if (widget.depositToWallet) {
      final success = await ref
          .read(walletControllerProvider.notifier)
          .deposit(
            _amount,
            description:
                widget.paymentReason ??
                'Deposit via CardFields (Order: $orderId)',
          );

      if (success) {
        setState(() => _status = 'Success');
        await HapticHelper.successFeedback();
        if (widget.onSuccess != null) widget.onSuccess!();
      } else {
        throw Exception(
          'Successfully captured payment, but failed to credit database wallet.',
        );
      }
    } else {
      setState(() => _status = 'Success');
      await HapticHelper.successFeedback();
      if (widget.onSuccess != null) widget.onSuccess!();
    }
  }

  // ── REAL PAYPAL API CALLS (REDIRECT) ──────────────────────

  Future<void> _startRealCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _createResponseJson = null;
      _captureResponseJson = null;
      _capturedFee = null;
      _capturedNet = null;
    });

    try {
      // 1. Authenticate with PayPal Sandbox
      setState(() => _status = 'Authenticating');
      final basicAuth = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
      final tokenRes = await http.post(
        Uri.parse('https://api-m.sandbox.paypal.com/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'Accept-Language': 'en_US',
        },
        body: 'grant_type=client_credentials',
      );

      if (tokenRes.statusCode != 200) {
        throw Exception(
          'OAuth failed (${tokenRes.statusCode}): ${tokenRes.body}',
        );
      }

      final tokenData = jsonDecode(tokenRes.body);
      _accessToken = tokenData['access_token'];

      // 2. Create Order
      setState(() => _status = 'CreatingOrder');
      final orderRes = await http.post(
        Uri.parse('https://api-m.sandbox.paypal.com/v2/checkout/orders'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'intent': 'CAPTURE',
          'purchase_units': [
            {
              'amount': {
                'currency_code': 'USD',
                'value': _amount.toStringAsFixed(2),
              },
              'description': widget.paymentReason ?? 'KeepSIMs Wallet Top-up',
            },
          ],
          'application_context': {
            'brand_name': 'KeepSIMs Shield',
            'user_action': 'PAY_NOW',
            'return_url': 'https://keepsims.com/success.html',
            'cancel_url': 'https://KeepSIMs.com/',
          },
        }),
      );

      _createResponseJson =
          '/* PayPal API Order Creation (v2/checkout/orders) */\n\n'
          'POST https://api.sandbox.paypal.com/v2/checkout/orders\n\n'
          'Response:\n${const JsonEncoder.withIndent('  ').convert(jsonDecode(orderRes.body))}';

      if (orderRes.statusCode != 201) {
        throw Exception('Create Order failed: ${orderRes.body}');
      }

      final orderData = jsonDecode(orderRes.body);
      _orderId = orderData['id'];

      final links = orderData['links'] as List;
      final approveLink = links.firstWhere(
        (l) => l['rel'] == 'approve' || l['rel'] == 'payer-action',
        orElse: () => null,
      );
      if (approveLink == null) {
        throw Exception('No approval link returned from PayPal. Links: $links');
      }
      _approveUrl = approveLink['href'];

      setState(() => _status = 'AwaitingPayment');
      await HapticHelper.successFeedback();

      // Launch standard browser
      final approveUri = Uri.parse(_approveUrl!);
      if (await canLaunchUrl(approveUri)) {
        await launchUrl(approveUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch browser to complete approval.');
      }
    } catch (e) {
      setState(() {
        _status = 'Error';
        _errorMessage = e.toString();
      });
      await HapticHelper.errorFeedback();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureRealPayment() async {
    if (_orderId == null || _accessToken == null) return;

    setState(() {
      _isLoading = true;
      _status = 'Capturing';
    });

    try {
      final captureRes = await http.post(
        Uri.parse(
          'https://api-m.sandbox.paypal.com/v2/checkout/orders/$_orderId/capture',
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      _captureResponseJson =
          '/* PayPal API Payout Capture (v2/checkout/orders/{id}/capture) */\n\n'
          'POST https://api.sandbox.paypal.com/v2/checkout/orders/$_orderId/capture\n\n'
          'Response:\n${const JsonEncoder.withIndent('  ').convert(jsonDecode(captureRes.body))}';

      if (captureRes.statusCode != 201 && captureRes.statusCode != 200) {
        throw Exception('Capture failed: ${captureRes.body}');
      }

      final captureData = jsonDecode(captureRes.body);

      // Parse PayPal Fee and Net Payout
      try {
        final captureDetails =
            captureData['purchase_units'][0]['payments']['captures'][0];
        final breakdown = captureDetails['seller_receivable_breakdown'];
        if (breakdown != null) {
          _capturedFee = double.tryParse(
            breakdown['paypal_fee']['value'].toString(),
          );
          _capturedNet = double.tryParse(
            breakdown['net_amount']['value'].toString(),
          );
        }
      } catch (_) {
        _capturedFee = _calculatedFee;
        _capturedNet = _calculatedNet;
      }

      if (widget.depositToWallet) {
        // 4. Deposit into Wallet
        final success = await ref
            .read(walletControllerProvider.notifier)
            .deposit(
              _amount,
              description:
                  widget.paymentReason ??
                  'Deposit via PayPal (Order: $_orderId)',
            );

        if (success) {
          setState(() => _status = 'Success');
          await HapticHelper.successFeedback();
          if (widget.onSuccess != null) widget.onSuccess!();
        } else {
          throw Exception(
            'Successfully captured payment, but failed to credit app wallet database.',
          );
        }
      } else {
        setState(() => _status = 'Success');
        await HapticHelper.successFeedback();
        if (widget.onSuccess != null) widget.onSuccess!();
      }
    } catch (e) {
      setState(() {
        _status = 'Error';
        _errorMessage = e.toString();
      });
      await HapticHelper.errorFeedback();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ── MOCK OFFLINE EXPERIENCE (REDIRECT) ─────────────────────

  Future<void> _startOfflineMockCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _createResponseJson = null;
      _captureResponseJson = null;
      _capturedFee = null;
      _capturedNet = null;
      _status = 'Authenticating';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _status = 'CreatingOrder');
    await Future.delayed(const Duration(milliseconds: 600));

    // Simulate mock order
    _orderId = 'MOCK_PAYPAL_${DateTime.now().millisecondsSinceEpoch % 100000}';
    _approveUrl = 'https://www.sandbox.paypal.com/checkoutnow?token=$_orderId';
    _createResponseJson = jsonEncode({
      'id': _orderId,
      'status': 'PAYER_ACTION_REQUIRED',
      'intent': 'CAPTURE',
      'purchase_units': [
        {
          'amount': {
            'currency_code': 'USD',
            'value': _amount.toStringAsFixed(2),
          },
        },
      ],
      'links': [
        {'href': _approveUrl, 'rel': 'payer-action', 'method': 'GET'},
      ],
    });

    setState(() => _status = 'AwaitingPayment');
    _showMockCheckoutSheet();
    setState(() => _isLoading = false);
  }

  void _showMockCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMockPaypalSheet(),
    );
  }

  Widget _buildMockPaypalSheet() {
    int sheetStep =
        1; // 1: Login, 2: Select Funding Source, 3: Confirm, 4: Processing
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA), // Classic PayPal off-white background
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          height: 520,
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF003087),
                    size: 20,
                  ),
                  const Row(
                    children: [
                      Text(
                        'Pay',
                        style: TextStyle(
                          color: Color(0xFF003087),
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'Pal',
                        style: TextStyle(
                          color: Color(0xFF0070BA),
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE2E6EB)),

              // Step content
              Expanded(
                child: () {
                  if (sheetStep == 1) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Log in with your PayPal Sandbox account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          controller: TextEditingController(
                            text: 'sandbox-buyer@keepsims.com',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          enabled: false,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          controller: TextEditingController(text: '••••••••'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0070BA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () {
                              setSheetState(() => sheetStep = 2);
                            },
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else if (sheetStep == 2) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose how to pay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFundingOption(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'PayPal Balance',
                          subtitle: '\$25.40 USD available',
                          selected: true,
                        ),
                        const SizedBox(height: 10),
                        _buildFundingOption(
                          icon: Icons.credit_card_rounded,
                          title: 'Visa ending in 4321',
                          subtitle: 'Preferred for card backups',
                          selected: false,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total to pay',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '\$${_amount.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFFFFC439,
                              ), // PayPal Yellow
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () {
                              setSheetState(() => sheetStep = 3);
                              _completeOfflineMockCapture();
                            },
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(
                                color: Color(0xFF003087),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0070BA)),
                        SizedBox(height: 20),
                        Text(
                          'Authorizing transaction...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    );
                  }
                }(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFundingOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF0070BA) : Colors.grey[300]!,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? const Color(0xFF0070BA) : Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF0070BA),
              size: 20,
            ),
        ],
      ),
    );
  }

  Future<void> _completeOfflineMockCapture() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    // Create mock capture JSON response
    _captureResponseJson = jsonEncode({
      'id': 'MOCK_CAPTURE_${DateTime.now().millisecondsSinceEpoch % 100000}',
      'status': 'COMPLETED',
      'purchase_units': [
        {
          'payments': {
            'captures': [
              {
                'status': 'COMPLETED',
                'amount': {
                  'currency_code': 'USD',
                  'value': _amount.toStringAsFixed(2),
                },
                'seller_receivable_breakdown': {
                  'gross_amount': {
                    'currency_code': 'USD',
                    'value': _amount.toStringAsFixed(2),
                  },
                  'paypal_fee': {
                    'currency_code': 'USD',
                    'value': _calculatedFee.toStringAsFixed(2),
                  },
                  'net_amount': {
                    'currency_code': 'USD',
                    'value': _calculatedNet.toStringAsFixed(2),
                  },
                },
              },
            ],
          },
        },
      ],
    });

    _capturedFee = _calculatedFee;
    _capturedNet = _calculatedNet;

    // Credit app wallet
    final success = await ref
        .read(walletControllerProvider.notifier)
        .deposit(
          _amount,
          description: 'Deposit via PayPal (Mock Order: $_orderId)',
        );

    if (mounted) {
      Navigator.pop(context); // Close bottom sheet
      setState(() {
        if (success) {
          _status = 'Success';
        } else {
          _status = 'Error';
          _errorMessage =
              'Successfully authorized mock payment, but failed to credit app wallet database.';
        }
      });
    }
  }

  void _resetSimulator() async {
    await HapticHelper.lightTick();
    setState(() {
      _status = 'Idle';
      _orderId = null;
      _approveUrl = null;
      _errorMessage = null;
      _createResponseJson = null;
      _captureResponseJson = null;
      _capturedFee = null;
      _capturedNet = null;
      _cardNumberController.clear();
      _cardExpiryController.clear();
      _cardCvvController.clear();
      _cardHolderController.clear();
      _cardBrand = 'generic';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Wallet Deposit (PayPal Test)',
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.onSurfaceColor,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.primaryColor,
          labelColor: context.onSurfaceColor,
          unselectedLabelColor: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
          tabs: const [
            Tab(text: 'Simulator'),
            Tab(text: 'API Payloads'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSimulatorTab(), _buildPayloadsTab()],
      ),
    );
  }

  Widget _buildSimulatorTab() {
    final isDark = context.isDarkMode;

    if (_status == 'Success') {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRunFlowTracker(),
              const SizedBox(height: 32),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 22,
                  ),
                  label: const Text(
                    'Done / Return to App',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sandbox API Connection',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
              Switch(
                value: !_isOfflineMock,
                activeThumbColor: context.primaryColor,
                activeTrackColor: context.primaryColor.withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() {
                    _isOfflineMock = !val;
                  });
                },
              ),
            ],
          ),
          Text(
            _isOfflineMock
                ? 'Running in mock offline simulator mode. Visual checkout only.'
                : 'Using PayPal Sandbox REST credentials to execute real test orders.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 16),

          // Amount Selector Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Amount to Pay',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAmountChip(2.0),
                    _buildAmountChip(5.0),
                    _buildAmountChip(10.0),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: context.onSurfaceColor),
                  decoration: InputDecoration(
                    labelText: 'Custom Amount (USD)',
                    labelStyle: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: context.onSurfaceColor),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fee Calculator Display Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF003087).withValues(alpha: 0.15),
                        const Color(0xFF0070BA).withValues(alpha: 0.05),
                      ]
                    : [
                        const Color(0xFF003087).withValues(alpha: 0.04),
                        const Color(0xFF0070BA).withValues(alpha: 0.02),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF0070BA).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.network(
                      'https://www.paypalobjects.com/webstatic/mktg/logo/pp_cc_v3_notification_icon.png',
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.payment_rounded,
                        color: Color(0xFF003087),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Merchant Fee & Payout Breakdown',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  'Gross Payment Amount:',
                  '\$${_amount.toStringAsFixed(2)}',
                  isBold: true,
                ),
                const Divider(height: 16),
                _buildBreakdownRow(
                  'PayPal Merchant Fee (3.49% + \$0.49):',
                  '-\$${_calculatedFee.toStringAsFixed(2)}',
                  color: Colors.red[300],
                ),
                const Divider(height: 16),
                _buildBreakdownRow(
                  'Net Payout (What you get):',
                  '\$${_calculatedNet.toStringAsFixed(2)}',
                  color: Colors.green[400],
                  isBold: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'PayPal retains \$${_calculatedFee.toStringAsFixed(2)} of this transaction. Your Net percentage is ${(_amount > 0 ? (_calculatedNet / _amount * 100) : 0).toStringAsFixed(1)}%.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Payment Method Selector Segment
          Text(
            'Select Checkout Interface Style',
            style: AppTextStyles.titleMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _paymentMethod = 'paypal';
                      _resetSimulator();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'paypal'
                          ? const Color(0xFF0070BA)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0070BA)),
                    ),
                    child: Center(
                      child: Text(
                        'PayPal Redirection',
                        style: TextStyle(
                          color: _paymentMethod == 'paypal'
                              ? Colors.white
                              : const Color(0xFF0070BA),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _paymentMethod = 'card';
                      _resetSimulator();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'card'
                          ? const Color(0xFF0070BA)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0070BA)),
                    ),
                    child: Center(
                      child: Text(
                        'Custom CardFields (Direct)',
                        style: TextStyle(
                          color: _paymentMethod == 'card'
                              ? Colors.white
                              : const Color(0xFF0070BA),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Render Selected Form
          if (_paymentMethod == 'paypal') ...[
            _buildRunFlowTracker(),
            const SizedBox(height: 24),

            // Standard action button
            if (_status == 'Idle' || _status == 'Success' || _status == 'Error')
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0070BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_isOfflineMock) {
                            _startOfflineMockCheckout();
                          } else {
                            _startRealCheckout();
                          }
                        },
                  icon: const Icon(Icons.flash_on_rounded),
                  label: Text(
                    _isOfflineMock
                        ? 'Run Simulated Offline Checkout'
                        : 'Create Real Sandbox Order (\$${_amount.toStringAsFixed(2)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

            if (_status == 'AwaitingPayment') ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4EDEA3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _captureRealPayment,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Confirm & Capture Sandbox Payout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _resetSimulator,
                  child: Text(
                    'Cancel Order',
                    style: TextStyle(color: context.onSurfaceColor),
                  ),
                ),
              ),
            ],
          ] else ...[
            // Direct Card Fields Form
            _buildCardFieldsForm(),
          ],

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(double val) {
    final isSelected = _amount == val;
    final isDark = context.isDarkMode;

    return ChoiceChip(
      label: Text(
        '\$${val.toStringAsFixed(0)}',
        style: TextStyle(
          color: isSelected ? Colors.white : context.onSurfaceColor,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0070BA),
      backgroundColor: isDark ? AppColors.darkCard : Colors.grey[200],
      onSelected: (_) => _selectAmount(val),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color ?? context.onSurfaceColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildRunFlowTracker() {
    if (_status == 'Idle') return const SizedBox.shrink();

    final isDark = context.isDarkMode;
    Color statusColor = Colors.orange;
    String statusTitle = 'Active';
    IconData icon = Icons.info_outline;

    if (_status == 'Success') {
      statusColor = AppColors.success;
      statusTitle = 'Success';
      icon = Icons.check_circle_outline;
    } else if (_status == 'Error') {
      statusColor = AppColors.error;
      statusTitle = 'Error';
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Status: $statusTitle',
                style: AppTextStyles.titleMedium.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_status == 'Success' || _status == 'Error')
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _resetSimulator,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_status == 'Authenticating')
            const Text(
              'Authenticating Sandbox Credentials with OAuth token...',
            ),
          if (_status == 'CreatingOrder')
            const Text('Initiating checkout order payload creation...'),
          if (_status == 'AwaitingPayment') ...[
            Text(
              'Order ID: $_orderId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Awaiting sandbox customer payment approval. We opened the PayPal checkout tab in your external browser.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you log in and approve the payment in the browser, return here and click "Confirm & Capture Sandbox Payout" to complete the flow.',
              style: TextStyle(
                color: isDark ? Colors.blue[200] : Colors.blue[800],
                fontSize: 12,
              ),
            ),
          ],
          if (_status == 'Capturing')
            const Text('Requesting capture verification from PayPal...'),
          if (_status == 'Success') ...[
            Text('Sandbox payment verified and captured! Order: $_orderId'),
            const SizedBox(height: 8),
            _buildBreakdownRow(
              'Gross Payment:',
              '\$${_amount.toStringAsFixed(2)}',
            ),
            if (_capturedFee != null) ...[
              _buildBreakdownRow(
                'PayPal Fee Retained:',
                '-\$${_capturedFee!.toStringAsFixed(2)}',
                color: Colors.red[300],
              ),
              _buildBreakdownRow(
                'Final Merchant Payout:',
                '\$${_capturedNet!.toStringAsFixed(2)}',
                color: Colors.green[400],
                isBold: true,
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.depositToWallet
                        ? Icons.wallet_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.depositToWallet
                          ? 'Successfully deposited \$${_amount.toStringAsFixed(2)} into your app wallet balance!'
                          : 'Payment of \$${_amount.toStringAsFixed(2)} completed successfully!',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_status == 'Error') ...[
            const Text('An error occurred during transaction execution:'),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardFieldsForm() {
    final isDark = context.isDarkMode;

    if (_status == 'Success' ||
        _status == 'Error' ||
        _status == 'Authenticating' ||
        _status == 'CreatingOrder' ||
        _status == 'Capturing') {
      return _buildRunFlowTracker();
    }

    return Form(
      key: _cardFormKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credit / Debit Card',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildCardBrandBadge(),
              ],
            ),
            const SizedBox(height: 20),

            // Cardholder Name
            TextFormField(
              controller: _cardHolderController,
              style: TextStyle(color: context.onSurfaceColor),
              decoration: InputDecoration(
                labelText: 'Cardholder Name',
                labelStyle: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please enter cardholder name'
                  : null,
            ),
            const SizedBox(height: 16),

            // Card Number Field
            TextFormField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.onSurfaceColor),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                CardNumberFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Card Number',
                labelStyle: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.credit_card_rounded),
              ),
              validator: (val) {
                if (val == null || val.replaceAll(' ', '').length < 15) {
                  return 'Please enter a valid card number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Expiry & CVV Side-by-Side
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExpiryController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.onSurfaceColor),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      ExpiryDateFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Expiry (MM/YY)',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 5 || !val.contains('/')) {
                        return 'Invalid date';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: TextStyle(color: context.onSurfaceColor),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'CVV / CVC',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 3) {
                        return 'Invalid CVV';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0070BA), // PayPal Blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_cardFormKey.currentState!.validate()) {
                          if (_isOfflineMock) {
                            _startCardTokenizationFlow();
                          } else {
                            _startRealCardPayment();
                          }
                        }
                      },
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  'Pay Securely (\$${_amount.toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBrandBadge() {
    if (_cardBrand == 'generic') {
      return const Icon(Icons.credit_card_rounded, color: Colors.grey);
    }

    String label = 'CARD';
    Color bgColor = Colors.grey;

    if (_cardBrand == 'visa') {
      label = 'VISA';
      bgColor = const Color(0xFF003087);
    } else if (_cardBrand == 'mastercard') {
      label = 'MC';
      bgColor = Colors.deepOrange;
    } else if (_cardBrand == 'amex') {
      label = 'AMEX';
      bgColor = const Color(0xFF0070BA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPayloadsTab() {
    final isDark = context.isDarkMode;

    if (_createResponseJson == null && _captureResponseJson == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.code_rounded,
                size: 48,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              const SizedBox(height: 16),
              Text(
                'No Payload Data Yet',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Run a simulation or real Sandbox order to inspect the HTTP request/response JSON payload structures.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_createResponseJson != null) ...[
            Text(
              '1. Order Init / Card Tokenization',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildJsonCodeBlock(_createResponseJson!),
            const SizedBox(height: 24),
          ],
          if (_captureResponseJson != null) ...[
            Text(
              '2. Order / Nonce Capture API',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildJsonCodeBlock(_captureResponseJson!),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonCodeBlock(String jsonStr) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey[400]!,
        ),
      ),
      child: Stack(
        children: [
          SelectableText(
            jsonStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payload JSON copied to clipboard!'),
                    duration: Duration(seconds: 1),
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

// ── CUSTOM TEXT FORMATTERS FOR PREMIUM UX ─────────────────────

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    return newValue.copyWith(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    return newValue.copyWith(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
