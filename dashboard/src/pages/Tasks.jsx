import { useState, useEffect } from 'react';
import { fetchActiveTasks } from '../api.js';

const MOCK_TASKS = [
  { id: 'T-8821', type: 'GroceryDelivery', customer: 'Priya Sharma', customerPhone: '98XX XXXX 12', driver: 'Ravi Kumar', driverPhone: '97XX XXXX 45', status: 'EN_ROUTE_PICKUP', pickup: 'Gupta Kirana, Vaishali Nagar', drop: 'Sector 4, Vaishali', fare: 65, paymentMode: 'Khata', distance: '2.1 km', duration: '4 min', createdAt: '10:43' },
  { id: 'T-8820', type: 'MobilityRide', customer: 'Amit Singh', customerPhone: '99XX XXXX 78', driver: 'Deepak Yadav', driverPhone: '96XX XXXX 23', status: 'AT_PICKUP', pickup: 'Civil Lines', drop: 'Mansarovar Metro', fare: 120, paymentMode: 'Cash', distance: '7.8 km', duration: '—', createdAt: '10:40' },
  { id: 'T-8819', type: 'GroceryDelivery', customer: 'Sunita Devi', customerPhone: '98XX XXXX 90', driver: 'Mohan Das', driverPhone: '95XX XXXX 67', status: 'PICKED_UP', pickup: 'Sharma Dairy', drop: 'Malviya Nagar', fare: 130, paymentMode: 'UPI', distance: '4.3 km', duration: '7 min', createdAt: '10:35' },
  { id: 'T-8818', type: 'CourierP2P', customer: 'Raj Verma', customerPhone: '97XX XXXX 34', driver: 'Aakash Gupta', driverPhone: '94XX XXXX 56', status: 'AT_DROP', pickup: 'C-Scheme', drop: 'Pink City, Johari Bazar', fare: 90, paymentMode: 'Cash', distance: '5.5 km', duration: '—', createdAt: '10:20' },
  { id: 'T-8817', type: 'SchoolTransit', customer: 'Sharma Family', customerPhone: '96XX XXXX 11', driver: 'Suresh Patel', driverPhone: '93XX XXXX 22', status: 'EN_ROUTE_PICKUP', pickup: 'Sector 7, Jaipur', drop: 'DPS School', fare: 200, paymentMode: 'Subscription', distance: '6.1 km', duration: '12 min', createdAt: '10:15' },
];

const STATUS_BADGE = {
  EN_ROUTE_PICKUP: ['badge-purple', '🟣 En Route Pickup'],
  AT_PICKUP: ['badge-orange', '🟠 At Pickup'],
  PICKED_UP: ['badge-cyan', '🔵 Picked Up'],
  AT_DROP: ['badge-yellow', '🟡 At Drop'],
  COMPLETED: ['badge-green', '✅ Completed'],
  BROADCASTING: ['badge-red', '📡 Broadcasting'],
};

const TYPE_ICON = {
  GroceryDelivery: '🛒',
  MobilityRide: '🚗',
  CourierP2P: '📦',
  SchoolTransit: '🏫',
};

