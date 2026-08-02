import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider((ref) => LocationService());

final currentLocationProvider = StreamProvider<LatLng>((ref) async* {
  final service = ref.read(locationServiceProvider);
  await service.ensurePermission();
  yield* service.watchPosition();
});
