double _d(dynamic v) => (v as num).toDouble();

class MapPoint {
  final String name;
  final double lat;
  final double lng;
  const MapPoint(this.name, this.lat, this.lng);
}

class Place {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final bool isBusStop;
  const Place(this.id, this.name, this.lat, this.lng, {this.isBusStop = false});

  factory Place.location(Map<String, dynamic> j) =>
      Place(j['location_id'] as int, j['location_name'] as String, _d(j['latitude']), _d(j['longitude']), isBusStop: false);
  factory Place.stop(Map<String, dynamic> j) =>
      Place(j['stop_id'] as int, j['stop_name'] as String, _d(j['latitude']), _d(j['longitude']), isBusStop: true);

  MapPoint get point => MapPoint(name, lat, lng);

  String get uniqueKey => '${isBusStop ? "stop" : "loc"}_$id';
}

/// Where the user starts: a campus location or bus stop chosen from the list, or the GPS position.
class Origin {
  final String name;
  final double lat;
  final double lng;
  final int? locationId; // null when the origin is a raw GPS fix
  final bool isBusStop;
  const Origin(this.name, this.lat, this.lng, {this.locationId, this.isBusStop = false});

  factory Origin.fromPlace(Place p) => Origin(p.name, p.lat, p.lng, locationId: p.id, isBusStop: p.isBusStop);
  MapPoint get point => MapPoint(name, lat, lng);
}

/// Locations, bus stops and shuttle segments as stored in the database.
class Reference {
  final List<Place> locations;
  final List<Place> stops;
  final List<Map<String, dynamic>> routes;
  const Reference(this.locations, this.stops, this.routes);

  /// Merged list of all campus landmarks and bus stops for route selection.
  List<Place> get allPlaces => [...locations, ...stops];

  /// Shuttle segments as pairs of points, for drawing the faint shuttle network on the map.
  List<List<MapPoint>> get routeLines {
    final byId = {for (final s in stops) s.id: s.point};
    final out = <List<MapPoint>>[];
    for (final r in routes) {
      final a = byId[r['start_stop']], b = byId[r['end_stop']];
      if (a != null && b != null) out.add([a, b]);
    }
    return out;
  }

  /// Deduplicated shuttle segments with route names and distances.
  List<NamedRouteSegment> get namedRouteSegments {
    final byId = {for (final s in stops) s.id: s.point};
    final seen = <String>{};
    final out = <NamedRouteSegment>[];
    for (final r in routes) {
      final s1 = r['start_stop'] as int?;
      final s2 = r['end_stop'] as int?;
      if (s1 == null || s2 == null) continue;
      final key = s1 < s2 ? '$s1-$s2' : '$s2-$s1';
      final name = (r['route_name'] as String?)?.trim() ?? 'Campus shuttle';
      final fullKey = '$name:$key';
      if (seen.add(fullKey)) {
        final a = byId[s1], b = byId[s2];
        if (a != null && b != null) {
          out.add(NamedRouteSegment(
            routeName: name,
            start: a,
            end: b,
            distance: (r['distance'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
    }
    return out;
  }

  /// Unique route line names available in the campus shuttle network.
  List<String> get routeNames {
    final names = <String>{};
    for (final r in routes) {
      final name = (r['route_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names.toList();
  }

  String? stopName(int id) {
    for (final s in stops) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  String? locationName(int id) {
    for (final l in locations) {
      if (l.id == id) return l.name;
    }
    return null;
  }
}

/// Represents a shuttle route segment between two bus stops with its route name.
class NamedRouteSegment {
  final String routeName;
  final MapPoint start;
  final MapPoint end;
  final double distance;

  const NamedRouteSegment({
    required this.routeName,
    required this.start,
    required this.end,
    this.distance = 0,
  });

  MapPoint get midpoint => MapPoint(
        routeName,
        (start.lat + end.lat) / 2,
        (start.lng + end.lng) / 2,
      );
}

class RouteResult {
  final bool found;
  final String? reason;
  final String origin;
  final String destination;
  final String mode; // 'bus' | 'walk'
  final double distanceKm;
  final int timeMin;
  final List<String> steps;
  final List<String> lines;
  final List<MapPoint> busStops;
  final List<MapPoint> path;
  final double? directKm;
  final int? directWalkMin;

  const RouteResult({
    required this.found,
    this.reason,
    required this.origin,
    required this.destination,
    this.mode = 'walk',
    this.distanceKm = 0,
    this.timeMin = 0,
    this.steps = const [],
    this.lines = const [],
    this.busStops = const [],
    this.path = const [],
    this.directKm,
    this.directWalkMin,
  });
}

class HistoryItem {
  final String source;
  final String destination;
  final String date;
  const HistoryItem(this.source, this.destination, this.date);
}

String formatKm(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(2)} km';

/// Server dates look like "2026-10-05 11:20:00" (UTC).
String formatWhen(String s) {
  final d = DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z')?.toLocal();
  if (d == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
