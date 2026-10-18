// Isolated Task 2 fixture. Applies the complete provider credential migration.
// Vault encryption, Supabase JWT verification and external consumers are stubs.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const { PGlite } = await import(process.env.PGLITE_MODULE_PATH
  ? pathToFileURL(process.env.PGLITE_MODULE_PATH).href : '@electric-sql/pglite');
const db = new PGlite();
let passed = 0;
let currentTest = 'fixture bootstrap';
const adminId = '00000000-0000-4000-8000-000000000001';
const userId = '00000000-0000-4000-8000-000000000002';
const adminClaims = { sub: adminId, role: 'authenticated', app_metadata: { is_power_user: true } };
const userClaims = { sub: userId, role: 'authenticated', app_metadata: {} };
const firstReplacement = 'fixture-first-relay-secret-32-bytes-only';
const nextReplacement = 'fixture-second-relay-secret-32-bytes-only';
const reference = 'fixture change reference';

async function test(label, run) {
  currentTest = label;
  await run();
  passed++;
  console.log(`PASS ${label}`);
}

async function asRole(role, claims, run, options = {}) {
  assert(['anon', 'authenticated', 'service_role'].includes(role));
  await db.exec('BEGIN');
  try {
    await db.exec(`SET LOCAL ROLE ${role}`);
    await db.query("SELECT set_config('request.jwt.claims', $1, true)", [JSON.stringify(claims)]);
    for (const [key, value] of Object.entries(options)) {
      assert(['fixture.vault_fail', 'fixture.audit_fail'].includes(key));
      await db.query('SELECT set_config($1, $2, true)', [key, value]);
    }
    const result = await run();
    await db.exec('COMMIT');
    return result;
  } catch (error) {
    await db.exec('ROLLBACK');
    throw error;
  }
}

async function rejects(run, code, replacement = firstReplacement) {
  let rejected = false;
  try { await run(); }
  catch (error) {
    rejected = true;
    assert.equal(error.code, code, 'Expected the controlled SQLSTATE');
    const exposed = JSON.stringify({ message: error.message, detail: error.detail, hint: error.hint });
    if (typeof replacement === 'string' && replacement.trim().length > 3) {
      assert(!exposed.includes(replacement), 'Public errors must omit credential values');
    }
  }
  assert(rejected, 'Expected the operation to be rejected');
}

const rotate = (key = 'TURN_SHARED_SECRET', value = firstReplacement, version = 0, reason = reference) =>
  db.query('SELECT public.admin_rotate_provider_credential($1, $2, $3, $4) AS result', [key, value, reason, version]);
const list = () => db.query('SELECT * FROM public.admin_list_provider_credentials()');
const adminRotate = (...args) => asRole('authenticated', adminClaims, () => rotate(...args));
const scalar = async (query, params = []) => (await db.query(query, params)).rows[0].value;
const auditCount = () => scalar('SELECT count(*)::integer AS value FROM public.fixture_admin_audit');
const version = (key = 'TURN_SHARED_SECRET') => scalar('SELECT version AS value FROM public.provider_credential_registry WHERE credential_key=$1', [key]);
const stored = (key = 'TURN_SHARED_SECRET') => scalar('SELECT secret AS value FROM vault.secrets WHERE name=$1', [key]);

