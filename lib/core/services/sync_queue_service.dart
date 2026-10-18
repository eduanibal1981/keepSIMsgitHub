import 'package:keep_sims/features/scheduled_topups/model/schedule_mutation_request.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';

part 'sync_queue_service.g.dart';

class SyncOperation {
  final String id;
  final String
  type; // 'sim_line_add', 'sim_line_update', 'sim_line_delete', 'topup_schedule_save'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] as String,
    type: json['type'] as String,
    payload: json['payload'] as Map<String, dynamic>,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

@Riverpod(keepAlive: true)
class SyncQueue extends _$SyncQueue {
  @override
  List<SyncOperation> build() {
    // Listen to network status changes to auto-sync when online
    ref.listen(connectivityServiceProvider, (previous, next) {
      if (next == NetworkStatus.online) {
        processQueue(Supabase.instance.client);
      }
    });

    final cache = ref.watch(localCacheServiceProvider);
    final jsonList = cache.readJson('offline_sync_queue');
    if (jsonList is List) {
      return jsonList
          .map((item) => SyncOperation.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> addToQueue(String type, Map<String, dynamic> payload) async {
    final newOp = SyncOperation(
      id: '${DateTime.now().microsecondsSinceEpoch}_${payload.hashCode}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    state = [...state, newOp];
    await _persist();
  }

  Future<void> _persist() async {
    final cache = ref.read(localCacheServiceProvider);
    await cache.writeJson(
      'offline_sync_queue',
      state.map((op) => op.toJson()).toList(),
    );
  }

  Future<void> removeFromQueue(String id) async {
    state = state.where((op) => op.id != id).toList();
    await _persist();
  }

  Future<void> clearQueue() async {
    state = [];
    await _persist();
  }

  Future<void> processQueue(SupabaseClient client) async {
    if (state.isEmpty) return;

    // Drain the queue sequentially
    final ops = List<SyncOperation>.from(state);

    for (final op in ops) {
      try {
        if (op.type == 'sim_line_add') {
          final addPayload = Map<String, dynamic>.from(op.payload)
            ..removeWhere((key, _) => _verificationFields.contains(key));
          if (addPayload['id'] != null &&
              (addPayload['id'].toString().startsWith('offline_') ||
                  !_isValidUuid(addPayload['id'].toString()))) {
            addPayload.remove('id');
          }
          await client.from('sim_lines').upsert(addPayload);
        } else if (op.type == 'sim_line_update') {
          final lineId = op.payload['id'] as String;
          final updatePayload = Map<String, dynamic>.from(op.payload)
            ..remove('id')
            ..removeWhere((key, _) => _verificationFields.contains(key));
          await client.from('sim_lines').update(updatePayload).eq('id', lineId);
        } else if (op.type == 'sim_line_delete') {
          final lineId = op.payload['id'] as String;
          await client.from('sim_lines').delete().eq('id', lineId);
        } else if (op.type == 'line_schedule_initialize') {
          if (op.payload['user_id'] != client.auth.currentUser?.id) {
            continue;
          }
          await client.rpc(
            'initialize_line_schedules',
            params: {'p_sim_line_id': op.payload['sim_line_id']},
          );
        } else if (op.type == 'topup_schedule_save') {
          // A queue saved under another account must wait for that account.
          if (op.payload['user_id'] != null &&
              op.payload['user_id'] != client.auth.currentUser?.id) {
            continue;
          }
          if ((op.payload['schedule_type'] ?? 'notify') != 'notify') {
            // Paid schedules require a fresh online price review, never replay.
            await removeFromQueue(op.id);
            continue;
          }
          await client.rpc(
            'save_customer_schedule',
            params: ScheduleMutationRequest.fromJson(op.payload),
          );
        }

        // Successfully executed, remove from the queue
        await removeFromQueue(op.id);
      } on PostgrestException catch (e) {
        // If there's a database constraint or issue, log and skip/remove to avoid blocking
        print(
          'Offline Sync Queue POSTGREST Exception [Op: ${op.id}]: ${e.message}',
        );
        await removeFromQueue(op.id);
      } catch (e) {
        // Network failures should pause the sync queue processing
        print('Offline Sync Queue general error [Op: ${op.id}]: $e');
        break;
      }
    }
  }

  // Also sanitize operations saved by older clients before the server boundary
  // was repaired; stale queued verification fields must not be replayed.
  static const _verificationFields = {
    'verification_status',
    'health_score',
    'is_carrier_verified',
    'carrier_status',
    'carrier_verified_at',
    'detected_operator_name',
  };

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _isValidUuid(String val) => _uuidRegex.hasMatch(val);
}
