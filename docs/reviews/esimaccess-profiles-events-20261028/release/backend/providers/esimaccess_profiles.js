'use strict';
// Provider facts, never installation/expiry inferred from purchase time.
const text = v => typeof v === 'string' && v.trim() ? v.trim() : null;
const bytes = v => v !== null && v !== undefined && v !== '' && typeof v !== 'boolean' &&
  Number.isSafeInteger(Number(v)) && Number(v) >= 0 ? Number(v) : null;
const date = v => text(v) && /^\d{4}-\d\d-\d\dT/.test(v) && Number.isFinite(Date.parse(v)) ? new Date(v).toISOString() : null;

function activation(lpa, address, matching) {
  let full = text(lpa);
  if (!full && text(address) && text(matching)) full = `LPA:1$${address.trim()}$${matching.trim()}`;
  const parts = full?.split('$');
  if (!parts || parts[0] !== 'LPA:1' || parts.length < 3 || parts.length > 4 ||
      !/^(?=.{1,253}$)[A-Za-z0-9.-]+$/.test(parts[1]) || !parts[1].includes('.') ||
      !parts[2] || /\s/.test(parts[2]) || full.length > 1024) return null;
  return { lpa_string: full, smdp_address: parts[1], matching_id: parts[2] };
}

function normalizeProfile(item, { checkedAt = new Date().toISOString() } = {}) {
  if (!item || typeof item !== 'object') return null;
  const profileRef = text(item.esimTranNo);
  if (!profileRef || profileRef.length > 100) return null;
  const state = text(item.esimStatus) || 'UNKNOWN';
  const installation = ({RELEASED:'released',DOWNLOAD:'downloaded',INSTALLATION:'installed',ENABLED:'enabled',DISABLED:'disabled',DELETED:'deleted'})[item.smdpStatus] || 'unknown';
  const profileState = ({GOT_RESOURCE:'issued',IN_USE:'active',USED_UP:'active',SUSPENDED:'suspended',CANCEL:'cancelled',REVOKE:'revoked',USED_EXPIRED:'expired',UNUSED_EXPIRED:'expired'})[state] || 'unknown';
  const bundle = ({GOT_RESOURCE:'not_started',IN_USE:'active',USED_UP:'depleted',USED_EXPIRED:'expired',UNUSED_EXPIRED:'expired',CANCEL:'cancelled',REVOKE:'cancelled'})[state] || 'unknown';
  const total = bytes(item.totalVolume), used = bytes(item.orderUsage);
  const credentials = activation(item.ac, item.smdpAddress, item.matchingId);
  const iccid = text(item.iccid);
  return {
    supplier_profile_ref: profileRef, provider_order_ref: text(item.orderNo), transaction_id: text(item.transactionId),
    iccid: iccid && /^\d{15,22}$/.test(iccid) ? iccid : null,
    ...(credentials || {}), issuance_proven: Boolean(credentials && iccid && /^\d{15,22}$/.test(iccid)),
    profile_state: profileState, installation_state: installation, bundle_state: bundle,
    provider_state: {esimStatus:state,smdpStatus:text(item.smdpStatus),activeType:item.activeType ?? null},
    activation_trigger: ({1:'installation',2:'first_network_connection'})[item.activeType] || 'unknown',
    // An unactivated profile's expiredTime is not assumed to be bundle expiry.
    confirmed_expires_at: ['active','depleted','expired'].includes(bundle) ? date(item.expiredTime) : null,
    first_activated_at: null, activation_deadline_at: null,
    data_total_bytes: total, data_used_bytes: used,
    data_remaining_bytes: total !== null && used !== null ? Math.max(0,total-used) : null,
    usage_observed_at: null, checked_at: checkedAt,
  };
}

function normalizeUsage(item, profileRef) {
  if (!item || (item.esimTranNo && String(item.esimTranNo) !== profileRef)) return null;
  const total=bytes(item.totalData),used=bytes(item.dataUsage);
  if (total === null || used === null) return null;
  return {data_total_bytes:total,data_used_bytes:used,data_remaining_bytes:Math.max(0,total-used),
    // Provider usage responses may supply lastUpdateTime as ISO UTC or epoch ms.
    usage_observed_at: date(item.lastUpdateTime) ||
      (bytes(item.lastUpdateTime) !== null && Number(item.lastUpdateTime)>1000000000000 ? new Date(Number(item.lastUpdateTime)).toISOString() : null)};
}

module.exports={activation,normalizeProfile,normalizeUsage};
