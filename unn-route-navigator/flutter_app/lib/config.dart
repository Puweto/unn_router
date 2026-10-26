/// Address of the Dart API server (the `server/` folder of this project).
///
/// Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
/// The default is the Android emulator's alias for the computer it runs on.
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:3000');

/// Where the map opens when there is nothing to show yet (Nsukka campus, approximate).
const double kCampusLat = 6.8673;
const double kCampusLng = 7.4085;
