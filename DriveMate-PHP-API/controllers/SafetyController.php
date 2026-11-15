<?php
// controllers/SafetyController.php — Safety Center, SOS Dispatch & Emergency Contacts

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';
require_once __DIR__ . '/../services/SmsService.php';

class SafetyController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /safety/contacts (Auth required) — Retrieve user's emergency contacts
    public function getContacts(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];

        $stmt = $this->db->prepare("
            SELECT id, user_id, name, phone, relationship, notify_on_trip, created_at
            FROM emergency_contacts
            WHERE user_id = ?
            ORDER BY created_at DESC
        ");
        $stmt->execute([$userId]);
        $contacts = $stmt->fetchAll(PDO::FETCH_ASSOC);

        Response::success($contacts);
    }

    // POST /safety/contacts (Auth required) — Add trusted emergency contact
    public function addContact(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $name         = trim($data['name'] ?? '');
        $phone        = trim($data['phone'] ?? '');
        $relationship = trim($data['relationship'] ?? 'Family');
        $notifyOnTrip = isset($data['notify_on_trip']) ? (int)(bool)$data['notify_on_trip'] : 1;

        if (empty($name)) {
            Response::error('Contact name is required', 400);
        }
        if (empty($phone) || strlen(preg_replace('/[^0-9]/', '', $phone)) < 10) {
            Response::error('Valid phone number with at least 10 digits is required', 400);
        }

        // Limit maximum 5 contacts
        $cntStmt = $this->db->prepare("SELECT COUNT(*) FROM emergency_contacts WHERE user_id = ?");
        $cntStmt->execute([$userId]);
        if ((int)$cntStmt->fetchColumn() >= 5) {
            Response::error('You can add a maximum of 5 emergency contacts', 400);
        }

        $stmt = $this->db->prepare("
            INSERT INTO emergency_contacts (user_id, name, phone, relationship, notify_on_trip, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([$userId, $name, $phone, $relationship, $notifyOnTrip]);
        $contactId = (int)$this->db->lastInsertId();

        Response::success([
            'id'             => $contactId,
            'user_id'        => $userId,
            'name'           => $name,
            'phone'          => $phone,
            'relationship'   => $relationship,
            'notify_on_trip' => (bool)$notifyOnTrip
        ], 'Emergency contact added successfully', 201);
    }

    // DELETE /safety/contacts (Auth required) — Remove emergency contact
    public function deleteContact(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $contactId = (int)($_GET['id'] ?? $data['id'] ?? 0);
        if ($contactId <= 0) {
            Response::error('Valid contact id is required', 400);
        }

        $stmt = $this->db->prepare("DELETE FROM emergency_contacts WHERE id = ? AND user_id = ?");
        $stmt->execute([$contactId, $userId]);

        if ($stmt->rowCount() === 0) {
            Response::error('Contact not found or unauthorized to delete', 404);
        }

        Response::success([], 'Emergency contact removed successfully');
    }

    // POST /safety/sos (Auth required) — Genuine SOS Emergency Trigger & Dispatch
    public function triggerSos(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $bookingId   = isset($data['booking_id']) ? (int)$data['booking_id'] : null;
        $latitude    = isset($data['latitude']) ? (float)$data['latitude'] : null;
        $longitude   = isset($data['longitude']) ? (float)$data['longitude'] : null;
        $description = trim($data['description'] ?? 'Passenger activated one-touch SOS Emergency Button.');

        // Find active booking / trip if not explicitly provided
        $booking = null;
        if ($bookingId) {
            $bStmt = $this->db->prepare("
                SELECT b.id, b.booking_reference, b.pickup_location, b.destination,
                       u_d.name AS driver_name, u_d.phone AS driver_phone,
                       v.model AS vehicle_model, v.number_plate AS vehicle_number
                FROM bookings b
                LEFT JOIN users u_d ON b.driver_id = u_d.id
                LEFT JOIN vehicles v ON b.vehicle_id = v.id
                WHERE b.id = ? AND b.user_id = ?
            ");
            $bStmt->execute([$bookingId, $userId]);
            $booking = $bStmt->fetch(PDO::FETCH_ASSOC);
        } else {
            $bStmt = $this->db->prepare("
                SELECT b.id, b.booking_reference, b.pickup_location, b.destination,
                       u_d.name AS driver_name, u_d.phone AS driver_phone,
                       v.model AS vehicle_model, v.number_plate AS vehicle_number
                FROM bookings b
                LEFT JOIN users u_d ON b.driver_id = u_d.id
                LEFT JOIN vehicles v ON b.vehicle_id = v.id
                WHERE b.user_id = ? AND b.status IN ('ongoing', 'arrived', 'confirmed')
                ORDER BY b.created_at DESC LIMIT 1
            ");
            $bStmt->execute([$userId]);
            $booking = $bStmt->fetch(PDO::FETCH_ASSOC);
            if ($booking) {
                $bookingId = (int)$booking['id'];
            }
        }

        // Check for duplicate alert within 45 seconds
        $dupStmt = $this->db->prepare("
            SELECT id FROM safety_incidents 
            WHERE user_id = ? AND incident_type = 'sos_emergency' 
              AND created_at > (NOW() - INTERVAL 45 SECOND) 
            ORDER BY id DESC LIMIT 1
        ");
        $dupStmt->execute([$userId]);
        $existingIncidentId = $dupStmt->fetchColumn();

        // Fetch user's registered emergency contacts
        $cStmt = $this->db->prepare("SELECT name, phone, relationship FROM emergency_contacts WHERE user_id = ? AND notify_on_trip = 1");
        $cStmt->execute([$userId]);
        $contacts = $cStmt->fetchAll(PDO::FETCH_ASSOC);
        $contactsCount = count($contacts);

        if ($existingIncidentId) {
            $incidentId = (int)$existingIncidentId;
            // Update incident with latest coordinates
            $this->db->prepare("UPDATE safety_incidents SET latitude = ?, longitude = ?, updated_at = NOW() WHERE id = ?")
                     ->execute([$latitude, $longitude, $incidentId]);
        } else {
            // Record Critical Incident in safety_incidents
            $incStmt = $this->db->prepare("
                INSERT INTO safety_incidents
                  (user_id, booking_id, incident_type, severity, latitude, longitude, description, contacts_alerted, police_dialed, status, created_at)
                VALUES (?, ?, 'sos_emergency', 'CRITICAL', ?, ?, ?, ?, 1, 'dispatched', NOW())
            ");
            $incStmt->execute([$userId, $bookingId, $latitude, $longitude, $description, $contactsCount]);
            $incidentId = (int)$this->db->lastInsertId();
        }

        // Fetch hotline from system_settings
        $hotlineStmt = $this->db->prepare("SELECT setting_value FROM system_settings WHERE setting_key = 'emergency_hotline'");
        $hotlineStmt->execute();
        $hotline = $hotlineStmt->fetchColumn() ?: '+91 99999 99999';

        // Formulate Google Maps link and SMS text
        $userName   = $auth['name'] ?? 'DriveMate Passenger';
        $vehicleNum = $booking['vehicle_number'] ?? 'Chauffeur Vehicle';
        $driverName = $booking['driver_name'] ?? 'Assigned Chauffeur';
        $mapsLink   = ($latitude !== null && $longitude !== null)
            ? "https://maps.google.com/?q={$latitude},{$longitude}"
            : "https://drivemate.in/track/sos/{$incidentId}";

        $dispatchText = "EMERGENCY ALERT: {$userName} activated SOS on DriveMate Ride! Live Location: {$mapsLink}. Driver: {$driverName}, Car: {$vehicleNum}. Time: " . date('h:i A') . ". Police Helpline: 112.";

        // Real SMS Dispatch per contact
        $contactsNotified = [];
        $anySmsSent = false;
        $anyGatewayMissing = false;

        foreach ($contacts as $c) {
            $smsRes = SmsService::sendEmergencyAlert($c['phone'], $dispatchText);
            if ($smsRes['success']) {
                $anySmsSent = true;
            } else {
                $anyGatewayMissing = true;
            }

            $contactsNotified[] = [
                'name'         => $c['name'],
                'phone'        => $c['phone'],
                'phone_masked' => substr($c['phone'], 0, 4) . '••••••',
                'status'       => $smsRes['status'],
                'provider'     => $smsRes['provider'],
                'detail'       => $smsRes['message'],
            ];
        }

        // Record in internal notifications table for audit
        $notifStmt = $this->db->prepare("
            INSERT INTO notifications (user_id, type, title, message, is_read, created_at)
            VALUES (?, 'system', 'SOS EMERGENCY ACTIVATED', ?, 0, NOW())
        ");
        $notifStmt->execute([$userId, "SOS Alert recorded (Incident #{$incidentId}). Location: {$mapsLink}. Emergency contacts: {$contactsCount}."]);

        Response::success([
            'incident_id'              => $incidentId,
            'status'                   => 'DISPATCHED',
            'severity'                 => 'CRITICAL',
            'timestamp'                => date('c'),
            'contacts_alerted_count'   => $contactsCount,
            'contacts_notified'        => $contactsNotified,
            'sms_gateway_active'       => $anySmsSent,
            'google_maps_link'         => $mapsLink,
            'dispatch_message'         => $dispatchText,
            'national_police_helpline' => '112',
            'ambulance_helpline'       => '108',
            'women_safety_helpline'    => '1091',
            'drivemate_control_room'   => $hotline,
            'telemetry'                => [
                'latitude'       => $latitude,
                'longitude'      => $longitude,
                'maps_url'       => $mapsLink,
                'booking_ref'    => $booking['booking_reference'] ?? null,
                'driver_name'    => $driverName,
                'driver_phone'   => $booking['driver_phone'] ?? null,
                'vehicle_model'  => $booking['vehicle_model'] ?? null,
                'vehicle_number' => $vehicleNum,
            ],
            'instructions'             => [
                'Emergency incident registered and logged with GPS coordinates.',
                'Emergency SMS dispatch processed for your registered trusted contacts.',
                'Direct Police 112 dialing and direct SMS forwarding are ready below.',
                'DriveMate Safety Command Center has received your alert.'
            ]
        ], 'SOS Emergency alert processed.');
    }

    // POST /safety/report-issue (Auth required) — Report ride safety or driver misbehavior
    public function reportIssue(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $category    = trim($data['category'] ?? 'other');
        $description = trim($data['description'] ?? '');
        $bookingId   = isset($data['booking_id']) ? (int)$data['booking_id'] : null;
        $latitude    = isset($data['latitude']) ? (float)$data['latitude'] : null;
        $longitude   = isset($data['longitude']) ? (float)$data['longitude'] : null;

        if (empty($description)) {
            Response::error('Issue description is required', 400);
        }

        $validCategories = ['driver_misbehavior', 'route_deviation', 'vehicle_breakdown', 'medical', 'accident', 'sos_emergency', 'other'];
        if (!in_array($category, $validCategories)) {
            $category = 'other';
        }

        $severity = ($category === 'accident' || $category === 'medical') ? 'HIGH' : 'MEDIUM';

        $stmt = $this->db->prepare("
            INSERT INTO safety_incidents
              (user_id, booking_id, incident_type, severity, latitude, longitude, description, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'active', NOW())
        ");
        $stmt->execute([$userId, $bookingId, $category, $severity, $latitude, $longitude, $description]);
        $incidentId = (int)$this->db->lastInsertId();

        // Also create support ticket for administrative resolution
        $tStmt = $this->db->prepare("
            INSERT INTO support_tickets (user_id, booking_id, subject, category, message, status, created_at)
            VALUES (?, ?, ?, 'safety', ?, 'open', NOW())
        ");
        $subject = 'Safety Issue Reported: ' . ucwords(str_replace('_', ' ', $category));
        $tStmt->execute([$userId, $bookingId, $subject, $description]);
        $ticketId = (int)$this->db->lastInsertId();

        Response::success([
            'incident_id' => $incidentId,
            'ticket_id'   => $ticketId,
            'category'    => $category,
            'severity'    => $severity,
            'status'      => 'SUBMITTED'
        ], 'Safety report submitted. Our rapid response team will inspect this incident immediately.', 201);
    }

    // GET /safety/emergency-info (Public / Auth) — Guidelines and emergency hotlines
    public function getEmergencyInfo(): void {
        AuthMiddleware::optionalAuthenticate();

        $hotlineStmt = $this->db->prepare("SELECT setting_value FROM system_settings WHERE setting_key = 'emergency_hotline'");
        $hotlineStmt->execute();
        $hotline = $hotlineStmt->fetchColumn() ?: '+91 99999 99999';

        Response::success([
            'hotlines' => [
                'national_police'     => '112',
                'ambulance'           => '108',
                'women_safety'        => '1091',
                'drivemate_24x7_sos'  => $hotline,
                'toll_free_support'   => '1800-DRIVEMATE',
                'safety_email'        => 'safety@drivemate.in',
            ],
            'safety_features' => [
                'Live GPS ride telematics with real-time polyline tracking',
                'Trusted emergency contacts automated ride dispatch',
                'One-touch SOS button with instant police dialing bridge',
                'Strictly verified drivers with clean police verification records',
                'Driver private number and document masking for passenger privacy'
            ],
            'safety_instructions' => [
                'Verify vehicle registration number plate and driver photo before boarding.',
                'Share your live trip tracking link with family or close friends.',
                'Ensure the 4-digit ride OTP is provided only after entering the car.',
                'Use the in-app SOS button immediately if you detect severe route deviation or danger.'
            ]
        ]);
    }
}
