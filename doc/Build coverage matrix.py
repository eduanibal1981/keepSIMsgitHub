#!/usr/bin/env python3
"""
build_coverage_matrix.py
------------------------
Pulls your top-up aggregator catalog(s) and flattens them into ONE CSV:
the "aggregator coverage export" the advertising plan needs.

Output columns (this is what drives corridor strategy):
    country, country_iso, carrier, aggregator, live, denomination_type,
    min_amount, max_amount, fixed_amounts, currency, cost_basis,
    margin_pct, keep_alive_amount, mini_refill_viable, notes

WHY THESE COLUMNS:
    min_amount vs keep_alive_amount decides whether Premium auto-mini-refill
    is sellable in a corridor at all. margin_pct decides max CAC per corridor.
    Everything else is targeting eligibility.

USAGE:
    export ZENDIT_API_KEY="..."
    python build_coverage_matrix.py --probe          # dump raw JSON, inspect shape
    python build_coverage_matrix.py                  # build the CSV

If the field names don't match your account's response, edit FIELD_MAP.
Run --probe first; it writes raw_zendit.json so you can see actual keys.
"""

import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ---------------------------------------------------------------------------
# CONFIG — adjust to match your working integration
# ---------------------------------------------------------------------------

ZENDIT_BASE = os.environ.get("ZENDIT_BASE", "https://api.zendit.io/v1")
ZENDIT_CATALOG_PATH = os.environ.get("ZENDIT_CATALOG_PATH", "/offers")
ZENDIT_API_KEY = os.environ.get("ZENDIT_API_KEY", "")

# Origin markets only — where the SIM is. GCC is where customers LIVE and is
# irrelevant to coverage.
TARGET_ISO = ["IN", "PK", "BD", "PH", "NP", "LK", "EG", "LB", "IQ", "SY"]

ISO_NAMES = {
    "IN": "India", "PK": "Pakistan", "BD": "Bangladesh", "PH": "Philippines",
    "NP": "Nepal", "LK": "Sri Lanka", "EG": "Egypt", "LB": "Lebanon",
    "IQ": "Iraq", "SY": "Syria",
}

# Candidate key names, tried in order. Add yours if the probe shows different.
FIELD_MAP = {
    "carrier":      ["operator", "operatorName", "carrier", "brand", "name", "subType"],
    "country_iso":  ["country", "countryCode", "iso", "isoCode", "country_iso"],
    "currency":     ["currency", "destinationCurrency", "currencyCode", "senderCurrency"],
    "min_amount":   ["min", "minAmount", "minimum", "minValue", "priceMin"],
    "max_amount":   ["max", "maxAmount", "maximum", "maxValue", "priceMax"],
    "fixed_list":   ["fixedAmounts", "denominations", "values", "amounts", "fixedValues"],
    "denom_type":   ["type", "denominationType", "offerType", "priceType"],
    "live":         ["enabled", "available", "active", "status", "isActive"],
    "cost":         ["cost", "wholesale", "price", "senderAmount", "costPrice"],
    "identifier":   ["id", "offerId", "sku", "productId"],
}

TIMEOUT = 30
PAGE_LIMIT = 200
MAX_PAGES = 100


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

def http_get(url, headers, retries=3):
    for attempt in range(retries):
        req = urllib.request.Request(url, headers=headers, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:400]
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                wait = 2 ** attempt
                print(f"  HTTP {e.code}, retrying in {wait}s...", file=sys.stderr)
                time.sleep(wait)
                continue
            raise SystemExit(f"\nHTTP {e.code} on {url}\n{body}\n")
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise SystemExit(f"\nConnection failed: {e.reason}\nCheck ZENDIT_BASE.\n")
    return None


