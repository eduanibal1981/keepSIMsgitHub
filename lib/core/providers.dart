/// SIM Shield — Global Repository Providers
///
/// Every new repository MUST be registered here.
/// Uses Riverpod code generation with @riverpod annotations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/auth/contract/auth_contract.dart';
import 'package:keep_sims/features/auth/repository/auth_repository.dart';
import 'package:keep_sims/features/profile/domain/contract/profile_contract.dart';
import 'package:keep_sims/features/profile/data/repository/profile_repository.dart';
import 'package:keep_sims/features/wallet/contract/wallet_contract.dart';
import 'package:keep_sims/features/wallet/repository/wallet_repository.dart';
import 'package:keep_sims/features/scheduled_topups/contract/scheduled_topup_contract.dart';
import 'package:keep_sims/features/scheduled_topups/repository/scheduled_topup_repository.dart';
import 'package:keep_sims/features/referrals/contract/referrals_contract.dart';
import 'package:keep_sims/features/referrals/repository/referrals_repository.dart';
import 'package:keep_sims/features/payments/contract/payments_contract.dart';
import 'package:keep_sims/features/payments/repository/payments_repository.dart';
import 'package:keep_sims/features/offline_recharge/contract/offline_refill_contract.dart';
import 'package:keep_sims/features/offline_recharge/repository/offline_refill_repository.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import 'package:keep_sims/features/support/contract/support_contract.dart';
import 'package:keep_sims/features/support/repository/support_repository.dart';

part 'providers.g.dart';

// ============================================================
// Auth
// ============================================================

/// Provides the [AuthContract] implementation.
@riverpod
AuthContract authRepository(Ref ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider.notifier);
  return AuthRepository(supabase, cache, connectivity);
}

// ============================================================
// Profile
// ============================================================

/// Provides the [ProfileContract] implementation.
@riverpod
ProfileContract profileRepository(Ref ref) => ProfileRepository(supabase);

// ============================================================
// Wallet
// ============================================================

/// Provides the [WalletContract] implementation.
@riverpod
WalletContract walletRepository(Ref ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider.notifier);
  return WalletRepository(supabase, cache, connectivity);
}

// ============================================================
// Scheduled Top-Ups
// ============================================================

/// Provides the [ScheduledTopupContract] implementation.
@riverpod
ScheduledTopupContract scheduledTopupRepository(Ref ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider.notifier);
  final syncQueue = ref.watch(syncQueueProvider.notifier);
  return ScheduledTopupRepository(supabase, cache, connectivity, syncQueue);
}

// ============================================================
// Referrals
// ============================================================

/// Provides the [ReferralsContract] implementation.
@riverpod
ReferralsContract referralsRepository(Ref ref) => ReferralsRepository(supabase);

// ============================================================
// Payments
// ============================================================

/// Provides the [PaymentsContract] implementation.
@riverpod
PaymentsContract paymentsRepository(Ref ref) => PaymentsRepository(supabase);

// ============================================================
// Offline Recharge / Refill
// ============================================================

@riverpod
OfflineRefillContract offlineRefillRepository(Ref ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider.notifier);
  return OfflineRefillRepository(supabase, cache, connectivity);
}

// ============================================================
// Support
// ============================================================

/// Provides the [SupportContract] implementation.
@riverpod
SupportContract supportRepository(Ref ref) => SupportRepository(supabase);
