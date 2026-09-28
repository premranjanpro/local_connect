import { useState, useEffect } from 'react';
import { useTaskHub, useTelemetryHub } from '../hooks/useSignalR.js';

// ── Mock data for demo when API is offline ────────────────────────────────────
const MOCK_STATS = [
  { label: 'Online Drivers', value: 14, delta: '+3', up: true, icon: '🛵', color: '#6c63ff', bg: 'rgba(108,99,255,0.12)' },
  { label: 'Active Tasks', value: 8, delta: '+2', up: true, icon: '📦', color: '#3ecfcf', bg: 'rgba(62,207,207,0.12)' },
  { label: 'Today\'s Orders', value: 127, delta: '+18%', up: true, icon: '🛒', color: '#00e676', bg: 'rgba(0,230,118,0.12)' },
  { label: 'Subscriptions', value: 312, delta: '+5', up: true, icon: '🥛', color: '#ff9f43', bg: 'rgba(255,159,67,0.12)' },
  { label: 'Khata Balance Due', value: '₹48,200', delta: null, up: null, icon: '📒', color: '#ffd93d', bg: 'rgba(255,217,61,0.12)' },
  { label: 'Avg ETA (min)', value: 11, delta: '-2', up: true, icon: '⏱', color: '#ff6b6b', bg: 'rgba(255,107,107,0.12)' },
];

const MOCK_TASKS = [
  { id: 'T-8821', type: 'GroceryDelivery', customer: 'Priya Sharma', driver: 'Ravi Kumar', status: 'EN_ROUTE_PICKUP', pickup: 'Gupta Kirana', drop: 'Sector 4, Vaishali', fare: '₹65', eta: '4 min' },
  { id: 'T-8820', type: 'MobilityRide', customer: 'Amit Singh', driver: 'Deepak Yadav', status: 'AT_PICKUP', pickup: 'Civil Lines', drop: 'Mansarovar', fare: '₹120', eta: '—' },
  { id: 'T-8819', type: 'GroceryDelivery', customer: 'Sunita Devi', driver: 'Mohan Das', status: 'PICKED_UP', pickup: 'Sharma Dairy', drop: 'Malviya Nagar', fare: '₹130', eta: '7 min' },
  { id: 'T-8818', type: 'CourierP2P', customer: 'Raj Verma', driver: 'Aakash Gupta', status: 'AT_DROP', pickup: 'C-Scheme', drop: 'Pink City', fare: '₹90', eta: '—' },
  { id: 'T-8817', type: 'SchoolTransit', customer: 'Sharma Family', driver: 'Suresh Patel', status: 'EN_ROUTE_PICKUP', pickup: 'Sector 7', drop: 'Delhi Public School', fare: '₹200', eta: '12 min' },
];

const MOCK_AUDIT = [
  { time: '10:44:02', actor: 'Ravi Kumar', role: 'Driver', action: 'TaskAccepted', entity: 'T-8821', ip: '192.168.1.45' },
  { time: '10:43:55', actor: 'Priya Sharma', role: 'Customer', action: 'OrderPlaced', entity: 'T-8821', ip: '192.168.1.12' },
  { time: '10:43:30', actor: 'System', role: 'Worker', action: 'SubscriptionDispatched', entity: 'SUB-221', ip: 'localhost' },
  { time: '10:42:10', actor: 'Deepak Yadav', role: 'Driver', action: 'OTPVerified_Pickup', entity: 'T-8820', ip: '192.168.1.78' },
  { time: '10:40:55', actor: 'Sunita Devi', role: 'Customer', action: 'SubscriptionPaused', entity: 'SUB-118', ip: '192.168.1.34' },
];

const STATUS_BADGE = {
  EN_ROUTE_PICKUP: 'badge-purple',
  AT_PICKUP: 'badge-orange',
  PICKED_UP: 'badge-cyan',
  AT_DROP: 'badge-yellow',
  COMPLETED: 'badge-green',
  BROADCASTING: 'badge-red',
};

