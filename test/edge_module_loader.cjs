const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');

// Execute the actual Edge modules with isolated provider/DB adapters.
function loadEdge(file, context = {}, cache = new Map()) {
  file = path.resolve(file);
  if (cache.has(file)) return cache.get(file);
  let code = stripTypeScriptTypes(fs.readFileSync(file, 'utf8'));
  const deps = [];
  code = code.replace(/^import\s+\{([^}]+)\}\s+from\s+["']([^"']+)["'];?\s*$/gm, (_, names, reference) => {
    const dependency = reference.startsWith('.')
      ? loadEdge(path.resolve(path.dirname(file), reference), context, cache) : context;
    const index = deps.push(dependency) - 1;
    return `const {${names.replace(/\bas\b/g, ':')}} = deps[${index}];`;
  });
  const exports = [...code.matchAll(/export (?:async )?(?:function|const|class) (\w+)/g)].map((x) => x[1]);
  code = code.replace(/^export /gm, '');
  const result = new Function('deps', 'Deno', 'fetch', code + `;return {${exports.join(',')}};`)(
    deps, { env: { get: (key) => context.env?.[key] } }, context.fetch || global.fetch);
  cache.set(file, result);
  return result;
}

function builder(resolve) {
  const filters = {}, operations = {};
  const b = {
    select: () => b, order: () => b, limit: () => b,
    eq: (key, value) => { filters[key] = value; return b; },
    update: (value) => { operations.update = value; return b; },
    insert: (value) => { operations.insert = value; return b; },
    maybeSingle: () => Promise.resolve(resolve(filters, operations)),
    single: () => Promise.resolve(resolve(filters, operations)),
    then: (ok, bad) => Promise.resolve(resolve(filters, operations)).then(ok, bad),
  };
  return b;
}

function targetLedger() {
  const rows = new Map();
  return { rows, async rpc(name, args) {
    const key = `${args.p_notification_id}:${args.p_channel}:${args.p_target_key}`;
    if (name === 'claim_notification_channel_target') {
      let row = rows.get(key);
      if (!row) { row = { state: 'pending', attempt_count: 0, snapshot: args.p_snapshot }; rows.set(key, row); }
      const claimed = row.state === 'pending' || (row.state === 'failed' && row.retryable && row.attempt_count < 3);
      if (claimed) { row.state = 'attempting'; row.attempt_count++; row.claim_token = crypto.randomUUID(); }
      return { data: { claimed, claim_token: row.claim_token, target: { ...row } } };
    }
    if (name === 'finish_notification_channel_target') {
      const row = rows.get(key);
      if (row.claim_token !== args.p_claim_token) return { data: { persisted: false } };
      if (row.state === 'attempting') Object.assign(row, { state: args.p_state, retryable: args.p_retryable, detail: args.p_detail });
      return { data: { persisted: true, target: { ...row } } };
    }
    throw Error(`Unexpected RPC ${name}`);
  } };
}
module.exports = { loadEdge, builder, targetLedger };
