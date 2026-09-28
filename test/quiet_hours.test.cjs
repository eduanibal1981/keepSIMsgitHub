const { test } = require('node:test');
const assert = require('node:assert/strict');

test('quiet hours release in Muscat local time', async () => {
  const { quietHoursReleaseTime } = await import('../supabase/functions/process-alert-outbox/quiet_hours.ts');
  const release = quietHoursReleaseTime(new Date('2026-09-27T20:00:00Z'),
    'Asia/Muscat', '22:00:00', '07:00:00');
  assert.equal(release.toISOString(), '2026-09-28T03:00:00.000Z');
});

test('spring DST jump releases at the next real local end', async () => {
  const { quietHoursReleaseTime } = await import('../supabase/functions/process-alert-outbox/quiet_hours.ts');
  const release = quietHoursReleaseTime(new Date('2026-03-08T06:30:00Z'),
    'America/New_York', '22:00:00', '03:00:00');
  assert.equal(release.toISOString(), '2026-03-08T07:00:00.000Z');
});

test('autumn repeated hour stays quiet until the second local hour ends', async () => {
  const { quietHoursReleaseTime } = await import('../supabase/functions/process-alert-outbox/quiet_hours.ts');
  const release = quietHoursReleaseTime(new Date('2026-11-01T05:30:00Z'),
    'America/New_York', '22:00:00', '02:00:00');
  assert.equal(release.toISOString(), '2026-11-01T07:00:00.000Z');
});
