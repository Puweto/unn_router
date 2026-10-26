import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../models.dart';

/// Director of Transport: tap the exact spot on the map (satellite view helps) to set a
/// location or bus stop's coordinates, instead of typing latitude and longitude by hand.
class PickLocationScreen extends StatefulWidget {
  final LatLng? initial;
  final List<MapPoint> others; // existing places, shown for reference
  const PickLocationScreen({super.key, this.initial, this.others = const []});
  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _picked;
  bool _isSatellite = true;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.others;
    final start = widget.initial ??
        (others.isEmpty
            ? const LatLng(kCampusLat, kCampusLng)
            : LatLng(
                others.map((p) => p.lat).reduce((a, b) => a + b) / others.length,
                others.map((p) => p.lng).reduce((a, b) => a + b) / others.length,
              ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick on map'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt, color: Colors.white, size: 18),
            label: Text(_isSatellite ? 'Street' : 'Satellite', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: start,
                initialZoom: 17.0,
                minZoom: 12.0,
                maxZoom: 19.0,
                onTap: (tapPosition, point) => setState(() => _picked = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ng.edu.unn.unn_route_navigator',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    for (final o in others)
                      Marker(
                        point: LatLng(o.lat, o.lng),
                        width: 120,
                        height: 44,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blueAccent, width: 1),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.place, color: Colors.blueAccent, size: 10),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      o.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 12),
                          ],
                        ),
                      ),
                    if (_picked != null)
                      Marker(
                        point: _picked!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_picked == null
                      ? 'Tap the map to place the pin.'
                      : 'Latitude ${_picked!.latitude.toStringAsFixed(7)}   Longitude ${_picked!.longitude.toStringAsFixed(7)}'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
                    child: const Text('Use these coordinates'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
