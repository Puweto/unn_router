import 'package:flutter/material.dart';
import '../api.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';
import 'pick_location_screen.dart';

enum _Kind { text, number, stop, loc }

class _Field {
  final String key, label;
  final _Kind kind;
  final bool required;
  final String? hint;
  const _Field(this.key, this.label, this.kind, {this.required = true, this.hint});
}

const _autoDistance = 'Leave empty to calculate automatically from the map positions';

class _Resource {
  final String label, path, idKey;
  final List<String> columns;
  final List<_Field> fields;
  final bool readOnly, noDelete;
  const _Resource(this.label, this.path, this.idKey, this.columns, {this.fields = const [], this.readOnly = false, this.noDelete = false});
  String get writePath => '/admin/$path';
}

const _resources = <_Resource>[
  _Resource('Locations', 'locations', 'location_id', ['location_name', 'latitude', 'longitude'],
      fields: [_Field('location_name', 'Name', _Kind.text), _Field('latitude', 'Latitude', _Kind.number), _Field('longitude', 'Longitude', _Kind.number)]),
  _Resource('Bus stops', 'bus-stops', 'stop_id', ['stop_name', 'latitude', 'longitude'],
      fields: [_Field('stop_name', 'Name', _Kind.text), _Field('latitude', 'Latitude', _Kind.number), _Field('longitude', 'Longitude', _Kind.number)]),
  _Resource('Bus routes', 'routes', 'route_id', ['route_name', 'start_stop', 'end_stop', 'distance'],
      fields: [
        _Field('route_name', 'Line name', _Kind.text, required: false),
        _Field('start_stop', 'From stop', _Kind.stop),
        _Field('end_stop', 'To stop', _Kind.stop),
        _Field('distance', 'Distance (km)', _Kind.number, required: false, hint: _autoDistance),
      ]),
  _Resource('Users', 'users', 'user_id', ['fullname', 'role', 'date_registered'], readOnly: true),
  _Resource('Search history', 'history', 'history_id', ['fullname', 'source', 'destination', 'search_date'], readOnly: true, noDelete: true),
];

/// Director of Transport: Manage Locations / Bus Stops / Bus Routes / Road Network / Users, View Search History.
class DirectorScreen extends StatefulWidget {
  const DirectorScreen({super.key});
  @override
  State<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends State<DirectorScreen> {
  int _tab = 0;
  late Future<(Reference, List<Map<String, dynamic>>)> _data;

  _Resource get _res => _resources[_tab];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final res = _res;
    // Public list for editable resources, admin endpoints for users and history.
    final listPath = res.readOnly ? '/admin/${res.path}' : '/${res.path}';
    _data = () async {
      final ref = await Api.reference();
      final rows = await Api.adminList(listPath);
      return (ref, rows);
    }();
  }

  void _refresh() => setState(_load);

  String _cell(Map<String, dynamic> row, String col, Reference ref) {
    final v = row[col];
    if (v == null) return '—';
    if (col == 'start_stop' || col == 'end_stop') return ref.stopName(v as int) ?? '$v';
    if (col == 'start_location' || col == 'end_location') return ref.locationName(v as int) ?? '$v';
    if (col == 'date_registered' || col == 'search_date') return formatWhen('$v');
    return '$v';
  }

