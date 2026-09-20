import { CallMedia, terminalCallStatuses } from './call-media.ts';

export async function handleMediaEvent(audio: CallMedia, record: any, event: any,
  rpc: (name: string, args: Record<string, unknown>) => Promise<{ ok: boolean; body: any }>) {
  const payload = event.payload;
  const state = JSON.parse(atob(payload.client_state));
  const leg = state.mediaLeg;
  if (!['app', 'destination'].includes(leg) || !payload.call_control_id) throw new Error('Invalid call audio correlation');
  const field = leg === 'app' ? 'telnyx_call_control_id_leg_a' : 'telnyx_call_control_id_leg_b';
  if (record[field] && record[field] !== payload.call_control_id) throw new Error('Call leg mismatch');
  if (!await audio.session(record.id)) throw new Error('Call audio session missing');
  // Webhooks may arrive before the originating HTTP response is saved.
  await audio.patch(record.id, { [field]: payload.call_control_id });
  record = await audio.record(record.id);
  if (terminalCallStatuses.includes(record.status) || record.cancellation_requested_at) {
    // Stop legs that appeared after the user cancelled during setup.
    if (event.event_type !== 'call.hangup') await audio.hangup(payload.call_control_id);
    if (terminalCallStatuses.includes(record.status)) return;
  }
  if (event.event_type === 'call.answered' && leg === 'app' && !record.cancellation_requested_at) {
    await audio.ready(record.id, 'app_answered');
  } else if (event.event_type === 'call.bridged' && !record.answered_at && !record.cancellation_requested_at) {
    const occurred = new Date(event.occurred_at || payload.occurred_at || new Date().toISOString());
    if (!Number.isFinite(occurred.getTime())) throw new Error('Bridge timestamp missing');
    // Neither SIP login nor answering the app leg is a connected conversation.
    await audio.db(`call_records?id=eq.${record.id}&answered_at=is.null&status=not.in.(${terminalCallStatuses.join(',')})`, 'PATCH', {
      status: 'in_progress', answered_at: occurred.toISOString(),
    });
  } else if (event.event_type === 'call.hangup') {
    const ended = new Date(event.occurred_at || payload.occurred_at || new Date().toISOString());
    if (!Number.isFinite(ended.getTime())) throw new Error('Hangup timestamp missing');
    const cause = String(payload.hangup_cause || '').toLowerCase();
    const sip = Number(payload.sip_hangup_cause);
    let status = 'failed';
    let error = leg === 'app' ? 'The app audio connection ended.' : 'Call could not be completed.';
    if (record.answered_at) { status = 'completed'; error = ''; }
    else if (record.cancellation_requested_at) { status = 'cancelled'; error = ''; }
    else if (sip === 603) { status = 'declined'; error = 'Call declined or rejected by the destination network.'; }
    else if (sip === 486 || cause === 'user_busy') { status = 'busy'; error = 'Destination line is busy.'; }
    else if ([408, 480].includes(sip) || ['timeout', 'no_answer'].includes(cause)) { status = 'no_answer'; error = 'The call was not answered.'; }
    // Close the other leg before finalizing. Failures return 500 for provider retry.
    await audio.hangup(leg === 'app' ? record.telnyx_call_control_id_leg_b : record.telnyx_call_control_id_leg_a);
    const session = await audio.session(record.id);
    if (session?.credential_id) {
      await audio.deleteCredential(session.credential_id);
      await audio.db(`call_media_sessions?id=eq.${encodeURIComponent(session.id)}`, 'PATCH', { cleaned_up: true }).catch(() => {});
    }
    const result = await rpc('finish_media_call', {
      p_call_id: record.id, p_ended_at: ended.toISOString(), p_status: status,
      p_error: error || null, p_payload: payload,
    });
    if (!result.ok) throw new Error('Unable to finalize call audio session');
  }
}
