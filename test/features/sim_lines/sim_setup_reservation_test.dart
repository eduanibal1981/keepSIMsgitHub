import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<Map<String, dynamic>> reserve(
    Map<String, dynamic> serverResponse,
  ) async {
    final client = SupabaseClient(
      'https://reservation-test.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/reserve_sim_setup_holds');
        expect(jsonDecode(request.body), {'p_order_id': 'setup-order'});
        return http.Response(
          jsonEncode(serverResponse),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    try {
      return await PlanPayment.reserveSimSetupHolds(
        'setup-order',
        client: client,
      );
    } finally {
      await client.dispose();
    }
  }

  test('zero-balance server response reaches the deposit flow', () async {
    final result = await reserve({
      'success': false,
      'code': 'insufficient_funds',
      'available_balance': 0,
      'required_balance': 2.5,
      'shortfall': 2.5,
    });

    expect(result['success'], isFalse);
    expect(result['error'], 'insufficient_balance');
    expect(result['current_balance'], 0);
    expect(
      PlanPayment.calculateShortfall(
        fee: (result['required_balance'] as num).toDouble(),
        availableBalance: (result['current_balance'] as num).toDouble(),
      ),
      5.0,
    );
    expect(result['shortfall'], 2.5);
  });

  test('shortfall uses spendable balance after existing holds', () async {
    final result = await reserve({
      'success': false,
      'code': 'insufficient_funds',
      'available_balance': 1.25,
      'required_balance': 8,
      'shortfall': 6.75,
    });

    expect(result['error'], 'insufficient_balance');
    expect(result['current_balance'], 1.25);
    expect(
      PlanPayment.calculateShortfall(
        fee: (result['required_balance'] as num).toDouble(),
        availableBalance: (result['current_balance'] as num).toDouble(),
      ),
      6.75,
    );
  });

  test('installed-client response also reaches the deposit flow', () async {
    final result = await reserve({
      'success': false,
      'error': 'insufficient_balance',
      'current_balance': 0,
      'shortfall': 2.5,
    });

    expect(result['error'], 'insufficient_balance');
    expect(result['current_balance'], 0);
    expect(result['shortfall'], 2.5);
  });

  test('funded order remains reserved with its hold identifiers', () async {
    final response = {
      'success': true,
      'status': 'reserved',
      'annual_fee_hold_id': 'fee-hold',
      'first_refill_hold_id': null,
      'total_charge_usd': 2.5,
    };

    expect(await reserve(response), response);
  });

  test('other failures do not prompt for a deposit', () async {
    final result = await reserve({
      'success': false,
      'code': 'order_expired',
      'error': 'Order expired',
    });

    expect(result['error'], 'Order expired');
    expect(result.containsKey('current_balance'), isFalse);
  });
}
