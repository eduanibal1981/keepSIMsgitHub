// Worker runtime source and PM2 names live in the authoritative backend worktree.
// Deploy worker-fleet.pm2.config.cjs with that source using the scoped SSH/SCP
// procedure; do not start the former queue-* aliases alongside existing workers.
// Supplier reconciliation retains its separate financial-cutover config.
module.exports = require('../backend-sync-wt/worker-fleet.pm2.config.cjs');
