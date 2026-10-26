-- UNN Route Navigator: Comprehensive Campus Data
-- Locations, Bus Stops, and Shuttle Route Connections
USE unn_route_navigator;

-- 1. Locations
INSERT INTO locations (location_name, latitude, longitude) VALUES
  ('Chitis', 6.8655000, 7.4105000),
  ('First Bank', 6.8650000, 7.4074000),
  ('UNN Stadium', 6.8664000, 7.4042000),
  ('ICT', 6.8629000, 7.4066000),
  ('Nutrition and Dietetics', 6.8633000, 7.4102000),
  ('VC Office', 6.8628000, 7.4081000),
  ('Bookshop', 6.8638000, 7.4072000),
  ('Jimbazz', 6.8658000, 7.4083000),
  ('Christ Church', 6.8616000, 7.4042000),
  ('FPSLT', 6.8702000, 7.4128000),
  ('Container', 6.8647000, 7.4078000),
  ('Admission Office', 6.8623000, 7.4075000),
  ('UNN Guest House', 6.8644000, 7.4068000),
  ('GS Building', 6.8626000, 7.4054000),
  ('Abuja Building', 6.8670000, 7.4121000),
  ('Faculty of Arts', 6.8632000, 7.4047000),
  ('St Peters Catholic Church', 6.8587000, 7.4105000),
  ('Agric', 6.8650000, 7.4126000),
  ('Eni Njoku Boys Hostel', 6.8686000, 7.4018000),
  ('Marlima', 6.8622000, 7.4098000),
  ('Biological Sciences', 6.8655000, 7.4088000)
ON DUPLICATE KEY UPDATE latitude = VALUES(latitude), longitude = VALUES(longitude);

-- 2. Bus Stops
INSERT INTO bus_stops (stop_name, latitude, longitude) VALUES
  ('Pharmacy', 6.8631000, 7.4109000),
  ('CEDR Hall', 6.8646000, 7.4116000),
  ('Ogige Market Shuttle Park', 6.8512000, 7.3998000),
  ('Ziks Flat', 6.8717000, 7.3983000),
  ('Second Gate', 6.8678000, 7.4172000),
  ('Eyoyita Hostel', 6.8631000, 7.4096000),
  ('SUB', 6.8665000, 7.4075000),
  ('Okpara Hostel', 6.8652000, 7.4045000),
  ('Vet', 6.8662000, 7.4132000),
  ('Greenhouse', 6.8639000, 7.4215000),
  ('UBA Hall of Fame', 6.8628000, 7.4082000),
  ('Total Junction', 6.8525000, 7.4005000),
  ('Hilltop Junction', 6.8695000, 7.4145000),
  ('Odim Gate', 6.8595000, 7.4010000)
ON DUPLICATE KEY UPDATE latitude = VALUES(latitude), longitude = VALUES(longitude);

-- 3. Shuttle Routes (Bus Stop to Bus Stop)
INSERT INTO routes (route_name, start_stop, end_stop, distance) VALUES
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Ogige Market Shuttle Park'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Total Junction'), 0.20),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Total Junction'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Ogige Market Shuttle Park'), 0.20),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Total Junction'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), 0.98),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Total Junction'), 0.98),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Okpara Hostel'), 0.93),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Okpara Hostel'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), 0.93),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Okpara Hostel'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), 0.45),
  ('Town Shuttle', (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Okpara Hostel'), 0.45),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'UBA Hall of Fame'), 0.52),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'UBA Hall of Fame'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), 0.52),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'UBA Hall of Fame'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Eyoyita Hostel'), 0.20),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Eyoyita Hostel'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'UBA Hall of Fame'), 0.20),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Eyoyita Hostel'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Pharmacy'), 0.18),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Pharmacy'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Eyoyita Hostel'), 0.18),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Pharmacy'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), 0.23),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Pharmacy'), 0.23),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Vet'), 0.31),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Vet'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), 0.31),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Vet'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Hilltop Junction'), 0.49),
  ('Campus Main Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Hilltop Junction'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Vet'), 0.49),
  ('Hilltop - Second Gate', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Hilltop Junction'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Second Gate'), 0.44),
  ('Hilltop - Second Gate', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Second Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Hilltop Junction'), 0.44),
  ('Ziks Flat Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Ziks Flat'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), 1.74),
  ('Ziks Flat Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Ziks Flat'), 1.74),
  ('Ziks Flat Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), 1.32),
  ('Ziks Flat Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'SUB'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Odim Gate'), 1.32),
  ('Agric Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Greenhouse'), 1.37),
  ('Agric Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Greenhouse'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'CEDR Hall'), 1.37),
  ('Agric Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Greenhouse'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Second Gate'), 0.80),
  ('Agric Line', (SELECT stop_id FROM bus_stops WHERE stop_name = 'Second Gate'), (SELECT stop_id FROM bus_stops WHERE stop_name = 'Greenhouse'), 0.80);
