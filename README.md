# YelliGo — Bike-Taxi Platform (MVP) — Open Source

A low-cost, self-hostable bike-taxi ride-hailing platform. Flutter Customer + Captain
(Driver) apps, Node.js/TypeScript + Socket.io real-time matching, PostgreSQL/PostGIS,
Redis Geo, self-hosted OSRM routing, and a web-based Admin Panel.

## Repo Structure

```
yelligo/
├── backend/            # Node.js + TypeScript + Socket.io real-time server
│   ├── src/
│   ├── docker/          # docker-compose for Postgres/PostGIS, Redis, OSRM
│   ├── package.json
│   └── .env.example
├── database/            # Standalone SQL: schema, functions, sample lifecycle queries
│   ├── schema.sql
│   ├── functions.sql
│   └── sample_queries.sql
├── mobile/               # Customer app - Flutter (flutter_map + Riverpod)
│   ├── lib/
│   └── pubspec.yaml
├── captain/               # Driver (Captain) app - Flutter
│   ├── lib/
│   └── pubspec.yaml
├── admin-panel/            # Admin web dashboard (static HTML/JS, no build step)
│   ├── index.html
│   └── assets/
├── .github/workflows/       # CI: auto-builds Customer + Captain APKs on push
└── docs/
```

## Quick Start

### 1. Infra (Postgres/PostGIS, Redis, OSRM)

```bash
cd backend/docker
# Place a .osm.pbf extract (e.g. from Geofabrik) at ./osrm-data/region.osm.pbf
docker compose --profile prep run --rm osrm-prep   # one-time OSRM graph build
docker compose up -d postgres redis osrm
```

Load the schema:
```bash
psql -h localhost -U yelligo_user -d yelligo -f ../../database/schema.sql
psql -h localhost -U yelligo_user -d yelligo -f ../../database/functions.sql
```

### 2. Backend

```bash
cd backend
cp .env.example .env   # edit DATABASE_URL, REDIS_URL, OSRM_BASE_URL as needed
npm install
npm run dev             # http://localhost:4000, health check at /health
```

### 3. Customer App (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

### 4. Captain (Driver) App (Flutter)

```bash
cd captain
flutter pub get
flutter run
```

Ships with a `MockDispatchService` that simulates incoming ride alerts every 8-18s so
you can test the full accept → navigate → OTP → complete flow without a live backend.
Swap it for `SocketService` (already written, just needs wiring into
`captain_provider.dart`) once your backend is running — point `baseUrl` at
`http://10.0.2.2:4000` on the Android emulator or your LAN IP on a physical device.

### 5. Admin Panel (no build step)

```bash
cd admin-panel
python3 -m http.server 8080   # or any static file server
```
Open `http://localhost:8080`. Edit `assets/config.js` to point `YELLIGO_API_BASE_URL`
at your backend. Requires the backend to be running — it exposes `/admin/*` REST
endpoints for stats, live driver positions, recent rides, and the driver verification
queue.

### 6. Getting real APK files

Push this repo to GitHub — `.github/workflows/build-apk.yml` automatically builds
release APKs for both the Customer and Captain apps on every push to `main`, and
attaches them as downloadable artifacts on the Actions run. No local Android Studio
setup needed. (Note: this produces debug-signed release builds suitable for testing;
for a Play Store submission you'll need to add your own signing key config.)

By default `OsrmService(useMock: true)` (both apps) uses a mocked route/dispatch
generator so you can run the UI without wiring the backend yet. Set `useMock: false`
and point `baseUrl` at your OSRM instance once ready.

## What's Included

- **Database**: `users`, `drivers`, `vehicles`, `rides`, `driver_locations` +
  `current_driver_location`, all PostGIS-indexed (GIST), plus a `find_nearby_drivers()`
  KNN function and full ride-lifecycle SQL.
- **Backend**: Socket.io handlers for driver location pings (Redis `GEOADD`),
  `request_ride` → OSRM routing + fare estimate → nearby-driver matching → targeted
  `new_ride_alert` emits, race-safe `accept_ride` (Redis `SET NX` lock + Postgres
  guarded `UPDATE`), and a REST `/admin/*` API for the dashboard.
- **Customer app**: Full-screen `flutter_map` (OSM tiles) with live location marker,
  bottom sheet for pickup/destination, polyline route rendering, Bike/Auto vehicle
  selector, fare display, and a Riverpod state machine (`SelectingDestination →
  FindingDriver → RideAccepted → InTransit`) using Dart 3 sealed classes.
- **Captain (Driver) app**: Online/offline toggle, incoming ride alert with countdown
  timer and accept/decline, OTP entry to start trip, active-trip map view, earnings
  summary card, and a real `SocketService` (socket_io_client) ready to wire in.
- **Admin Panel**: Live driver map (MapLibre GL), today's stats + ride-status donut
  chart (Chart.js), recent rides table, and a driver document-verification queue —
  all polling the backend's `/admin/*` REST endpoints.

## Known Gaps (MVP scope)

- Captain app uses `MockDispatchService` by default — swap in `SocketService` once
  your backend is live.
- No auth/JWT middleware wired into Socket.io connections yet.
- No real geocoding (mock geocoder stubbed in `osrm_service.dart`).
- Single-process `Map`-based in-memory state in the backend — fine for one instance,
  needs a Redis-backed store to scale horizontally.
- Admin panel uses polling, not push updates — fine for MVP, swap for a Socket.io
  listener later if you want instant live-map updates.

## License

MIT — see [LICENSE](./LICENSE).
