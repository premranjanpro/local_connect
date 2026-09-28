import { useState } from 'react';
import Overview from './pages/Overview.jsx';
import LiveMap from './pages/LiveMap.jsx';
import Tasks from './pages/Tasks.jsx';
import AuditLogs from './pages/AuditLogs.jsx';
import CommunicationLogs from './pages/CommunicationLogs.jsx';
import Subscriptions from './pages/Subscriptions.jsx';

const NAV = [
  { id: 'overview',     icon: '⚡', label: 'Overview' },
  { id: 'live-map',     icon: '🗺️', label: 'Live Driver Map' },
  { id: 'tasks',        icon: '📦', label: 'Active Tasks' },
  { id: 'subscriptions',icon: '🥛', label: 'Subscriptions' },
  { id: 'audit',        icon: '📋', label: 'Audit Trail' },
  { id: 'comms',        icon: '📨', label: 'Communication Logs' },
];

export default function App() {
  const [page, setPage] = useState('overview');

  const pageMap = {
    'overview':      <Overview />,
    'live-map':      <LiveMap />,
    'tasks':         <Tasks />,
    'subscriptions': <Subscriptions />,
    'audit':         <AuditLogs />,
    'comms':         <CommunicationLogs />,
  };

  const pageTitle = {
    'overview':       'Overview',
    'live-map':       'Live Driver Map',
    'tasks':          'Active Tasks',
    'subscriptions':  'Subscriptions & Dispatch',
    'audit':          'Audit Trail',
    'comms':          'Communication Logs',
  };

  const pageSub = {
    'overview':       'Real-time platform health and key metrics',
    'live-map':       'Spatial view of all online drivers and active orders',
    'tasks':          'All in-flight delivery and mobility tasks',
    'subscriptions':  'Morning auto-dispatch management and vacation mode control',
    'audit':          'Immutable log of all state transitions and permission checks',
    'comms':          'Outbound SMS, WhatsApp, email, and push delivery tracker',
  };

  return (
    <div className="layout">
      {/* ── Sidebar ────────────────────────────────────────────────────────── */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="logo-icon">🛵</div>
          <div>
            <div className="brand-name">ShopConnector</div>
            <div className="brand-sub">Admin Dashboard</div>
          </div>
        </div>

        <div className="nav-section-label">Platform</div>
        {NAV.map(n => (
          <div
            key={n.id}
            className={`nav-item ${page === n.id ? 'active' : ''}`}
            onClick={() => setPage(n.id)}
          >
            <span className="icon">{n.icon}</span>
            <span>{n.label}</span>
          </div>
        ))}

        <div className="sidebar-footer">
          <div className="online-badge">
            <div className="online-dot" />
            All systems online
          </div>
          <div style={{ fontSize: 10, color: 'var(--text-faint)', marginTop: 6 }}>
            Native Windows Stack · No Docker
          </div>
        </div>
      </aside>

      {/* ── Main ───────────────────────────────────────────────────────────── */}
      <div className="main-content">
        <div className="topbar">
          <div>
            <div className="topbar-title">{pageTitle[page]}</div>
            <div className="topbar-sub">{pageSub[page]}</div>
          </div>
          <div className="topbar-actions">
            <div className="search-box">
              <span>🔍</span>
              <input placeholder="Search tasks, drivers, users..." />
            </div>
            <button className="btn btn-primary" style={{ gap: 6 }}>
              ⚙️ Settings
            </button>
          </div>
        </div>

        <div className="page-content">
          <div className="fade-in" key={page}>
            {pageMap[page]}
          </div>
        </div>
      </div>
    </div>
  );
}
