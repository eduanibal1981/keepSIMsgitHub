import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:keep_sims/features/topup/data/models/top_up_result.dart';
import 'package:keep_sims/features/topup/domain/repositories/i_top_up_repository.dart';

class ZenditRepository implements ITopUpRepository {
  final String _apiSecret =
      'sand_0296bcc7-526e-4efb-b4f9-8b11108e7c396a29abd0a371a4c9f33194dd';
  // Use sandbox API URL if one exists, falling back to a general endpoint structure
  final String _baseUrl = 'https://api.zendit.io/v1';

  @override
  Future<TopUpResult> executeRecharge({
    required String phoneNumber,
    required String countryCode,
    required double amount,
  }) async {
    try {
      // 1. Fetch all offers for the given country
      final offerResponse = await http.get(
        Uri.parse(
          '$_baseUrl/topups/offers?country=$countryCode&_limit=100&_offset=0',
        ),
        headers: {
          'Authorization': 'Bearer $_apiSecret',
          'Content-Type': 'application/json',
        },
      );

      if (offerResponse.statusCode != 200) {
        return TopUpResult(
          success: false,
          transactionId: '',
          errorMessage: 'Failed to fetch offers: ${offerResponse.body}',
        );
      }

      final offerData = jsonDecode(offerResponse.body);
      final list = offerData['list'] as List<dynamic>?;

      if (list == null || list.isEmpty) {
        return TopUpResult(
          success: false,
          transactionId: '',
          errorMessage: 'No top-up offers available for country: $countryCode',
        );
      }

      // 2. Find the offer closest to the user's requested amount in USD (price.fixed)
      Map<String, dynamic>? bestOffer;
      double minDiff = double.infinity;

      for (final offer in list) {
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

      if (bestOffer == null) {
        return TopUpResult(
          success: false,
          transactionId: '',
          errorMessage: 'No matching offer found for amount: \$${amount.toStringAsFixed(2)}',
        );
      }

      final offerId = bestOffer['offerId'];
      final transactionId = 'z_sand_${DateTime.now().millisecondsSinceEpoch}';
      final formattedPhone = phoneNumber.startsWith('+')
          ? phoneNumber
          : '+$phoneNumber';

      // Parse local benefit and actual USD cost details
      final send = bestOffer['send'] ?? {};
      final sendFixed = send['fixed'] as int? ?? 0;
      final sendDivisor = send['currencyDivisor'] as int? ?? 100;
      final sendCurrency = send['currency'] ?? '';
      final sendAmount = sendFixed / sendDivisor;
      final localBenefitStr = '${sendAmount.toStringAsFixed(2)} $sendCurrency';

      final price = bestOffer['price'] ?? {};
      final priceFixed = price['fixed'] as int? ?? 0;
      final priceDivisor = price['currencyDivisor'] as int? ?? 100;
      final actualUsdCost = priceFixed / priceDivisor;

      // 3. Execute the purchase
      final purchaseResponse = await http.post(
        Uri.parse('$_baseUrl/topups/purchases'),
        headers: {
          'Authorization': 'Bearer $_apiSecret',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'transactionId': transactionId,
          'offerId': offerId,
          'recipientPhoneNumber': formattedPhone,
        }),
      );

      if (purchaseResponse.statusCode == 200 ||
          purchaseResponse.statusCode == 201) {
        var purchaseData = jsonDecode(purchaseResponse.body);
        String currentStatus = purchaseData['status'] ?? 'PENDING';
        
        // Poll status up to 5 times (1 second intervals) to get the final status (FAILED / SUCCESSFUL)
        int pollCount = 0;
        while ((currentStatus == 'ACCEPTED' || 
                currentStatus == 'PENDING' || 
                currentStatus == 'AUTHORIZED' || 
                currentStatus == 'IN_PROGRESS') && 
               pollCount < 5) {
          await Future.delayed(const Duration(seconds: 1));
          try {
            final checkResponse = await http.get(
              Uri.parse('$_baseUrl/topups/purchases/$transactionId'),
              headers: {
                'Authorization': 'Bearer $_apiSecret',
                'Content-Type': 'application/json',
              },
            );
            if (checkResponse.statusCode == 200) {
              final checkData = jsonDecode(checkResponse.body);
              purchaseData = checkData;
              currentStatus = checkData['status'] ?? currentStatus;
            }
          } catch (_) {
            // Ignore temporary network errors during polling
          }
          pollCount++;
        }

        if (currentStatus == 'FAILED' || currentStatus == 'DECLINED') {
          final errorMsg = purchaseData['error']?['message'] ?? 
              'Transaction failed with status: $currentStatus';
          return TopUpResult(
            success: false,
            transactionId: purchaseData['transactionId'] ?? transactionId,
            errorMessage: errorMsg,
          );
        }

        return TopUpResult(
          success: true,
          transactionId: purchaseData['transactionId'] ?? transactionId,
          amountToppedUp: actualUsdCost,
          localBenefit: localBenefitStr,
        );
      } else {
        return TopUpResult(
          success: false,
          transactionId: transactionId,
          errorMessage:
              'Purchase API Error: ${purchaseResponse.statusCode} - ${purchaseResponse.body}',
        );
      }
    } catch (e) {
      return TopUpResult(
        success: false,
        transactionId: '',
        errorMessage: 'Network/CORS Exception: ${e.toString()}',
      );
    }
  }

  /// Fetches all available offers for a country code.
  Future<List<dynamic>> fetchOffersForCountry(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/topups/offers?country=$countryCode&_limit=100&_offset=0',
        ),
        headers: {
          'Authorization': 'Bearer $_apiSecret',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['list'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }
}
