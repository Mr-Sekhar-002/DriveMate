-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: drivemate
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin_audit_logs`
--

DROP TABLE IF EXISTS `admin_audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_audit_logs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int(10) unsigned NOT NULL,
  `action` varchar(100) NOT NULL,
  `target_type` varchar(50) NOT NULL,
  `target_id` int(10) unsigned DEFAULT NULL,
  `details` text DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_action` (`action`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_audit_logs`
--

LOCK TABLES `admin_audit_logs` WRITE;
/*!40000 ALTER TABLE `admin_audit_logs` DISABLE KEYS */;
INSERT INTO `admin_audit_logs` VALUES (1,1,'login','admin',1,'Admin logged into web panel','::1','2026-10-31 17:58:16'),(2,1,'login','admin',1,'Admin logged into web panel','::1','2026-10-31 17:58:50'),(3,1,'login','admin',1,'Admin logged into web panel','::1','2026-10-31 18:23:29');
/*!40000 ALTER TABLE `admin_audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bookings`
--

DROP TABLE IF EXISTS `bookings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bookings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `type` enum('hire_driver','rent_car','rent_car_driver') NOT NULL,
  `hiring_type` enum('one_way','round_trip','hourly','full_day') DEFAULT 'one_way',
  `driver_id` int(10) unsigned DEFAULT NULL,
  `vehicle_id` int(10) unsigned DEFAULT NULL,
  `car_listing_id` int(10) unsigned DEFAULT NULL,
  `start_date` datetime NOT NULL,
  `end_date` datetime DEFAULT NULL,
  `pickup_location` varchar(300) DEFAULT NULL,
  `pickup_lat` decimal(10,7) DEFAULT NULL,
  `pickup_lng` decimal(10,7) DEFAULT NULL,
  `destination` varchar(300) DEFAULT NULL,
  `dest_lat` decimal(10,7) DEFAULT NULL,
  `dest_lng` decimal(10,7) DEFAULT NULL,
  `distance_km` decimal(8,2) DEFAULT NULL,
  `duration_minutes` int(11) DEFAULT NULL,
  `estimated_fare` decimal(10,2) DEFAULT NULL,
  `customer_offer` decimal(10,2) DEFAULT NULL,
  `driver_counter_offer` decimal(10,2) DEFAULT NULL,
  `customer_car_model` varchar(150) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `total_amount` decimal(10,2) DEFAULT 0.00,
  `negotiated_fare` decimal(10,2) DEFAULT NULL,
  `negotiation_status` enum('NONE','PENDING','AGREED','REJECTED') DEFAULT 'NONE',
  `start_otp` varchar(6) DEFAULT NULL,
  `start_otp_attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `start_otp_verified_at` datetime DEFAULT NULL,
  `start_otp_expires_at` datetime DEFAULT NULL,
  `payment_status` enum('unpaid','paid','refunded') DEFAULT 'unpaid',
  `status` enum('pending','confirmed','arrived','ongoing','completed','cancelled') DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `driver_id` (`driver_id`),
  KEY `vehicle_id` (`vehicle_id`),
  KEY `car_listing_id` (`car_listing_id`),
  KEY `idx_bookings_status` (`status`),
  KEY `idx_bookings_payment_status` (`payment_status`),
  KEY `idx_bookings_created_at` (`created_at`),
  CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `bookings_ibfk_4` FOREIGN KEY (`car_listing_id`) REFERENCES `car_listings` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bookings`
--

LOCK TABLES `bookings` WRITE;
/*!40000 ALTER TABLE `bookings` DISABLE KEYS */;
INSERT INTO `bookings` VALUES (1,2,'hire_driver','one_way',3,1,NULL,'2026-10-10 10:00:00',NULL,'Salt Lake Sector V, Kolkata',NULL,NULL,'Howrah Railway Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,550.00,NULL,'NONE','4821',0,NULL,NULL,'paid','completed','2026-10-03 15:46:39'),(2,2,'rent_car','one_way',NULL,2,NULL,'2026-10-15 08:00:00',NULL,'Netaji Subhash Chandra Bose Airport',NULL,NULL,'Digha Beach, West Bengal',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2800.00,NULL,'NONE','4821',0,NULL,NULL,'unpaid','confirmed','2026-10-03 15:46:39'),(3,1,'hire_driver','one_way',3,NULL,NULL,'2026-10-10 10:00:00','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',NULL,NULL,'Howrah Railway Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','4821',0,NULL,NULL,'unpaid','pending','2026-10-08 15:08:03'),(4,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 06:39:46','0000-00-00 00:00:00','Kakdwip Railway Station',NULL,NULL,'Kakdwip Market',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,500.00,'AGREED','4821',0,NULL,NULL,'unpaid','completed','2026-10-31 11:09:46'),(5,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 07:52:53',NULL,'Kakdwip Railway Station',21.8767000,88.1912000,'Lot 8 Ferry Ghat',21.8712000,88.1824000,14.80,28,467.20,420.00,460.00,'Honda City (Automatic)','Waiting at platform 1 exit',460.00,460.00,'AGREED','2794',0,NULL,NULL,'unpaid','confirmed','2026-10-31 12:22:53'),(6,5,'hire_driver','one_way',9,NULL,NULL,'2026-10-28 18:12:29',NULL,'Kakdwip Station',NULL,NULL,'Lot 8 Ghat',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','4821',0,NULL,NULL,'paid','completed','2026-10-28 18:12:29'),(7,6,'hire_driver','one_way',10,NULL,NULL,'2026-10-29 18:12:29',NULL,'Kakdwip Market',NULL,NULL,'Namkhana',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,350.00,NULL,'NONE','4821',0,NULL,NULL,'paid','completed','2026-10-29 18:12:29'),(8,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:18:43','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',22.5800000,88.4300000,'Park Street, Kolkata',22.5500000,88.3500000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','3305',5,NULL,'2026-11-01 19:48:43','unpaid','confirmed','2026-10-31 19:48:43'),(9,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:18:43','0000-00-00 00:00:00','Airport, Kolkata',NULL,NULL,'Howrah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,600.00,NULL,'NONE',NULL,0,'2026-10-31 19:48:43','2026-11-01 19:48:43','unpaid','ongoing','2026-10-31 19:48:43'),(10,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:18:44','0000-00-00 00:00:00','New Town, Kolkata',NULL,NULL,'Airport, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,480.00,'PENDING','2635',0,NULL,'2026-11-01 19:48:44','unpaid','pending','2026-10-31 19:48:44'),(11,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:18:45','0000-00-00 00:00:00','Gariahat, Kolkata',NULL,NULL,'Sealdah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','8850',0,NULL,'2026-11-01 19:48:45','paid','confirmed','2026-10-31 19:48:45'),(12,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:19:17','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',22.5800000,88.4300000,'Park Street, Kolkata',22.5500000,88.3500000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','7385',5,NULL,'2026-11-01 19:49:17','unpaid','confirmed','2026-10-31 19:49:17'),(13,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:19:18','0000-00-00 00:00:00','Airport, Kolkata',NULL,NULL,'Howrah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,600.00,NULL,'NONE',NULL,0,'2026-10-31 19:49:18','2026-11-01 19:49:18','unpaid','ongoing','2026-10-31 19:49:18'),(14,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:19:18','0000-00-00 00:00:00','New Town, Kolkata',NULL,NULL,'Airport, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,480.00,'PENDING','4134',0,NULL,'2026-11-01 19:49:18','unpaid','pending','2026-10-31 19:49:18'),(15,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:19:20','0000-00-00 00:00:00','Gariahat, Kolkata',NULL,NULL,'Sealdah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','4277',0,NULL,'2026-11-01 19:49:21','paid','confirmed','2026-10-31 19:49:21'),(16,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:50','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',22.5800000,88.4300000,'Park Street, Kolkata',22.5500000,88.3500000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','6744',5,NULL,'2026-10-31 16:06:50','unpaid','confirmed','2026-10-31 20:06:50'),(17,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:51','0000-00-00 00:00:00','Airport, Kolkata',NULL,NULL,'Howrah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,600.00,NULL,'NONE',NULL,0,'2026-10-31 20:06:51','2026-10-31 16:06:51','unpaid','ongoing','2026-10-31 20:06:51'),(18,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:51','0000-00-00 00:00:00','Behala Chowrasta, Kolkata',NULL,NULL,'Howrah Station, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,400.00,NULL,'NONE','1947',0,NULL,'2026-10-31 16:06:51','unpaid','confirmed','2026-10-31 20:06:51'),(19,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 19:36:51','0000-00-00 00:00:00','New Town Action Area 1',NULL,NULL,'Sealdah Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,550.00,NULL,'NONE','3118',0,NULL,'2026-10-31 20:06:51','unpaid','confirmed','2026-10-31 20:06:51'),(20,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:51','0000-00-00 00:00:00','Jadavpur, Kolkata',NULL,NULL,'Ruby General Hospital',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,300.00,NULL,'NONE',NULL,0,'2026-10-31 20:06:51','2026-10-31 16:06:51','unpaid','arrived','2026-10-31 20:06:51'),(21,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:52','0000-00-00 00:00:00','New Town, Kolkata',NULL,NULL,'Airport, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,480.00,'PENDING','6049',0,NULL,'2026-10-31 16:06:52','unpaid','pending','2026-10-31 20:06:52'),(22,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 15:36:53','0000-00-00 00:00:00','Gariahat, Kolkata',NULL,NULL,'Sealdah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','7701',0,NULL,'2026-10-31 16:06:53','paid','confirmed','2026-10-31 20:06:53'),(23,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:21','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',22.5800000,88.4300000,'Park Street, Kolkata',22.5500000,88.3500000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','2389',5,NULL,'2026-10-31 20:38:21','unpaid','confirmed','2026-10-31 20:08:21'),(24,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:21','0000-00-00 00:00:00','Airport, Kolkata',NULL,NULL,'Howrah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,600.00,NULL,'NONE',NULL,0,'2026-10-31 20:08:21','2026-10-31 20:38:21','unpaid','ongoing','2026-10-31 20:08:21'),(25,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:22','0000-00-00 00:00:00','Behala Chowrasta, Kolkata',NULL,NULL,'Howrah Station, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,400.00,NULL,'NONE','7693',0,NULL,'2026-10-31 20:38:22','unpaid','confirmed','2026-10-31 20:08:22'),(26,2,'hire_driver','one_way',3,NULL,NULL,'2026-11-01 00:08:22','0000-00-00 00:00:00','New Town Action Area 1',NULL,NULL,'Sealdah Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,550.00,NULL,'NONE','2400',0,NULL,'2026-11-01 00:38:22','unpaid','confirmed','2026-10-31 20:08:22'),(27,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:22','0000-00-00 00:00:00','Jadavpur, Kolkata',NULL,NULL,'Ruby General Hospital',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,300.00,NULL,'NONE',NULL,0,'2026-10-31 20:08:22','2026-10-31 20:38:22','unpaid','arrived','2026-10-31 20:08:22'),(28,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:22','0000-00-00 00:00:00','New Town, Kolkata',NULL,NULL,'Airport, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,480.00,'PENDING','9627',0,NULL,'2026-10-31 20:38:22','unpaid','pending','2026-10-31 20:08:22'),(29,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:08:23','0000-00-00 00:00:00','Gariahat, Kolkata',NULL,NULL,'Sealdah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','4809',0,NULL,'2026-10-31 20:38:23','paid','confirmed','2026-10-31 20:08:23'),(30,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:30','0000-00-00 00:00:00','Salt Lake Sector V, Kolkata',22.5800000,88.4300000,'Park Street, Kolkata',22.5500000,88.3500000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','8742',5,NULL,'2026-10-31 20:46:31','unpaid','confirmed','2026-10-31 20:16:31'),(31,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:31','0000-00-00 00:00:00','Airport, Kolkata',NULL,NULL,'Howrah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,600.00,NULL,'NONE',NULL,0,'2026-10-31 20:16:31','2026-10-31 20:46:31','unpaid','ongoing','2026-10-31 20:16:31'),(32,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:31','0000-00-00 00:00:00','Behala Chowrasta, Kolkata',NULL,NULL,'Howrah Station, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,400.00,NULL,'NONE','8644',0,NULL,'2026-10-31 20:46:31','unpaid','confirmed','2026-10-31 20:16:31'),(33,2,'hire_driver','one_way',3,NULL,NULL,'2026-11-01 00:16:31','0000-00-00 00:00:00','New Town Action Area 1',NULL,NULL,'Sealdah Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,550.00,NULL,'NONE','8182',0,NULL,'2026-11-01 00:46:31','unpaid','confirmed','2026-10-31 20:16:31'),(34,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:31','0000-00-00 00:00:00','Jadavpur, Kolkata',NULL,NULL,'Ruby General Hospital',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,300.00,NULL,'NONE',NULL,0,'2026-10-31 20:16:32','2026-10-31 20:46:31','unpaid','arrived','2026-10-31 20:16:31'),(35,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:32','0000-00-00 00:00:00','New Town, Kolkata',NULL,NULL,'Airport, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,500.00,480.00,'PENDING','6074',0,NULL,'2026-10-31 20:46:32','unpaid','pending','2026-10-31 20:16:32'),(36,2,'hire_driver','one_way',3,NULL,NULL,'2026-10-31 20:16:32','0000-00-00 00:00:00','Gariahat, Kolkata',NULL,NULL,'Sealdah, Kolkata',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,450.00,NULL,'NONE','3256',0,NULL,'2026-10-31 20:46:32','paid','confirmed','2026-10-31 20:16:32');
/*!40000 ALTER TABLE `bookings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `car_listings`
--

DROP TABLE IF EXISTS `car_listings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `car_listings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `owner_id` int(10) unsigned NOT NULL,
  `vehicle_id` int(10) unsigned DEFAULT NULL,
  `type` enum('self_drive','rent_with_driver','both') DEFAULT 'self_drive',
  `daily_rate` decimal(10,2) NOT NULL,
  `hourly_rate` decimal(10,2) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `available_from` date DEFAULT NULL,
  `available_to` date DEFAULT NULL,
  `file_url` varchar(300) DEFAULT NULL,
  `status` enum('active','inactive') DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `owner_id` (`owner_id`),
  KEY `vehicle_id` (`vehicle_id`),
  CONSTRAINT `car_listings_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `car_listings_ibfk_2` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `car_listings`
--

LOCK TABLES `car_listings` WRITE;
/*!40000 ALTER TABLE `car_listings` DISABLE KEYS */;
INSERT INTO `car_listings` VALUES (1,4,1,'self_drive',1800.00,200.00,'Fuel-efficient, clean sedan perfect for city drives and short weekend trips.',NULL,NULL,NULL,'active','2026-10-03 15:46:39'),(2,4,2,'both',2800.00,320.00,'Feature-packed premium SUV with panoramic sunroof and automatic transmission.',NULL,NULL,NULL,'active','2026-10-03 15:46:39'),(3,4,3,'rent_with_driver',4200.00,480.00,'Spacious 7-seater luxury MPV for family vacations and outstation journeys.',NULL,NULL,NULL,'active','2026-10-03 15:46:39');
/*!40000 ALTER TABLE `car_listings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `documents`
--

DROP TABLE IF EXISTS `documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `documents` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `type` enum('kyc','rc','dl','insurance','photo') NOT NULL,
  `file_url` varchar(300) NOT NULL,
  `status` enum('pending','verified','rejected') DEFAULT 'pending',
  `verified_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `documents_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `documents`
--

LOCK TABLES `documents` WRITE;
/*!40000 ALTER TABLE `documents` DISABLE KEYS */;
/*!40000 ALTER TABLE `documents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `driver_device_tokens`
--

DROP TABLE IF EXISTS `driver_device_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `driver_device_tokens` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `driver_id` int(10) unsigned NOT NULL,
  `fcm_token` varchar(500) NOT NULL,
  `device_model` varchar(100) DEFAULT NULL,
  `device_os` varchar(50) DEFAULT 'Android',
  `app_version` varchar(30) DEFAULT '1.0.0',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_driver_token` (`driver_id`,`fcm_token`(191)),
  KEY `idx_driver` (`driver_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `driver_device_tokens`
--

LOCK TABLES `driver_device_tokens` WRITE;
/*!40000 ALTER TABLE `driver_device_tokens` DISABLE KEYS */;
INSERT INTO `driver_device_tokens` VALUES (1,3,'fcm_test_token_driver_amitava_8932','Realme 5G Smartphone','Android 14','1.0.0',1,'2026-10-31 12:07:31','2026-10-31 12:07:31');
/*!40000 ALTER TABLE `driver_device_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `driver_profile`
--

DROP TABLE IF EXISTS `driver_profile`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `driver_profile` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `license_number` varchar(50) DEFAULT NULL,
  `vehicle_type` varchar(50) DEFAULT NULL,
  `vehicle_model` varchar(100) DEFAULT NULL,
  `vehicle_number` varchar(30) DEFAULT NULL,
  `documents` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`documents`)),
  `avg_rating` decimal(3,2) DEFAULT 0.00,
  `total_trips` int(11) DEFAULT 0,
  `earnings` decimal(10,2) DEFAULT 0.00,
  `status` enum('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  `is_online` tinyint(1) DEFAULT 1,
  `current_lat` decimal(10,7) DEFAULT NULL,
  `current_lng` decimal(10,7) DEFAULT NULL,
  `last_active_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `experience_years` int(11) DEFAULT 5,
  `hourly_rate` decimal(10,2) DEFAULT 150.00,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `idx_driver_online_status` (`status`,`is_online`),
  CONSTRAINT `driver_profile_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `driver_profile`
--

LOCK TABLES `driver_profile` WRITE;
/*!40000 ALTER TABLE `driver_profile` DISABLE KEYS */;
INSERT INTO `driver_profile` VALUES (1,3,'DL-0420110055441','Sedan','Maruti Suzuki Dzire VXI','WB-02-AK-4421',NULL,5.00,151,31390.00,'verified',1,21.8780000,88.1925000,'2026-10-28 10:58:58','2026-10-03 15:46:39',5,150.00),(2,9,'DL-WB96-2019-003412','Sedan/SUV','Hyundai Creta SX','WB-06-B-8910',NULL,4.90,184,38500.00,'verified',1,21.8735000,88.1855000,NULL,'2026-10-31 18:11:40',6,160.00),(3,10,'DL-WB96-2022-004481','Hatchback','Maruti Suzuki Swift','WB-02-C-1122',NULL,4.70,96,19200.00,'verified',1,21.8845000,88.1995000,NULL,'2026-10-31 18:11:40',3,140.00);
/*!40000 ALTER TABLE `driver_profile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fare_negotiations`
--

DROP TABLE IF EXISTS `fare_negotiations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fare_negotiations` (
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fare_negotiations`
--

LOCK TABLES `fare_negotiations` WRITE;
/*!40000 ALTER TABLE `fare_negotiations` DISABLE KEYS */;
INSERT INTO `fare_negotiations` VALUES (1,4,2,'customer',450.00,500.00,'COUNTER_OFFERED','Kakdwip morning offer','2026-10-31 11:09:46','2026-10-31 11:10:06'),(2,4,3,'driver',500.00,NULL,'ACCEPTED','Traffic is heavy near Kakdwip Market | Accepted by customer','2026-10-31 11:10:06','2026-10-31 11:10:25'),(3,5,2,'customer',420.00,460.00,'COUNTER_OFFERED','Waiting at platform 1 exit','2026-10-31 12:22:53','2026-10-31 12:22:54'),(4,5,3,'driver',460.00,NULL,'ACCEPTED','Can do for ?460 with luggage assistance | Accepted by customer','2026-10-31 12:22:54','2026-10-31 12:22:54'),(5,10,2,'customer',450.00,480.00,'COUNTER_OFFERED','Customer proposed initial fare offer','2026-10-31 19:48:44','2026-10-31 19:48:45'),(6,10,3,'driver',480.00,NULL,'PENDING','Driver counter-offer','2026-10-31 19:48:45','2026-10-31 19:48:45'),(7,14,2,'customer',450.00,480.00,'COUNTER_OFFERED','Customer proposed initial fare offer','2026-10-31 19:49:18','2026-10-31 19:49:20'),(8,14,3,'driver',480.00,NULL,'PENDING','Driver counter-offer','2026-10-31 19:49:20','2026-10-31 19:49:20'),(9,21,2,'customer',450.00,480.00,'COUNTER_OFFERED','Customer proposed initial fare offer','2026-10-31 20:06:52','2026-10-31 20:06:53'),(10,21,3,'driver',480.00,NULL,'PENDING','Driver counter-offer','2026-10-31 20:06:53','2026-10-31 20:06:53'),(11,28,2,'customer',450.00,480.00,'COUNTER_OFFERED','Customer proposed initial fare offer','2026-10-31 20:08:22','2026-10-31 20:08:23'),(12,28,3,'driver',480.00,NULL,'PENDING','Driver counter-offer','2026-10-31 20:08:23','2026-10-31 20:08:23'),(13,35,2,'customer',450.00,480.00,'COUNTER_OFFERED','Customer proposed initial fare offer','2026-10-31 20:16:32','2026-10-31 20:16:32'),(14,35,3,'driver',480.00,NULL,'PENDING','Driver counter-offer','2026-10-31 20:16:32','2026-10-31 20:16:32');
/*!40000 ALTER TABLE `fare_negotiations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_logs`
--

DROP TABLE IF EXISTS `notification_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_logs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `recipient_user_id` int(10) unsigned NOT NULL,
  `booking_id` int(10) unsigned DEFAULT NULL,
  `notification_type` varchar(50) DEFAULT 'booking_request',
  `title` varchar(200) NOT NULL,
  `body` text NOT NULL,
  `status` enum('sent','failed','queued') DEFAULT 'sent',
  `response_code` int(11) DEFAULT 200,
  `error_message` text DEFAULT NULL,
  `sent_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_recipient` (`recipient_user_id`),
  KEY `idx_booking` (`booking_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_logs`
--

LOCK TABLES `notification_logs` WRITE;
/*!40000 ALTER TABLE `notification_logs` DISABLE KEYS */;
INSERT INTO `notification_logs` VALUES (1,3,5,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 12:22:54'),(2,3,10,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 19:48:45'),(3,3,14,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 19:49:20'),(4,3,21,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 20:06:53'),(5,3,28,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 20:08:23'),(6,3,35,'booking_request','New Booking Request!','A customer has requested a car booking. Tap to view details.','failed',404,NULL,'2026-10-31 20:16:32');
/*!40000 ALTER TABLE `notification_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `type` enum('push','booking','payment','system') DEFAULT 'push',
  `title` varchar(200) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `idx_notif_user_read` (`user_id`,`is_read`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 12:22:53'),(2,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 19:48:44'),(3,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 19:49:18'),(4,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 20:06:52'),(5,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 20:08:22'),(6,3,'booking','New Booking Request!','A customer has requested a car booking. Tap to view details.',0,'2026-10-31 20:16:32');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `otp_verifications`
--

DROP TABLE IF EXISTS `otp_verifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `otp_verifications` (
  `phone` varchar(20) NOT NULL,
  `otp` varchar(10) NOT NULL,
  `expires_at` datetime NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `last_sent_at` datetime NOT NULL DEFAULT current_timestamp(),
  `resend_available_at` datetime DEFAULT NULL,
  PRIMARY KEY (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `otp_verifications`
--

LOCK TABLES `otp_verifications` WRITE;
/*!40000 ALTER TABLE `otp_verifications` DISABLE KEYS */;
INSERT INTO `otp_verifications` VALUES ('9876543210','604236','2026-10-08 15:17:55',0,'2026-10-31 10:56:04',NULL);
/*!40000 ALTER TABLE `otp_verifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `booking_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `payment_method` varchar(50) DEFAULT 'cash',
  `transaction_id` varchar(200) DEFAULT NULL,
  `refund_id` varchar(200) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `status` enum('pending','paid','failed','refunded') DEFAULT 'pending',
  `paid_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `booking_id` (`booking_id`),
  KEY `idx_payments_user_id` (`user_id`),
  KEY `idx_payments_status` (`status`),
  KEY `idx_payments_txn` (`transaction_id`),
  CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
INSERT INTO `payments` VALUES (1,1,1,350.00,'upi','UPI_19376E85E1DE',NULL,'UPI QR generated','pending',NULL,'2026-10-03 15:46:54'),(2,1,2,500.00,'cash','CASH_B78BB0CF9670','RFND_4DBF845A3578','Cash received by driver','refunded','2026-10-08 15:08:02','2026-10-03 15:46:54'),(3,1,1,350.00,'upi','UPI_1ABF03E8F341',NULL,'UPI QR generated','pending',NULL,'2026-10-08 15:08:01'),(4,1,1,150.00,'wallet','WLT_9F5631603785',NULL,'Paid using DriveMate In-App Wallet','paid','2026-10-08 15:08:02','2026-10-08 15:08:02'),(5,1,1,350.00,'upi','UPI_549619C81120',NULL,'UPI QR generated','pending',NULL,'2026-10-08 15:33:12'),(6,1,1,150.00,'wallet','WLT_4F90D1ED7E4A',NULL,'Paid using DriveMate In-App Wallet','paid','2026-10-08 15:33:15','2026-10-08 15:33:15'),(7,4,2,500.00,'upi','DM_TXN_4_1793443868_6806A9',NULL,'Pending payment invoice created','pending',NULL,'2026-10-31 16:21:08'),(8,11,2,450.00,'razorpay','pay_d1b70523867af30c',NULL,'Razorpay verified: order=order_sb_651d1149e7163e4b, pay=pay_d1b70523867af30c','paid','2026-10-31 19:48:46','2026-10-31 19:48:45'),(9,15,2,450.00,'razorpay','pay_bd0db6e80e87a5ae',NULL,'Razorpay verified: order=order_sb_012cf9f7d38cfd57, pay=pay_bd0db6e80e87a5ae','paid','2026-10-31 19:49:21','2026-10-31 19:49:21'),(10,22,2,450.00,'razorpay','pay_2a2e87b831a35a2a',NULL,'Razorpay verified: order=order_sb_ab9e01cb5fa40fbf, pay=pay_2a2e87b831a35a2a','paid','2026-10-31 20:06:53','2026-10-31 20:06:53'),(11,29,2,450.00,'razorpay','pay_0543d1fc2861c0de',NULL,'Razorpay verified: order=order_sb_6546e487ceb2a39a, pay=pay_0543d1fc2861c0de','paid','2026-10-31 20:08:23','2026-10-31 20:08:23'),(12,36,2,450.00,'razorpay','pay_32779dee807bed9c',NULL,'Razorpay verified: order=order_sb_b15c6a2811a9635f, pay=pay_32779dee807bed9c','paid','2026-10-31 20:16:32','2026-10-31 20:16:32');
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reviews` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `driver_id` int(10) unsigned DEFAULT NULL,
  `booking_id` int(10) unsigned DEFAULT NULL,
  `rating` tinyint(4) NOT NULL CHECK (`rating` between 1 and 5),
  `comment` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_review` (`booking_id`,`user_id`),
  KEY `user_id` (`user_id`),
  KEY `driver_id` (`driver_id`),
  CONSTRAINT `reviews_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reviews_ibfk_2` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `reviews_ibfk_3` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reviews`
--

LOCK TABLES `reviews` WRITE;
/*!40000 ALTER TABLE `reviews` DISABLE KEYS */;
INSERT INTO `reviews` VALUES (3,3,NULL,1,5,'Self rating test','2026-10-31 16:51:00'),(4,2,3,1,5,'Duplicate rating test','2026-10-31 16:51:00'),(9,5,9,6,5,'Amitava was extremely punctual, professional, and drove smoothly through heavy highway traffic.','2026-10-29 18:12:29'),(10,6,10,7,5,'Very courteous and knows Kolkata-Kakdwip routes thoroughly.','2026-10-30 18:12:29');
/*!40000 ALTER TABLE `reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `support_tickets`
--

DROP TABLE IF EXISTS `support_tickets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `support_tickets` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `booking_id` int(10) unsigned DEFAULT NULL,
  `subject` varchar(200) NOT NULL,
  `category` enum('booking','payment','trip','driver','vehicle','app','other') DEFAULT 'other',
  `message` text NOT NULL,
  `admin_reply` text DEFAULT NULL,
  `status` enum('open','in_progress','resolved','closed') DEFAULT 'open',
  `created_at` datetime DEFAULT current_timestamp(),
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `idx_support_booking_id` (`booking_id`),
  KEY `idx_support_status` (`status`),
  CONSTRAINT `support_tickets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `support_tickets`
--

LOCK TABLES `support_tickets` WRITE;
/*!40000 ALTER TABLE `support_tickets` DISABLE KEYS */;
INSERT INTO `support_tickets` VALUES (1,1,NULL,'Invoice clarification','payment','Need assistance regarding GST calculation for booking #1',NULL,'open','2026-10-08 15:08:04',NULL),(2,2,1,'Route navigation clarification','','The route via Lot 8 Ghat was diverted due to local tide.',NULL,'open','2026-10-31 16:59:10',NULL),(3,2,1,'Route navigation clarification','trip','The route via Lot 8 Ghat was diverted due to local tide.',NULL,'open','2026-10-31 16:59:45',NULL),(4,2,1,'Route navigation clarification','trip','The route via Lot 8 Ghat was diverted due to local tide.',NULL,'open','2026-10-31 17:13:24',NULL);
/*!40000 ALTER TABLE `support_tickets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_settings`
--

DROP TABLE IF EXISTS `system_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `system_settings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) NOT NULL,
  `setting_value` text NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `setting_key` (`setting_key`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_settings`
--

LOCK TABLES `system_settings` WRITE;
/*!40000 ALTER TABLE `system_settings` DISABLE KEYS */;
INSERT INTO `system_settings` VALUES (1,'base_fare','150.00','Base pickup fare in INR','2026-10-31 10:56:04'),(2,'rate_per_km','14','Standard rate per kilometer in INR','2026-10-03 15:46:39'),(3,'rate_per_minute','2','Ride duration rate per minute in INR','2026-10-03 15:46:39'),(4,'gst_percent','5','Goods & Services Tax percentage','2026-10-03 15:46:39'),(5,'platform_commission_percent','15','Platform commission taken from driver earnings','2026-10-03 15:46:39'),(6,'upi_vpa','drivemate@icici','Company UPI VPA for customer payments','2026-10-03 15:46:39'),(7,'upi_payee_name','DriveMate Mobility Services','Merchant display name in UPI apps','2026-10-03 15:46:39'),(8,'emergency_sos_number','112','National emergency helpline','2026-10-03 15:46:39'),(9,'driver_oneway_base','150.00','One-way hiring base charge in INR','2026-10-31 12:19:38'),(10,'driver_oneway_km_rate','14.00','One-way driver rate per km in INR','2026-10-31 12:19:38'),(11,'driver_oneway_hr_rate','60.00','One-way driver rate per hour in INR','2026-10-31 12:19:38'),(12,'driver_roundtrip_base','250.00','Round-trip hiring base charge in INR','2026-10-31 12:19:38'),(13,'driver_roundtrip_km_rate','12.00','Round-trip driver rate per km in INR','2026-10-31 12:19:38'),(14,'driver_roundtrip_hr_rate','80.00','Round-trip driver rate per hour in INR','2026-10-31 12:19:38'),(15,'driver_hourly_base','100.00','Hourly driver base charge in INR','2026-10-31 12:19:38'),(16,'driver_hourly_rate','150.00','Hourly driver rate per hour in INR','2026-10-31 12:19:38'),(17,'driver_fullday_base','1200.00','Full day driver flat package base in INR','2026-10-31 12:19:38'),(18,'driver_allowance','50.00','Chauffeur convenience and safety allowance in INR','2026-10-31 12:19:38');
/*!40000 ALTER TABLE `system_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `trip_status_history`
--

DROP TABLE IF EXISTS `trip_status_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `trip_status_history` (
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
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trip_status_history`
--

LOCK TABLES `trip_status_history` WRITE;
/*!40000 ALTER TABLE `trip_status_history` DISABLE KEYS */;
INSERT INTO `trip_status_history` VALUES (1,2,'ongoing',3,'Trip started by assigned driver','2026-10-31 11:10:51'),(2,3,'ongoing',3,'Trip started by assigned driver','2026-10-31 19:48:44'),(3,4,'ongoing',3,'Trip started by assigned driver','2026-10-31 19:49:18'),(4,5,'ongoing',3,'Trip started by assigned driver','2026-10-31 20:06:51'),(5,6,'ongoing',3,'Trip started by assigned driver','2026-10-31 20:08:21'),(6,7,'ongoing',3,'Trip started by assigned driver','2026-10-31 20:16:31');
/*!40000 ALTER TABLE `trip_status_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `trips`
--

DROP TABLE IF EXISTS `trips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `trips` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `booking_id` int(10) unsigned NOT NULL,
  `driver_id` int(10) unsigned DEFAULT NULL,
  `vehicle_id` int(10) unsigned DEFAULT NULL,
  `start_location` varchar(300) DEFAULT NULL,
  `start_lat` decimal(10,7) DEFAULT NULL,
  `start_lng` decimal(10,7) DEFAULT NULL,
  `end_location` varchar(300) DEFAULT NULL,
  `end_lat` decimal(10,7) DEFAULT NULL,
  `end_lng` decimal(10,7) DEFAULT NULL,
  `current_lat` decimal(10,7) DEFAULT NULL,
  `current_lng` decimal(10,7) DEFAULT NULL,
  `bearing` float DEFAULT 0,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `distance_km` decimal(8,2) DEFAULT 0.00,
  `fare` decimal(10,2) DEFAULT 0.00,
  `status` enum('ongoing','completed','cancelled') DEFAULT 'ongoing',
  `updated_at` datetime DEFAULT NULL ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `booking_id` (`booking_id`),
  KEY `driver_id` (`driver_id`),
  KEY `vehicle_id` (`vehicle_id`),
  KEY `idx_trips_status` (`status`),
  KEY `idx_trips_driver_status` (`driver_id`,`status`),
  CONSTRAINT `trips_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trips_ibfk_2` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `trips_ibfk_3` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trips`
--

LOCK TABLES `trips` WRITE;
/*!40000 ALTER TABLE `trips` DISABLE KEYS */;
INSERT INTO `trips` VALUES (1,1,3,1,'Salt Lake Sector V, Kolkata',22.5800000,88.4200000,'',NULL,NULL,22.5800000,88.3700000,0,'2026-10-03 15:46:39','2026-10-08 15:08:03',12.50,550.00,'completed','2026-10-08 15:08:03'),(2,4,3,NULL,'Kakdwip Railway Station',21.8767000,88.1912000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 11:10:51',NULL,0.00,0.00,'completed','2026-10-31 18:10:42'),(3,9,3,NULL,'Airport, Kolkata',22.6500000,88.4400000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 19:48:44',NULL,0.00,0.00,'ongoing',NULL),(4,13,3,NULL,'Airport, Kolkata',22.6500000,88.4400000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 19:49:18',NULL,0.00,0.00,'ongoing',NULL),(5,17,3,NULL,'Airport, Kolkata',22.6500000,88.4400000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 20:06:51',NULL,0.00,0.00,'ongoing',NULL),(6,24,3,NULL,'Airport, Kolkata',22.6500000,88.4400000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 20:08:21',NULL,0.00,0.00,'ongoing',NULL),(7,31,3,NULL,'Airport, Kolkata',22.6500000,88.4400000,NULL,NULL,NULL,NULL,NULL,0,'2026-10-31 20:16:31',NULL,0.00,0.00,'ongoing',NULL);
/*!40000 ALTER TABLE `trips` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('customer','driver','owner','admin') NOT NULL DEFAULT 'customer',
  `avatar` varchar(300) DEFAULT NULL,
  `fcm_token` text DEFAULT NULL,
  `phone_verified` tinyint(1) NOT NULL DEFAULT 0,
  `status` enum('active','banned','pending') NOT NULL DEFAULT 'active',
  `preferred_language` varchar(10) DEFAULT 'en',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone` (`phone`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Admin DriveMate','admin@drivemate.com','9000000000','$2y$10$AED/4iy.Ggl7AfJ5yDfKd.nLR1YmrcxjRbJNs8EPBem16.L8xOQtC','admin',NULL,NULL,0,'active','en','2026-10-03 15:46:39'),(2,'Rahul Sharma (Customer)','customer@drivemate.com','9876543210','$2y$10$AED/4iy.Ggl7AfJ5yDfKd.nLR1YmrcxjRbJNs8EPBem16.L8xOQtC','customer',NULL,NULL,0,'active','en','2026-10-03 15:46:39'),(3,'Rajesh Kumar (Driver)','driver@drivemate.com','9811223344','$2y$10$AED/4iy.Ggl7AfJ5yDfKd.nLR1YmrcxjRbJNs8EPBem16.L8xOQtC','driver',NULL,'fcm_test_token_driver_amitava_8932',0,'active','en','2026-10-03 15:46:39'),(4,'Vikram Singh (Owner)','owner@drivemate.com','9822334455','$2y$10$mzaSC.x69pSY8atltkAZjehNiIN5J7l4LDVhAhvaB2SfpFzbQv2cG','owner',NULL,NULL,0,'active','en','2026-10-03 15:46:39'),(5,'Amit Kumar','amit@example.com','9876500001','$2y$10$6NduokebzgCuri.LlPg4.uI/5dLOI1ubqNckuLhw5uiz.qjLg4kmO','customer',NULL,NULL,0,'active','en','2026-10-08 15:07:54'),(6,'Rohan Das','rohan.user1@example.com','9876500112','$2y$10$87ZH7rLXe8R1eyZQON3SNe5r/sdkKyt0qbaGovdxdFo4/589MXFGK','customer',NULL,NULL,0,'active','en','2026-10-08 15:39:33'),(7,'Rohan Das','rohan.das@example.com','9876500123','$2y$10$NU4cE0oyGksrB8C9EkLbGeN8rne6fSVFcwdR4tTxnalgzMYRBLyIm','customer',NULL,NULL,0,'active','en','2026-10-08 15:42:56'),(8,'samiran','sd8659225@gmail.com','8348708261','$2y$10$76MIaDFawob/bvLgNaXw..RfFBYo16pfBm/WPaov/CnszhtP7C0/q','customer',NULL,NULL,0,'active','en','2026-10-28 15:28:31'),(9,'Amitava Roy (Chauffeur)','amitava.driver@drivemate.com','9830012345','\\/4iy.Ggl7AfJ5yDfKd.nLR1YmrcxjRbJNs8EPBem16.L8xOQtC','driver',NULL,NULL,0,'active','en','2026-10-31 18:11:40'),(10,'Animesh Barman','animesh.driver@drivemate.com','9830098765','\\/4iy.Ggl7AfJ5yDfKd.nLR1YmrcxjRbJNs8EPBem16.L8xOQtC','driver',NULL,NULL,0,'active','en','2026-10-31 18:11:40');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vehicles`
--

DROP TABLE IF EXISTS `vehicles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vehicles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `owner_id` int(10) unsigned NOT NULL,
  `type` varchar(50) NOT NULL,
  `model` varchar(100) NOT NULL,
  `number_plate` varchar(30) NOT NULL,
  `color` varchar(30) DEFAULT NULL,
  `capacity` tinyint(4) DEFAULT 4,
  `status` enum('active','inactive') DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `number_plate` (`number_plate`),
  KEY `owner_id` (`owner_id`),
  CONSTRAINT `vehicles_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vehicles`
--

LOCK TABLES `vehicles` WRITE;
/*!40000 ALTER TABLE `vehicles` DISABLE KEYS */;
INSERT INTO `vehicles` VALUES (1,4,'sedan','Maruti Suzuki Dzire (Manual)','WB-01-AB-1234','Pearl White',4,'active','2026-10-03 15:46:39'),(2,4,'suv','Hyundai Creta SX (Automatic)','WB-01-CD-5678','Phantom Black',5,'active','2026-10-03 15:46:39'),(3,4,'luxury','Toyota Innova Crysta (Diesel)','WB-01-EF-9012','Silver Metallic',7,'active','2026-10-03 15:46:39');
/*!40000 ALTER TABLE `vehicles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallet_transactions`
--

DROP TABLE IF EXISTS `wallet_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wallet_transactions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `wallet_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `type` enum('credit','debit') NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `reference_type` varchar(50) DEFAULT 'topup',
  `reference_id` varchar(100) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `balance_after` decimal(10,2) NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `wallet_id` (`wallet_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `wallet_transactions_ibfk_1` FOREIGN KEY (`wallet_id`) REFERENCES `wallets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `wallet_transactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallet_transactions`
--

LOCK TABLES `wallet_transactions` WRITE;
/*!40000 ALTER TABLE `wallet_transactions` DISABLE KEYS */;
INSERT INTO `wallet_transactions` VALUES (1,1,2,'credit',1000.00,'welcome_bonus','INIT_1000','DriveMate Welcome Wallet Credit',1000.00,'2026-10-03 15:46:39'),(2,3,1,'credit',200.00,'topup','TOP_4D329C32BFEA','Wallet Top-up',200.00,'2026-10-03 15:46:54'),(3,3,1,'credit',500.00,'topup','TOP_992C721CE3ED','Wallet Top-up',700.00,'2026-10-08 15:08:02'),(4,3,1,'debit',150.00,'booking_payment','1','Payment for Booking #1',550.00,'2026-10-08 15:08:02'),(5,1,2,'credit',500.00,'refund','1','Refund for cancelled booking',1500.00,'2026-10-08 15:08:03'),(6,3,1,'debit',150.00,'booking_payment','1','Payment for Booking #1',400.00,'2026-10-08 15:33:15');
/*!40000 ALTER TABLE `wallet_transactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallets`
--

DROP TABLE IF EXISTS `wallets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wallets` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `balance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` varchar(10) NOT NULL DEFAULT 'INR',
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `wallets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallets`
--

LOCK TABLES `wallets` WRITE;
/*!40000 ALTER TABLE `wallets` DISABLE KEYS */;
INSERT INTO `wallets` VALUES (1,2,1500.00,'INR','2026-10-03 15:46:39','2026-10-08 15:08:03'),(2,3,500.00,'INR','2026-10-03 15:46:39','2026-10-03 15:46:39'),(3,1,400.00,'INR','2026-10-03 15:46:54','2026-10-08 15:33:15');
/*!40000 ALTER TABLE `wallets` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-31 20:26:01
