import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import { env } from './config/env';
import { initSockets } from './sockets';
import { adminRouter } from './routes/admin.routes';

const app = express();
app.use(express.json());

// Admin panel is served as a static page (see admin-panel/) and calls these
// endpoints from the browser, so CORS needs to be open for local dev.
app.use((_req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: Date.now() }));
app.use('/admin', adminRouter);

const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: '*' },
  pingInterval: 10000,
  pingTimeout: 5000,
});

initSockets(io);

server.listen(env.PORT, () => {
  console.log(`[Server] YelliGo matching service running on port ${env.PORT}`);
});
