# Campus Route Navigator: Flutter app

Dart / Flutter app (Android and iOS). It needs the API server from `../server` running, and a Google Maps API key. See the main `README.md` for the whole setup; this file is the app-specific part.

Requires Flutter 3.27 or newer (Dart 3.3+).

## 1. Create the platform folders (one time)
This folder contains the Dart code only. Generate `android/` and `ios/` around it:
```bash
cd flutter_app
flutter create . --project-name unn_route_navigator --org ng.edu.unn
flutter pub get
```
If it offers to overwrite `lib/`, `test/` or `pubspec.yaml`, keep ours.
`flutter create` also generates a `test/widget_test.dart`; ours replaces it, so keep ours.

## 2. Android permissions
`android/app/src/main/AndroidManifest.xml`, inside `<manifest>` and above `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
Add `android:usesCleartextTraffic="true"` to the `<application ...>` tag while the server uses plain `http://` on your computer. Remove it once the API is served over HTTPS.

## 3. Google Maps key
**Android**: inside `<application>` in the same manifest:
```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_GOOGLE_MAPS_KEY"/>
```
If the build says `minSdkVersion` is too low, open `android/app/build.gradle(.kts)` and set `minSdk = 23` (or higher).

**iOS**: in `ios/Runner/AppDelegate.swift` add `import GoogleMaps` and, inside `application(_:didFinishLaunchingWithOptions:)`, `GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_KEY")`. In `ios/Runner/Info.plist` add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show where you are on the campus map and to start routes from your position.</string>
```
Do not publish your key in a public repository. Restrict it to your app (package name + SHA-1 on Android) in Google Cloud.

## 4. Run
```bash
flutter run                                                        # Android emulator, server on your computer
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000    # real phone: your computer's IP
flutter test
```

## Screens (Chapter 3 mapping)
| File | Chapter 3 |
|---|---|
| `main.dart`, `screens/splash_screen.dart` | Display splash screen, is user information available? |
| `screens/auth_screen.dart` | Enter / save user information (name only) |
| `screens/home_screen.dart` | Input design: current location (list or GPS), destination, Search Route |
| `routing.dart` | Retrieve route data, calculate shortest route (Dijkstra) |
| `screens/result_screen.dart`, `widgets/route_map.dart` | Output design: route on Google Maps, distance, time, bus stops |
| `screens/stops_screen.dart` | View bus stops / locations, view Google Maps |
| `screens/history_screen.dart` | View route history |
| `screens/director_login_screen.dart`, `screens/director_screen.dart`, `screens/pick_location_screen.dart` | Director of Transport dashboard |
| `api.dart` | Mobile app to MySQL (through the Dart server) |

## Status
Written without a Flutter or Dart SDK available, so it has **not been compiled or run yet**. The first `flutter pub get && flutter analyze` may show small fixes (a deprecation or a package-version difference). Send me the exact messages and I will fix them.
