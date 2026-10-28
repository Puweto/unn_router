import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models.dart';
import '../routing.dart';

/// Checks and requests location permission.
Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

LatLng _ll(MapPoint p) => LatLng(p.lat, p.lng);

/// Brand & line colors for campus shuttle routes.
Color getRouteColor(String name) {
  final n = name.trim().toLowerCase();
  if (n.contains('main')) return const Color(0xFF1976D2); // Royal Blue
  if (n.contains('town')) return const Color(0xFFF57C00); // Amber Orange
  if (n.contains('ziks')) return const Color(0xFF8E24AA); // Royal Violet
  if (n.contains('agric')) return const Color(0xFF2E7D32); // Forest Green
  if (n.contains('hilltop') || n.contains('second gate')) return const Color(0xFF00897B); // Teal
  return const Color(0xFF455A64); // Slate Grey
}

/// Campus map displaying:
/// - Start (My Location) & End (Destination) pins with distinct badges
/// - Route polyline drawing the distance and route between points
/// - Authentic Google Maps Street and Satellite imagery
/// - Auto-camera fitting so the full trip is visible immediately
class RouteMap extends StatefulWidget {
  final List<MapPoint> path; // origin, stops..., destination
  final List<MapPoint> stops; // bus stops to mark
  final List<MapPoint> locations; // campus locations to mark
  final List<List<MapPoint>> network; // fallback faint network
  final List<NamedRouteSegment> namedRoutes; // rich shuttle routes with names
  final List<String> pathLines; // route line names used in the active path
  final double? distanceKm; // total distance along the route
  final int? walkingTimeMin; // estimated walking time in minutes
  final double height;
  final bool showControls;

  const RouteMap({
    super.key,
    this.path = const [],
    this.stops = const [],
    this.locations = const [],
    this.network = const [],
    this.namedRoutes = const [],
    this.pathLines = const [],
    this.distanceKm,
    this.walkingTimeMin,
    this.height = 380,
    this.showControls = true,
  });

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  bool _showLocations = true;
  Position? _myPosition;
  String? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    final ok = await ensureLocationPermission();
    if (mounted && ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) setState(() => _myPosition = pos);
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.stops != widget.stops ||
        oldWidget.locations != widget.locations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  List<LatLng> get _pointsToFit {
    if (widget.path.isNotEmpty) {
      return [for (final p in widget.path) LatLng(p.lat, p.lng)];
    }
    if (_selectedRoute != null) {
      return widget.namedRoutes
          .where((r) => r.routeName == _selectedRoute)
          .expand((r) => [LatLng(r.start.lat, r.start.lng), LatLng(r.end.lat, r.end.lng)])
          .toList();
    }
    final pts = <LatLng>[];
    for (final s in widget.stops) {
      pts.add(LatLng(s.lat, s.lng));
    }
    for (final l in widget.locations) {
      pts.add(LatLng(l.lat, l.lng));
    }
    return pts;
  }

