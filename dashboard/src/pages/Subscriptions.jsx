import { useState, useEffect } from 'react';
import { runDailyDispatch, fetchAllSubscriptions } from '../api.js';

const MOCK_SUBS = [
  { id: 'S-001', customerName: 'Priya Sharma', itemName: 'Pure Farm Cow Milk', quantity: 1, unit: 'litre', pricePerDelivery: 65, deliverySlot: '06:00 - 07:30 AM', businessName: 'Sharma Dairy', isActive: true, isPaused: false, daysOfWeek: 'Everyday' },
  { id: 'S-002', customerName: 'Sunita Devi', itemName: 'Fresh Buffalo Milk', quantity: 2, unit: 'litre', pricePerDelivery: 144, deliverySlot: '06:00 - 07:30 AM', businessName: 'Gupta Dairy', isActive: true, isPaused: true, daysOfWeek: 'Everyday' },
  { id: 'S-003', customerName: 'Amit Singh', itemName: 'Brown Bread + Eggs Basket', quantity: 1, unit: 'basket', pricePerDelivery: 85, deliverySlot: '06:30 - 07:30 AM', businessName: 'Morning Mart', isActive: true, isPaused: false, daysOfWeek: 'Weekdays' },
  { id: 'S-004', customerName: 'Raj Verma', itemName: 'Homestyle Veg Thali', quantity: 1, unit: 'tiffin', pricePerDelivery: 110, deliverySlot: '12:30 - 01:30 PM', businessName: 'Devi Tiffin Service', isActive: true, isPaused: false, daysOfWeek: 'Mon,Wed,Fri' },
  { id: 'S-005', customerName: 'Reena Gupta', itemName: '20L RO Water Can', quantity: 1, unit: 'can', pricePerDelivery: 45, deliverySlot: '08:00 - 10:00 AM', businessName: 'Pure Drops', isActive: true, isPaused: false, daysOfWeek: 'Everyday' },
  { id: 'S-006', customerName: 'Deepak Sharma', itemName: 'Pure Farm Cow Milk', quantity: 1.5, unit: 'litre', pricePerDelivery: 98, deliverySlot: '06:00 - 07:30 AM', businessName: 'Sharma Dairy', isActive: false, isPaused: false, daysOfWeek: 'Everyday' },
];

const DISPATCH_LOG = [
  { date: '2026-09-27', dispatched: 287, paused: 25, skipped: 0, status: 'Done', ranAt: '06:00 AM' },
  { date: '2026-09-26', dispatched: 285, paused: 27, skipped: 0, status: 'Done', ranAt: '06:00 AM' },
  { date: '2026-09-25', dispatched: 290, paused: 22, skipped: 3, status: 'Done', ranAt: '06:00 AM' },
];

