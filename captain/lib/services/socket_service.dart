import 'package:socket_io_client/socket_io_client.dart' as io;

/// Real Socket.io client wired to the exact event contract defined in the
/// backend's `sockets/driver.handlers.ts`. This is the production
/// replacement for MockDispatchService - point [baseUrl] at your backend
/// (e.g. http://10.0.2.2:4000 on the Android emulator) and call [connect]
/// once the driver logs in.
class SocketService {
  io.Socket? _socket;
  final String baseUrl;

  SocketService({required this.baseUrl});

  io.Socket connect(String driverId) {
    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket.connect();
    socket.onConnect((_) {
      socket.emit('driver_online', {'driver_id': driverId});
    });
    return socket;
  }

  void sendLocationUpdate({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) {
    _socket?.emit('location_update', {
      'driver_id': driverId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
    });
  }

  void acceptRide({required String rideId, required String driverId}) {
    _socket?.emit('accept_ride', {'ride_id': rideId, 'driver_id': driverId});
  }

  void sendTripStatusUpdate({required String rideId, required String status}) {
    _socket?.emit('trip_status_update', {'ride_id': rideId, 'status': status});
  }

  void goOffline(String driverId) {
    _socket?.emit('driver_offline', {'driver_id': driverId});
    _socket?.disconnect();
  }

  // Listen for: new_ride_alert, ride_confirmed, ride_taken,
  // ride_already_taken, trip_status_updated - via socket.on(...) in the
  // CaptainController once this is wired in place of MockDispatchService.

  void dispose() {
    _socket?.dispose();
  }
}
