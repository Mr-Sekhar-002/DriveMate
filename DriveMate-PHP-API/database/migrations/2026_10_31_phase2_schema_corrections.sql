-- ====================================================================
-- DriveMate Migration: 2026_10_31_phase2_schema_corrections.sql
-- Description: Phase 2 Database Schema Correction, Canonical Columns,
--              Foreign Key Relationships, and Performance Indexes.
-- Compatible: MariaDB 10.4+ / MySQL 8.0+ (Safe and Repeatable)
-- ====================================================================

-- 1. BOOKINGS TABLE CORRECTIONS & MISSING COLUMNS
ALTER TABLE `bookings`
  MODIFY COLUMN `start_otp` VARCHAR(6) DEFAULT NULL,
  MODIFY COLUMN `status` ENUM('pending','confirmed','arrived','ongoing','completed','cancelled') DEFAULT 'pending';

ALTER TABLE `bookings`
  ADD COLUMN IF NOT EXISTS `hiring_type` ENUM('one_way','round_trip','hourly','full_day') DEFAULT 'one_way' AFTER `type`,
  ADD COLUMN IF NOT EXISTS `pickup_lat` DECIMAL(10,7) DEFAULT NULL AFTER `pickup_location`,
  ADD COLUMN IF NOT EXISTS `pickup_lng` DECIMAL(10,7) DEFAULT NULL AFTER `pickup_lat`,
  ADD COLUMN IF NOT EXISTS `dest_lat` DECIMAL(10,7) DEFAULT NULL AFTER `destination`,
  ADD COLUMN IF NOT EXISTS `dest_lng` DECIMAL(10,7) DEFAULT NULL AFTER `dest_lat`,
  ADD COLUMN IF NOT EXISTS `distance_km` DECIMAL(8,2) DEFAULT NULL AFTER `dest_lng`,
  ADD COLUMN IF NOT EXISTS `duration_minutes` INT(11) DEFAULT NULL AFTER `distance_km`,
  ADD COLUMN IF NOT EXISTS `estimated_fare` DECIMAL(10,2) DEFAULT NULL AFTER `duration_minutes`,
  ADD COLUMN IF NOT EXISTS `customer_offer` DECIMAL(10,2) DEFAULT NULL AFTER `estimated_fare`,
  ADD COLUMN IF NOT EXISTS `driver_counter_offer` DECIMAL(10,2) DEFAULT NULL AFTER `customer_offer`,
  ADD COLUMN IF NOT EXISTS `customer_car_model` VARCHAR(150) DEFAULT NULL AFTER `driver_counter_offer`,
  ADD COLUMN IF NOT EXISTS `notes` TEXT DEFAULT NULL AFTER `customer_car_model`,
  ADD COLUMN IF NOT EXISTS `negotiated_fare` DECIMAL(10,2) DEFAULT NULL AFTER `total_amount`,
  ADD COLUMN IF NOT EXISTS `negotiation_status` ENUM('NONE','PENDING','AGREED','REJECTED') DEFAULT 'NONE' AFTER `negotiated_fare`,
  ADD COLUMN IF NOT EXISTS `start_otp_attempts` TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `start_otp`,
  ADD COLUMN IF NOT EXISTS `start_otp_verified_at` DATETIME DEFAULT NULL AFTER `start_otp_attempts`,
  ADD COLUMN IF NOT EXISTS `start_otp_expires_at` DATETIME DEFAULT NULL AFTER `start_otp_verified_at`;

-- 2. TRIPS TABLE CORRECTIONS
ALTER TABLE `trips`
  ADD COLUMN IF NOT EXISTS `bearing` FLOAT DEFAULT 0.0 AFTER `current_lng`,
  ADD COLUMN IF NOT EXISTS `updated_at` DATETIME DEFAULT NULL AFTER `status`;

-- 3. USERS TABLE CORRECTIONS
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `phone_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `fcm_token`,
  ADD COLUMN IF NOT EXISTS `preferred_language` VARCHAR(10) DEFAULT 'en' AFTER `status`;

-- 4. DRIVER PROFILE TABLE CORRECTIONS
ALTER TABLE `driver_profile`
  ADD COLUMN IF NOT EXISTS `experience_years` INT(11) DEFAULT 1 AFTER `total_trips`,
  ADD COLUMN IF NOT EXISTS `hourly_rate` DECIMAL(10,2) DEFAULT 120.00 AFTER `experience_years`,
  ADD COLUMN IF NOT EXISTS `is_online` TINYINT(1) NOT NULL DEFAULT 0 AFTER `hourly_rate`,
  ADD COLUMN IF NOT EXISTS `current_lat` DECIMAL(10,7) DEFAULT NULL AFTER `is_online`,
  ADD COLUMN IF NOT EXISTS `current_lng` DECIMAL(10,7) DEFAULT NULL AFTER `current_lat`,
  ADD COLUMN IF NOT EXISTS `last_active_at` DATETIME DEFAULT NULL AFTER `current_lng`;

-- 5. PAYMENTS TABLE CORRECTIONS
ALTER TABLE `payments`
  ADD COLUMN IF NOT EXISTS `refund_id` VARCHAR(200) DEFAULT NULL AFTER `transaction_id`,
  ADD COLUMN IF NOT EXISTS `paid_at` DATETIME DEFAULT NULL AFTER `status`;

-- 6. SUPPORT TICKETS CATEGORY CORRECTION
ALTER TABLE `support_tickets`
  MODIFY COLUMN `category` ENUM('booking','payment','trip','driver','vehicle','app','other') DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS `admin_reply` TEXT DEFAULT NULL AFTER `message`,
  ADD COLUMN IF NOT EXISTS `resolved_at` DATETIME DEFAULT NULL AFTER `created_at`;

-- 7. PERFORMANCE & AUDIT INDEXES (Using CREATE INDEX IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_bookings_status ON `bookings` (`status`);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON `bookings` (`payment_status`);
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON `bookings` (`created_at`);

CREATE INDEX IF NOT EXISTS idx_trips_status ON `trips` (`status`);
CREATE INDEX IF NOT EXISTS idx_trips_driver_status ON `trips` (`driver_id`, `status`);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON `payments` (`user_id`);
CREATE INDEX IF NOT EXISTS idx_payments_status ON `payments` (`status`);
CREATE INDEX IF NOT EXISTS idx_payments_txn ON `payments` (`transaction_id`);

CREATE INDEX IF NOT EXISTS idx_support_booking_id ON `support_tickets` (`booking_id`);
CREATE INDEX IF NOT EXISTS idx_support_status ON `support_tickets` (`status`);

CREATE INDEX IF NOT EXISTS idx_notif_user_read ON `notifications` (`user_id`, `is_read`);

CREATE INDEX IF NOT EXISTS idx_driver_online_status ON `driver_profile` (`status`, `is_online`);

-- ====================================================================
-- End of Migration
-- ====================================================================
