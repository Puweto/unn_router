/// Tables 3.1 to 3.7 of Chapter 3 (users is name-only, as required by the supervisor).
/// The same statements are in ../../db/schema.mysql.sql for reference or manual import.
const schemaStatements = <String>[
  '''CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    fullname VARCHAR(100) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    date_registered DATETIME NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS director_of_transport (
    directorId INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS locations (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL UNIQUE,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS bus_stops (
    stop_id INT AUTO_INCREMENT PRIMARY KEY,
    stop_name VARCHAR(100) NOT NULL UNIQUE,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS routes (
    route_id INT AUTO_INCREMENT PRIMARY KEY,
    route_name VARCHAR(100) NULL,
    start_stop INT NOT NULL,
    end_stop INT NOT NULL,
    distance DOUBLE NOT NULL,
    FOREIGN KEY (start_stop) REFERENCES bus_stops(stop_id) ON DELETE CASCADE,
    FOREIGN KEY (end_stop) REFERENCES bus_stops(stop_id) ON DELETE CASCADE
  )''',
  '''CREATE TABLE IF NOT EXISTS route_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    source VARCHAR(100) NOT NULL,
    destination VARCHAR(100) NOT NULL,
    search_date DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
  )''',
];
