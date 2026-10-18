// Resolve historical SQL by its original filename without restoring a queue.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
module.exports = function migrationSource(filename) {
  if (path.basename(filename) !== filename || filename.includes('\\')) throw Error('Expected a migration filename');
  const active = path.join(root, 'supabase/migrations', filename);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/reviews/migration-cleanup-20261016/manifest.json'), 'utf8'));
  const entry = manifest.migrations.find(row => row.file === filename);
  if (fs.existsSync(active)) {
    const bytes=fs.readFileSync(active);
    if (entry?.action==='archived' && crypto.createHash('sha256').update(bytes).digest('hex')!==entry.sha256) throw Error('Restored archive differs: '+filename);
    return bytes.toString('utf8').replace(/^\uFEFF/, '');
  }
  if (!entry || entry.action !== 'archived') throw Error('Migration source missing: ' + filename);
  const sourcePath = path.resolve(root, entry.current_path);
  if (!sourcePath.startsWith(root + path.sep)) throw Error('Invalid archive path');
  const bytes = fs.readFileSync(sourcePath);
  if (crypto.createHash('sha256').update(bytes).digest('hex') !== entry.sha256) throw Error('Archived source differs: ' + filename);
  return bytes.subarray(0, 2).equals(Buffer.from([255, 254])) ? bytes.subarray(2).toString('utf16le') : bytes.toString('utf8').replace(/^\uFEFF/, '');
};
