import { useState, useEffect, useCallback } from 'react';
import * as HubConnection from '@microsoft/signalr';

const BASE_HUB_URL = '/hubs';

// ── SignalR connection factory ───────────────────────────────────────────────

function buildConnection(hubPath) {
  return new HubConnection.HubConnectionBuilder()
    .withUrl(BASE_HUB_URL + hubPath, {
      accessTokenFactory: () => localStorage.getItem('admin_token') || '',
    })
    .withAutomaticReconnect()
    .configureLogging(HubConnection.LogLevel.Warning)
    .build();
}

// ── useTaskHub ────────────────────────────────────────────────────────────────
// Connects to /hubs/tasks — receives TaskStatusChanged, DriverAssigned events

export function useTaskHub(onTaskEvent) {
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const conn = buildConnection('/tasks');

    conn.on('TaskStatusChanged', (payload) => {
      onTaskEvent?.({ type: 'TaskStatusChanged', ...payload });
    });

    conn.on('DriverAssigned', (payload) => {
      onTaskEvent?.({ type: 'DriverAssigned', ...payload });
    });

    conn.on('ForceLogout', (payload) => {
      onTaskEvent?.({ type: 'ForceLogout', ...payload });
    });

    conn.onreconnected(() => setConnected(true));
    conn.onclose(() => setConnected(false));

    conn.start()
      .then(() => {
        setConnected(true);
        console.log('[TaskHub] Connected');
      })
      .catch((e) => console.warn('[TaskHub] Connection failed:', e));

    return () => conn.stop();
  }, []);

  return connected;
}

// ── useTelemetryHub ───────────────────────────────────────────────────────────
// Connects to /hubs/telemetry — receives OnLocationUpdate events

export function useTelemetryHub(onLocationUpdate) {
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const conn = buildConnection('/telemetry');

    conn.on('OnLocationUpdate', (payload) => {
      onLocationUpdate?.({
        taskId: payload.taskId,
        lat: payload.latitude,
        lng: payload.longitude,
        speed: payload.speed,
        heading: payload.heading,
        timestamp: payload.timestamp,
      });
    });

    conn.onreconnected(() => setConnected(true));
    conn.onclose(() => setConnected(false));

    conn.start()
      .then(() => {
        setConnected(true);
        console.log('[TelemetryHub] Connected');
      })
      .catch((e) => console.warn('[TelemetryHub] Connection failed:', e));

    return () => conn.stop();
  }, []);

  return connected;
}

// ── useChatHub ───────────────────────────────────────────────────────────────
// Connects to /hubs/chat — for monitoring incoming messages

export function useChatHub(onNewMessage) {
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const conn = buildConnection('/chat');

    conn.on('NewMessage', (payload) => {
      onNewMessage?.({ type: 'NewMessage', ...payload });
    });

    conn.onreconnected(() => setConnected(true));
    conn.onclose(() => setConnected(false));

    conn.start()
      .then(() => { setConnected(true); })
      .catch(() => {});

    return () => conn.stop();
  }, []);

  return connected;
}
