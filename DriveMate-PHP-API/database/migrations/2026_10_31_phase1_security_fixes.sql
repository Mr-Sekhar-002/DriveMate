-- Migration: 2026_10_31_phase1_security_fixes.sql
-- Description: Phase 1 Backend Security Hardening: Remove default OTP, add attempt limits and expiry

-- 1. Remove master default '4821' from start_otp in bookings table
ALTER TABLE bookings MODIFY COLUMN start_otp VARCHAR(6) DEFAULT NULL;

-- 2. Add start_otp_attempts column to track failed OTP attempts (max 5)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS start_otp_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER start_otp;

-- 3. Add start_otp_verified_at column to record one-time verification timestamp
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS start_otp_verified_at DATETIME DEFAULT NULL AFTER start_otp_attempts;

-- 4. Add start_otp_expires_at column for time-based OTP validity
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS start_otp_expires_at DATETIME DEFAULT NULL AFTER start_otp_verified_at;
