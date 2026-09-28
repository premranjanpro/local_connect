import { useState, useEffect, useRef } from 'react';
import { useTaskHub } from '../hooks/useSignalR.js';
import { fetchAuditLogs } from '../api.js';

const MOCK_LOGS = [
  { id: 'AL-001', createdAt: '2026-09-27 10:44:02', actorName: 'Ravi Kumar', actorRole: 'Driver', action: 'TaskAccepted', entityType: 'Task', entityId: 'T-8821', ipAddress: '192.168.1.45', oldState: 'BROADCASTING', newState: 'EN_ROUTE_PICKUP' },
  { id: 'AL-002', createdAt: '2026-09-27 10:43:55', actorName: 'Priya Sharma', actorRole: 'Customer', action: 'OrderPlaced', entityType: 'Task', entityId: 'T-8821', ipAddress: '192.168.1.12', oldState: null, newState: 'CREATED' },
  { id: 'AL-003', createdAt: '2026-09-27 10:43:30', actorName: 'System', actorRole: 'Worker', action: 'SubscriptionDispatched', entityType: 'Subscription', entityId: 'SUB-221', ipAddress: '127.0.0.1', oldState: 'PENDING', newState: 'SCHEDULED' },
  { id: 'AL-004', createdAt: '2026-09-27 10:42:10', actorName: 'Deepak Yadav', actorRole: 'Driver', action: 'OTPVerified_Pickup', entityType: 'Task', entityId: 'T-8820', ipAddress: '192.168.1.78', oldState: 'AT_PICKUP', newState: 'PICKED_UP' },
  { id: 'AL-005', createdAt: '2026-09-27 10:40:55', actorName: 'Sunita Devi', actorRole: 'Customer', action: 'SubscriptionPaused', entityType: 'Subscription', entityId: 'SUB-118', ipAddress: '192.168.1.34', oldState: 'ACTIVE', newState: 'PAUSED' },
  { id: 'AL-006', createdAt: '2026-09-27 10:38:20', actorName: 'Admin', actorRole: 'Admin', action: 'KhataApproved', entityType: 'KhataCustomerSetting', entityId: 'K-041', ipAddress: '127.0.0.1', oldState: null, newState: 'ENABLED' },
  { id: 'AL-007', createdAt: '2026-09-27 10:35:00', actorName: 'Mohan Das', actorRole: 'Driver', action: 'DutyStatusChanged', entityType: 'DriverProfile', entityId: 'D-003', ipAddress: '192.168.1.99', oldState: 'OFF_DUTY', newState: 'FREE' },
  { id: 'AL-008', createdAt: '2026-09-27 10:33:45', actorName: 'System', actorRole: 'Worker', action: 'MonthEndKhataSync', entityType: 'KhataLedger', entityId: 'BIZ-001', ipAddress: '127.0.0.1', oldState: null, newState: 'SYNCED' },
  { id: 'AL-009', createdAt: '2026-09-27 10:30:12', actorName: 'Aakash Gupta', actorRole: 'Driver', action: 'LoginFromNewDevice', entityType: 'UserDeviceSession', entityId: 'SES-789', ipAddress: '10.0.0.44', oldState: 'DEVICE_1', newState: 'DEVICE_2' },
  { id: 'AL-010', createdAt: '2026-09-27 10:28:00', actorName: 'System', actorRole: 'Auth', action: 'ForceLogout', entityType: 'UserDeviceSession', entityId: 'SES-788', ipAddress: '127.0.0.1', oldState: 'ACTIVE', newState: 'REVOKED' },
];

const ROLE_BADGE = {
  Driver: 'badge-purple',
  Customer: 'badge-cyan',
  Admin: 'badge-red',
  Worker: 'badge-orange',
  Auth: 'badge-yellow',
};

const ACTION_COLOR = {
  TaskAccepted: '#6c63ff',
  OrderPlaced: '#3ecfcf',
  OTPVerified_Pickup: '#00e676',
  SubscriptionDispatched: '#ff9f43',
  SubscriptionPaused: '#ffd93d',
  ForceLogout: '#ff6b6b',
  DutyStatusChanged: '#3ecfcf',
  KhataApproved: '#00e676',
  MonthEndKhataSync: '#ff9f43',
  LoginFromNewDevice: '#ff6b6b',
};

