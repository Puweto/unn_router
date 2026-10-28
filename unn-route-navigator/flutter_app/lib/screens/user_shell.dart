import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'stops_screen.dart';

/// Bottom-navigation shell for Freshmen / Visitors: Find route, Bus stops, History.
class UserShell extends StatefulWidget {
  const UserShell({super.key});
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;
  late Future<Reference> _ref;
  // Shared between Home and History ("Search again").
  final ValueNotifier<({String from, String to})> _draft = ValueNotifier((from: '', to: ''));

  @override
  void initState() {
    super.initState();
    _ref = Api.reference();
    if (Session.user == null) {
      Api.me().then((u) {
        if (mounted) setState(() => Session.user = u);
      }).catchError((Object _) {});
    }
  }

  void _reload() {
    setState(() {
      _ref = Api.reference();
    });
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Campus Route Navigator', 'Bus stops & locations', 'Route history'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from database',
            onPressed: () {
              _reload();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reloaded latest data from MySQL database'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const TextButton(onPressed: Session.end, child: Text('Sign out', style: TextStyle(color: Color(0xFF0B5D34), fontWeight: FontWeight.bold))),
        ],
      ),
      body: FutureBuilder<Reference>(
        future: _ref,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ]),
              ),
            );
          }
          final ref = snap.data!;
          return switch (_tab) {
            0 => HomeScreen(reference: ref, draft: _draft),
            1 => StopsScreen(reference: ref, onRefresh: () async => _reload()),
            _ => HistoryScreen(onSearchAgain: (from, to) {
                _draft.value = (from: from, to: to);
                setState(() => _tab = 0);
              }),
          };
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Find route'),
          NavigationDestination(icon: Icon(Icons.directions_bus_outlined), selectedIcon: Icon(Icons.directions_bus), label: 'Bus stops'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
