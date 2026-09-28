import { useState, useEffect } from 'react';
import { fetchCommLogs } from '../api.js';

const MOCK_COMMS = [
  { id: 'C-001', createdAt: '10:44:01', recipient: 'Priya Sharma', channel: 'SMS', template: 'OrderPlaced', status: 'Delivered', messageId: 'MSG-8821-A', body: 'Your order T-8821 has been placed. Driver Ravi Kumar is on the way!' },
  { id: 'C-002', createdAt: '10:43:58', recipient: 'Ravi Kumar', channel: 'Push', template: 'NewTaskBroadcast', status: 'Delivered', messageId: 'FCM-4522', body: '📦 New delivery from Gupta Kirana to Sector 4. Fare ₹65. Slide to accept.' },
  { id: 'C-003', createdAt: '10:43:30', recipient: 'Sunita Devi', channel: 'WhatsApp', template: 'SubscriptionDispatch', status: 'Sent', messageId: 'WA-5521', body: '🥛 Good morning! Your daily milk delivery is scheduled for 6:00–7:30 AM today. Due: ₹65 (Khata).' },
  { id: 'C-004', createdAt: '10:42:00', recipient: 'Deepak Yadav', channel: 'Push', template: 'OTPForPickup', status: 'Delivered', messageId: 'FCM-4500', body: '🔐 Pickup OTP for T-8820: 5829. Share with customer for verification.' },
  { id: 'C-005', createdAt: '10:40:50', recipient: 'Sunita Devi', channel: 'SMS', template: 'VacationMode', status: 'Delivered', messageId: 'MSG-SUB118', body: 'Your milk delivery is paused from Sep 28 to Oct 2. ₹0 charge for these days. Enjoy your vacation!' },
  { id: 'C-006', createdAt: '10:38:00', recipient: 'Raj Verma', channel: 'WhatsApp', template: 'KhataReceipt', status: 'Read', messageId: 'WA-5499', body: '📒 Khata Statement: Outstanding balance ₹1,200 at Sharma Dairy. Pay by 30 Sep.' },
  { id: 'C-007', createdAt: '10:35:00', recipient: 'Mohan Das', channel: 'Push', template: 'DutyOnline', status: 'Delivered', messageId: 'FCM-4490', body: '✅ You are now Online and eligible to receive nearby task broadcasts.' },
  { id: 'C-008', createdAt: '10:33:00', recipient: 'All Subscribers', channel: 'SMS', template: 'MonthEndKhata', status: 'Delivered', messageId: 'BULK-SEP', body: '📋 September Khata Statement: 26 deliveries ✓, 4 vacation days ₹0. Total Due: ₹1,690.' },
];

const CHANNEL_BADGE = {
  SMS: 'badge-cyan',
  WhatsApp: 'badge-green',
  Push: 'badge-purple',
  Email: 'badge-orange',
};

const STATUS_BADGE = {
  Delivered: 'badge-green',
  Read: 'badge-cyan',
  Sent: 'badge-orange',
  Failed: 'badge-red',
  Pending: 'badge-yellow',
};

