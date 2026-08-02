// Point this at your running backend (see backend/.env PORT, default 4000).
// For local dev this is usually http://localhost:4000.
const YELLIGO_API_BASE_URL = 'http://localhost:4000';

// How often the dashboard polls for fresh data (ms). A production build
// would use Socket.io directly instead of polling - see notes in app.js.
const POLL_INTERVAL_MS = 5000;

// Default map center (Bengaluru) - change to your operating city.
const DEFAULT_MAP_CENTER = [77.5946, 12.9716];
