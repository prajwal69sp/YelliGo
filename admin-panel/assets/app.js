/**
 * YelliGo Admin Panel — vanilla JS dashboard.
 *
 * Talks directly to the backend REST endpoints defined in
 * backend/src/routes/admin.routes.ts:
 *   GET  /admin/stats/summary
 *   GET  /admin/drivers/live
 *   GET  /admin/rides/recent
 *   GET  /admin/drivers/pending
 *   PATCH /admin/drivers/:id/verify
 *
 * No build step required — open index.html directly, or serve the folder
 * with any static file server. Polling is used here for simplicity; swap
 * fetchLiveDrivers() for a Socket.io listener on 'driver_location_broadcast'
 * if you want push-based updates instead of a 5s poll.
 */

let map;
let statusChart;
const driverMarkers = new Map();

function setConnectionStatus(ok) {
  const dot = document.getElementById('connDot');
  const text = document.getElementById('connText');
  dot.style.background = ok ? '#22c55e' : '#ef4444';
  text.textContent = ok ? 'Live' : 'Backend unreachable';
}

async function fetchJson(path) {
  const res = await fetch(`${YELLIGO_API_BASE_URL}${path}`);
  if (!res.ok) throw new Error(`Request failed: ${path}`);
  return res.json();
}

function initMap() {
  map = new maplibregl.Map({
    container: 'map',
    style: 'https://demotiles.maplibre.org/style.json', // swap for your self-hosted style
    center: DEFAULT_MAP_CENTER,
    zoom: 11,
  });
  map.addControl(new maplibregl.NavigationControl(), 'top-right');
}

function initChart() {
  const ctx = document.getElementById('statusChart');
  statusChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: [],
      datasets: [{ data: [], backgroundColor: ['#3b82f6', '#fbbf24', '#a78bfa', '#4ade80', '#f87171'] }],
    },
    options: {
      plugins: { legend: { position: 'bottom', labels: { color: '#9aa1ac', boxWidth: 10, font: { size: 11 } } } },
    },
  });
}

async function refreshStats() {
  const data = await fetchJson('/admin/stats/summary');

  document.getElementById('statRides').textContent = data.rides_today ?? '0';
  document.getElementById('statRevenue').textContent = `₹${Math.round(data.revenue_today ?? 0)}`;

  const online = (data.driver_status_breakdown || []).find((d) => d.status === 'ONLINE');
  document.getElementById('statOnline').textContent = online?.count ?? '0';

  const breakdown = data.ride_status_breakdown || [];
  statusChart.data.labels = breakdown.map((b) => b.status);
  statusChart.data.datasets[0].data = breakdown.map((b) => b.count);
  statusChart.update();
}

async function refreshLiveDrivers() {
  const data = await fetchJson('/admin/drivers/live');
  const seen = new Set();

  for (const driver of data.drivers || []) {
    seen.add(driver.driver_id);
    const color = driver.status === 'ON_TRIP' ? '#f59e0b' : '#22c55e';

    if (driverMarkers.has(driver.driver_id)) {
      const marker = driverMarkers.get(driver.driver_id);
      marker.setLngLat([driver.lng, driver.lat]);
      marker.getElement().style.background = color;
    } else {
      const el = document.createElement('div');
      el.style.width = '12px';
      el.style.height = '12px';
      el.style.borderRadius = '50%';
      el.style.background = color;
      el.style.border = '2px solid white';
      el.style.boxShadow = '0 0 0 2px rgba(0,0,0,0.3)';

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([driver.lng, driver.lat])
        .setPopup(new maplibregl.Popup({ offset: 12 }).setText(`Driver ${driver.driver_id.slice(0, 8)}`))
        .addTo(map);
      driverMarkers.set(driver.driver_id, marker);
    }
  }

  // Remove markers for drivers no longer live (went offline / stale)
  for (const [id, marker] of driverMarkers.entries()) {
    if (!seen.has(id)) {
      marker.remove();
      driverMarkers.delete(id);
    }
  }
}

function statusBadge(status) {
  return `<span class="badge ${status}">${status}</span>`;
}

async function refreshRecentRides() {
  const data = await fetchJson('/admin/rides/recent?limit=15');
  const tbody = document.getElementById('ridesTableBody');

  if (!data.rides || data.rides.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty-state">No rides yet</td></tr>';
    return;
  }

  tbody.innerHTML = data.rides
    .map((r) => {
      const fare = r.fare_final ?? r.fare_estimated ?? 0;
      const time = new Date(r.requested_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      return `<tr>
        <td>${r.passenger_name ?? '—'}</td>
        <td>${r.driver_name ?? '—'}</td>
        <td>${statusBadge(r.status)}</td>
        <td>₹${Math.round(fare)}</td>
        <td>${time}</td>
      </tr>`;
    })
    .join('');
}

async function refreshPendingDrivers() {
  const data = await fetchJson('/admin/drivers/pending');
  const tbody = document.getElementById('pendingTableBody');
  document.getElementById('statPending').textContent = data.drivers?.length ?? '0';

  if (!data.drivers || data.drivers.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" class="empty-state">Nothing pending 🎉</td></tr>';
    return;
  }

  tbody.innerHTML = data.drivers
    .map(
      (d) => `<tr>
        <td>${d.full_name}</td>
        <td>${d.license_number}</td>
        <td><button class="btn" onclick="verifyDriver('${d.id}')">Verify</button></td>
      </tr>`
    )
    .join('');
}

async function verifyDriver(driverId) {
  await fetch(`${YELLIGO_API_BASE_URL}/admin/drivers/${driverId}/verify`, { method: 'PATCH' });
  refreshPendingDrivers();
}

async function refreshAll() {
  try {
    await Promise.all([refreshStats(), refreshLiveDrivers(), refreshRecentRides(), refreshPendingDrivers()]);
    setConnectionStatus(true);
  } catch (err) {
    console.error('[admin] refresh failed:', err);
    setConnectionStatus(false);
  }
}

initMap();
initChart();
map.on('load', () => {
  refreshAll();
  setInterval(refreshAll, POLL_INTERVAL_MS);
});
