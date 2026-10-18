import { CallMedia, terminalCallStatuses } from './call-media.ts';

export async function handleMediaEvent(audio: CallMedia, record: any, event: any,
  rpc: (name: string, args: Record<string, unknown>) => Promise<{ ok: boolean; body: any }>) {
  const payload = event.payload;
  const state = JSON.parse(atob(payload.client_state));
  const leg = state.mediaLeg;
  if (!['app', 'destination'].includes(leg) || !payload.call_control_id || state.callRecordId !== record.id) {
    throw new Error('Invalid call audio correlation');
  }
  const field = leg === 'app' ? 'telnyx_call_control_id_leg_a' : 'telnyx_call_control_id_leg_b';
  if (record[field] && record[field] !== payload.call_control_id) throw new Error('Call leg mismatch');
  if (!await audio.session(record.id)) throw new Error('Call audio session missing');
  // Missing timestamps are uncertainty, never an invented billable duration.
  const occurred = new Date(event.occurred_at || payload.occurred_at || 'invalid');
  if (!Number.isFinite(occurred.getTime())) throw new Error('Provider event timestamp missing');
  await audio.rpc('record_media_call_evidence', {
    p_call_id: record.id, p_leg: leg, p_event_type: event.event_type,
    p_occurred_at: occurred.toISOString(), p_payload: payload,
  });
  record = await audio.record(record.id);
  if (record.billing_state === 'settled' || terminalCallStatuses.includes(record.status)) {
    if (event.event_type !== 'call.hangup') await audio.hangup(payload.call_control_id);
    return;
  }
  if (record.cancellation_requested_at && event.event_type !== 'call.hangup') await audio.hangup(payload.call_control_id);
  if (event.event_type === 'call.answered' && leg === 'app' && !record.cancellation_requested_at) {
    await audio.ready(record.id, 'app_answered');
  }
  if (event.event_type === 'call.hangup') {
    try {
      await audio.hangup(leg === 'app' ? record.telnyx_call_control_id_leg_b : record.telnyx_call_control_id_leg_a);
    } catch (error) {
      await audio.patch(record.id, { billing_state: 'reconciliation_required', reconciliation_reason: 'termination_unknown' });
      throw error;
    }
    const session = await audio.session(record.id);
    if (session?.credential_id) {
      await audio.deleteCredential(session.credential_id);
      await audio.db(`call_media_sessions?id=eq.${encodeURIComponent(session.id)}`, 'PATCH', { cleaned_up: true }).catch(() => {});
    }
  }
  // Only destination termination settles a submitted destination. An app-leg
  // hangup requests closure and waits for that evidence. A late bridge can now
  // settle a hangup that arrived first using its original stored timestamp.
  if (record.destination_ended_at || (event.event_type === 'call.hangup' && leg === 'app' && !record.destination_submission_at)) {
    try {
      const result = await rpc('finish_media_call', {
        p_call_id: record.id, p_ended_at: record.destination_ended_at || occurred.toISOString(),
        p_status: record.destination_terminal_status || 'cancelled', p_error: null,
        p_payload: record.destination_terminal_payload || payload,
      });
      if (!result.ok) throw new Error('Unable to finalize call audio session');
    } catch (error) {
      await audio.patch(record.id, { billing_state: 'reconciliation_required', reconciliation_reason: 'settlement_failed' });
      throw error;
    }
  }
}
