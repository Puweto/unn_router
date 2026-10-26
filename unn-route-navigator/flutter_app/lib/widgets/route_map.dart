import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../models.dart';

/// Requests location permission and tells whether the blue "you are here" dot can be shown.
Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

LatLng _ll(MapPoint p) => LatLng(p.lat, p.lng);

/// Brand & line colors for UNN campus shuttle routes.
Color getRouteColor(String name) {
  final n = name.trim().toLowerCase();
  if (n.contains('main')) return const Color(0xFF1976D2); // Vibrant Royal Blue
  if (n.contains('town')) return const Color(0xFFF57C00); // Amber Orange
  if (n.contains('ziks')) return const Color(0xFF8E24AA); // Royal Violet
  if (n.contains('agric')) return const Color(0xFF2E7D32); // Forest Green
  if (n.contains('hilltop') || n.contains('second gate')) return const Color(0xFF00897B); // Teal
  return const Color(0xFF455A64); // Slate Grey
}

/// Campus map displaying:
/// - Distinct color-coded shuttle routes with corridor name badges
/// - Clear campus location landmark name tags
/// - Prominent bus stop name tags
/// - Start & End pins with origin/destination names
/// - Interactive route filter strip & label visibility toggle
class RouteMap extends StatefulWidget {
  final List<MapPoint> path; // origin, stops..., destination
  final List<MapPoint> stops; // bus stops to mark
  final List<MapPoint> locations; // campus locations to mark
  final List<List<MapPoint>> network; // fallback faint network
  final List<NamedRouteSegment> namedRoutes; // rich shuttle routes with names
  final List<String> pathLines; // route line names used in the active path
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
    this.walkingTimeMin,
    this.height = 340,
    this.showControls = true,
  });

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _mapController = MapController();
  Position? _myPosition;
  bool _isSatellite = false;
  bool _showLabels = true;
  String? _selectedRoute; // null = all routes

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

  List<MapPoint> get _all => [
        ...widget.path,
        ...widget.stops,
        ...widget.locations,
        for (final r in widget.namedRoutes) ...[r.start, r.end],
        for (final r in widget.network) ...r,
      ];

  void _fit() {
    final pts = widget.path.isNotEmpty
        ? widget.path
        : (_selectedRoute != null
            ? widget.namedRoutes
                .where((r) => r.routeName == _selectedRoute)
                .expand((r) => [r.start, r.end])
                .toList()
            : _all);

    if (pts.isEmpty) return;
    final coords = pts.map((p) => LatLng(p.lat, p.lng)).toList();
    if (coords.length == 1) {
      _mapController.move(coords.first, 17.0);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coords,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          maxZoom: 17.5,
        ),
      );
    }
  }

  /// Calculates the best midpoint for each unique route line to place its name badge.
  Map<String, LatLng> _calculateRouteMidpoints() {
    final grouped = <String, List<NamedRouteSegment>>{};
    for (final seg in widget.namedRoutes) {
      grouped.putIfAbsent(seg.routeName, () => []).add(seg);
    }

    final midpoints = <String, LatLng>{};
    for (final entry in grouped.entries) {
      final segs = entry.value;
      if (segs.isEmpty) continue;
      // Pick the segment with the greatest distance to place the label badge
      NamedRouteSegment best = segs.first;
      for (final s in segs) {
        if (s.distance > best.distance) best = s;
      }
      midpoints[entry.key] = LatLng(
        (best.start.lat + best.end.lat) / 2,
        (best.start.lng + best.end.lng) / 2,
      );
    }
    return midpoints;
  }

  void _showPlaceDetails(String title, String category, LatLng coord) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: category.contains('Stop')
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.contains('Stop')
                          ? Icons.directions_bus
                          : Icons.location_on,
                      color: category.contains('Stop')
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.my_location, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Coordinates: ${coord.latitude.toStringAsFixed(6)}, ${coord.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _mapController.move(coord, 18.0);
                },
                icon: const Icon(Icons.center_focus_strong, size: 18),
                label: const Text('Center on Map'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.path.isNotEmpty ? widget.path : _all;
    final initialCenter = pts.isEmpty
        ? const LatLng(kCampusLat, kCampusLng)
        : LatLng(
            pts.map((p) => p.lat).reduce((a, b) => a + b) / pts.length,
            pts.map((p) => p.lng).reduce((a, b) => a + b) / pts.length,
          );

    final uniqueRouteNames = widget.namedRoutes
        .map((r) => r.routeName)
        .toSet()
        .toList();

    final routeMidpoints = _calculateRouteMidpoints();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 16.0,
                minZoom: 11.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: _fit,
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ng.edu.unn.unn_route_navigator',
                  maxZoom: 19,
                ),
                // Shuttle network polylines
                PolylineLayer(
                  polylines: [
                    // If namedRoutes is provided, render each with its distinctive route color
                    if (widget.namedRoutes.isNotEmpty)
                      for (final seg in widget.namedRoutes) ...[
                        // Casing for contrast
                        Polyline(
                          points: [_ll(seg.start), _ll(seg.end)],
                          color: _selectedRoute == null || _selectedRoute == seg.routeName
                              ? Colors.black.withValues(alpha: 0.35)
                              : Colors.transparent,
                          strokeWidth: 6.5,
                          strokeCap: StrokeCap.round,
                        ),
                        // Colored Route Line
                        Polyline(
                          points: [_ll(seg.start), _ll(seg.end)],
                          color: _selectedRoute == null
                              ? getRouteColor(seg.routeName)
                              : (_selectedRoute == seg.routeName
                                  ? getRouteColor(seg.routeName)
                                  : getRouteColor(seg.routeName).withValues(alpha: 0.2)),
                          strokeWidth: _selectedRoute == seg.routeName ? 6.0 : 4.5,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ]
                    else
                      // Fallback to plain network lines
                      for (var i = 0; i < widget.network.length; i++)
                        Polyline(
                          points: widget.network[i].map(_ll).toList(),
                          color: Colors.grey.shade400.withValues(alpha: 0.8),
                          strokeWidth: 3,
                        ),

                    // Active searched navigation path
                    if (widget.path.length > 1) ...[
                      // High-contrast outer casing
                      Polyline(
                        points: widget.path.map(_ll).toList(),
                        color: const Color(0xFF0D47A1),
                        strokeWidth: 8.5,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Vibrant blue navigation polyline
                      Polyline(
                        points: widget.path.map(_ll).toList(),
                        color: const Color(0xFF00B0FF),
                        strokeWidth: 5.5,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ],
                ),
                // Markers Layer (Routes, Locations, Bus Stops, Start/End)
                MarkerLayer(
                  markers: [
                    // 1. ROUTE NAME BADGES along the route polylines
                    if (_showLabels && widget.namedRoutes.isNotEmpty)
                      for (final entry in routeMidpoints.entries)
                        if (_selectedRoute == null || _selectedRoute == entry.key)
                          Marker(
                            point: entry.value,
                            width: 146,
                            height: 32,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRoute =
                                      _selectedRoute == entry.key ? null : entry.key;
                                });
                                _fit();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: getRouteColor(entry.key),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.directions_bus,
                                        size: 11, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        entry.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                    // 2. ACTIVE PATH ROUTE CALLOUT (if searching a route)
                    if (widget.path.length > 1)
                      Marker(
                        point: LatLng(
                          (widget.path.first.lat + widget.path.last.lat) / 2,
                          (widget.path.first.lng + widget.path.last.lng) / 2,
                        ),
                        width: 170,
                        height: 30,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.pathLines.isNotEmpty
                                    ? Icons.directions_bus
                                    : Icons.directions_walk,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.pathLines.isNotEmpty
                                      ? widget.pathLines.join(' · ')
                                      : (widget.walkingTimeMin != null
                                          ? 'Est. Walk: ${widget.walkingTimeMin} min'
                                          : 'Walking Route'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 3. CAMPUS LOCATIONS
                    for (final l in widget.locations)
                      Marker(
                        point: _ll(l),
                        width: _showLabels ? 130 : 30,
                        height: _showLabels ? 46 : 30,
                        alignment: _showLabels
                            ? Alignment.bottomCenter
                            : Alignment.center,
                        child: GestureDetector(
                          onTap: () => _showPlaceDetails(
                              l.name, 'Campus Landmark', _ll(l)),
                          child: _showLabels
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 125),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.96),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFF1565C0),
                                            width: 1.2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3,
                                            offset: Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.place,
                                              size: 11,
                                              color: Color(0xFF1565C0)),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              l.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF0D47A1),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down,
                                        color: Color(0xFF1565C0), size: 14),
                                  ],
                                )
                              : const Icon(Icons.place,
                                  color: Color(0xFF1565C0), size: 26),
                        ),
                      ),

                    // 4. BUS STOPS
                    for (final s in widget.stops)
                      Marker(
                        point: _ll(s),
                        width: _showLabels ? 130 : 28,
                        height: _showLabels ? 46 : 28,
                        alignment: _showLabels
                            ? Alignment.bottomCenter
                            : Alignment.center,
                        child: GestureDetector(
                          onTap: () => _showPlaceDetails(
                              s.name, 'Campus Bus Stop', _ll(s)),
                          child: _showLabels
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 125),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8E1)
                                            .withValues(alpha: 0.96),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFE65100),
                                            width: 1.3),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3,
                                            offset: Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.directions_bus,
                                              size: 11,
                                              color: Color(0xFFE65100)),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              s.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF3E2723),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down,
                                        color: Color(0xFFE65100), size: 14),
                                  ],
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5C542),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black87, width: 1.5),
                                  ),
                                  child: const Icon(Icons.directions_bus,
                                      size: 15, color: Color(0xFF3A2D00)),
                                ),
                        ),
                      ),

                    // 5. START ORIGIN PIN
                    if (widget.path.isNotEmpty)
                      Marker(
                        point: _ll(widget.path.first),
                        width: 140,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B5D34),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(0, 1.5))
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trip_origin,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Start: ${widget.path.first.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.location_on,
                                color: Color(0xFF0B5D34), size: 26),
                          ],
                        ),
                      ),

                    // 6. DESTINATION PIN
                    if (widget.path.length > 1)
                      Marker(
                        point: _ll(widget.path.last),
                        width: 140,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC62828),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(0, 1.5))
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sports_score,
                                      size: 11, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'End: ${widget.path.last.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.location_on,
                                color: Color(0xFFC62828), size: 26),
                          ],
                        ),
                      ),

                    // 7. CURRENT GPS POSITION
                    if (_myPosition != null)
                      Marker(
                        point: LatLng(
                            _myPosition!.latitude, _myPosition!.longitude),
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Top Control Overlay: Satellite / Street & Names Toggle
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSatellite ? Icons.map : Icons.satellite_alt,
                                size: 15,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isSatellite ? 'Street' : 'Satellite',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Names / Labels Toggle
                    Material(
                      color: _showLabels
                          ? const Color(0xFF0B5D34)
                          : Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _showLabels = !_showLabels),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showLabels ? Icons.label : Icons.label_off,
                                size: 15,
                                color: _showLabels ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showLabels ? 'Names: On' : 'Names: Off',
                                style: TextStyle(
                                  color: _showLabels
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

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
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.center_focus_strong,
                              size: 18, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Route Filter Strip (Horizontally scrollable route selection)
            if (widget.showControls && uniqueRouteNames.isNotEmpty)
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _selectedRoute == null
                                ? const Color(0xFF263238)
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _selectedRoute == null
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                                width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 3)
                            ],
                          ),
                          child: Text(
                            'All Routes (${uniqueRouteNames.length})',
                            style: TextStyle(
                              color: _selectedRoute == null
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Individual route chips
                      for (final name in uniqueRouteNames)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRoute =
                                    _selectedRoute == name ? null : name;
                              });
                              _fit();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: _selectedRoute == name
                                    ? getRouteColor(name)
                                    : Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: getRouteColor(name),
                                  width: _selectedRoute == name ? 1.6 : 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 3)
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _selectedRoute == name
                                          ? Colors.white
                                          : getRouteColor(name),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: _selectedRoute == name
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 10.5,
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
          ],
        ),
      ),
    );
  }
}
