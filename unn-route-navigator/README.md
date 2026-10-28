# Campus Route Navigator

Campus route navigator for the University of Nigeria, Nsukka. **100% Dart and Flutter.**

| Part | Technology | Folder |
|---|---|---|
| Mobile app (Android / iOS) | Flutter + Dart | `flutter_app/` |
| Map and GPS | Google Maps (`google_maps_flutter`) and `geolocator` | inside the app |
| API server | Dart (`shelf`) | `server/` |
| Database | MySQL, 6 tables: users, director_of_transport, locations, bus_stops, routes, route_history | `db/` (`schema.mysql.sql`, `sample_data.sql`, `useful_queries.sql`) |

How it works: the app signs the user in with a **name only**, downloads the locations, bus stops and shuttle routes from MySQL (through the Dart server), runs **Dijkstra's shortest-path algorithm** on the shuttle network (`flutter_app/lib/routing.dart`) from the user's GPS position or chosen location to the destination (walking to the nearest stop, riding, walking on), and shows the route, distance and travel time on **Google Maps**. Every search is saved to the user's history. The Director of Transport manages locations, bus stops and shuttle routes from an admin dashboard inside the same app.

## Setup (Windows / macOS / Linux, VS Code)

### 1. Install
| Tool | Notes |
|---|---|
| **VS Code** + the **Flutter** extension (installs Dart support) | code.visualstudio.com |
| **Flutter SDK 3.27+** (includes the Dart SDK) | docs.flutter.dev/get-started/install. Run `flutter doctor` and fix any ✗. |
| **Android Studio** | for the Android SDK and emulator (SDK Manager: Android SDK, Platform-Tools, Command-line Tools, Emulator). Create a virtual phone with a **"Google APIs"/"Google Play"** system image, or Google Maps will not draw. |
| **MySQL** | MySQL Community Server + Workbench, or XAMPP (start the *MySQL* module). |
| **Git** | Windows only, needed by Flutter. |

### 2. MySQL
Start MySQL. The server creates the database `unn_route_navigator`, all tables and sample data by itself on first start. It only needs a MySQL user that may create databases (the default `root`).

### 3. Run the API server (terminal 1)
```bash
cd server
dart pub get
dart run bin/server.dart
```
You should see `UNN Route Navigator API running on http://localhost:3000`.

Settings are environment variables. Defaults: MySQL at `127.0.0.1:3306`, user `root`, **empty password** (typical for XAMPP). If your MySQL root has a password:

```powershell
# Windows PowerShell
$env:DB_PASSWORD="your-password"; $env:DIRECTOR_PASSWORD="choose-a-strong-one"; $env:TOKEN_SECRET="a-long-random-string"; dart run bin/server.dart
```
```bash
# macOS / Linux
DB_PASSWORD=your-password DIRECTOR_PASSWORD=choose-a-strong-one TOKEN_SECRET=a-long-random-string dart run bin/server.dart
```
Other variables: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME`, `PORT`, `DIRECTOR_USERNAME`, `DB_SECURE`.
The first start creates the Director account `director` with password `director123` unless `DIRECTOR_PASSWORD` is set. **Change it before real use.**

*MySQL 8 "authentication" error?* Either run `ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-password';` in MySQL, or start the server with `DB_SECURE=true`.

### 4. Google Maps key (needed for the map)
1. Go to console.cloud.google.com, create a project, and **enable "Maps SDK for Android"** (and "Maps SDK for iOS" if you build for iPhone).
2. Create an **API key** (APIs & Services, Credentials). Google requires a billing account for Maps Platform; check their current free allowance, which is normally plenty for a student project.
3. Put it in the app (see `flutter_app/README.md`, step 3).

### 5. Run the app (terminal 2)
```bash
cd flutter_app
flutter create . --project-name unn_route_navigator --org ng.edu.unn   # one time: generates android/ and ios/
flutter pub get
flutter run            # emulator: reaches the server at http://10.0.2.2:3000
```
On a real phone (same Wi-Fi as the computer): `flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:3000` (allow `dart` through the Windows firewall).

Full platform steps (permissions, Maps key): `flutter_app/README.md`.

### Tests
```bash
cd flutter_app && flutter test      # Dijkstra, journey planner, app start-up
cd server && dart test              # tokens, password hashing, distance maths
```

## Important: make the map accurate

The sample data is **only an example**. Landmark names are real, but the coordinates are approximate and the shuttle lines are made up. With Google Maps the pins will land close to, not exactly on, the real places.

The Director of Transport fixes this in the app: sign in as Director, open **Locations** or **Bus stops**, tap **Edit**, then **Pick on map**. Switch to *Satellite*, tap the exact spot, and save. For **Bus routes**, leave *Distance* empty and it is calculated from the two bus stops' positions, or type the measured distance. Travel times use 5 km/h walking, 20 km/h on the bus and 5 minutes' wait per shuttle line (constants in `flutter_app/lib/routing.dart`).

## What changed in Chapter 3 (update your document)

- **Tables:** the database has 6 tables. The `roads` table (Table 3.4) is removed; the `routes` table (bus stop to bus stop, with distance) is the network Dijkstra searches. Update the class diagram (remove `Road`) and the list of tables in 3.3.3.
- **Table 3.1 users:** `user_id`, `fullname` (unique), `date_registered`. Email, password and role are gone; sign-in is by name. The Director keeps `username` and a hashed `password`.
- **Use case / activity / sequence diagrams:** "Provide User Information" is just the name. Route calculation (Dijkstra) runs inside the Flutter app after it fetches route data from MySQL; Google Maps displays the result.
- **Class diagram:** `User` has `userId`, `fullName`, `dateRegistered`; no email.
- **Tools statement:** Flutter and Dart (app and API server), Google Maps API, GPS (`geolocator`), MySQL.

## Limits to know about

- **Name-only sign-in is not secure authentication.** Anyone who types the same name signs in as that person and sees their search history (only place names and times are stored). Two students with the same name share a profile. This is what the supervisor asked for; a PIN or Google sign-in would fix it.
- **No live bus tracking.** "Real-time" here means the user's own live GPS position on the map. Shuttle buses have no GPS feed, so arrival times are estimates.
- **Route lines are straight between stops**, not bent along the road shape. Add more bus stops or road points on long curves, or ask for Google Directions support.
