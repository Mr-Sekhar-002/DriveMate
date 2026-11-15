<?php
// controllers/SupportController.php — Support tickets & complaints management

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class SupportController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /support/faqs (Public / Auth) — Real Support Contact & Categorized FAQs
    public function getFaqs(): void {
        $contact = [
            'helpline'     => '+91 98000 11223',
            'toll_free'    => '1800-DRIVEMATE',
            'emergency'    => '112',
            'email'        => 'support@drivemate.com',
            'office'       => 'Station Road, Kakdwip Central, South 24 Parganas, West Bengal 743347',
            'hours'        => '24x7 Customer Support & Emergency Dispatch',
        ];

        $faqs = [
            [
                'id'       => 1,
                'category' => 'booking',
                'question' => 'How do I hire a verified chauffeur?',
                'answer'   => 'Select "Hire a Driver" from your home dashboard, choose your travel type (One-Way, Round-Trip, or Hourly), specify your pickup and destination in Kakdwip or regional routes, review the estimated fare, and submit your booking. A verified chauffeur accepts and arrives promptly.'
            ],
            [
                'id'       => 2,
                'category' => 'booking',
                'question' => 'Can I negotiate the ride fare with my chauffeur?',
                'answer'   => 'Yes. DriveMate supports Two-Way Fare Negotiation. You can submit a reasonable counter-offer. When both parties agree, the negotiated fare is locked for your trip and itemized on your final GST tax invoice.'
            ],
            [
                'id'       => 3,
                'category' => 'payment',
                'question' => 'How does payment and QR code settlement work?',
                'answer'   => 'When a trip is completed by the chauffeur, DriveMate computes the exact mutually accepted fare plus 5% GST. A secure UPI QR code and payment link are generated instantly for Google Pay, PhonePe, Paytm, and BHIM. Alternatively, you can settle with cash directly.'
            ],
            [
                'id'       => 4,
                'category' => 'payment',
                'question' => 'How do I access and download my GST Tax Invoice?',
                'answer'   => 'Open "Invoices & Receipts" from the bottom navigation or view any completed trip summary. Tap "View Invoice" to inspect itemized tax amounts (Subtotal, CGST 2.5%, SGST 2.5%, Platform Fee) and tap "Share Invoice" or "Download PDF Receipt" to save it.'
            ],
            [
                'id'       => 5,
                'category' => 'trip',
                'question' => 'How does live ride tracking and map navigation work?',
                'answer'   => 'The live tracking screen renders actual OpenStreetMap tiles with genuine OSRM routing geometry. The camera automatically focuses on your route and displays the chauffeur\'s actual GPS location. No fake or simulated telemetry is ever shown.'
            ],
            [
                'id'       => 6,
                'category' => 'trip',
                'question' => 'What is the Start OTP and when should I share it?',
                'answer'   => 'Every booking includes a confidential 4-digit verification OTP. For your safety, share this OTP with your chauffeur only after you have met in person and are ready to begin the journey.'
            ],
            [
                'id'       => 7,
                'category' => 'driver',
                'question' => 'How can a driver contact the assigned customer?',
                'answer'   => 'On the Driver Dashboard, tap the "Call Customer" button to open the Android phone dialer with the customer\'s verified mobile number. The driver then manually presses the call button in the phone dialer.'
            ],
            [
                'id'       => 8,
                'category' => 'driver',
                'question' => 'How does a driver accept bookings and receive payouts?',
                'answer'   => 'When online, the driver receives nearby booking requests with pickup/destination coordinates. Once a ride is completed and verified, earnings are recorded to the driver\'s verified earnings balance.'
            ],
            [
                'id'       => 9,
                'category' => 'app',
                'question' => 'What should I do in an emergency situation?',
                'answer'   => 'Tap the red "SOS Safety" button on the live tracking screen or driver dashboard to instantly connect to the National Emergency Helpline (112) or call our 24x7 Operations Support Help Desk.'
            ],
        ];

        Response::success([
            'contact' => $contact,
            'faqs'    => $faqs,
        ]);
    }

    // POST /support/create-ticket (Auth required)
    public function createTicket(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $subject   = trim($data['subject'] ?? '');
        $category  = $data['category'] ?? 'other'; // booking, payment, trip, driver, vehicle, app, other
        $message   = trim($data['message'] ?? '');
        $bookingId = !empty($data['booking_id']) ? (int)$data['booking_id'] : null;

        if (!$subject || !$message) {
            Response::error('Subject and message are required', 400);
        }

        // Validate booking ownership if booking_id was provided
        if ($bookingId !== null) {
            $bStmt = $this->db->prepare("SELECT id FROM bookings WHERE id = ? AND (user_id = ? OR driver_id = ?)");
            $bStmt->execute([$bookingId, $userId, $userId]);
            if (!$bStmt->fetch()) {
                Response::error('Invalid booking reference: booking not found or does not belong to you', 400);
            }
        }

        $stmt = $this->db->prepare("
            INSERT INTO support_tickets (user_id, booking_id, subject, category, message, status, created_at)
            VALUES (?, ?, ?, ?, ?, 'open', NOW())
        ");
        $stmt->execute([$userId, $bookingId, $subject, $category, $message]);
        $ticketId = (int)$this->db->lastInsertId();

        Response::success([
            'ticket_id'  => $ticketId,
            'status'     => 'open',
            'created_at' => date('Y-m-d H:i:s')
        ], 'Support ticket submitted successfully', 201);
    }

    // GET /support/my-tickets (Auth required)
    public function myTickets(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];

        $stmt = $this->db->prepare("
            SELECT st.*, b.type AS booking_type, b.pickup_location, b.destination, b.total_amount, b.status AS booking_status
            FROM support_tickets st
            LEFT JOIN bookings b ON st.booking_id = b.id
            WHERE st.user_id = ?
            ORDER BY st.created_at DESC
        ");
        $stmt->execute([$userId]);
        $tickets = $stmt->fetchAll();
        Response::success($tickets);
    }

    // GET /admin/support/tickets (Admin only)
    public function listAll(): void {
        AuthMiddleware::requireRole('admin');

        $status = $_GET['status'] ?? null;
        $sql = "
            SELECT st.*, u.name AS user_name, u.email AS user_email, u.phone AS user_phone, u.role AS user_role
            FROM support_tickets st
            JOIN users u ON st.user_id = u.id
        ";
        $params = [];
        if ($status) {
            $sql .= " WHERE st.status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY st.created_at DESC";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        Response::success($stmt->fetchAll());
    }

    // PUT /admin/support/reply (Admin only)
    public function replyTicket(): void {
        AuthMiddleware::requireRole('admin');
        $data = Response::body();

        $ticketId = (int)($data['ticket_id'] ?? 0);
        $reply    = trim($data['admin_reply'] ?? '');
        $status   = $data['status'] ?? 'resolved';

        if (!$ticketId || !$reply) {
            Response::error('ticket_id and admin_reply are required');
        }

        $stmt = $this->db->prepare("
            UPDATE support_tickets 
            SET admin_reply = ?, status = ?, updated_at = NOW() 
            WHERE id = ?
        ");
        $stmt->execute([$reply, $status, $ticketId]);

        Response::success([], 'Ticket reply saved and status updated');
    }
}
