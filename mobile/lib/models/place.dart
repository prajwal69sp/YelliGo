import 'package:latlong2/latlong.dart';

class Place {
  final LatLng latLng;
  final String address;

  const Place({required this.latLng, required this.address});
}
