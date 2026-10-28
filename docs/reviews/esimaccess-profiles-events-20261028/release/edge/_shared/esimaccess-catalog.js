// ESIM-02 contract. Keep the Edge mirror byte-identical except its export line.
// Source: https://docs.esimaccess.com/ (reviewed 2026-10-28).
const text = value => typeof value === 'string' && value.trim() ? value.trim() : null;
const number = value => typeof value !== 'boolean' && value !== null && value !== '' && value !== undefined &&
  Number.isFinite(Number(value)) ? Number(value) : null;
const integer = value => Number.isSafeInteger(number(value)) && number(value) >= 0 ? number(value) : null;
const timestamp = value => text(value) && Number.isFinite(Date.parse(value)) ? new Date(value).toISOString() : null;

function extractIsoCountries(pkg) {
  const values = [];
  for (const key of ['location', 'locationCode', 'locationCodeList', 'coveredCountries', 'locationList']) {
    const raw = pkg?.[key];
    for (const item of Array.isArray(raw) ? raw : typeof raw === 'string' ? raw.split(',') : []) {
      values.push(typeof item === 'string' ? item : item?.locationCode || item?.code);
    }
  }
  for (const item of Array.isArray(pkg?.locationNetworkList) ? pkg.locationNetworkList : []) values.push(item?.locationCode);
  return [...new Set(values.filter(v => typeof v === 'string').map(v => v.trim().toUpperCase())
    .filter(v => /^[A-Z]{2}$/.test(v)))].sort();
}

function normalizeEsimAccessOffer(pkg, { observedAt = new Date().toISOString(), type = 'BASE' } = {}) {
  if (!pkg || typeof pkg !== 'object' || type !== 'BASE' || pkg.type === 'TOPUP') return null;
  const productId = text(pkg.packageCode);
  const alias = text(pkg.slug);
  // Existing catalogue keys remain packageCode-first. Never merge by description/slug.
  const bundleName = productId || alias;
  if (!bundleName) return null;
  const countries = extractIsoCountries(pkg);
  const dataType = integer(pkg.dataType);
  const planType = ({ 1: 'total', 2: 'daily_throttled', 3: 'daily_cutoff', 4: 'daily_unlimited' })[dataType] || 'unknown';
  const daily = [2, 3, 4].includes(dataType);
  const bytes = integer(pkg.volume);
  const duration = integer(pkg.duration);
  const unit = text(pkg.durationUnit)?.toUpperCase() || null;
  // Do not assume months are 30 days, or a missing unit means days.
  const days = unit === 'DAY' ? duration : unit === 'HOUR' && duration !== null ? Math.ceil(duration / 24) : null;
  const rawPrice = integer(pkg.price);
  if (rawPrice === null || (pkg.currencyCode && pkg.currencyCode !== 'USD')) return null;
  const fup = text(pkg.fupPolicy);
  const networks = (Array.isArray(pkg.locationNetworkList) ? pkg.locationNetworkList : []).map(loc => ({
    country_code: text(loc?.locationCode)?.toUpperCase() || null,
    location_name: text(loc?.locationName),
    operators: (Array.isArray(loc?.operatorList) ? loc.operatorList : []).map(op => ({
      name: text(op?.operatorName), network_type: text(op?.networkType),
    })).filter(op => op.name),
  }));
  const details = {
    schema_version: 1, product_alias: alias, supplier_product_id: productId, discovery_type: 'BASE',
    plan_type: planType, allowance_bytes: bytes === null ? null : String(bytes),
    daily_behavior: ({ 2: 'slows_after_allowance', 3: 'stops_after_allowance', 4: 'unlimited' })[dataType] || null,
    activation_trigger: ({ 1: 'installation', 2: 'first_network_connection' })[integer(pkg.activeType)] || 'unknown',
    unused_validity_value: integer(pkg.unusedValidTime), unused_validity_unit: unit,
    duration_value: duration, duration_unit: unit,
    topup_support: ({ 1: 'unsupported', 2: 'supported', 3: 'daily_extension' })[integer(pkg.supportTopUpType)] || 'unknown',
    fup_text: fup, networks, apn: text(pkg.apn), help_text: text(pkg.installationGuide) || text(pkg.helpText),
    source_updated_at: timestamp(pkg.updatedAt) || timestamp(pkg.updateTime), observed_at: observedAt,
  };
  // Only documented package facts are retained, never the whole API envelope.
  const providerValues = {};
  for (const key of ['packageCode', 'slug', 'name', 'description', 'price', 'currencyCode', 'volume',
    'dataType', 'duration', 'durationUnit', 'unusedValidTime', 'activeType', 'supportTopUpType',
    'fupPolicy', 'location', 'locationNetworkList', 'apn', 'installationGuide', 'helpText', 'updatedAt', 'updateTime']) {
    if (pkg[key] !== undefined) providerValues[key] = pkg[key];
  }
  return {
    provider: 'esimaccess', bundle_name: bundleName,
    description: text(pkg.description) || text(pkg.name) || '', countries,
    roaming_enabled: countries.length > 1 ? countries : [],
    // Legacy MB is MiB, rounded down. Bytes remain authoritative in details.
    data_amount_mb: bytes === null ? 0 : Math.floor(bytes / 1048576), duration_days: days || 0,
    wholesale_price_usd: rawPrice / 10000, image_url: text(pkg.imageUrl) || text(pkg.locationLogo),
    // A slowing/cut-off plan must never enter an unlimited-only filter.
    is_unlimited: dataType === 4 || (planType === 'unknown' && pkg.isUnlimited === true),
    bundle_group: daily ? 'DayPass' : dataType === 1 ? 'Fixed Bundle' : null,
    speed_tier: dataType === 1 ? 'fixed' : null, region: text(pkg.region), country_count: countries.length,
    is_active: pkg.enabled !== false && (pkg.status == null || ['ACTIVE', 'NORMAL', 'ENABLED'].includes(pkg.status)),
    updated_at: observedAt, catalogue_details: details, provider_values: providerValues,
    provider_values_expires_at: new Date(Date.parse(observedAt) + 30 * 86400000).toISOString(),
  };
}

export { normalizeEsimAccessOffer, extractIsoCountries };
