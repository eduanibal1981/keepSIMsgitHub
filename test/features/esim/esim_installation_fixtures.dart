import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';

UserEsim installationFixture([Map<String, dynamic> changes = const {}]) =>
    UserEsim.fromRecord({
      'id': 'fixture-profile',
      'user_id': 'fixture-owner',
      'order_id': 'fixture-order',
      'iccid': '8900000000000000001',
      'bundle_name': 'Fixture travel plan',
      'provider': 'esimaccess',
      'status': 'active',
      'profile_state': 'issued',
      'installation_state': 'released',
      'bundle_state': 'not_started',
      'issuance_verified': true,
      'lpa_string': r'LPA:1$fixture.invalid$private-code',
      'qr_code_url': 'https://untrusted.invalid/private-code.png',
      'activation_trigger': 'first_network_connection',
      'last_observation_at': DateTime.now().toUtc().toIso8601String(),
      ...changes,
    });

class InstallationAuthFixture extends AuthController {
  InstallationAuthFixture([this.owner = 'fixture-owner']);
  final String? owner;
  @override
  FutureOr<UserProfile?> build() =>
      owner == null ? null : UserProfile(id: owner!);
  void signInAs(String? owner) =>
      state = AsyncData(owner == null ? null : UserProfile(id: owner));
}

class InstallationProfilesFixture extends UserEsimsController {
  InstallationProfilesFixture(this.profile);
  final UserEsim profile;
  @override
  FutureOr<List<UserEsim>> build() => [profile];
  void replace(UserEsim profile) => state = AsyncData([profile]);
}