export default function Tasks() {
  const [tasks, setTasks] = useState(MOCK_TASKS);
  const [selected, setSelected] = useState(null);
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setLoading(true);
    fetchActiveTasks()
      .then(data => { if (data?.length) setTasks(data); })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const filtered = statusFilter === 'ALL' ? tasks : tasks.filter(t => t.status === statusFilter);

  return (
    <div>
      {/* ── Filters ─────────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {['ALL', 'EN_ROUTE_PICKUP', 'AT_PICKUP', 'PICKED_UP', 'AT_DROP', 'BROADCASTING'].map(s => (
          <button
            key={s}
            className={`btn ${statusFilter === s ? 'btn-primary' : 'btn-ghost'}`}
            style={{ fontSize: 11 }}
            onClick={() => setStatusFilter(s)}
          >
            {s.replace(/_/g, ' ')}
            {s === 'ALL' && ` (${tasks.length})`}
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: selected ? '1fr 380px' : '1fr', gap: 20 }}>
        {/* ── Task Table ─────────────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Active Tasks</div>
              <div className="card-sub">{filtered.length} tasks in progress</div>
            </div>
            <span className="badge badge-green" style={{ animation: 'pulse 1.5s infinite' }}>● Live</span>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Task ID</th>
                <th>Type</th>
                <th>Customer</th>
                <th>Driver</th>
                <th>Route</th>
                <th>Status</th>
                <th>Fare</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(t => {
                const [badgeClass, statusLabel] = STATUS_BADGE[t.status] || ['badge-purple', t.status];
                return (
                  <tr
                    key={t.id}
                    onClick={() => setSelected(selected?.id === t.id ? null : t)}
                    style={{ cursor: 'pointer', background: selected?.id === t.id ? 'rgba(108,99,255,0.05)' : '' }}
                  >
                    <td>
                      <span style={{ fontWeight: 700, color: 'var(--purple)', fontSize: 12 }}>{t.id}</span>
                    </td>
                    <td>
                      <span style={{ fontSize: 15 }}>{TYPE_ICON[t.type] || '📦'}</span>
                      <span style={{ fontSize: 11, color: 'var(--text-dim)', marginLeft: 5 }}>{t.type}</span>
                    </td>
                    <td style={{ fontSize: 12 }}>{t.customer}</td>
                    <td style={{ fontSize: 12 }}>{t.driver}</td>
                    <td style={{ fontSize: 11 }}>
                      <div style={{ color: 'var(--text-dim)' }}>📍 {t.pickup?.substring(0, 20)}…</div>
                      <div style={{ color: 'var(--red)', marginTop: 2 }}>🏁 {t.drop?.substring(0, 20)}…</div>
                    </td>
                    <td>
                      <span className={`badge ${badgeClass}`}>{statusLabel}</span>
                    </td>
                    <td style={{ fontWeight: 700, color: 'var(--green)' }}>₹{t.fare}</td>
                    <td style={{ color: 'var(--text-dim)', fontSize: 11 }}>{t.createdAt}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* ── Task Detail Panel ──────────────────────────────────────────── */}
        {selected && (
          <div className="card fade-in" style={{ alignSelf: 'start' }}>
            <div className="card-header">
              <div>
                <div className="card-title">{selected.id}</div>
                <div className="card-sub">{selected.type}</div>
              </div>
              <button className="btn btn-ghost" style={{ fontSize: 11 }} onClick={() => setSelected(null)}>✕</button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {[
                { label: 'Customer', value: selected.customer, sub: selected.customerPhone },
                { label: 'Driver', value: selected.driver, sub: selected.driverPhone },
                { label: 'Pickup', value: selected.pickup },
                { label: 'Drop', value: selected.drop },
                { label: 'Distance', value: selected.distance },
                { label: 'ETA', value: selected.duration },
                { label: 'Fare', value: `₹${selected.fare}`, highlight: true },
                { label: 'Payment', value: selected.paymentMode },
              ].map((row, i) => (
                <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <span style={{ fontSize: 11, color: 'var(--text-faint)', fontWeight: 500 }}>{row.label}</span>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{
                      fontSize: 12, fontWeight: 600,
                      color: row.highlight ? 'var(--green)' : 'var(--text)',
                    }}>{row.value}</div>
                    {row.sub && <div style={{ fontSize: 10, color: 'var(--text-faint)', marginTop: 1 }}>{row.sub}</div>}
                  </div>
                </div>
              ))}

              <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ fontSize: 11, color: 'var(--text-faint)', fontWeight: 600, marginBottom: 4 }}>Status</div>
                {['BROADCASTING', 'EN_ROUTE_PICKUP', 'AT_PICKUP', 'PICKED_UP', 'AT_DROP', 'COMPLETED'].map(s => {
                  const active = s === selected.status;
                  const done = ['BROADCASTING', 'EN_ROUTE_PICKUP', 'AT_PICKUP', 'PICKED_UP', 'AT_DROP', 'COMPLETED']
                    .indexOf(s) < ['BROADCASTING', 'EN_ROUTE_PICKUP', 'AT_PICKUP', 'PICKED_UP', 'AT_DROP', 'COMPLETED']
                    .indexOf(selected.status);
                  return (
                    <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{
                        width: 10, height: 10, borderRadius: '50%', flexShrink: 0,
                        background: active ? 'var(--green)' : done ? 'var(--purple)' : 'var(--border-light)',
                        boxShadow: active ? '0 0 8px var(--green)' : 'none',
                      }} />
                      <span style={{ fontSize: 11, color: active ? 'var(--green)' : done ? 'var(--purple)' : 'var(--text-faint)' }}>
                        {s.replace(/_/g, ' ')}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
