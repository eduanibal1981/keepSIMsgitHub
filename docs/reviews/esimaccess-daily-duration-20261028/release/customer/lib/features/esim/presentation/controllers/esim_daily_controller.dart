import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_daily_selection.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';

final esimDailyQuoteProvider = FutureProvider.autoDispose
    .family<EsimRechargeQuote, EsimDailySelection>((ref, selection) async {
      final owner = ref.watch(authControllerProvider).value?.id;
      if (owner == null || !selection.valid) {
        return const EsimRechargeQuote(status: 'INVALID_DURATION');
      }
      final quote = await ref
          .watch(esimRepositoryProvider)
          .quoteDaily(selection);
      if (!ref.mounted ||
          ref.read(authControllerProvider).value?.id != owner ||
          (quote.status == 'QUOTED' &&
              (quote.ownerId != owner ||
                  quote.payerId != owner ||
                  quote.profileId != selection.profileId ||
                  quote.offer?.duration != selection.days))) {
        return const EsimRechargeQuote(status: 'QUOTE_UNAVAILABLE');
      }
      return quote;
    });