  Future<void> _edit(Reference ref, {Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(resource: _res, reference: ref, row: row),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.adminDelete(_res.writePath, row[_res.idKey] as int);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Director of Transport'),
        actions: const [TextButton(onPressed: Session.end, child: Text('Sign out', style: TextStyle(color: Colors.white)))],
      ),
      floatingActionButton: _res.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final (ref, _) = await _data;
                if (mounted) _edit(ref);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: _resources.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(_resources[i].label),
                selected: i == _tab,
                onSelected: (_) => setState(() {
                  _tab = i;
                  _load();
                }),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<(Reference, List<Map<String, dynamic>>)>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}', textAlign: TextAlign.center)));
                }
                final (ref, rows) = snap.data!;
                if (rows.isEmpty) return Center(child: Text('No ${_res.label.toLowerCase()} yet.'));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final cols = _res.columns;
                    return Card(
                      child: ListTile(
                        title: Text(_cell(row, cols.first, ref), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([for (final c in cols.skip(1)) '${c.replaceAll('_', ' ')}: ${_cell(row, c, ref)}'].join('\n')),
                        isThreeLine: cols.length > 2,
                        trailing: _res.noDelete
                            ? null
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                if (!_res.readOnly) IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => _edit(ref, row: row)),
                                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(row)),
                              ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  final _Resource resource;
  final Reference reference;
  final Map<String, dynamic>? row;
  const _EditSheet({required this.resource, required this.reference, this.row});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _text;
  final Map<String, int?> _ids = {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _text = {};
    for (final f in widget.resource.fields) {
      final v = widget.row?[f.key];
      if (f.kind == _Kind.stop || f.kind == _Kind.loc) {
        _ids[f.key] = v as int?;
      } else {
        _text[f.key] = TextEditingController(text: v == null ? '' : '$v');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final lat = double.tryParse(_text['latitude']!.text.trim());
    final lng = double.tryParse(_text['longitude']!.text.trim());
    final r = widget.resource;
    final others = [
      for (final p in (r.path == 'bus-stops' ? widget.reference.stops : widget.reference.locations)) p.point,
    ];
    final picked = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => PickLocationScreen(initial: lat != null && lng != null ? LatLng(lat, lng) : null, others: others),
    ));
    if (picked != null && mounted) {
      setState(() {
        _text['latitude']!.text = picked.latitude.toStringAsFixed(7);
        _text['longitude']!.text = picked.longitude.toStringAsFixed(7);
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final body = <String, dynamic>{};
    for (final f in widget.resource.fields) {
      if (f.kind == _Kind.text) {
        final t = _text[f.key]!.text.trim();
        body[f.key] = t.isEmpty ? null : t;
      } else if (f.kind == _Kind.number) {
        final t = _text[f.key]!.text.trim();
        body[f.key] = t.isEmpty ? null : double.parse(t);
      } else {
        body[f.key] = _ids[f.key];
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.adminSave(widget.resource.writePath, body, id: widget.row?[widget.resource.idKey] as int?);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.row == null ? 'Add: ${r.label}' : 'Edit: ${r.label}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final f in r.fields) ...[
                if (f.kind == _Kind.stop || f.kind == _Kind.loc)
                  DropdownButtonFormField<int>(
                    initialValue: _ids[f.key],
                    decoration: InputDecoration(labelText: f.label),
                    items: [
                      for (final p in (f.kind == _Kind.stop ? widget.reference.stops : widget.reference.locations)) DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => _ids[f.key] = v,
                    validator: (v) => v == null ? 'Choose one' : null,
                  )
                else
                  TextFormField(
                    controller: _text[f.key],
                    decoration: InputDecoration(labelText: f.label, helperText: f.hint, helperMaxLines: 2),
                    keyboardType: f.kind == _Kind.number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (f.kind == _Kind.number) {
                        if (t.isEmpty) return f.required ? 'Required' : null;
                        return double.tryParse(t) == null ? 'Enter a number' : null;
                      }
                      return f.required && t.isEmpty ? 'Required' : null;
                    },
                  ),
                const SizedBox(height: 12),
              ],
              if (_text.containsKey('latitude') && _text.containsKey('longitude')) ...[
                OutlinedButton.icon(onPressed: _pickOnMap, icon: const Icon(Icons.map_outlined), label: const Text('Pick on map')),
                const SizedBox(height: 12),
              ],
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
              FilledButton(onPressed: _busy ? null : _save, child: Text(widget.row == null ? 'Add' : 'Save changes')),
            ],
          ),
        ),
      ),
    );
  }
}
