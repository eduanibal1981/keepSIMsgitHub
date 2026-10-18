/// The only customer-controlled schedule inputs. Financial/owner/engine fields
/// from cached rows are deliberately never sent as authority.
class ScheduleMutationRequest {
  static Map<String, dynamic> fromJson(Map<String, dynamic> value) {
    final type = value['schedule_type'] as String? ?? 'notify';
    final id = value['id']?.toString();
    return {
      'p_sim_line_id': value['sim_line_id'],
      'p_schedule_type': type,
      'p_frequency_days': value['frequency_days'],
      'p_next_execution_at': value['next_execution_at'],
      'p_is_active': value['is_active'] ?? true,
      'p_schedule_id': id != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)
          ? id
          : null,
      'p_offer_id': type == 'notify' ? null : value['offer_id'],
      'p_offer_value': type == 'notify' ? null : value['offer_value'],
      'p_max_authorized_usd': type == 'notify'
          ? null
          : value['max_authorized_usd'],
    };
  }
}