try {
  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth;
    CREATE SCHEMA vault;
    REVOKE ALL ON SCHEMA vault FROM PUBLIC;
    GRANT USAGE ON SCHEMA public, auth TO anon, authenticated, service_role;
    -- Reproduce broad platform defaults; the real migration must remove these.
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT (nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'sub')::uuid;
    $$;
    CREATE FUNCTION public.assert_admin() RETURNS uuid LANGUAGE plpgsql AS $$
    BEGIN
      IF auth.uid() IS NULL OR NOT coalesce((nullif(current_setting('request.jwt.claims', true), '')::jsonb
        #>>'{app_metadata,is_power_user}')::boolean, false) THEN
        RAISE EXCEPTION 'Admin required' USING ERRCODE='KS460';
      END IF;
      RETURN auth.uid();
    END;
    $$;
    CREATE TABLE vault.secrets (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE NOT NULL,
      secret text NOT NULL, description text, updated_at timestamptz DEFAULT now()
    );
    REVOKE ALL ON vault.secrets FROM PUBLIC, anon, authenticated, service_role;
    CREATE FUNCTION vault.create_secret(new_secret text, new_name text, new_description text)
    RETURNS uuid LANGUAGE plpgsql AS $$
    DECLARE v_id uuid;
    BEGIN
      INSERT INTO vault.secrets(name, secret, description) VALUES(new_name, new_secret, new_description) RETURNING id INTO v_id;
      IF current_setting('fixture.vault_fail', true) = 'on' THEN
        RAISE EXCEPTION 'Fixture Vault diagnostic: %', new_secret;
      END IF;
      RETURN v_id;
    END;
    $$;
    CREATE FUNCTION vault.update_secret(secret_id uuid, new_secret text, new_name text, new_description text)
    RETURNS void LANGUAGE plpgsql AS $$
    BEGIN
      UPDATE vault.secrets SET name=new_name, secret=new_secret, description=new_description, updated_at=now() WHERE id=secret_id;
      IF current_setting('fixture.vault_fail', true) = 'on' THEN
        RAISE EXCEPTION 'Fixture Vault diagnostic: %', new_secret;
      END IF;
    END;
    $$;
    CREATE TABLE public.fixture_admin_audit (
      actor uuid, action text, entity_type text, entity_id text,
      before_data jsonb, after_data jsonb, notes text
    );
    REVOKE ALL ON public.fixture_admin_audit FROM PUBLIC, anon, authenticated, service_role;
    CREATE FUNCTION public.admin_log(p_action text,p_entity_type text,p_entity_id text,p_before jsonb,p_after jsonb,p_notes text)
    RETURNS void LANGUAGE plpgsql AS $$
    BEGIN
      INSERT INTO public.fixture_admin_audit VALUES(auth.uid(),p_action,p_entity_type,p_entity_id,p_before,p_after,p_notes);
      IF current_setting('fixture.audit_fail', true) = 'on' THEN
        RAISE EXCEPTION 'Fixture audit unavailable';
      END IF;
    END;
    $$;
    -- The full forward migration must replace this legacy generic signature.
    CREATE FUNCTION public.admin_set_vault_secret(p_name text,p_secret text,p_description text DEFAULT '')
    RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$
      SELECT vault.create_secret(p_secret,p_name,p_description);
    $$;
  `);

  await test('complete credential migration applies to the isolated fixture', async () => {
    const source = fs.readFileSync(new URL('../../supabase/migrations/20261016205533_admin_provider_credentials.sql', import.meta.url), 'utf8');
    await db.exec(source);
    assert.equal(await scalar('SELECT count(*)::integer AS value FROM public.provider_credential_registry'), 13);
  });

  await test('credential RPC grants exclude anon and service role', async () => {
    for (const role of ['anon', 'service_role']) {
      for (const signature of ['public.admin_list_provider_credentials()',
        'public.admin_rotate_provider_credential(text,text,text,integer)',
        'public.admin_confirm_provider_credential_rotation(text,integer)',
        'public.admin_set_vault_secret(text,text,text)']) {
        assert.equal(await scalar('SELECT has_function_privilege($1,$2,\'EXECUTE\') AS value', [role, signature]), false);
      }
    }
    assert.equal(await scalar("SELECT has_function_privilege('authenticated','public.admin_list_provider_credentials()','EXECUTE') AS value"), true);
    assert.equal(await scalar("SELECT count(*)::integer AS value FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.proname IN ('admin_list_provider_credentials','admin_rotate_provider_credential','admin_set_vault_secret','admin_confirm_provider_credential_rotation') AND a.grantee=0 AND a.privilege_type='EXECUTE'"), 0);
  });

  await test('credential functions pin SECURITY DEFINER search paths', async () => {
    const rows = (await db.query("SELECT prosecdef,proconfig FROM pg_proc WHERE proname IN ('admin_list_provider_credentials','admin_rotate_provider_credential','admin_set_vault_secret','admin_confirm_provider_credential_rotation')")).rows;
    assert.equal(rows.length, 4);
    assert(rows.every(row => row.prosecdef && row.proconfig.includes('search_path=""')));
  });

  for (const role of ['anon', 'service_role']) {
    await test(`${role} cannot invoke credential APIs even with an admin-shaped claim`, async () => {
      await rejects(() => asRole(role, adminClaims, list), '42501');
      await rejects(() => asRole(role, adminClaims, () => rotate()), '42501');
    });
  }

  await test('ordinary authenticated and missing-identity sessions are denied in the body', async () => {
    await rejects(() => asRole('authenticated', userClaims, list), 'KS460');
    await rejects(() => asRole('authenticated', userClaims, () => rotate()), 'KS460');
    await rejects(() => asRole('authenticated', {app_metadata:{is_power_user:true}}, list), 'KS460');
  });

  await test('API roles cannot read or mutate credential registry directly', async () => {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      for (const query of [
        'SELECT * FROM public.provider_credential_registry',
        "UPDATE public.provider_credential_registry SET version=999",
        'DELETE FROM public.provider_credential_registry',
        'TRUNCATE public.provider_credential_registry',
      ]) await rejects(() => asRole(role, adminClaims, () => db.query(query)), '42501');
    }
  });

  await test('administrator JWT cannot read Vault or private audit directly', async () => {
    await rejects(() => asRole('authenticated', adminClaims, () => db.query('SELECT * FROM vault.secrets')), '42501');
    await rejects(() => asRole('authenticated', adminClaims, () => db.query('SELECT * FROM public.fixture_admin_audit')), '42501');
  });

  await test('authorized list exposes only allowlisted metadata and Vault presence', async () => {
    const rows = (await asRole('authenticated', adminClaims, list)).rows;
    assert.equal(rows.length, 13);
    assert(rows.every(row => row.configured === false && row.version === 0 && row.last_rotated_at === null));
    assert(rows.some(row => row.credential_key === 'PAYPAL_CLIENT_SECRET'));
    assert(rows.every(row => row.requires_external_sync));
    assert(!Object.keys(rows[0]).some(key => ['secret', 'value', 'decrypted_secret', 'old_secret'].includes(key)));
  });

  await test('unknown credential names cannot create arbitrary Vault entries', async () => {
    await rejects(() => adminRotate('UNMANAGED_FIXTURE_KEY'), 'KS701');
    assert.equal(await scalar('SELECT count(*)::integer AS value FROM vault.secrets'), 0);
  });

  await test('missing or stale expected versions fail before a write', async () => {
    await rejects(() => adminRotate('TURN_SHARED_SECRET', firstReplacement, null), 'KS702');
    await rejects(() => adminRotate('TURN_SHARED_SECRET', firstReplacement, 1), 'KS702');
    assert.equal(await version(), 0);
  });

  await test('empty, padded, placeholder, multiline and oversize replacements fail closed', async () => {
    for (const value of [null, '', ' ', '<replacement>', 'changeme', 'placeholder', 'replace_me', 'replace-me', 'replace me', 'your_key', 'your-key',
      ' padded-fixture ', 'fixture\nline', 'fixture\rline', 'x'.repeat(16385)]) {
      await rejects(() => adminRotate('TURN_SHARED_SECRET', value), 'KS703', value ?? firstReplacement);
    }
    assert.equal(await version(), 0);
  });

  await test('change references are required and cannot include the replacement', async () => {
    for (const reason of [null, '', 'abc', 'x'.repeat(501), `reference ${firstReplacement}`]) {
      await rejects(() => adminRotate('TURN_SHARED_SECRET', firstReplacement, 0, reason), 'KS704');
    }
    assert.equal(await auditCount(), 0);
  });

  await test('admin replacement creates one Vault value and a pending rotation record', async () => {
    const result = (await adminRotate()).rows[0].result;
    assert.equal(result.configured, true);
    assert.equal(result.version, 1);
    assert.equal(result.rotation_status, 'stored_pending_external_verification');
    assert.equal(result.requires_external_sync, true);
    assert(!JSON.stringify(result).includes(firstReplacement));
    assert.equal(await version(), 1);
    assert((await stored()) === firstReplacement, 'Fixture Vault contains the replacement');
    assert.equal(await auditCount(), 1);
  });

  await test('updating an existing credential advances the version without duplicate Vault names', async () => {
    const result = (await adminRotate('TURN_SHARED_SECRET', nextReplacement, 1)).rows[0].result;
    assert.equal(result.version, 2);
    assert((await stored()) === nextReplacement, 'Fixture Vault contains only the new replacement');
    assert.equal(await scalar("SELECT count(*)::integer AS value FROM vault.secrets WHERE name='TURN_SHARED_SECRET'"), 1);
    assert.equal(await auditCount(), 2);
  });

  await test('stale updates preserve the stored value, version and audit', async () => {
    await rejects(() => adminRotate('TURN_SHARED_SECRET', firstReplacement, 1), 'KS702');
    assert.equal(await version(), 2);
    assert((await stored()) === nextReplacement);
    assert.equal(await auditCount(), 2);
  });

  await test('metadata and audit never persist replacement or freeform reference', async () => {
    const rows = (await asRole('authenticated', adminClaims, list)).rows;
    assert.equal(rows.find(row => row.credential_key === 'TURN_SHARED_SECRET').configured, true);
    const audit = (await db.query('SELECT * FROM public.fixture_admin_audit')).rows;
    const exposed = JSON.stringify({ rows, audit });
    for (const value of [firstReplacement, nextReplacement, reference]) assert(!exposed.includes(value));
    assert(audit.every(row => row.actor === adminId));
  });

  await test('Vault create errors are sanitized and roll back all partial writes', async () => {
    await rejects(() => asRole('authenticated', adminClaims,
      () => rotate('TELNYX_API_KEY'), {'fixture.vault_fail':'on'}), 'KS705');
    assert.equal(await version('TELNYX_API_KEY'), 0);
    assert.equal(await scalar("SELECT count(*)::integer AS value FROM vault.secrets WHERE name='TELNYX_API_KEY'"), 0);
    assert.equal(await auditCount(), 2);
  });

  await test('Vault update errors preserve previous value and metadata', async () => {
    await rejects(() => asRole('authenticated', adminClaims,
      () => rotate('TURN_SHARED_SECRET', firstReplacement, 2), {'fixture.vault_fail':'on'}), 'KS705');
    assert.equal(await version(), 2);
    assert((await stored()) === nextReplacement);
    assert.equal(await auditCount(), 2);
  });

  await test('audit errors roll back the Vault value, registry and audit together', async () => {
    await rejects(() => asRole('authenticated', adminClaims,
      () => rotate('TELNYX_API_KEY'), {'fixture.audit_fail':'on'}), 'KS705');
    assert.equal(await version('TELNYX_API_KEY'), 0);
    assert.equal(await scalar("SELECT count(*)::integer AS value FROM vault.secrets WHERE name='TELNYX_API_KEY'"), 0);
    assert.equal(await auditCount(), 2);
  });

  await test('legacy generic writer cannot bypass managed credential versions', async () => {
    await rejects(() => asRole('authenticated', adminClaims,
      () => db.query('SELECT public.admin_set_vault_secret($1,$2,$3)', ['TURN_SHARED_SECRET', firstReplacement, 'fixture'])), 'KS706');
    assert.equal(await version(), 2);
    assert((await stored()) === nextReplacement);
  });

  await test('legacy WhatsApp names remain compatible and metadata only', async () => {
    const result = await asRole('authenticated', adminClaims,
      () => db.query('SELECT public.admin_set_vault_secret($1,$2,$3) AS id', ['wa_meta_token_fixture', firstReplacement, 'WhatsApp fixture']));
    assert(result.rows[0].id);
    assert((await stored('wa_meta_token_fixture')) === firstReplacement);
    assert.equal(await scalar("SELECT count(*)::integer AS value FROM public.provider_credential_registry WHERE credential_key='wa_meta_token_fixture'"), 0);
    const audit = JSON.stringify((await db.query('SELECT * FROM public.fixture_admin_audit')).rows);
    assert(!audit.includes(firstReplacement));
    assert.equal(await auditCount(), 3);
  });

  await test('legacy storage errors are sanitized and retain the previous WhatsApp value', async () => {
    await rejects(() => asRole('authenticated', adminClaims,
      () => db.query('SELECT public.admin_set_vault_secret($1,$2,$3)', ['wa_meta_token_fixture', nextReplacement, 'WhatsApp fixture']),
      {'fixture.vault_fail':'on'}), 'KS705', nextReplacement);
    assert((await stored('wa_meta_token_fixture')) === firstReplacement);
    assert.equal(await auditCount(), 3);
  });

  await test('outer transaction rollback restores successful Vault, audit and registry changes', async () => {
    await db.exec('BEGIN');
    await db.query("SELECT set_config('request.jwt.claims',$1,true)", [JSON.stringify(adminClaims)]);
    await db.exec('SET LOCAL ROLE authenticated');
    await rotate('TURN_SHARED_SECRET', firstReplacement, 2);
    await db.exec('ROLLBACK');
    assert.equal(await version(), 2);
    assert((await stored()) === nextReplacement);
    assert.equal(await auditCount(), 3);
  });

  await test('independent allowlisted credentials maintain independent versions', async () => {
    const result = (await adminRotate('TELNYX_API_KEY')).rows[0].result;
    assert.equal(result.version, 1);
    assert.equal(await version(), 2);
    assert.equal(await auditCount(), 4);
  });

  const confirm = (key = 'TURN_SHARED_SECRET', expected = 2) =>
    db.query('SELECT public.admin_confirm_provider_credential_rotation($1,$2)', [key,expected]);

  await test('completion is admin-only and requires a stored replacement at the expected version', async () => {
    await rejects(() => asRole('authenticated', userClaims, () => confirm()), 'KS460');
    await rejects(() => asRole('authenticated', adminClaims, () => confirm('DTONE_API_KEY',0)), 'KS707');
    await rejects(() => asRole('authenticated', adminClaims, () => confirm('TURN_SHARED_SECRET',1)), 'KS702');
    assert.equal(await auditCount(),4);
  });
  await test('operator confirmation is version-bound, audited and idempotent without changing the secret', async () => {
    await asRole('authenticated', adminClaims, () => confirm());
    const row = (await asRole('authenticated', adminClaims, list)).rows.find(r => r.credential_key === 'TURN_SHARED_SECRET');
    assert.equal(row.rotation_status,'operator_confirmed'); assert.equal(row.requires_external_sync,false);
    assert(row.verified_at); assert.equal(row.version,2); assert((await stored()) === nextReplacement);
    assert.equal(await auditCount(),5);
    await asRole('authenticated', adminClaims, () => confirm());
    assert.equal(await auditCount(),5);
  });
  await test('a new replacement invalidates prior confirmation and cannot be confirmed by a stale operator', async () => {
    await adminRotate('TURN_SHARED_SECRET',firstReplacement,2);
    const row = (await asRole('authenticated', adminClaims, list)).rows.find(r => r.credential_key === 'TURN_SHARED_SECRET');
    assert.equal(row.rotation_status,'stored_pending_external_verification'); assert.equal(row.requires_external_sync,true);
    assert.equal(row.verified_at,null); assert.equal(row.version,3);
    await rejects(() => asRole('authenticated', adminClaims, () => confirm()), 'KS702');
    assert.equal(await auditCount(),6);
  });
  await test('confirmation audit failure rolls its completion status back', async () => {
    await rejects(() => asRole('authenticated', adminClaims, () => confirm('TURN_SHARED_SECRET',3), {'fixture.audit_fail':'on'}),'KS705');
    const row = (await asRole('authenticated', adminClaims, list)).rows.find(r => r.credential_key === 'TURN_SHARED_SECRET');
    assert.equal(row.rotation_status,'stored_pending_external_verification'); assert.equal(await auditCount(),6);
  });
  await test('legacy aliases cannot bypass credential versions and weak relay replacements fail', async () => {
    for (const name of ['zendit_api_key','ZENDIT_API_KEY','COTURN_SHARED_SECRET']) {
      await rejects(() => asRole('authenticated', adminClaims, () => db.query('SELECT public.admin_set_vault_secret($1,$2,$3)',[name,firstReplacement,'fixture'])),'KS706');
    }
    await rejects(() => adminRotate('TURN_SHARED_SECRET','short-fixture',3),'KS703','short-fixture');
    assert.equal(await auditCount(),6);
  });

  console.log(`Credential SQL fixture: ${passed} passed. No production/provider calls.`);
} catch (error) {
  // Do not dump SQL parameters or fixture Vault diagnostics on a failure.
  console.error(`FAIL ${currentTest} (${error.code ?? error.name ?? 'unknown'})`);
  process.exitCode = 1;
} finally {
  await db.close();
}
