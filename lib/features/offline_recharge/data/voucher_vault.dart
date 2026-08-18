import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../model/offline_voucher_model.dart';

/// Where recharge PINs live on the handset.
///
/// Backed by `flutter_secure_storage`, i.e. the iOS Keychain and Android's
/// EncryptedSharedPreferences. Every other cached model in this feature goes
/// through `LocalCacheService` (plain SharedPreferences); a voucher must not,
/// because it is money in text form and SharedPreferences is an XML file that
/// survives into device backups in the clear.
///
/// The vault keeps its own index rather than calling `readAll()`. `readAll()`
/// returns every secret the app has stored — the biometric-lock flag lives in
/// the same store — and a bug that mistook one of those for a voucher would be
/// a bug that leaks or destroys the wrong secret.
class VoucherVault {
  VoucherVault(this._storage);

  final FlutterSecureStorage _storage;

  static const _indexKey = 'keepsims_voucher_index';
  static String _voucherKey(String simLineId) => 'keepsims_voucher_$simLineId';

  Future<List<String>> _index() async {
    final raw = await _storage.read(key: _indexKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      // Always growable — remove() is called on what this returns.
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: true);
      }
    } catch (_) {
      // A corrupt index must not hide the vouchers forever; rebuilding it is
      // impossible without readAll(), so the honest recovery is an empty index
      // plus whatever the server tells us on the next poll.
    }
    return <String>[];
  }

  Future<void> _writeIndex(List<String> ids) async {
    await _storage.write(key: _indexKey, value: jsonEncode(ids.toSet().toList()));
  }

  Future<StoredVoucher?> read(String simLineId) async {
    final raw = await _storage.read(key: _voucherKey(simLineId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return StoredVoucher.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<StoredVoucher>> readAllVouchers() async {
    final out = <StoredVoucher>[];
    for (final id in await _index()) {
      final v = await read(id);
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<void> save(StoredVoucher voucher) async {
    await _storage.write(
      key: _voucherKey(voucher.simLineId),
      value: jsonEncode(
        voucher.copyWith(storedAt: voucher.storedAt ?? DateTime.now()).toJson(),
      ),
    );
    final ids = await _index();
    if (!ids.contains(voucher.simLineId)) {
      await _writeIndex([...ids, voucher.simLineId]);
    }
  }

  /// Stamps the reveal locally. This is the one write that MUST succeed with no
  /// network, so it does not touch anything but the keystore.
  Future<StoredVoucher> markRevealed(StoredVoucher voucher) async {
    final revealed = voucher.copyWith(
      revealedAt: voucher.revealedAt ?? DateTime.now(),
      reported: false,
    );
    await save(revealed);
    return revealed;
  }

  Future<StoredVoucher> markReported(StoredVoucher voucher) async {
    final reported = voucher.copyWith(reported: true);
    await save(reported);
    return reported;
  }

  /// Drops a voucher. Called after settlement, when the server has confirmed
  /// the debt is closed — never on a reveal, because a revealed-but-unreported
  /// voucher is exactly the state the report retry loop needs to survive a
  /// restart.
  Future<void> remove(String simLineId) async {
    await _storage.delete(key: _voucherKey(simLineId));
    final ids = await _index();
    ids.remove(simLineId);
    await _writeIndex(ids);
  }

  /// Wipes everything. Sign-out only.
  Future<void> clear() async {
    for (final id in await _index()) {
      await _storage.delete(key: _voucherKey(id));
    }
    await _storage.delete(key: _indexKey);
  }
}
