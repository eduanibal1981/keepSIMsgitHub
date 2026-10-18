-- ISOLATED INFRASTRUCTURE ONLY. Never deploy this fixture.
-- Financial tables/constraints/ACLs/policies/selected real triggers are rebuilt
-- from financial_production_snapshot.json by production-fixture.mjs.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
-- External Supabase Auth is not recreated. These identity columns support
-- captured public FKs and claim predicates; no new-user/provider triggers run.
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,instance_id uuid,aud text,role text,encrypted_password text,
 email_confirmed_at timestamptz,created_at timestamptz,updated_at timestamptz,deleted_at timestamptz,
 is_anonymous boolean DEFAULT false,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub',nullif(current_setting('request.jwt.claim.sub',true),''))::uuid;
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role',nullif(current_setting('request.jwt.claim.role',true),''));
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon,authenticated,service_role;
-- Explicit external policy/supply adapters: these suites do not certify risk,
-- rate-limit, household-budget, admin-audit or supplier catalogue behavior.
CREATE FUNCTION public.enforce_rate_limit(text,text) RETURNS void LANGUAGE sql AS $$ SELECT; $$;
CREATE FUNCTION public.guard_money_action(text,numeric,text,text,uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"blocked":false}'::jsonb; $$;
CREATE FUNCTION public.household_spend_check(uuid,uuid,numeric,uuid) RETURNS TABLE(allowed boolean,reason text,monthly_cap numeric,spent_mtd numeric,remaining_usd numeric)
 LANGUAGE sql AS $$ SELECT true,NULL::text,100::numeric,0::numeric,100::numeric; $$;
CREATE FUNCTION public.admin_log(text,text,text,jsonb,jsonb,text) RETURNS uuid LANGUAGE sql AS $$ SELECT NULL::uuid; $$;
CREATE FUNCTION public.carrier_refill_offer(uuid,numeric) RETURNS TABLE(offer_code text,price_usd numeric,provider_code text,delivery_type text,offer_value bigint)
 LANGUAGE sql AS $$ SELECT 'fixture-offer',1.00::numeric,'dtone','airtime',1::bigint; $$;
-- M1 hardens these names; their notification/health trigger chains are omitted.
-- Accidental execution fails loudly rather than pretending delivery happened.
CREATE FUNCTION public.trg_fn_notify_topup_result() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
 BEGIN RAISE EXCEPTION 'Notification adapter outside financial fixture'; END; $$;
CREATE FUNCTION public.trg_scheduled_topup_health_sync() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
 BEGIN RAISE EXCEPTION 'Health adapter outside financial fixture'; END; $$;
