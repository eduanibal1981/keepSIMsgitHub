import json, time
ps = json.load(open('/tmp/pm2.json'))
for p in ps:
    if 'refill' in p['name']:
        e = p['pm2_env']
        print(e['name'], e['status'], 'restarts:', e['restart_time'], 'up_s:', round(time.time() - e['pm_uptime'] / 1000))