def fetch_zendit(iso_list, probe=False):
    """Pull the catalog. Paginates until exhausted."""
    if not ZENDIT_API_KEY:
        raise SystemExit("ZENDIT_API_KEY not set. export ZENDIT_API_KEY='...'")

    headers = {
        "Authorization": f"Bearer {ZENDIT_API_KEY}",
        "Accept": "application/json",
    }

    all_items = []
    for iso in iso_list:
        print(f"  {iso} ({ISO_NAMES.get(iso, iso)})...", end="", flush=True)
        offset, pages, got = 0, 0, 0
        while pages < MAX_PAGES:
            qs = urllib.parse.urlencode(
                {"country": iso, "limit": PAGE_LIMIT, "offset": offset}
            )
            data = http_get(f"{ZENDIT_BASE}{ZENDIT_CATALOG_PATH}?{qs}", headers)

            items = extract_items(data)
            if not items:
                break
            for it in items:
                it.setdefault("_requested_iso", iso)
            all_items.extend(items)
            got += len(items)

            if probe and all_items:
                return all_items
            if len(items) < PAGE_LIMIT:
                break
            offset += PAGE_LIMIT
            pages += 1
        print(f" {got} offers")
    return all_items


def extract_items(payload):
    """Find the list of offers wherever the API buried it."""
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []
    for key in ("list", "items", "data", "offers", "results", "records", "content"):
        v = payload.get(key)
        if isinstance(v, list):
            return v
    for v in payload.values():
        if isinstance(v, list) and v and isinstance(v[0], dict):
            return v
    return []


# ---------------------------------------------------------------------------
# Field resolution
# ---------------------------------------------------------------------------

def flatten(d, prefix="", out=None):
    if out is None:
        out = {}
    for k, v in (d or {}).items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            flatten(v, f"{key}.", out)
        else:
            out[key] = v
    return out


def pick(flat, candidates):
    """Exact match first, then case-insensitive suffix match."""
    for c in candidates:
        if c in flat and flat[c] not in (None, ""):
            return flat[c]
    lowered = {k.lower(): v for k, v in flat.items()}
    for c in candidates:
        cl = c.lower()
        if cl in lowered and lowered[cl] not in (None, ""):
            return lowered[cl]
        for k, v in lowered.items():
            if k.endswith("." + cl) and v not in (None, ""):
                return v
    return ""


def as_bool_live(val):
    if val in ("", None):
        return "UNKNOWN"
    if isinstance(val, bool):
        return "YES" if val else "NO"
    s = str(val).strip().lower()
    if s in ("true", "1", "active", "enabled", "available", "live", "ok"):
        return "YES"
    if s in ("false", "0", "inactive", "disabled", "unavailable", "off"):
        return "NO"
    return str(val)


def normalize(item):
    flat = flatten(item)

    fixed = pick(flat, FIELD_MAP["fixed_list"])
    if isinstance(fixed, str) and fixed:
        fixed_str = fixed
    elif isinstance(fixed, (list, tuple)):
        fixed_str = ";".join(str(x) for x in fixed)
    else:
        fixed_str = ""
        # a nested list won't survive flatten(); recover it from the raw item
        for cand in FIELD_MAP["fixed_list"]:
            raw = item.get(cand)
            if isinstance(raw, (list, tuple)) and raw:
                fixed_str = ";".join(str(x) for x in raw)
                break

    denom = str(pick(flat, FIELD_MAP["denom_type"]) or "").upper()
    if not denom:
        denom = "FIXED" if fixed_str else ("RANGE" if pick(flat, FIELD_MAP["min_amount"]) else "")

    min_amt = pick(flat, FIELD_MAP["min_amount"])
    if not min_amt and fixed_str:
        try:
            min_amt = min(float(x) for x in fixed_str.split(";") if x.strip())
        except ValueError:
            pass

    iso = str(pick(flat, FIELD_MAP["country_iso"]) or item.get("_requested_iso", "")).upper()[:2]

    return {
        "country": ISO_NAMES.get(iso, iso),
        "country_iso": iso,
        "carrier": pick(flat, FIELD_MAP["carrier"]),
        "aggregator": "Zendit",
        "live": as_bool_live(pick(flat, FIELD_MAP["live"])),
        "denomination_type": denom,
        "min_amount": min_amt,
        "max_amount": pick(flat, FIELD_MAP["max_amount"]),
        "fixed_amounts": fixed_str,
        "currency": pick(flat, FIELD_MAP["currency"]),
        "cost_basis": pick(flat, FIELD_MAP["cost"]),
        "margin_pct": "",            # you fill: from your own pricing config
        "keep_alive_amount": "",     # you fill: from carrier_rules
        "mini_refill_viable": "",    # computed once the two above are filled
        "offer_id": pick(flat, FIELD_MAP["identifier"]),
        "notes": "",
    }