  void _fit() {
    final pts = _pointsToFit;
    if (pts.isEmpty) return;
    _mapController.rotate(0);
    if (pts.length == 1) {
      _mapController.move(pts.first, 16.5);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 70),
        maxZoom: 16.5,
      ),
    );
  }

  LatLng get _initialCenter {
    if (widget.path.isNotEmpty) {
      if (widget.path.length >= 2) {
        final o = widget.path.first;
        final d = widget.path.last;
        return LatLng((o.lat + d.lat) / 2, (o.lng + d.lng) / 2);
      }
      return LatLng(widget.path.first.lat, widget.path.first.lng);
    }
    if (widget.stops.isNotEmpty) {
      return LatLng(widget.stops.first.lat, widget.stops.first.lng);
    }
    return const LatLng(kCampusLat, kCampusLng);
  }

  double get _initialZoom {
    if (widget.path.length >= 2) {
      final o = widget.path.first;
      final d = widget.path.last;
      final dist = haversineKm(o.lat, o.lng, d.lat, d.lng);
      if (dist < 0.6) return 16.2;
      if (dist < 1.5) return 15.0;
      if (dist < 3.0) return 14.0;
      return 13.2;
    }
    return 15.2;
  }

  double get _totalDistanceKm {
    if (widget.distanceKm != null && widget.distanceKm! > 0) {
      return widget.distanceKm!;
    }
    double total = 0;
    for (var i = 0; i < widget.path.length - 1; i++) {
      total += haversineKm(
        widget.path[i].lat,
        widget.path[i].lng,
        widget.path[i + 1].lat,
        widget.path[i + 1].lng,
      );
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final uniqueRouteNames = widget.namedRoutes
        .map((e) => e.routeName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 12.0,
                maxZoom: 19.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) _fit();
                  });
                },
              ),
              children: [
                // Google Maps Tile Layer (Real Google Maps Street & Satellite)
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'ng.edu.unn.unn_route_navigator',
                  maxZoom: 20,
                ),

                // Polylines: Route line or campus shuttle network
                PolylineLayer(
                  polylines: [
                    if (widget.path.isNotEmpty) ...[
                      // High-contrast deep navy casing for visibility
                      Polyline(
                        points: [for (final p in widget.path) LatLng(p.lat, p.lng)],
                        color: const Color(0xFF0D47A1),
                        strokeWidth: 8.0,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Vibrant royal blue route polyline
                      Polyline(
                        points: [for (final p in widget.path) LatLng(p.lat, p.lng)],
                        color: const Color(0xFF00B0FF),
                        strokeWidth: 5.0,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ] else ...[
                      // Campus shuttle route segments
                      if (widget.namedRoutes.isNotEmpty)
                        for (final seg in widget.namedRoutes)
                          if (_selectedRoute == null || _selectedRoute == seg.routeName)
                            Polyline(
                              points: [
                                LatLng(seg.start.lat, seg.start.lng),
                                LatLng(seg.end.lat, seg.end.lng),
                              ],
                              color: getRouteColor(seg.routeName),
                              strokeWidth: _selectedRoute == seg.routeName ? 6.0 : 4.0,
                              strokeCap: StrokeCap.round,
                              strokeJoin: StrokeJoin.round,
                            )
                      else if (widget.network.isNotEmpty)
                        for (final net in widget.network)
                          Polyline(
                            points: [for (final p in net) LatLng(p.lat, p.lng)],
                            color: const Color(0xFF90A4AE),
                            strokeWidth: 3.0,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                    ],
                  ],
                ),

                // Markers: Origin & Destination ONLY when searching route; Stops & Landmarks when overview
                MarkerLayer(
                  markers: [
                    if (widget.path.isNotEmpty) ...[
                      // 1. ORIGIN PIN (Green)
                      Marker(
                        point: LatLng(widget.path.first.lat, widget.path.first.lng),
                        width: 170,
                        height: 64,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                widget.path.first.name == 'My location'
                                    ? 'My Location'
                                    : 'Start: ${widget.path.first.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 36),
                          ],
                        ),
                      ),

                      // 2. DESTINATION PIN (Red)
                      if (widget.path.length > 1)
                        Marker(
                          point: LatLng(widget.path.last.lat, widget.path.last.lng),
                          width: 180,
                          height: 64,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB71C1C),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Text(
                                  'Destination: ${widget.path.last.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Icon(Icons.location_on, color: Color(0xFFC62828), size: 36),
                            ],
                          ),
                        ),
                    ] else ...[
                      // Campus Bus Stops
                      for (final s in widget.stops)
                        Marker(
                          point: LatLng(s.lat, s.lng),
                          width: 130,
                          height: 48,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFE65100), width: 1),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                                ),
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFBF360C),
                                  ),
                                ),
                              ),
                              const Icon(Icons.directions_bus, color: Color(0xFFE65100), size: 18),
                            ],
                          ),
                        ),

                      // Campus Landmarks
                      if (_showLocations)
                        for (final l in widget.locations)
                          Marker(
                            point: LatLng(l.lat, l.lng),
                            width: 130,
                            height: 48,
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFF1565C0), width: 1),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                                  ),
                                  child: Text(
                                    l.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.place, color: Color(0xFF1565C0), size: 18),
                              ],
                            ),
                          ),
                    ],

                    // Live GPS dot if available
                    if (_myPosition != null)
                      Marker(
                        point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Google Logo Attribution (Bottom-Left)
            Positioned(
              left: 10,
              bottom: widget.path.isNotEmpty ? 46 : 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('o', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('o', style: TextStyle(color: Color(0xFFFBBC05), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('g', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('l', style: TextStyle(color: Color(0xFF34A853), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('e', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),

            // Top Control Overlay: Satellite / Street & Re-center
            if (widget.showControls)
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: Row(
                  children: [
                    // Satellite / Street Toggle
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _isSatellite = !_isSatellite),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSatellite ? Icons.map : Icons.satellite_alt,
                                size: 16,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isSatellite ? 'Street' : 'Satellite',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (widget.path.isEmpty && widget.locations.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: _showLocations ? const Color(0xFF0B5D34) : Colors.white,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _showLocations = !_showLocations),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showLocations ? Icons.place : Icons.place_outlined,
                                  size: 16,
                                  color: _showLocations ? Colors.white : Colors.black87,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _showLocations ? 'Landmarks: On' : 'Landmarks: Off',
                                  style: TextStyle(
                                    color: _showLocations ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Re-center button
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          setState(() => _selectedRoute = null);
                          _fit();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.center_focus_strong, size: 20, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Route Filter Strip (Horizontally scrollable route selection when viewing campus network)
            if (widget.showControls && widget.path.isEmpty && uniqueRouteNames.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // "All Routes" chip
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedRoute = null);
                          _fit();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedRoute == null
                                ? const Color(0xFF263238)
                                : Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedRoute == null ? Colors.black87 : Colors.grey.shade400,
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 3),
                            ],
                          ),
                          child: Text(
                            'All Routes (${uniqueRouteNames.length})',
                            style: TextStyle(
                              color: _selectedRoute == null ? Colors.white : Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final name in uniqueRouteNames)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRoute = _selectedRoute == name ? null : name;
                              });
                              _fit();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedRoute == name
                                    ? getRouteColor(name)
                                    : Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: getRouteColor(name),
                                  width: _selectedRoute == name ? 1.6 : 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 3),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _selectedRoute == name ? Colors.white : getRouteColor(name),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: _selectedRoute == name ? Colors.white : Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Distance indicator floating pill showing distance along the line
            if (widget.path.isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten, size: 15, color: Color(0xFF1565C0)),
                        const SizedBox(width: 5),
                        Text(
                          'Distance: ${formatKm(_totalDistanceKm)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
