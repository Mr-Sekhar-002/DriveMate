-- DriveMate Demo Seed Data
-- Import after database/schema.sql

USE drivemate;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE users;
TRUNCATE TABLE driver_profile;
TRUNCATE TABLE vehicles;
TRUNCATE TABLE car_listings;
TRUNCATE TABLE bookings;
TRUNCATE TABLE trips;
TRUNCATE TABLE payments;
TRUNCATE TABLE system_settings;
TRUNCATE TABLE wallets;
TRUNCATE TABLE wallet_transactions;
SET FOREIGN_KEY_CHECKS = 1;

-- Password for all demo accounts is: password
-- BCRYPT hash: $2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG

-- 1. Demo Users
INSERT INTO users (id, name, email, phone, password, role, status, created_at) VALUES
(1, 'Admin DriveMate', 'admin@drivemate.com', '9000000000', '$2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG', 'admin', 'active', NOW()),
(2, 'Rahul Sharma (Customer)', 'customer@drivemate.com', '9876543210', '$2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG', 'customer', 'active', NOW()),
(3, 'Rajesh Kumar (Driver)', 'driver@drivemate.com', '9811223344', '$2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG', 'driver', 'active', NOW()),
(4, 'Vikram Singh (Owner)', 'owner@drivemate.com', '9822334455', '$2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG', 'owner', 'active', NOW());

-- 2. Driver Profile
INSERT INTO driver_profile (id, user_id, license_number, vehicle_type, vehicle_model, vehicle_number, avg_rating, total_trips, earnings, status, created_at) VALUES
(1, 3, 'DL-0420110055441', 'Sedan', 'Maruti Suzuki Dzire VXI', 'WB-02-AK-4421', 4.95, 142, 28500.00, 'verified', NOW());

-- 3. Vehicles
INSERT INTO vehicles (id, owner_id, type, model, number_plate, color, capacity, status, created_at) VALUES
(1, 4, 'sedan', 'Maruti Suzuki Dzire (Manual)', 'WB-01-AB-1234', 'Pearl White', 4, 'active', NOW()),
(2, 4, 'suv', 'Hyundai Creta SX (Automatic)', 'WB-01-CD-5678', 'Phantom Black', 5, 'active', NOW()),
(3, 4, 'luxury', 'Toyota Innova Crysta (Diesel)', 'WB-01-EF-9012', 'Silver Metallic', 7, 'active', NOW());

-- 4. Car Rental Listings
INSERT INTO car_listings (id, owner_id, vehicle_id, type, daily_rate, hourly_rate, description, status, created_at) VALUES
(1, 4, 1, 'self_drive', 1800.00, 200.00, 'Fuel-efficient, clean sedan perfect for city drives and short weekend trips.', 'active', NOW()),
(2, 4, 2, 'both', 2800.00, 320.00, 'Feature-packed premium SUV with panoramic sunroof and automatic transmission.', 'active', NOW()),
(3, 4, 3, 'rent_with_driver', 4200.00, 480.00, 'Spacious 7-seater luxury MPV for family vacations and outstation journeys.', 'active', NOW());

-- 5. Demo Bookings
INSERT INTO bookings (id, user_id, type, driver_id, vehicle_id, start_date, pickup_location, destination, total_amount, payment_status, status, created_at) VALUES
(1, 2, 'hire_driver', 3, 1, '2026-10-10 10:00:00', 'Salt Lake Sector V, Kolkata', 'Howrah Railway Station', 500.00, 'unpaid', 'confirmed', NOW()),
(2, 2, 'rent_car', NULL, 2, '2026-10-15 08:00:00', 'Netaji Subhash Chandra Bose Airport', 'Digha Beach, West Bengal', 2800.00, 'unpaid', 'confirmed', NOW());

-- 6. Demo Trips
INSERT INTO trips (id, booking_id, driver_id, vehicle_id, start_location, end_location, start_lat, start_lng, current_lat, current_lng, end_lat, end_lng, distance_km, fare, status, start_time, end_time) VALUES
(1, 1, 3, 1, 'Salt Lake Sector V, Kolkata', 'Howrah Railway Station', 22.5800000, 88.4200000, 22.5850000, 88.3800000, 22.5830000, 88.3420000, 14.50, 500.00, 'completed', NOW(), NOW());

-- 7. In-App Wallet for Customer & Driver
INSERT INTO wallets (id, user_id, balance, currency, created_at) VALUES
(1, 2, 1000.00, 'INR', NOW()),
(2, 3, 500.00, 'INR', NOW());

INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after, created_at) VALUES
(1, 2, 'credit', 1000.00, 'welcome_bonus', 'INIT_1000', 'DriveMate Welcome Wallet Credit', 1000.00, NOW());

-- 8. System Settings
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('base_fare', '50', 'Base pickup fare in INR'),
('rate_per_km', '14', 'Standard rate per kilometer in INR'),
('rate_per_minute', '2', 'Ride duration rate per minute in INR'),
('gst_percent', '5', 'Goods & Services Tax percentage'),
('platform_commission_percent', '15', 'Platform commission taken from driver earnings'),
('upi_vpa', 'drivemate@icici', 'Company UPI VPA for customer payments'),
('upi_payee_name', 'DriveMate Mobility Services', 'Merchant display name in UPI apps'),
('emergency_sos_number', '112', 'National emergency helpline')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);
