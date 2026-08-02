import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/ride_state.dart';
import '../models/place.dart';

class OsrmService {
  final String baseUrl;
  final bool useMock;

  OsrmService({this.baseUrl = 'http://localhost:5000', this.useMock = true});

  Future<RouteInfo> getRoute(LatLng from, LatLng to) async {
    if (useMock) return _mockRoute(from, to);

    final url = Uri.parse(
      '$baseUrl/route/v1/driving/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('OSRM request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('No route found');
    }

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final geometry = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

    final distanceMeters = (route['distance'] as num).toDouble();
    final durationSeconds = (route['duration'] as num).toDouble();

    return RouteInfo(
      geometry: geometry,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      fareByVehicle: _calculateFares(distanceMeters, durationSeconds),
    );
  }

  Future<RouteInfo> _mockRoute(LatLng from, LatLng to) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final geometry = <LatLng>[];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      geometry.add(LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ));
    }

    const distance = Distance();
    final distanceMeters = distance.as(LengthUnit.Meter, from, to) * 1.3;
    final durationSeconds = (distanceMeters / 1000) * 180;

    return RouteInfo(
      geometry: geometry,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      fareByVehicle: _calculateFares(distanceMeters, durationSeconds),
    );
  }

  Map<VehicleType, double> _calculateFares(double distanceMeters, double durationSeconds) {
    final km = distanceMeters / 1000;
    final min = durationSeconds / 60;

    final bikeFare = 15 + km * 6 + min * 1.0;
    final autoFare = 25 + km * 11 + min * 1.5;

    return {
      VehicleType.bike: double.parse(bikeFare.toStringAsFixed(0)),
      VehicleType.auto: double.parse(autoFare.toStringAsFixed(0)),
    };
  }

  Future<Place> mockGeocode(String query, LatLng near) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Place(
      latLng: LatLng(near.latitude + 0.01, near.longitude + 0.01),
      address: query.isEmpty ? 'Selected destination' : query,
    );
  }
}
