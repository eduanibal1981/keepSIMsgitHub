const fs = require('fs');
const path = require('path');

const baseDir = path.join('c:', 'Users', 'abdal', 'Work', 'KeepSIMs', 'keep_sims', 'providersComparison_Tests');
const entries = fs.readdirSync(baseDir, { withFileTypes: true });

const results = [];

entries.forEach(entry => {
  if (entry.isDirectory()) {
    const fullPath = path.join(baseDir, entry.name);
    const files = fs.readdirSync(fullPath);
    results.push({
      folder: entry.name,
      fileCount: files.length,
      files: files
    });
  }
});

console.log('=== FOLDER ANALYSIS IN providersComparison_Tests ===\n');
const populated = results.filter(r => r.fileCount > 0);
const empty = results.filter(r => r.fileCount === 0);

console.log(`Populated folders (${populated.length}):`);
populated.forEach(p => console.log(`  - ${p.folder} (${p.fileCount} files): ${p.files.join(', ')}`));

console.log(`\nEmpty folders (${empty.length}):`);
empty.forEach(e => console.log(`  - ${e.folder}`));
