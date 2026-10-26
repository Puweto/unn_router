import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class HistoryScreen extends StatefulWidget {
  final void Function(String from, String to) onSearchAgain;
  const HistoryScreen({super.key, required this.onSearchAgain});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<HistoryItem>> _future = Api.history();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoryItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}', textAlign: TextAlign.center)));
        final rows = snap.data!;
        if (rows.isEmpty) return const Center(child: Text('Your searches will show up here.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = rows[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${h.source} → ${h.destination}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(formatWhen(h.date)),
              trailing: OutlinedButton(onPressed: () => widget.onSearchAgain(h.source, h.destination), child: const Text('Search again')),
            );
          },
        );
      },
    );
  }
}
