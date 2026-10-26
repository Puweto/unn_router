import 'dart:math';

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}

/// Road length estimate from two points: straight line x 1.25 (roads are never straight).
double roadEstimateKm(double lat1, double lng1, double lat2, double lng2) =>
    (haversineKm(lat1, lng1, lat2, lng2) * 1.25 * 100).round() / 100;
