-- 2026_10_30_osm_map_integration.sql
-- Add coordinate columns to bookings and bearing to trips for OpenStreetMap telemetry

-- Add pickup and destination coordinates to bookings table
ALTER TABLE `bookings`
  ADD COLUMN IF NOT EXISTS `pickup_lat` DECIMAL(10, 7) DEFAULT NULL AFTER `pickup_location`,
  ADD COLUMN IF NOT EXISTS `pickup_lng` DECIMAL(10, 7) DEFAULT NULL AFTER `pickup_lat`,
  ADD COLUMN IF NOT EXISTS `dest_lat` DECIMAL(10, 7) DEFAULT NULL AFTER `destination`,
  ADD COLUMN IF NOT EXISTS `dest_lng` DECIMAL(10, 7) DEFAULT NULL AFTER `dest_lat`;

-- Add vehicle bearing / orientation angle to trips for smooth marker rotation
ALTER TABLE `trips`
  ADD COLUMN IF NOT EXISTS `bearing` FLOAT DEFAULT 0.0 AFTER `current_lng`;

-- Seed default Kakdwip coordinates on sample bookings if null
UPDATE `bookings` 
SET `pickup_lat` = 21.8767, `pickup_lng` = 88.1912, `dest_lat` = 21.8712, `dest_lng` = 88.1824 
WHERE `pickup_lat` IS NULL AND `pickup_location` LIKE '%Kakdwip%';
