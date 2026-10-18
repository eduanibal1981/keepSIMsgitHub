// Public health is an aggregate only. Component/version/backlog details are
// restricted to service and assert_admin()-guarded SQL APIs.
export function createHealthHandler(createClient: any, env: (key: string) => string | undefined) {
  const headers = { 'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Content-Type': 'application/json',
    'Cache-Control': 'no-store' };
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers });
    if (req.method !== 'GET') return Response.json({ status: 'method_not_allowed' }, { status: 405, headers });
    try {
      const url = env('SUPABASE_URL');
      const key = env('SUPABASE_SERVICE_ROLE_KEY');
      if (!url || !key) throw Error('configuration');
      const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false },
        global: { fetch: (url: any, options: any) => fetch(url, { ...options, signal: AbortSignal.timeout(10000) }) } });
      const { data, error } = await db.rpc('get_worker_fleet_health');
      if (error || !data || data.manifest_version !== 1 || !['healthy', 'degraded'].includes(data.status) ||
          !Number.isInteger(data.healthy) || !Number.isInteger(data.unhealthy) || data.healthy < 0 || data.unhealthy < 0 ||
          data.healthy + data.unhealthy < 9 || (data.status === 'healthy' && data.unhealthy !== 0) ||
          (data.status === 'degraded' && data.unhealthy === 0)) throw Error('contract');
      return Response.json({ status: data.status, database: 'online',
        fleet: { healthy: data.healthy, unhealthy: data.unhealthy },
        timestamp: new Date().toISOString() }, { status: data.status === 'healthy' ? 200 : 503, headers });
    } catch {
      return Response.json({ status: 'unhealthy', database: 'unverified', code: 'health_unavailable',
        timestamp: new Date().toISOString() }, { status: 503, headers });
    }
  };
}