COLUMNS = [
    "country", "country_iso", "carrier", "aggregator", "live",
    "denomination_type", "min_amount", "max_amount", "fixed_amounts",
    "currency", "cost_basis", "margin_pct", "keep_alive_amount",
    "mini_refill_viable", "offer_id", "notes",
]


def dedupe(rows):
    seen, out = set(), []
    for r in rows:
        key = (r["country_iso"], str(r["carrier"]).lower(), r["offer_id"])
        if key in seen:
            continue
        seen.add(key)
        out.append(r)
    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true",
                    help="Fetch one page, dump raw JSON, print detected keys. Run this first.")
    ap.add_argument("--out", default="aggregator_coverage.csv")
    ap.add_argument("--countries", default=",".join(TARGET_ISO))
    args = ap.parse_args()

    iso_list = [c.strip().upper() for c in args.countries.split(",") if c.strip()]

    if args.probe:
        print("Probing Zendit (one page)...")
        items = fetch_zendit(iso_list[:1], probe=True)
        if not items:
            raise SystemExit("No offers returned. Check ZENDIT_CATALOG_PATH.")
        with open("raw_zendit.json", "w", encoding="utf-8") as f:
            json.dump(items[:5], f, indent=2, ensure_ascii=False)
        print("\nWrote raw_zendit.json (first 5 offers).")
        print("\nKeys in first offer:")
        for k, v in sorted(flatten(items[0]).items()):
            preview = str(v)[:60]
            print(f"  {k:<34} = {preview}")
        print("\nMapped preview:")
        for k, v in normalize(items[0]).items():
            print(f"  {k:<20} -> {v}")
        print("\nIf anything above is blank or wrong, add the real key name to FIELD_MAP.")
        return

    print(f"Pulling Zendit catalog for {len(iso_list)} origin markets...")
    items = fetch_zendit(iso_list)
    if not items:
        raise SystemExit("No offers returned.")

    rows = dedupe([normalize(i) for i in items])
    rows.sort(key=lambda r: (r["country"], str(r["carrier"])))

    with open(args.out, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)

    print(f"\nWrote {args.out} — {len(rows)} rows")

    # Coverage summary + gap report: the part that matters strategically
    print("\nCoverage by origin market:")
    for iso in iso_list:
        sub = [r for r in rows if r["country_iso"] == iso]
        carriers = sorted({str(r["carrier"]) for r in sub if r["carrier"]})
        name = ISO_NAMES.get(iso, iso)
        if not sub:
            print(f"  {name:<12} NO COVERAGE  <-- corridor cannot be advertised")
        else:
            mins = [float(r["min_amount"]) for r in sub
                    if str(r["min_amount"]).replace(".", "", 1).isdigit()]
            lo = f"min {min(mins):g}" if mins else "min UNKNOWN"
            print(f"  {name:<12} {len(sub):>3} offers | {len(carriers)} carriers | {lo}")
            print(f"               {', '.join(carriers[:6])}")

    missing = [ISO_NAMES.get(i, i) for i in iso_list
               if not any(r["country_iso"] == i for r in rows)]
    if missing:
        print(f"\n[!] No Zendit coverage: {', '.join(missing)}")
        print("    Check DoctorSIM/Reloadly for these before writing corridor creative.")

    print("\nNEXT: fill keep_alive_amount from your carrier_rules, then")
    print("      mini_refill_viable = YES where min_amount <= keep_alive_amount.")
    print("      Attach the CSV to your Fable session.")


if __name__ == "__main__":
    main()