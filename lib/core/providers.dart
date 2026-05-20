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

part 'providers.g.dart';

// ============================================================
// Auth
// ============================================================

/// Provides the [AuthContract] implementation.
@riverpod
AuthContract authRepository(Ref ref) => AuthRepository(supabase);

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
WalletContract walletRepository(Ref ref) => WalletRepository(supabase);

// ============================================================
// Scheduled Top-Ups
// ============================================================

/// Provides the [ScheduledTopupContract] implementation.
@riverpod
ScheduledTopupContract scheduledTopupRepository(Ref ref) => ScheduledTopupRepository(supabase);

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


