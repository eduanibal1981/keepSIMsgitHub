const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = require('../tools/migration-source.cjs');
test('historical dependency resolves to immutable archived bytes', () => {
  const manifest = require('../docs/reviews/migration-cleanup-20261016/manifest.json');
  const entry = manifest.migrations.find(e=>e.file==='20260917182910_calling_media_sessions.sql');
  assert.equal(source(entry.file),fs.readFileSync(path.join(__dirname,'..',entry.current_path),'utf8'));
});
test('pending source and absent/path-like filenames are handled deliberately', () => {
  assert.match(source('20261018070000_scheduled_pricing_boundary.sql'),/BEGIN;/);
  for (const name of ['../config.toml','..\\config.toml','missing.sql']) assert.throws(()=>source(name));
});
