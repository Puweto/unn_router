import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api.dart';
import '../models.dart';
import '../routing.dart';
import 'result_screen.dart';

/// Input design (Fig 3.4): current location, destination, Search Route.
/// Activity diagram: select current location -> select destination -> validate -> search.
class HomeScreen extends StatefulWidget {
  final Reference reference;
  final ValueNotifier<({String from, String to})> draft;
  const HomeScreen({super.key, required this.reference, required this.draft});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  String? _error;
  String? _info;
  bool _busy = false;
  Origin? _gps; // set by "Use my location"
  static const _gpsLabel = 'My location';

  @override
  void initState() {
    super.initState();
    _applyDraft();
    widget.draft.addListener(_applyDraft);
  }

  void _applyDraft() {
    _from.text = widget.draft.value.from;
    _to.text = widget.draft.value.to;
  }

  @override
  void dispose() {
    widget.draft.removeListener(_applyDraft);
    _from.dispose();
    _to.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  Place? _find(String text) {
    final t = text.trim().toLowerCase();
    for (final p in widget.reference.allPlaces) {
      if (p.name.toLowerCase() == t) return p;
    }
    return null;
  }

  void _swap() {
    if (_from.text.trim() == _gpsLabel || _to.text.trim() == _gpsLabel) {
      setState(() => _info = 'Your GPS position can only be the starting point.');
      return;
    }
    final f = _from.text;
    _from.text = _to.text;
    _to.text = f;
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _error = null;
      _info = 'Finding you…';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on GPS / location services, or pick your location from the list.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission was denied. Please pick your location from the list.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      final near = nearestPlace(pos.latitude, pos.longitude, widget.reference.allPlaces);
      if (near == null || near.$2 > 2) {
        throw 'You appear to be outside the campus. Please pick your location from the list.';
      }
      if (!mounted) return;
      setState(() {
        _gps = Origin(_gpsLabel, pos.latitude, pos.longitude);
        _from.text = _gpsLabel;
        final typeStr = near.$1.isBusStop ? 'bus stop' : 'landmark';
        _info = 'Using your GPS position (near ${near.$1.name} $typeStr).';
      });
    } catch (e) {
      if (mounted) setState(() { _info = null; _error = e is String ? e : 'Could not get your location. Please pick it from the list.'; });
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() { _error = null; _info = null; });
    widget.draft.removeListener(_applyDraft);
    widget.draft.value = (from: _from.text, to: _to.text);
    widget.draft.addListener(_applyDraft);
    // Validate current location and destination inputs
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty) {
      return setState(() => _error = 'Please enter both your current location and your destination.');
    }
    final usingGps = _gps != null && _from.text.trim() == _gpsLabel;
    final a = usingGps ? null : _find(_from.text), b = _find(_to.text);
    if (!usingGps && a == null) return setState(() => _error = 'We don\'t know "${_from.text.trim()}". Choose a location or bus stop from the list.');
    if (b == null) return setState(() => _error = 'We don\'t know "${_to.text.trim()}". Choose a location or bus stop from the list.');
    if (a != null && (a.uniqueKey == b.uniqueKey || a.name.toLowerCase() == b.name.toLowerCase())) {
      return setState(() => _error = 'Your current location and destination are the same place.');
    }
    setState(() => _busy = true);
    try {
      // Dijkstra runs in the app on the shuttle network downloaded from MySQL.
      final origin = usingGps ? _gps! : Origin.fromPlace(a!);
      final result = planJourney(origin, b, widget.reference);
      if (result.found) {
        // Saving history must never block the result.
        try {
          await Api.saveHistory(result.origin, result.destination);
        } catch (_) {}
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result, reference: widget.reference)));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong while planning the route. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _placeField(String label, TextEditingController c, FocusNode f, Widget trailing) {
    return RawAutocomplete<Place>(
      textEditingController: c,
      focusNode: f,
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        final all = widget.reference.allPlaces;
        return q.isEmpty ? all : all.where((l) => l.name.toLowerCase().contains(q));
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              decoration: InputDecoration(
                labelText: label,
                hintText: 'Type or pick a location or bus stop',
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 330),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: o.isBusStop
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        o.isBusStop ? Icons.directions_bus : Icons.place,
                        size: 16,
                        color: o.isBusStop
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    title: Text(
                      o.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      o.isBusStop ? 'Bus Stop' : 'Campus Location',
                      style: TextStyle(
                        fontSize: 11,
                        color: o.isBusStop
                            ? const Color(0xFFE65100)
                            : Colors.grey.shade600,
                        fontWeight: o.isBusStop ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = (Session.user?['fullname'] as String?)?.split(' ').first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (first != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Hello, $first 👋 Where to?')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _placeField('Select or enter your current location', _from, _fromFocus,
                    IconButton.outlined(onPressed: _useMyLocation, tooltip: 'Use my location', icon: const Icon(Icons.my_location))),
                const SizedBox(height: 16),
                _placeField('Select or enter your destination', _to, _toFocus,
                    IconButton.outlined(onPressed: _swap, tooltip: 'Swap', icon: const Icon(Icons.swap_vert))),
                if (_info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _search,
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Search Route'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
