-- UNN Route Navigator: handy queries for checking and reporting
USE unn_route_navigator;

-- Everything at a glance
SELECT COUNT(*) AS users FROM users;
SELECT COUNT(*) AS locations FROM locations;
SELECT COUNT(*) AS bus_stops FROM bus_stops;
SELECT COUNT(*) AS searches FROM route_history;

-- Shuttle segments with readable stop names
SELECT r.route_id, r.route_name, a.stop_name AS from_stop, b.stop_name AS to_stop, r.distance AS km
FROM routes r
JOIN bus_stops a ON a.stop_id = r.start_stop
JOIN bus_stops b ON b.stop_id = r.end_stop
ORDER BY r.route_name, r.route_id;

-- Latest searches with the user's name
SELECT u.fullname, h.source, h.destination, h.search_date
FROM route_history h JOIN users u ON u.user_id = h.user_id
ORDER BY h.search_date DESC LIMIT 50;

-- Most popular destinations
SELECT destination, COUNT(*) AS searches
FROM route_history GROUP BY destination ORDER BY searches DESC LIMIT 10;

-- Busiest users
SELECT u.fullname, COUNT(*) AS searches
FROM route_history h JOIN users u ON u.user_id = h.user_id
GROUP BY u.user_id, u.fullname ORDER BY searches DESC;

-- Bus stops not used by any shuttle segment
SELECT stop_name FROM bus_stops
WHERE stop_id NOT IN (SELECT start_stop FROM routes UNION SELECT end_stop FROM routes);

-- Start over with the sample data (deletes ALL places, bus stops, routes, users and history!)
-- SET FOREIGN_KEY_CHECKS = 0;
-- TRUNCATE route_history; TRUNCATE users; TRUNCATE routes; TRUNCATE bus_stops; TRUNCATE locations;
-- SET FOREIGN_KEY_CHECKS = 1;
-- then run sample_data.sql