export default function AuditLogs() {
  const [logs, setLogs] = useState(MOCK_LOGS);
  const [liveLogs, setLiveLogs] = useState([]);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL');
  const [page, setPage] = useState(0);
  const topRef = useRef();

  // Listen for live audit events via SignalR
  useTaskHub((event) => {
    const newLog = {
      id: `LIVE-${Date.now()}`,
      createdAt: new Date().toLocaleString(),
      actorName: event.driverName || event.actorName || 'System',
      actorRole: event.role || 'System',
      action: event.type,
      entityType: 'Task',
      entityId: event.taskId || '',
      ipAddress: 'SignalR',
      oldState: event.oldStatus,
      newState: event.newStatus,
      isLive: true,
    };
    setLiveLogs(prev => [newLog, ...prev.slice(0, 4)]);
  });

  // Try to load from API
  useEffect(() => {
    fetchAuditLogs(page, 20)
      .then(data => { if (data?.length) setLogs(data); })
      .catch(() => {});
  }, [page]);

  const allLogs = [...liveLogs, ...logs];

  const filtered = allLogs.filter(l => {
    const matchSearch = search === '' ||
      l.actorName?.toLowerCase().includes(search.toLowerCase()) ||
      l.action?.toLowerCase().includes(search.toLowerCase()) ||
      l.entityId?.toLowerCase().includes(search.toLowerCase());
    const matchRole = roleFilter === 'ALL' || l.actorRole === roleFilter;
    return matchSearch && matchRole;
  });

  return (
    <div ref={topRef}>
      {/* ── Controls ─────────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <div className="search-box">
          <span>🔍</span>
          <input
            placeholder="Search actor, action, entity..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        {['ALL', 'Driver', 'Customer', 'Admin', 'Worker', 'Auth'].map(r => (
          <button
            key={r}
            className={`btn ${roleFilter === r ? 'btn-primary' : 'btn-ghost'}`}
            style={{ fontSize: 11 }}
            onClick={() => setRoleFilter(r)}
          >
            {r}
          </button>
        ))}
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 6, alignItems: 'center' }}>
          <div className="online-dot" />
          <span style={{ fontSize: 11, color: 'var(--green)' }}>Live ({liveLogs.length} new)</span>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">Audit Trail</div>
            <div className="card-sub">Immutable log of all state transitions · {filtered.length} entries</div>
          </div>
          <button className="btn btn-ghost" style={{ fontSize: 11 }}>⬇ Export CSV</button>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>Actor</th>
              <th>Role</th>
              <th>Action</th>
              <th>Entity</th>
              <th>State Change</th>
              <th>IP</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((log, i) => (
              <tr key={log.id || i} className={log.isLive ? 'audit-row-new' : ''}
                style={{ background: log.isLive ? 'rgba(108,99,255,0.05)' : '' }}>
                <td style={{ fontSize: 11, color: 'var(--text-dim)', whiteSpace: 'nowrap' }}>
                  {log.isLive && <span style={{ color: 'var(--green)', fontSize: 10, marginRight: 4 }}>● </span>}
                  {log.createdAt}
                </td>
                <td style={{ fontSize: 12, fontWeight: 500 }}>{log.actorName}</td>
                <td>
                  <span className={`badge ${ROLE_BADGE[log.actorRole] || 'badge-purple'}`}>
                    {log.actorRole}
                  </span>
                </td>
                <td>
                  <span style={{
                    fontSize: 12, fontWeight: 600,
                    color: ACTION_COLOR[log.action] || 'var(--text)',
                  }}>
                    {log.action}
                  </span>
                </td>
                <td style={{ fontSize: 11 }}>
                  <div style={{ color: 'var(--text-dim)' }}>{log.entityType}</div>
                  <div style={{ color: 'var(--purple)', fontWeight: 600 }}>{log.entityId}</div>
                </td>
                <td style={{ fontSize: 11 }}>
                  {log.oldState && (
                    <span style={{ color: 'var(--red)' }}>{log.oldState}</span>
                  )}
                  {log.oldState && log.newState && (
                    <span style={{ color: 'var(--text-faint)', margin: '0 4px' }}>→</span>
                  )}
                  {log.newState && (
                    <span style={{ color: 'var(--green)' }}>{log.newState}</span>
                  )}
                </td>
                <td style={{ fontSize: 10, color: 'var(--text-faint)' }}>{log.ipAddress}</td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* Pagination */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 16 }}>
          <button className="btn btn-ghost" style={{ fontSize: 11 }} disabled={page === 0} onClick={() => setPage(p => p - 1)}>
            ← Previous
          </button>
          <span style={{ fontSize: 11, color: 'var(--text-dim)', padding: '8px 12px' }}>Page {page + 1}</span>
          <button className="btn btn-ghost" style={{ fontSize: 11 }} onClick={() => setPage(p => p + 1)}>
            Next →
          </button>
        </div>
      </div>
    </div>
  );
}
