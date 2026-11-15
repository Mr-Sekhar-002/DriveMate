-- DriveMate Database Migration: Enhancements for Production
-- Version: 2026_10_30_enhancements.sql
-- Compatible with MySQL 8.0 & MariaDB 10.4 (XAMPP)

-- 1. Fare Negotiations Table
CREATE TABLE IF NOT EXISTS `fare_negotiations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `booking_id` int(10) unsigned NOT NULL,
  `sender_id` int(10) unsigned NOT NULL,
  `sender_role` enum('customer','driver') NOT NULL,
  `offered_fare` decimal(10,2) NOT NULL,
  `counter_fare` decimal(10,2) DEFAULT NULL,
  `status` enum('PENDING','COUNTER_OFFERED','ACCEPTED','REJECTED','EXPIRED') NOT NULL DEFAULT 'PENDING',
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `booking_id` (`booking_id`),
  KEY `sender_id` (`sender_id`),
  CONSTRAINT `fk_negotiation_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_negotiation_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Trip Status History Table (Strict Lifecycle Management)
CREATE TABLE IF NOT EXISTS `trip_status_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `trip_id` int(10) unsigned NOT NULL,
  `status` enum('pending','confirmed','ongoing','completed','cancelled') NOT NULL,
  `changed_by_user_id` int(10) unsigned NOT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `trip_id` (`trip_id`),
  KEY `changed_by_user_id` (`changed_by_user_id`),
  CONSTRAINT `fk_tsh_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_tsh_user` FOREIGN KEY (`changed_by_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Update bookings table for fare negotiation support
ALTER TABLE `bookings` 
  ADD COLUMN IF NOT EXISTS `negotiated_fare` decimal(10,2) DEFAULT NULL AFTER `total_amount`,
  ADD COLUMN IF NOT EXISTS `negotiation_status` enum('NONE','PENDING','AGREED','REJECTED') DEFAULT 'NONE' AFTER `negotiated_fare`;

-- 4. Update otp_verifications table for security rate-limiting & cooldown
ALTER TABLE `otp_verifications`
  ADD COLUMN IF NOT EXISTS `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `last_sent_at` datetime NOT NULL DEFAULT current_timestamp(),
  ADD COLUMN IF NOT EXISTS `resend_available_at` datetime DEFAULT NULL;

-- 5. Seed Kakdwip and West Bengal / Pan-India standard pricing
UPDATE `system_settings` SET `setting_value` = '150.00' WHERE `setting_key` = 'base_fare';
UPDATE `system_settings` SET `setting_value` = '18.00' WHERE `setting_key` = 'per_km_rate';
UPDATE `system_settings` SET `setting_value` = '350.00' WHERE `setting_key` = 'driver_allowance';
UPDATE `system_settings` SET `setting_value` = 'INR' WHERE `setting_key` = 'currency';
UPDATE `system_settings` SET `setting_value` = '₹' WHERE `setting_key` = 'currency_symbol';
