"""Build isolated SQL checks for Free Call contracts; no DB connection or writes.

Run the output with Supabase MCP execute_sql. It tests the migration function
body in pg_temp with synthetic fixtures, then rolls back every object and row.
"""
import argparse
from pathlib import Path
from migration_archive import migration_path

ROOT = Path(__file__).resolve().parents[1]


def build(suite: str) -> str:
    if suite == 'recipient':
        source = migration_path('20261014212438_resolve_free_call_recipient_exact.sql').read_text()
        source = source[:source.index('COMMENT ON FUNCTION')]
        source = source.replace('public.resolve_free_call_recipient', 'pg_temp.resolve_free_call_recipient')
        for table in ['users', 'profiles', 'user_caller_ids', 'virtual_did_numbers', 'sim_lines', 'household_members', 'voip_call_sessions']:
            source = source.replace(('auth.' if table == 'users' else 'public.') + table, 'pg_temp.' + table)
        source = source.replace('public.consume_rate_limit', 'pg_temp.consume_rate_limit')
        setup = '''CREATE TEMP TABLE users(id uuid, phone text, phone_confirmed_at timestamptz, banned_until timestamptz);
CREATE TEMP TABLE profiles(id uuid, full_name text, phone text, avatar_url text);
CREATE TEMP TABLE user_caller_ids(user_id uuid, phone_number text, is_verified boolean);
CREATE TEMP TABLE virtual_did_numbers(user_id uuid, phone_number text, status text);
CREATE TEMP TABLE sim_lines(user_id uuid, phone_number text);
CREATE TEMP TABLE household_members(owner_id uuid, member_id uuid, invite_status text);
CREATE TEMP TABLE voip_call_sessions(caller_id uuid, callee_id uuid);
CREATE FUNCTION pg_temp.consume_rate_limit(text,text,integer,numeric) RETURNS TABLE(allowed boolean)
LANGUAGE sql AS $quota$ SELECT current_setting('keepsims.test_quota', true) IS DISTINCT FROM 'denied'; $quota$;
'''
        test = 'free_call_recipient_exact_test.sql'
        grant = ''
    else:
        source = migration_path('20261014214959_protect_caller_id_verification_fields.sql').read_text()
        source = source.replace('public.protect_caller_id_verification_fields', 'pg_temp.protect_caller_id_verification_fields').replace('public.user_caller_ids', 'pg_temp.user_caller_ids')
        setup = '''CREATE TEMP TABLE user_caller_ids(id text,user_id uuid,phone_number text,is_verified boolean DEFAULT false,verified_at timestamptz,label text,is_default boolean);
GRANT SELECT,INSERT,UPDATE ON pg_temp.user_caller_ids TO authenticated;
'''
        test = 'caller_id_verification_fields_test.sql'
        grant = "EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated', pg_my_temp_schema()::regnamespace);"
    assertions = (ROOT / 'supabase/tests' / test).read_text()
    return ('BEGIN; DO $preview$ BEGIN EXECUTE $setup$' + setup + '$setup$; EXECUTE $migration$' + source +
            '$migration$; ' + grant + ' END $preview$;\n' + assertions +
            "\nROLLBACK; SELECT 'Isolated assertions passed; all fixtures rolled back' AS result;\n")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=['recipient', 'verification-fields'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(build(args.suite))
    print(f'Wrote isolated {args.suite} SQL checks to {args.output}')