export default function Subscriptions() {
  const [subs, setSubs] = useState(MOCK_SUBS);
  const [dispatchLog, setDispatchLog] = useState(DISPATCH_LOG);
  const [running, setRunning] = useState(false);
  const [filter, setFilter] = useState('ALL');
  const [dispatchResult, setDispatchResult] = useState(null);

  useEffect(() => {
    fetchAllSubscriptions()
      .then(data => { if (data?.length) setSubs(data); })
      .catch(() => {});
  }, []);

  const filtered = subs.filter(s => {
    if (filter === 'ACTIVE') return s.isActive && !s.isPaused;
    if (filter === 'PAUSED') return s.isPaused;
    if (filter === 'INACTIVE') return !s.isActive;
    return true;
  });

  const activeCount = subs.filter(s => s.isActive && !s.isPaused).length;
  const pausedCount = subs.filter(s => s.isPaused).length;
  const totalRevenue = subs.filter(s => s.isActive && !s.isPaused)
    .reduce((sum, s) => sum + s.pricePerDelivery, 0);

  async function handleRunDispatch() {
    setRunning(true);
    setDispatchResult(null);
    try {
      const result = await runDailyDispatch();
      setDispatchResult({ success: true, ...result });
      const today = new Date().toISOString().split('T')[0];
      setDispatchLog(prev => [
        { date: today, dispatched: result.dispatchedCount, paused: result.pausedCount, skipped: 0, status: 'Done', ranAt: new Date().toLocaleTimeString() },
        ...prev
      ]);
    } catch (e) {
      // Demo mode
      const demoResult = { dispatchedCount: 287, pausedCount: 25, totalSubscriptions: 312 };
      setDispatchResult({ success: true, ...demoResult, demo: true });
    } finally {
      setRunning(false);
    }
  }

  return (
    <div>
      {/* ── Stats ────────────────────────────────────────────────────────── */}
      <div className="stat-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)', marginBottom: 20 }}>
        <div className="stat-card" style={{ '--accent': '#00e676', '--accent-bg': 'rgba(0,230,118,0.12)' }}>
          <div className="stat-icon">✅</div>
          <div>
            <div className="stat-value">{activeCount}</div>
            <div className="stat-label">Active Subscriptions</div>
          </div>
        </div>
        <div className="stat-card" style={{ '--accent': '#ffd93d', '--accent-bg': 'rgba(255,217,61,0.12)' }}>
          <div className="stat-icon">⏸️</div>
          <div>
            <div className="stat-value">{pausedCount}</div>
            <div className="stat-label">Vacation Paused</div>
          </div>
        </div>
        <div className="stat-card" style={{ '--accent': '#3ecfcf', '--accent-bg': 'rgba(62,207,207,0.12)' }}>
          <div className="stat-icon">💰</div>
          <div>
            <div className="stat-value">₹{totalRevenue}</div>
            <div className="stat-label">Daily Revenue</div>
          </div>
        </div>
        <div className="stat-card" style={{ '--accent': '#6c63ff', '--accent-bg': 'rgba(108,99,255,0.12)' }}>
          <div className="stat-icon">🥛</div>
          <div>
            <div className="stat-value">{subs.length}</div>
            <div className="stat-label">Total Subscriptions</div>
          </div>
        </div>
      </div>

      <div className="grid-2">
        {/* ── Subscription Table ──────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">All Subscriptions</div>
              <div className="card-sub">{filtered.length} shown</div>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              {['ALL', 'ACTIVE', 'PAUSED', 'INACTIVE'].map(f => (
                <button
                  key={f}
                  className={`btn ${filter === f ? 'btn-primary' : 'btn-ghost'}`}
                  style={{ fontSize: 10 }}
                  onClick={() => setFilter(f)}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          <table className="data-table">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Item</th>
                <th>Qty</th>
                <th>Slot</th>
                <th>Shop</th>
                <th>Price</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(s => (
                <tr key={s.id}>
                  <td style={{ fontSize: 12, fontWeight: 500 }}>{s.customerName}</td>
                  <td style={{ fontSize: 11 }}>{s.itemName}</td>
                  <td style={{ fontSize: 11 }}>{s.quantity} {s.unit}</td>
                  <td style={{ fontSize: 10, color: 'var(--cyan)' }}>{s.deliverySlot}</td>
                  <td style={{ fontSize: 11, color: 'var(--text-dim)' }}>{s.businessName}</td>
                  <td style={{ fontWeight: 600, color: 'var(--green)' }}>₹{s.pricePerDelivery}</td>
                  <td>
                    {!s.isActive
                      ? <span className="badge badge-red">Inactive</span>
                      : s.isPaused
                        ? <span className="badge badge-yellow">⏸ Paused</span>
                        : <span className="badge badge-green">✓ Active</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* ── Dispatch Control Panel ─────────────────────────────────────── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="card">
            <div className="card-header">
              <div>
                <div className="card-title">Morning Auto-Dispatch</div>
                <div className="card-sub">Runs automatically at 06:00 AM IST daily</div>
              </div>
            </div>

            <div style={{
              background: 'rgba(0,230,118,0.05)',
              border: '1px solid rgba(0,230,118,0.2)',
              borderRadius: 12, padding: 14, marginBottom: 16,
            }}>
              <div style={{ fontSize: 11, color: 'var(--green)', fontWeight: 600, marginBottom: 4 }}>⏰ Next Auto-Dispatch</div>
              <div style={{ fontSize: 20, fontWeight: 800 }}>Tomorrow 06:00 AM IST</div>
              <div style={{ fontSize: 11, color: 'var(--text-dim)', marginTop: 4 }}>
                Worker: SubscriptionDispatchWorker · UTC 00:30
              </div>
            </div>

            <button
              className="btn btn-primary"
              style={{ width: '100%', justifyContent: 'center', padding: '12px 0', marginBottom: 12 }}
              onClick={handleRunDispatch}
              disabled={running}
            >
              {running ? '⏳ Dispatching...' : '▶ Run Dispatch Now (Manual)'}
            </button>

            {dispatchResult && (
              <div className={`fade-in`} style={{
                background: dispatchResult.success ? 'rgba(0,230,118,0.08)' : 'rgba(255,107,107,0.08)',
                border: `1px solid ${dispatchResult.success ? 'rgba(0,230,118,0.25)' : 'rgba(255,107,107,0.25)'}`,
                borderRadius: 10, padding: 12, fontSize: 12,
              }}>
                {dispatchResult.success ? (
                  <>
                    <div style={{ color: 'var(--green)', fontWeight: 700, marginBottom: 6 }}>✅ Dispatch Complete!</div>
                    <div>📦 Dispatched: <strong>{dispatchResult.dispatchedCount}</strong></div>
                    <div>⏸ Paused (Vacation): <strong>{dispatchResult.pausedCount}</strong></div>
                    <div>📋 Total processed: <strong>{dispatchResult.totalSubscriptions}</strong></div>
                    {dispatchResult.demo && <div style={{ color: 'var(--text-faint)', fontSize: 10, marginTop: 4 }}>Demo mode — API offline</div>}
                  </>
                ) : (
                  <div style={{ color: 'var(--red)' }}>❌ Dispatch failed. Check API connection.</div>
                )}
              </div>
            )}
          </div>

          {/* Dispatch History */}
          <div className="card">
            <div className="card-header">
              <div className="card-title">Dispatch History</div>
            </div>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Dispatched</th>
                  <th>Paused</th>
                  <th>Ran At</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {dispatchLog.map((d, i) => (
                  <tr key={i}>
                    <td style={{ fontSize: 12 }}>{d.date}</td>
                    <td style={{ color: 'var(--green)', fontWeight: 600 }}>{d.dispatched}</td>
                    <td style={{ color: 'var(--yellow)' }}>{d.paused}</td>
                    <td style={{ fontSize: 11, color: 'var(--text-dim)' }}>{d.ranAt}</td>
                    <td><span className="badge badge-green">{d.status}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
