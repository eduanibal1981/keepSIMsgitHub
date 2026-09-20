// Server-created SIP leg A is joined to the authorized phone destination (leg B).
// The dedicated credential connection MUST have direct PSTN outbound disabled.
export const terminalCallStatuses = ['completed', 'declined', 'busy', 'no_answer', 'cancelled', 'failed'];

export class CallMedia {
  constructor(
    private url: string,
    private headers: Record<string, string>,
    private apiKey: string,
    private appId: string,
  ) {}

  async db(path: string, method = 'GET', body?: unknown): Promise<any[]> {
    const response = await fetch(`${this.url}/rest/v1/${path}`, {
      method, headers: { ...this.headers, Prefer: 'return=representation' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    if (!response.ok) throw new Error('Unable to save call audio state');
    return response.status === 204 ? [] : await response.json();
  }

  async provider(path: string, body?: unknown, method = 'POST'): Promise<any> {
    const response = await fetch(`https://api.telnyx.com/v2/${path}`, {
      method,
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    if (!response.ok) throw new Error(`Call audio provider request failed (${response.status})`);
    if (path.endsWith('/token')) {
      const text = await response.text();
      return text.replace(/^"|"$/g, '').trim();
    }
    return response.status === 204 ? {} : await response.json();
  }

  async deleteCredential(credentialId?: string | null) {
    if (!credentialId) return;
    try {
      await this.provider(`telephony_credentials/${encodeURIComponent(credentialId)}`, undefined, 'DELETE');
    } catch (_) {
      /* Already deleted or expired */
    }
  }

  async prepare(userId: string, connectionId: string) {
    if (!connectionId || !this.appId) throw new Error('In-app calling audio is not configured yet. Please try again later.');
    const { data: connection } = await this.provider(`credential_connections/${encodeURIComponent(connectionId)}`, undefined, 'GET');
    if (!connection?.active || connection.outbound?.outbound_voice_profile_id ||
        connection.sip_uri_calling_preference !== 'internal') {
      throw new Error('The call audio connection is not configured for app calling.');
    }
    // Bounded cleanup of expired sessions/credentials for this user
    try {
      const nowIso = new Date().toISOString();
      const expired = await this.db(`call_media_sessions?user_id=eq.${userId}&expires_at=lt.${encodeURIComponent(nowIso)}&cleaned_up=eq.false&select=id,credential_id&limit=5`);
      for (const item of expired) {
        if (item.credential_id) await this.deleteCredential(item.credential_id);
        await this.db(`call_media_sessions?id=eq.${encodeURIComponent(item.id)}`, 'PATCH', { cleaned_up: true }).catch(() => {});
      }
    } catch (_) {}
    const recent = await this.db(`call_media_sessions?user_id=eq.${userId}&created_at=gt.${encodeURIComponent(new Date(Date.now() - 60000).toISOString())}&select=id&limit=5`);
    if (recent.length >= 5) throw new Error('Please wait a minute before trying another call.');
    const expiresAt = new Date(Date.now() + 5 * 60000).toISOString();
    const { data: credential } = await this.provider('telephony_credentials', {
      connection_id: connectionId, name: `KeepSIMs ${crypto.randomUUID()}`, expires_at: expiresAt,
    });
    if (!credential?.id || !credential?.sip_username) throw new Error('Unable to create call audio credentials');
    try {
      const token = await this.provider(`telephony_credentials/${encodeURIComponent(credential.id)}/token`);
      const [session] = await this.db('call_media_sessions', 'POST', {
        user_id: userId, credential_id: credential.id, sip_username: credential.sip_username, expires_at: expiresAt, cleaned_up: false,
      });
      return { mediaSessionId: session.id, token, expiresAt };
    } catch (error) {
      await this.deleteCredential(credential.id);
      throw error;
    }
  }

  async claim(sessionId: string, userId: string, callId: string) {
    const [session] = await this.db(`call_media_sessions?id=eq.${encodeURIComponent(sessionId)}&user_id=eq.${userId}&call_record_id=is.null&expires_at=gt.${encodeURIComponent(new Date().toISOString())}`, 'PATCH', { call_record_id: callId });
    if (!session) throw new Error('Call audio session expired or already used. Please try again.');
    return session;
  }

  async session(callId: string) {
    const [session] = await this.db(`call_media_sessions?call_record_id=eq.${encodeURIComponent(callId)}`);
    return session;
  }

  async record(callId: string) {
    const [record] = await this.db(`call_records?id=eq.${encodeURIComponent(callId)}`);
    return record;
  }

  async patch(callId: string, values: Record<string, unknown>) {
    return this.db(`call_records?id=eq.${encodeURIComponent(callId)}&status=not.in.(${terminalCallStatuses.join(',')})`, 'PATCH', values);
  }

  async hangup(controlId: string | null) {
    if (!controlId) return;
    // An already ended leg is an idempotent success. Other failures are retryable.
    const response = await fetch(`https://api.telnyx.com/v2/calls/${encodeURIComponent(controlId)}/actions/hangup`, {
      method: 'POST', headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      if (!data.errors?.some((e: any) => String(e.code) === '90018')) throw new Error('Unable to end call. Please retry.');
    }
  }

  async close(record: any) {
    const results = await Promise.allSettled([this.hangup(record.telnyx_call_control_id_leg_a), this.hangup(record.telnyx_call_control_id_leg_b)]);
    const session = await this.session(record.id);
    if (session?.credential_id) {
      await this.deleteCredential(session.credential_id);
      await this.db(`call_media_sessions?id=eq.${encodeURIComponent(session.id)}`, 'PATCH', { cleaned_up: true }).catch(() => {});
    }
    const failure = results.find(r => r.status === 'rejected');
    if (failure?.status === 'rejected') throw failure.reason;
  }

  async dialApp(record: any, session: any, gateway: string) {
    const result = await this.provider('calls', {
      connection_id: this.appId,
      to: `sip:${session.sip_username}@sip.telnyx.com;secure=srtp`, from: gateway,
      timeout_secs: 20, time_limit_secs: 3600,
      command_id: record.id,
      client_state: btoa(JSON.stringify({ callRecordId: record.id, mediaLeg: 'app' })),
    });
    if (!result.data?.call_control_id) throw new Error('Unable to connect app audio');
    const changes = await this.patch(record.id, {
      telnyx_call_control_id_leg_a: result.data.call_control_id,
      telnyx_call_session_id: result.data.call_session_id,
    });
    if (!changes.length) await this.hangup(result.data.call_control_id);
  }

  async ready(callId: string, field: 'media_ready' | 'app_answered') {
    const patchObj: Record<string, boolean> = { [field]: true };
    await this.db(`call_media_sessions?call_record_id=eq.${encodeURIComponent(callId)}`, 'PATCH', patchObj);
    const session = await this.session(callId);
    const record = await this.record(callId);
    if (!session || !record || terminalCallStatuses.includes(record.status) || record.cancellation_requested_at) return;
    if (!session.media_ready || !session.app_answered || !record.telnyx_call_control_id_leg_a || record.telnyx_call_control_id_leg_b) return;
    // Atomically claim dialing to prevent race condition between concurrent readiness events
    const [claimed] = await this.db(`call_media_sessions?call_record_id=eq.${encodeURIComponent(callId)}&dial_started=eq.false`, 'PATCH', { dial_started: true });
    if (!claimed) return;
    const [wallet] = await this.db(`wallets?user_id=eq.${record.user_id}&select=balance`);
    const rate = Number(record.rate_per_minute_usd);
    const limit = Math.min(3600, Math.floor(Number(wallet?.balance) * 60 / rate));
    if (!Number.isFinite(limit) || rate <= 0 || limit < 1) {
      await this.db(`call_media_sessions?call_record_id=eq.${encodeURIComponent(callId)}`, 'PATCH', { dial_started: false }).catch(() => {});
      throw new Error('Insufficient wallet balance for this call.');
    }
    // Both racing readiness events use the same provider command ID and payload.
    try {
      const result = await this.provider('calls', {
        connection_id: this.appId, to: record.destination_number,
        from: record.effective_caller_id || record.caller_number,
        timeout_secs: 30, time_limit_secs: limit,
        command_id: session.id,
        link_to: record.telnyx_call_control_id_leg_a, bridge_on_answer: true,
        client_state: btoa(JSON.stringify({ callRecordId: callId, mediaLeg: 'destination' })),
      });
      if (result.data?.call_control_id) {
        const changes = await this.patch(callId, {
          telnyx_call_control_id_leg_b: result.data.call_control_id,
          status: 'ringing',
        });
        const latest = await this.record(callId);
        if (!changes.length || latest?.cancellation_requested_at) await this.hangup(result.data.call_control_id);
      }
    } catch (err) {
      await this.db(`call_media_sessions?call_record_id=eq.${encodeURIComponent(callId)}`, 'PATCH', { dial_started: false }).catch(() => {});
      throw err;
    }
  }
}
