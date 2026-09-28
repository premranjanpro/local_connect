import { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import L from 'leaflet';
import { useTelemetryHub, useTaskHub } from '../hooks/useSignalR.js';

// Fix Leaflet default icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// Custom driver marker icon (purple circle)
const driverIcon = (status) => L.divIcon({
  className: '',
  html: `<div style="
    width:36px;height:36px;
    background:linear-gradient(135deg,#6c63ff,#3ecfcf);
    border-radius:50%;
    display:flex;align-items:center;justify-content:center;
    font-size:16px;
    box-shadow:0 0 0 4px rgba(108,99,255,0.3),0 4px 12px rgba(0,0,0,0.4);
    border:2px solid rgba(255,255,255,0.3);
  ">🛵</div>`,
  iconSize: [36, 36],
  iconAnchor: [18, 18],
});

// Jaipur center
const MAP_CENTER = [26.9124, 75.7873];

// Mock drivers with live positions
const INITIAL_DRIVERS = [
  { id: 'd-001', name: 'Ravi Kumar', lat: 26.9124, lng: 75.7873, status: 'EN_ROUTE_PICKUP', task: 'T-8821', speed: 28 },
  { id: 'd-002', name: 'Deepak Yadav', lat: 26.9200, lng: 75.7950, status: 'AT_PICKUP', task: 'T-8820', speed: 0 },
  { id: 'd-003', name: 'Mohan Das', lat: 26.9050, lng: 75.7800, status: 'PICKED_UP', task: 'T-8819', speed: 32 },
  { id: 'd-004', name: 'Aakash Gupta', lat: 26.9180, lng: 75.8100, status: 'FREE', task: null, speed: 0 },
  { id: 'd-005', name: 'Suresh Patel', lat: 26.9300, lng: 75.7700, status: 'EN_ROUTE_PICKUP', task: 'T-8817', speed: 24 },
  { id: 'd-006', name: 'Rajesh Sharma', lat: 26.9080, lng: 75.8000, status: 'FREE', task: null, speed: 0 },
];

const STATUS_COLOR = {
  FREE: '#00e676',
  EN_ROUTE_PICKUP: '#6c63ff',
  AT_PICKUP: '#ff9f43',
  PICKED_UP: '#3ecfcf',
  AT_DROP: '#ffd93d',
  OFF_DUTY: '#666',
};

export default function LiveMap() {
  const [drivers, setDrivers] = useState(INITIAL_DRIVERS);
  const [selected, setSelected] = useState(null);
  const [filter, setFilter] = useState('ALL');
  const [locationPings, setLocationPings] = useState(0);

  // Receive live location updates from TelemetryHub
  const telemetryConnected = useTelemetryHub((loc) => {
    setLocationPings(p => p + 1);
    setDrivers(prev => prev.map(d => {
      if (d.task === loc.taskId) {
        return { ...d, lat: loc.lat, lng: loc.lng, speed: loc.speed };
      }
      return d;
    }));
  });

  // Simulate gentle movement for demo (remove in production)
  useEffect(() => {
    if (telemetryConnected) return; // Use real data if connected
    const interval = setInterval(() => {
      setDrivers(prev => prev.map(d => {
        if (d.status === 'FREE' || d.status === 'OFF_DUTY') return d;
        return {
          ...d,
          lat: d.lat + (Math.random() - 0.5) * 0.0003,
          lng: d.lng + (Math.random() - 0.5) * 0.0003,
        };
      }));
    }, 2500);
    return () => clearInterval(interval);
  }, [telemetryConnected]);

  const filtered = filter === 'ALL' ? drivers : drivers.filter(d => d.status === filter);

  const statusCounts = drivers.reduce((acc, d) => {
    acc[d.status] = (acc[d.status] || 0) + 1;
    return acc;
  }, {});

  return (
    <div>
      {/* ── Controls ─────────────────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center', flexWrap: 'wrap' }}>
        {['ALL', 'FREE', 'EN_ROUTE_PICKUP', 'AT_PICKUP', 'PICKED_UP', 'AT_DROP'].map(f => (
          <button
            key={f}
            className={`btn ${filter === f ? 'btn-primary' : 'btn-ghost'}`}
            style={{ fontSize: 11 }}
            onClick={() => setFilter(f)}
          >
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: STATUS_COLOR[f] || '#6c63ff', display: 'inline-block', marginRight: 4 }} />
            {f.replace(/_/g, ' ')}
            <span style={{ marginLeft: 4, opacity: 0.7 }}>
              ({f === 'ALL' ? drivers.length : (statusCounts[f] || 0)})
            </span>
          </button>
        ))}
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
            <div style={{ width: 7, height: 7, borderRadius: '50%', background: telemetryConnected ? 'var(--green)' : 'var(--red)' }} />
            <span style={{ fontSize: 11, color: 'var(--text-dim)' }}>
              {telemetryConnected ? `Live (${locationPings} pings)` : 'Demo mode'}
            </span>
          </div>
        </div>
      </div>

      <div className="grid-map-table">
        {/* ── Live Map ────────────────────────────────────────────────────── */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <MapContainer
            center={MAP_CENTER}
            zoom={14}
            style={{ height: 520, width: '100%', borderRadius: 16 }}
          >
            <TileLayer
              attribution='© OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {filtered.map(driver => (
              <Marker
                key={driver.id}
                position={[driver.lat, driver.lng]}
                icon={driverIcon(driver.status)}
                eventHandlers={{ click: () => setSelected(driver) }}
              >
                <Popup>
                  <div style={{ fontFamily: 'Inter', fontSize: 13, minWidth: 180 }}>
                    <div style={{ fontWeight: 700, marginBottom: 4 }}>🛵 {driver.name}</div>
                    <div style={{ color: STATUS_COLOR[driver.status], fontWeight: 600, marginBottom: 4 }}>
                      {driver.status.replace(/_/g, ' ')}
                    </div>
                    {driver.task && <div style={{ fontSize: 11 }}>Task: {driver.task}</div>}
                    <div style={{ fontSize: 11, color: '#666' }}>Speed: {driver.speed} km/h</div>
                    <div style={{ fontSize: 10, color: '#999', marginTop: 4 }}>
                      {driver.lat.toFixed(5)}, {driver.lng.toFixed(5)}
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        {/* ── Driver List ─────────────────────────────────────────────────── */}
        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title">Driver Fleet</div>
              <div className="card-sub">{filtered.length} drivers shown</div>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 460, overflowY: 'auto' }}>
            {filtered.map(d => (
              <div
                key={d.id}
                onClick={() => setSelected(d)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '10px 12px',
                  background: selected?.id === d.id ? 'rgba(108,99,255,0.1)' : 'var(--bg-card2)',
                  border: `1px solid ${selected?.id === d.id ? 'rgba(108,99,255,0.4)' : 'var(--border-light)'}`,
                  borderRadius: 10, cursor: 'pointer',
                  transition: 'all 0.15s',
                }}
              >
                <div style={{
                  width: 36, height: 36,
                  background: `linear-gradient(135deg, ${STATUS_COLOR[d.status]}33, ${STATUS_COLOR[d.status]}55)`,
                  borderRadius: 10, display: 'grid', placeItems: 'center',
                  fontSize: 16, flexShrink: 0,
                }}>🛵</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {d.name}
                  </div>
                  <div style={{ fontSize: 11, color: STATUS_COLOR[d.status], fontWeight: 600 }}>
                    {d.status.replace(/_/g, ' ')}
                  </div>
                </div>
                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  {d.task && <div style={{ fontSize: 10, color: 'var(--purple)' }}>{d.task}</div>}
                  <div style={{ fontSize: 10, color: 'var(--text-faint)' }}>{d.speed} km/h</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