export default function Overview() {
  const [liveEvents, setLiveEvents] = useState([]);
  const [driverCount, setDriverCount] = useState(14);
  const [activeTaskCount, setActiveTaskCount] = useState(8);

  // Real-time SignalR connections
  const taskConnected = useTaskHub((event) => {
    setLiveEvents(prev => [
      { ...event, receivedAt: new Date().toLocaleTimeString() },
      ...prev.slice(0, 9),
    ]);
    if (event.type === 'TaskStatusChanged') {
      setActiveTaskCount(c => c + 1);
    }
  });

  const telemetryConnected = useTelemetryHub((loc) => {
    // Just track that we're getting real-time GPS pings
  });

  return (
    <div>
      {/* ── Live Status Banner ───────────────────────────────────────────── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        background: 'var(--bg-card)', border: '1px solid var(--border-light)',
        borderRadius: 'var(--radius)', padding: '12px 20px', marginBottom: 20,
      }}>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <div style={{
            width: 8, height: 8, background: taskConnected ? 'var(--green)' : 'var(--red)',
            borderRadius: '50%', animation: taskConnected ? 'pulse 1.5s infinite' : 'none'
          }} />
          <span style={{ fontSize: 12, color: taskConnected ? 'var(--green)' : 'var(--red)' }}>
            Task Hub {taskConnected ? 'Connected' : 'Offline'}
          </span>
        </div>
        <span style={{ color: 'var(--border-light)' }}>|</span>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <div style={{
            width: 8, height: 8, background: telemetryConnected ? 'var(--cyan)' : 'var(--red)',
            borderRadius: '50%'
          }} />
          <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>
            Telemetry Hub {telemetryConnected ? 'Live' : 'Offline'}
          </span>
        </div>
        <span style={{ marginLeft: 'auto', fontSize: 11, color: 'var(--text-faint)' }}>
          Last updated: {new Date().toLocaleTimeString()}
        </span>
      </div>

      {/* ── Stat Cards ────────────────────────────────────────────────────── */}
      <div className="stat-grid">
        {MOCK_STATS.map((s, i) => (
          <div key={i} className="stat-card" style={{ '--accent': s.color, '--accent-bg': s.bg }}>
            <div className="stat-icon">{s.icon}</div>
            <div>
              <div className="stat-value">{s.value}</div>
              <div className="stat-label">{s.label}</div>
              {s.delta && (
                <div className={`stat-delta ${s.up ? 'up' : 'down'}`}>
                  {s.up ? '↑' : '↓'} {s.delta} today
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      <div className="grid-2">
        {/* ── Active Tasks Table ──────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Active Tasks</div>
              <div className="card-sub">Live in-flight deliveries & rides</div>
            </div>
            <span className="badge badge-purple">{MOCK_TASKS.length} live</span>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Task</th>
                <th>Customer</th>
                <th>Driver</th>
                <th>Status</th>
                <th>Fare</th>
                <th>ETA</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_TASKS.map(t => (
                <tr key={t.id}>
                  <td>
                    <div style={{ fontWeight: 600, fontSize: 12 }}>{t.id}</div>
                    <div style={{ fontSize: 10, color: 'var(--text-dim)' }}>{t.type}</div>
                  </td>
                  <td style={{ fontSize: 12 }}>{t.customer}</td>
                  <td style={{ fontSize: 12 }}>{t.driver}</td>
                  <td>
                    <span className={`badge ${STATUS_BADGE[t.status] || 'badge-purple'}`}>
                      {t.status.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td style={{ fontWeight: 600, color: 'var(--green)' }}>{t.fare}</td>
                  <td style={{ color: 'var(--cyan)', fontSize: 12 }}>{t.eta}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* ── Live Audit Feed ─────────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Live Audit Feed</div>
              <div className="card-sub">Real-time state transitions</div>
            </div>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <div className="online-dot" />
              <span style={{ fontSize: 11, color: 'var(--green)' }}>Live</span>
            </div>
          </div>

          {/* Real-time SignalR events */}
          {liveEvents.length > 0 && (
            <div style={{ marginBottom: 12 }}>
              {liveEvents.slice(0, 3).map((e, i) => (
                <div key={i} className="audit-row-new" style={{
                  background: 'rgba(108,99,255,0.08)', border: '1px solid rgba(108,99,255,0.2)',
                  borderRadius: 8, padding: '8px 12px', marginBottom: 6,
                  fontSize: 11,
                }}>
                  <span style={{ color: 'var(--purple)', fontWeight: 600 }}>[LIVE] </span>
                  <span style={{ color: 'var(--text-dim)' }}>{e.receivedAt} · </span>
                  <span>{e.type}</span>
                </div>
              ))}
            </div>
          )}

          <table className="data-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Entity</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_AUDIT.map((a, i) => (
                <tr key={i}>
                  <td style={{ color: 'var(--text-dim)', fontSize: 11 }}>{a.time}</td>
                  <td>
                    <div style={{ fontSize: 12, fontWeight: 500 }}>{a.actor}</div>
                    <div style={{ fontSize: 10, color: 'var(--text-faint)' }}>{a.role}</div>
                  </td>
                  <td>
                    <span className="badge badge-purple">{a.action}</span>
                  </td>
                  <td style={{ fontSize: 11, color: 'var(--cyan)' }}>{a.entity}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
