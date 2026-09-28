// Shared API client for the admin dashboard
// Proxied via Vite to http://localhost:5000

const BASE = '/api/v1';

// Admin stores a session token in localStorage (set manually for now)
function getToken() {
  return localStorage.getItem('admin_token') || '';
}

function headers() {
  const tok = getToken();
  const h = { 'Content-Type': 'application/json' };
  if (tok) h['Authorization'] = `Bearer ${tok}`;
  return h;
}

async function get(path) {
  const res = await fetch(BASE + path, { headers: headers() });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function post(path, body) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

// ── Stats & Overview ─────────────────────────────────────────────────────────

export async function fetchDashboardStats() {
  // Returns overview stats from audit logs aggregation
  try {
    const [drivers, tasks, audits] = await Promise.all([
      get('/drivers'),
      get('/tasks?status=active&limit=5'),
      get('/audit/recent?limit=5'),
    ]);
    return { drivers, tasks, audits };
  } catch {
    return { drivers: [], tasks: [], audits: [] };
  }
}

// ── Drivers ──────────────────────────────────────────────────────────────────

export const fetchDrivers = () => get('/drivers');
export const fetchDriverLocation = (driverId) =>
  get(`/drivers/${driverId}/location`);

// ── Tasks ─────────────────────────────────────────────────────────────────────

export const fetchActiveTasks = () => get('/tasks?status=active&limit=50');
export const fetchAllTasks = (page = 0, size = 30) =>
  get(`/tasks?page=${page}&size=${size}`);
export const fetchTaskById = (id) => get(`/tasks/${id}`);

// ── Audit Logs ────────────────────────────────────────────────────────────────

export const fetchAuditLogs = (page = 0, size = 30, userId = '') => {
  const qs = userId ? `?page=${page}&size=${size}&userId=${userId}` : `?page=${page}&size=${size}`;
  return get(`/audit/logs${qs}`);
};

// ── Communication Logs ────────────────────────────────────────────────────────

export const fetchCommLogs = (page = 0, size = 30) =>
  get(`/audit/communications?page=${page}&size=${size}`);

// ── Subscriptions ─────────────────────────────────────────────────────────────

export const fetchAllSubscriptions = (businessId) =>
  businessId
    ? get(`/subscriptions/merchant/${businessId}`)
    : get('/subscriptions/my');

export const runDailyDispatch = (targetDate) =>
  post(`/subscriptions/run-daily-dispatch${targetDate ? `?targetDate=${targetDate}` : ''}`, {});

// ── Businesses ───────────────────────────────────────────────────────────────

export const fetchBusinesses = () => get('/businesses');

// ── Khata ─────────────────────────────────────────────────────────────────────

export const fetchKhataLedger = (businessId, customerId) =>
  get(`/khata/ledger?businessId=${businessId}&customerId=${customerId}`);