export default function CommunicationLogs() {
  const [logs, setLogs] = useState(MOCK_COMMS);
  const [search, setSearch] = useState('');
  const [channelFilter, setChannelFilter] = useState('ALL');
  const [expanded, setExpanded] = useState(null);

  useEffect(() => {
    fetchCommLogs(0, 30)
      .then(data => { if (data?.length) setLogs(data); })
      .catch(() => {});
  }, []);

  const filtered = logs.filter(l => {
    const matchSearch = search === '' ||
      l.recipient?.toLowerCase().includes(search.toLowerCase()) ||
      l.template?.toLowerCase().includes(search.toLowerCase()) ||
      l.body?.toLowerCase().includes(search.toLowerCase());
    const matchChannel = channelFilter === 'ALL' || l.channel === channelFilter;
    return matchSearch && matchChannel;
  });

  const stats = MOCK_COMMS.reduce((acc, l) => {
    acc[l.channel] = (acc[l.channel] || 0) + 1;
    return acc;
  }, {});

  return (
    <div>
      {/* ── Channel Stats ────────────────────────────────────────────────── */}
      <div className="stat-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)', marginBottom: 20 }}>
        {[
          { ch: 'SMS', icon: '💬', color: '#3ecfcf', bg: 'rgba(62,207,207,0.12)' },
          { ch: 'WhatsApp', icon: '📲', color: '#00e676', bg: 'rgba(0,230,118,0.12)' },
          { ch: 'Push', icon: '🔔', color: '#6c63ff', bg: 'rgba(108,99,255,0.12)' },
          { ch: 'Email', icon: '📧', color: '#ff9f43', bg: 'rgba(255,159,67,0.12)' },
        ].map(({ ch, icon, color, bg }) => (
          <div key={ch} className="stat-card" style={{ '--accent': color, '--accent-bg': bg }}>
            <div className="stat-icon">{icon}</div>
            <div>
              <div className="stat-value">{stats[ch] || 0}</div>
              <div className="stat-label">{ch} Today</div>
            </div>
          </div>
        ))}
      </div>

      {/* ── Filters ──────────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center' }}>
        <div className="search-box">
          <span>🔍</span>
          <input
            placeholder="Search recipient, template, message..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        {['ALL', 'SMS', 'WhatsApp', 'Push', 'Email'].map(ch => (
          <button
            key={ch}
            className={`btn ${channelFilter === ch ? 'btn-primary' : 'btn-ghost'}`}
            style={{ fontSize: 11 }}
            onClick={() => setChannelFilter(ch)}
          >
            {ch}
          </button>
        ))}
      </div>

      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">Communication Logs</div>
            <div className="card-sub">Outbound SMS, WhatsApp, Push & Email delivery tracker · {filtered.length} messages</div>
          </div>
          <button className="btn btn-ghost" style={{ fontSize: 11 }}>⬇ Export CSV</button>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Recipient</th>
              <th>Channel</th>
              <th>Template</th>
              <th>Status</th>
              <th>Message ID</th>
              <th>Preview</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((log, i) => (
              <>
                <tr
                  key={log.id}
                  onClick={() => setExpanded(expanded === log.id ? null : log.id)}
                  style={{ cursor: 'pointer' }}
                >
                  <td style={{ fontSize: 11, color: 'var(--text-dim)', whiteSpace: 'nowrap' }}>{log.createdAt}</td>
                  <td style={{ fontSize: 12, fontWeight: 500 }}>{log.recipient}</td>
                  <td>
                    <span className={`badge ${CHANNEL_BADGE[log.channel] || 'badge-purple'}`}>
                      {log.channel}
                    </span>
                  </td>
                  <td style={{ fontSize: 11, color: 'var(--purple)', fontWeight: 600 }}>{log.template}</td>
                  <td>
                    <span className={`badge ${STATUS_BADGE[log.status] || 'badge-yellow'}`}>
                      {log.status}
                    </span>
                  </td>
                  <td style={{ fontSize: 10, color: 'var(--text-faint)' }}>{log.messageId}</td>
                  <td style={{ fontSize: 11, color: 'var(--text-dim)', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {log.body?.substring(0, 50)}…
                  </td>
                </tr>
                {expanded === log.id && (
                  <tr key={`${log.id}-expanded`}>
                    <td colSpan={7} style={{
                      background: 'rgba(108,99,255,0.05)',
                      padding: '12px 16px',
                      fontSize: 12,
                      color: 'var(--text)',
                      borderLeft: '3px solid var(--purple)',
                    }}>
                      <strong style={{ color: 'var(--purple)' }}>Full message:</strong> {log.body}
                    </td>
                  </tr>
                )}
              </>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
