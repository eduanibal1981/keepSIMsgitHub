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
          await client.from('sim_lines').upsert(op.payload);
        } else if (op.type == 'sim_line_update') {
          final lineId = op.payload['id'] as String;
          await client.from('sim_lines').update(op.payload).eq('id', lineId);
        } else if (op.type == 'sim_line_delete') {
          final lineId = op.payload['id'] as String;
          await client.from('sim_lines').delete().eq('id', lineId);
        } else if (op.type == 'topup_schedule_save') {
          await client.from('scheduled_topups').upsert(op.payload);
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
}
