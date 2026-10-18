#!/usr/bin/env python3
"""Recover data-free SQL evidence from an existing export; never connect or apply SQL."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/reviews/source-reproducibility-20261018'
OUTPUT = ROOT / 'supabase/recovered/20261018'
PURPOSES = {
    'update_execution_failed': ('legacy execution failure', '20261017190000_supplier_outcome_recovery.sql'),
    'update_execution_status': ('legacy worker settlement overload', '20261017164417_scheduled_refill_worker_contracts.sql'),
    'sync_power_user_claim': ('Auth admin-claim trigger', None),
    'credit_wallet': ('legacy wallet credit helper', '20261016020000_wallet_funding_integrity.sql'),
    'handle_new_user': ('Auth signup/profile bootstrap trigger', None),
    'update_updated_at': ('shared timestamp trigger', None),
    'handle_new_household_member': ('household membership trigger', None),
    'resolve_pending_household_invites': ('signup household invite resolution', None),
    'claim_instant_executions': ('legacy instant-worker claim', '20261018070000_scheduled_pricing_boundary.sql'),
    'update_line_health': ('SIM health trigger', None),
    'check_refill_pipeline_health': ('scheduled pipeline health', None),
    'is_user_suspended': ('JWT suspension helper', None),
    'sync_suspended_claim': ('Auth suspension-claim trigger', None),
    'bind_telegram_bot': ('Telegram binding helper', None),
    'get_current_context': ('request context helper', None),
    'schedule_delayed_notification': ('legacy notification queue producer', None),
}

# A lexical comparison must preserve string literal contents. Whitespace folding
# with a regular expression alone can silently change embedded SQL/JSON/text.
TOKEN = re.compile(r"--[^\n]*|/\*[\s\S]*?\*/|'(?:''|[^'])*'|\"(?:\"\"|[^\"])*\"|[A-Za-z_][A-Za-z_0-9$]*|\s+|.")


def normalized_body(body):
    tokens = []
    position = 0
    while position < len(body):
        if body[position].isspace():
            position += 1
            continue
        if body.startswith('--', position):
            end = body.find('\n', position)
            position = len(body) if end == -1 else end + 1
            continue
        if body.startswith('/*', position):
            depth = 1; position += 2
            while depth and position < len(body):
                if body.startswith('/*', position): depth += 1; position += 2
                elif body.startswith('*/', position): depth -= 1; position += 2
                else: position += 1
            if depth: raise ValueError('Unterminated SQL comment')
            continue
        start = position
        delimiter = re.match(r'\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$', body[position:])
        if delimiter:
            tag = delimiter[0]; end = body.find(tag, position + len(tag))
            if end == -1: raise ValueError('Unterminated dollar literal')
            position = end + len(tag)
        elif body[position] in ("'", '"'):
            quote = body[position]; position += 1
            escaped = quote == "'" and start > 0 and body[start-1] in 'eE' and (start < 2 or not body[start-2].isalnum())
            while position < len(body):
                if escaped and body[position] == '\\': position += 2
                elif body[position] == quote:
                    position += 1
                    if position < len(body) and body[position] == quote: position += 1
                    else: break
                else: position += 1
            else: raise ValueError('Unterminated SQL literal')
        else:
            word = re.match(r'[A-Za-z_][A-Za-z_0-9$]*', body[position:])
            position += len(word[0]) if word else 1
        token = body[start:position]
        if token.startswith('"') and re.fullmatch(r'"[a-z_][a-z_0-9]*"', token):
            token = token[1:-1]
        elif re.fullmatch(r'[A-Za-z_][A-Za-z_0-9$]*', token):
            token = token.lower()
        tokens.append(token)
    return '\x1f'.join(tokens)


def read_sql(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig')


def dump_functions(sql):
    # The supplied pg_dump format has a dollar-delimited AS on its own line.
    # This intentionally rejects other formats rather than guessing at a body.
    pattern = re.compile(r'CREATE OR REPLACE FUNCTION "public"\."(?P<name>[^"]+)"\('
                         r'(?P<header>[\s\S]*?)\n    AS (?P<tag>\$[^$]*\$)'
                         r'(?P<body>[\s\S]*?)(?P=tag);')
    return [{'name':m['name'],'header':m['header'],'body':m['body'],'definition':m[0]}
            for m in pattern.finditer(sql)]


def argument_types(header):
    # Stop at the matching close parenthesis, splitting only top-level commas.
    args, current, depth = [], [], 0
    for match in TOKEN.finditer(header):
        token = match.group()
        if token == ')' and depth == 0:
            if current: args.append(current)
            break
        if token == ',' and depth == 0:
            args.append(current); current = []; continue
        if token == '(': depth += 1
        if token == ')': depth -= 1
        if not token.isspace(): current.append(token)
    types = []
    for tokens in args:
        if not tokens: continue
        words = [t.strip('"').lower() for t in tokens]
        if words[0] == 'out': continue
        if words[0] in ('in', 'inout', 'variadic'): words = words[1:]
        # pg_dump always emits named arguments in this export.
        words = words[1:]
        if 'default' in words: words = words[:words.index('default')]
        value = ' '.join(words).replace(' [ ]', '[]').replace('public . ', '')
        value = {'int4':'integer','int8':'bigint','bool':'boolean','float8':'double precision',
                 'timestamptz':'timestamp with time zone'}.get(value, value)
        types.append(value)
    return ', '.join(types)


def recover(schema, output=OUTPUT):
    from scan_embedded_secrets import scan_text
    dump = dump_functions(read_sql(schema))
    catalog = json.loads((EVIDENCE / 'live-metadata.json').read_text())
    by_signature = {(f['name'], f['types']):f for f in catalog['functions']}
    by_dump = {}
    for fn in dump:
        signature = (fn['name'], argument_types(fn['header']))
        if signature in by_dump: raise ValueError(f'Duplicate exported signature: {signature}')
        by_dump[signature] = fn
    comparison = []
    recovered = []
    for signature, live in sorted(by_signature.items()):
        fn = by_dump.get(signature)
        matched = fn is not None and hashlib.sha256(fn['body'].encode()).hexdigest() == live['source_sha256']
        comparison.append({'name':signature[0],'types':signature[1],'exact_body_match':matched})
        if matched:
            comparison[-1]['non_public_static_references'] = sorted(set(
                '.'.join(x) for x in re.findall(r'\b(auth|storage|vault|net|cron|extensions)\s*\.\s*"?([A-Za-z_][A-Za-z_0-9]*)"?', fn['body'])))
        if signature[0] not in PURPOSES: continue
        if not matched: raise ValueError(f'Export/live body or signature mismatch: {signature}')
        findings = scan_text(fn['definition'], signature[0])
        if findings: raise ValueError(f'Embedded-secret scan rejected {signature[0]}: {[f.rule for f in findings]}')
        purpose, successor = PURPOSES[signature[0]]
        recovered.append({'name':signature[0],'types':signature[1],'identity':live['identity'],
                          'purpose':purpose,'successor':successor,
                          'acl':live['acl'],'settings':live['settings'],
                          'security_definer':live['security_definer'],
                          'source_sha256':live['source_sha256'],
                          'normalized_body_sha256':hashlib.sha256(normalized_body(fn['body']).encode()).hexdigest(),
                          'definition':fn['definition']})
    if len(recovered) != 17: raise ValueError(f'Expected 17 identified signatures, got {len(recovered)}')
    output.mkdir(parents=True, exist_ok=True)
    result = {'format':1,'project_id':catalog['project_id'],'evidence_date':catalog['capture_date'],
              'input_sha256':hashlib.sha256(schema.read_bytes()).hexdigest(),
              'scope':'Historical deployed contracts as evidence. Not a migration or an approved provisioning baseline.',
              'functions':recovered,'export_live_comparison':comparison}
    (output / 'public-routines.json').write_text(json.dumps(result, indent=2)+'\n')
    print(f"Recovered {len(recovered)} signatures; {sum(x['exact_body_match'] for x in comparison)}/{len(comparison)} export/live bodies match.")
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('schema', type=Path)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    recover(args.schema, args.output)
