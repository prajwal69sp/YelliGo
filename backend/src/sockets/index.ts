import { Server } from 'socket.io';
import { registerDriverHandlers } from './driver.handlers';
import { registerRiderHandlers } from './rider.handlers';

export function initSockets(io: Server) {
  io.on('connection', (socket) => {
    console.log(`[Socket] client connected: ${socket.id}`);

    registerDriverHandlers(io, socket);
    registerRiderHandlers(io, socket);

    socket.on('disconnect', (reason) => {
      console.log(`[Socket] client disconnected: ${socket.id} (${reason})`);
    });
  });
}
